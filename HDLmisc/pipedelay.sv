/*!
 * \file pipedelay.sv
 * \brief 流水线数据同步保持器
 * \details 本模块用于按延时输出计划比特位图对输入数据做时序延迟
 * \author 钟勇
 * \depends miscs, packconv
 */
`include "miscs.svh"
/*! \brief 流水线数据同步保持器 */
module pipedelay_taps #(
   parameter int              DATABITW  = 8,       ///< 待流水线延迟的数据位宽
   parameter bit[DATABITW-1:0]INITVAL   = {((DATABITW>0?DATABITW:1)){1'b0}},
   parameter int signed       DELAYTAPS = 0        ///< 延迟输出时钟拍数，必须大于等于0
) (
   input  bit                 clk,                 ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                aclr,                ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                sclr,                ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                clken,               ///< 模块使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] x,                   ///< 流水线待同步的数据信号
   output logic[DATABITW-1:0] pipe_x               ///< 经流水线同步后的数据信号
);
   initial if (DATABITW <= 0) $error("zero DATABITW found!");
   genvar i; generate if (DELAYTAPS > 1 && (DATABITW*DELAYTAPS) >= miscs::allbits2ram && ((DATABITW/DELAYTAPS) < 4 || ((DATABITW/DELAYTAPS) == 4 && (DATABITW%DELAYTAPS) == 0))) begin
      logic[DATABITW-1:0] pipe_array[DELAYTAPS-1:0] = '{(DELAYTAPS){INITVAL}};
      initial begin
         automatic int ii;
         for (ii = 0; ii < DELAYTAPS; ii++) pipe_array[ii] = INITVAL;
      end
      for (i = 0; i < DELAYTAPS; i++) begin
         wire[DATABITW-1:0]ipx;
         if (i == 0) assign ipx = x;
         else        assign ipx = pipe_array[i-1];
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if     (aclr) pipe_array[i] <= INITVAL;
            else if(sclr) pipe_array[i] <= INITVAL;
            else if(clken)pipe_array[i] <= ipx;
            else          pipe_array[i] <= pipe_array[i];
         end
      end
      assign pipe_x = pipe_array[DELAYTAPS-1];
   end
   else if (DELAYTAPS > 0) begin
      // 数据位宽相比RAM深度比例过大时， Vivado 2017 布设分布式RAM将会出错，而此时 Vivado 2017 编译器转换的寄存器拍数将与期望拍数不一致，需要手动规避该问题
      logic[DELAYTAPS:1][DATABITW-1:0] pipe_array = {(DELAYTAPS){INITVAL}};
      wire [DELAYTAPS:1][DATABITW-1:0] pa2upd;
      if (DELAYTAPS > 1) assign pa2upd = {pipe_array[DELAYTAPS-1:1], x};
      else               assign pa2upd = x;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) pipe_array <= {(DELAYTAPS){INITVAL}};
         else if (sclr) pipe_array <= {(DELAYTAPS){INITVAL}};
         else           pipe_array <= clken ? pa2upd : pipe_array;
      end
      assign pipe_x = pipe_array[DELAYTAPS];
   end
   else begin
      assign pipe_x = x;
   end
   endgenerate
endmodule
module pipedelay_taps_packedarray #(
   parameter int                             DATABITW  = 8, ///< 待流水线延迟的数组数据位宽
   parameter int                             ARRAYSIZ  = 2, ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][DATABITW-1:0] INITVAL   = {(ARRAYSIZ){{(DATABITW){1'b0}}}},
   parameter int signed                      DELAYTAPS = 0  ///< 延迟输出时钟拍数，必须大于等于0
) (clk, aclr, sclr, clken, x, pipe_x);
   input  bit                             clk;     ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            aclr;    ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            sclr;    ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            clken;  ///< 模块使能信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]x;       ///< 流水线待同步的数组数据信号
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]pipe_x;  ///< 经流水线同步后的数组数据信号

   wire[ARRAYSIZ*DATABITW-1:0]ix, px;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) cmbi(
      .in   (x ),
      .out  (ix)
   );
   pipedelay_taps #(
      .DATABITW   (DATABITW*ARRAYSIZ),
      .INITVAL    (INITVAL          ),
      .DELAYTAPS  (DELAYTAPS        )
   ) pdti(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .x       (ix      ),
      .pipe_x  (px      )
   );
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) splti(
      .in   (px      ),
      .out  (pipe_x  )
   );
endmodule
module pipedelay_taps_packedarray_extd #(
   parameter int                             DATABITW  = 8,      ///< 待流水线延迟的数组数据位宽
   parameter int                             ARRAYSIZ  = 2,      ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][DATABITW-1:0] INITVAL   = {(ARRAYSIZ){{(DATABITW){1'b0}}}},
   parameter int                             EXTDBITW  = 1,      ///< 待流水线延迟的额外数据位宽
   parameter bit[EXTDBITW-1:0]               INITEXTD  = {(EXTDBITW){1'b0}},
   parameter int signed                      DELAYTAPS = 0       ///< 延迟输出时钟拍数，必须大于等于0
) (clk, aclr, sclr, clken, x, ex, pipe_x, pipe_ex);
   input  bit                             clk;     ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            aclr;    ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            sclr;    ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            clken;  ///< 模块使能信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]x;       ///< 流水线待同步的数组数据信号
   input  wire[EXTDBITW-1:0]              ex;      ///< 流水线待同步的额外数据信号
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]pipe_x;  ///< 经流水线同步后的数组数据信号
   output wire[EXTDBITW-1:0]              pipe_ex; ///< 经流水线同步后的额外数据信号

   wire[EXTDBITW+ARRAYSIZ*DATABITW-1:0]ix, px;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) cmbi(
      .in   (x                         ),
      .out  (ix[ARRAYSIZ*DATABITW-1:0] )
   );
   assign ix[EXTDBITW+ARRAYSIZ*DATABITW-1:ARRAYSIZ*DATABITW] = ex;
   pipedelay_taps #(
      .DATABITW   (EXTDBITW+DATABITW*ARRAYSIZ),
      .INITVAL    ({INITEXTD, INITVAL}       ),
      .DELAYTAPS  (DELAYTAPS                 )
   ) pdti(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .x       (ix      ),
      .pipe_x  (px      )
   );
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) splti(
      .in   (px[ARRAYSIZ*DATABITW-1:0] ),
      .out  (pipe_x                    )
   );
   assign pipe_ex = px[EXTDBITW+ARRAYSIZ*DATABITW-1:ARRAYSIZ*DATABITW];
endmodule
module pipedelay_taps_unpackedarray #(
   parameter int                             DATABITW  = 8,      ///< 待流水线延迟的数据位宽
   parameter int                             ARRAYSIZ  = 2,      ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][DATABITW-1:0] INITVAL   = {(ARRAYSIZ){{(DATABITW){1'b0}}}},
   parameter int signed                      DELAYTAPS = 0       ///< 延迟输出时钟拍数，必须大于等于0
) (clk, aclr, sclr, clken, x, pipe_x);
   input  bit                 clk;                 ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                clken;              ///< 模块使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] x     [ARRAYSIZ-1:0];///< 流水线待同步的数据信号
   output wire [DATABITW-1:0] pipe_x[ARRAYSIZ-1:0];///< 经流水线同步后的数据信号

   wire[ARRAYSIZ-1:0][DATABITW-1:0]xc, piped_xc;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aci(
      .in   (x ),
      .out  (xc)
   );
   pipedelay_taps_packedarray #(
      .DATABITW   (DATABITW   ),
      .ARRAYSIZ   (ARRAYSIZ   ),
      .INITVAL    (INITVAL    ),
      .DELAYTAPS  (DELAYTAPS  )
   ) pdtpi(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .x       (xc      ),
      .pipe_x  (piped_xc)
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aco(
      .in   (piped_xc),
      .out  (pipe_x  )
   );
endmodule
module pipedelay_taps_unpackedarray_extd #(
   parameter int                             DATABITW  = 8,      ///< 待流水线延迟的数组数据位宽
   parameter int                             ARRAYSIZ  = 2,      ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][DATABITW-1:0] INITVAL   = {(ARRAYSIZ){{(DATABITW){1'b0}}}},
   parameter int                             EXTDBITW  = 1,      ///< 待流水线延迟的额外数据位宽
   parameter bit[EXTDBITW-1:0]               INITEXTD  = {(EXTDBITW){1'b0}},
   parameter int signed                      DELAYTAPS = 0       ///< 延迟输出时钟拍数，必须大于等于0
) (clk, aclr, sclr, clken, x, ex, pipe_x, pipe_ex);
   input  bit                 clk;                 ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                clken;              ///< 模块使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] x     [ARRAYSIZ-1:0];///< 流水线待同步的数组数据信号
   input  wire [EXTDBITW-1:0] ex;                  ///< 流水线待同步的额外数据信号
   output wire [DATABITW-1:0] pipe_x[ARRAYSIZ-1:0];///< 经流水线同步后的数组数据信号
   output wire [EXTDBITW-1:0] pipe_ex;             ///< 经流水线同步后的额外数据信号

   wire[ARRAYSIZ-1:0][DATABITW-1:0]xc, piped_xc;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aci(
      .in   (x ),
      .out  (xc)
   );
   pipedelay_taps_packedarray_extd #(
      .DATABITW   (DATABITW   ),
      .ARRAYSIZ   (ARRAYSIZ   ),
      .INITVAL    (INITVAL    ),
      .EXTDBITW   (EXTDBITW   ),
      .INITEXTD   (INITEXTD   ),
      .DELAYTAPS  (DELAYTAPS  )
   ) pdtpi(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .x       (xc      ),
      .ex      (ex      ),
      .pipe_x  (piped_xc),
      .pipe_ex (pipe_ex )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aco(
      .in   (piped_xc),
      .out  (pipe_x  )
   );
endmodule
module pipedelay_taps_packedunit_packedarray #(
   parameter int                                            DATABITW  = 8, ///< 待流水线延迟的数组数据位宽
   parameter int                                            AUNITSIZ  = 2, ///< 待流水线延迟的数组单元个数
   parameter int                                            ARRAYSIZ  = 2, ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0]  INITVAL   = {(ARRAYSIZ){{(AUNITSIZ){{(DATABITW){1'b0}}}}}},
   parameter int signed                                     DELAYTAPS = 0  ///< 延迟输出时钟拍数，必须大于等于0
) (clk, aclr, sclr, clken, x, pipe_x);
   input  bit                                            clk;     ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                                           aclr;    ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                                           sclr;    ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                                           clken;  ///< 模块使能信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] x;       ///< 流水线待同步的数组数据信号
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] pipe_x;  ///< 经流水线同步后的数组数据信号

   wire[ARRAYSIZ*AUNITSIZ*DATABITW-1:0]ix, px;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) cmbi(
      .in   (x ),
      .out  (ix)
   );
   pipedelay_taps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ),
      .INITVAL    (INITVAL                   ),
      .DELAYTAPS  (DELAYTAPS                 )
   ) pdti(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .x       (ix      ),
      .pipe_x  (px      )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) splti(
      .in   (px      ),
      .out  (pipe_x  )
   );
endmodule
module pipedelay_taps_packedunit_packedarray_extd #(
   parameter int                                            DATABITW  = 8, ///< 待流水线延迟的数组数据位宽
   parameter int                                            AUNITSIZ  = 2, ///< 待流水线延迟的数组单元个数
   parameter int                                            ARRAYSIZ  = 2, ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0]  INITVAL   = {(ARRAYSIZ){{(AUNITSIZ){{(DATABITW){1'b0}}}}}},
   parameter int                                            EXTDBITW  = 1, ///< 待流水线延迟的额外数据位宽
   parameter bit[EXTDBITW-1:0]                              INITEXTD  = {(EXTDBITW){1'b0}},
   parameter int signed                                     DELAYTAPS = 0  ///< 延迟输出时钟拍数，必须大于等于0
) (clk, aclr, sclr, clken, x, ex, pipe_x, pipe_ex);
   input  bit                                            clk;     ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                                           aclr;    ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                                           sclr;    ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                                           clken;  ///< 模块使能信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] x;       ///< 流水线待同步的数组数据信号
   input  wire[EXTDBITW-1:0]                             ex;      ///< 流水线待同步的额外数据信号
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] pipe_x;  ///< 经流水线同步后的数组数据信号
   output wire[EXTDBITW-1:0]                             pipe_ex; ///< 经流水线同步后的额外数据信号

   wire[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:0]ix, px;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) cmbi(
      .in   (x                                  ),
      .out  (ix[ARRAYSIZ*AUNITSIZ*DATABITW-1:0] )
   );
   assign ix[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW] = ex;
   pipedelay_taps #(
      .DATABITW   (EXTDBITW+DATABITW*AUNITSIZ*ARRAYSIZ),
      .INITVAL    ({INITEXTD, INITVAL}                ),
      .DELAYTAPS  (DELAYTAPS                          )
   ) pdti(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .x       (ix      ),
      .pipe_x  (px      )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) splti(
      .in   (px[ARRAYSIZ*AUNITSIZ*DATABITW-1:0] ),
      .out  (pipe_x                             )
   );
   assign pipe_ex = px[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW];
endmodule
module pipedelay_taps_packedunit_unpackedarray #(
   parameter int                                            DATABITW  = 8, ///< 待流水线延迟的数组数据位宽
   parameter int                                            AUNITSIZ  = 2, ///< 待流水线延迟的数组单元个数
   parameter int                                            ARRAYSIZ  = 2, ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0]  INITVAL   = {(ARRAYSIZ){{(AUNITSIZ){{(DATABITW){1'b0}}}}}},
   parameter int signed                                     DELAYTAPS = 0  ///< 延迟输出时钟拍数，必须大于等于0
) (clk, aclr, sclr, clken, x, pipe_x);
   input  bit                             clk;                 ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            aclr;                ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            sclr;                ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            clken;              ///< 模块使能信号，高电平(1)有效
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]x     [ARRAYSIZ-1:0];///< 流水线待同步的数据信号
   output wire[AUNITSIZ-1:0][DATABITW-1:0]pipe_x[ARRAYSIZ-1:0];///< 经流水线同步后的数据信号

   wire[ARRAYSIZ*AUNITSIZ*DATABITW-1:0]ix, px;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) cmbi(
      .in   (x ),
      .out  (ix)
   );
   pipedelay_taps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ),
      .INITVAL    (INITVAL                   ),
      .DELAYTAPS  (DELAYTAPS                 )
   ) pdti(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .x       (ix      ),
      .pipe_x  (px      )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) splti(
      .in   (px      ),
      .out  (pipe_x  )
   );
endmodule
module pipedelay_taps_packedunit_unpackedarray_extd #(
   parameter int                                            DATABITW  = 8, ///< 待流水线延迟的数组数据位宽
   parameter int                                            AUNITSIZ  = 2, ///< 待流水线延迟的数组单元个数
   parameter int                                            ARRAYSIZ  = 2, ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0]  INITVAL   = {(ARRAYSIZ){{(AUNITSIZ){{(DATABITW){1'b0}}}}}},
   parameter int                                            EXTDBITW  = 1, ///< 待流水线延迟的额外数据位宽
   parameter bit[EXTDBITW-1:0]                              INITEXTD  = {(EXTDBITW){1'b0}},
   parameter int signed                                     DELAYTAPS = 0  ///< 延迟输出时钟拍数，必须大于等于0
) (clk, aclr, sclr, clken, x, ex, pipe_x, pipe_ex);
   input  bit                             clk;                 ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            aclr;                ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            sclr;                ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            clken;              ///< 模块使能信号，高电平(1)有效
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]x     [ARRAYSIZ-1:0];///< 流水线待同步的数组数据信号
   input  wire[EXTDBITW-1:0]              ex;                  ///< 流水线待同步的额外数据信号
   output wire[AUNITSIZ-1:0][DATABITW-1:0]pipe_x[ARRAYSIZ-1:0];///< 经流水线同步后的数组数据信号
   output wire[EXTDBITW-1:0]              pipe_ex;             ///< 经流水线同步后的额外数据信号

   wire[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:0]ix, px;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) cmbi(
      .in   (x                                  ),
      .out  (ix[ARRAYSIZ*AUNITSIZ*DATABITW-1:0] )
   );
   assign ix[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW] = ex;
   pipedelay_taps #(
      .DATABITW   (EXTDBITW+DATABITW*AUNITSIZ*ARRAYSIZ),
      .INITVAL    ({INITEXTD, INITVAL}                ),
      .DELAYTAPS  (DELAYTAPS                          )
   ) pdti(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .x       (ix      ),
      .pipe_x  (px      )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) splti(
      .in   (px[ARRAYSIZ*AUNITSIZ*DATABITW-1:0] ),
      .out  (pipe_x                             )
   );
   assign pipe_ex = px[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW];
endmodule
module pipedelay_taps_unpackedunit_unpackedarray #(
   parameter int                                            DATABITW  = 8, ///< 待流水线延迟的数组数据位宽
   parameter int                                            AUNITSIZ  = 2, ///< 待流水线延迟的数组单元个数
   parameter int                                            ARRAYSIZ  = 2, ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0]  INITVAL   = {(ARRAYSIZ){{(AUNITSIZ){{(DATABITW){1'b0}}}}}},
   parameter int signed                                     DELAYTAPS = 0  ///< 延迟输出时钟拍数，必须大于等于0
) (clk, aclr, sclr, clken, x, pipe_x);
   input  bit                 clk;                                ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                aclr;                               ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                sclr;                               ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                clken;                             ///< 模块使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] x     [ARRAYSIZ-1:0][AUNITSIZ-1:0]; ///< 流水线待同步的数据信号
   output wire [DATABITW-1:0] pipe_x[ARRAYSIZ-1:0][AUNITSIZ-1:0]; ///< 经流水线同步后的数据信号

   wire[ARRAYSIZ*AUNITSIZ*DATABITW-1:0]ix, px;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) cmbi(
      .in   (x ),
      .out  (ix)
   );
   pipedelay_taps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ),
      .INITVAL    (INITVAL                   ),
      .DELAYTAPS  (DELAYTAPS                 )
   ) pdti(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .x       (ix      ),
      .pipe_x  (px      )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) splti(
      .in   (px      ),
      .out  (pipe_x  )
   );
endmodule
module pipedelay_taps_unpackedunit_unpackedarray_extd #(
   parameter int                                            DATABITW  = 8, ///< 待流水线延迟的数组数据位宽
   parameter int                                            AUNITSIZ  = 2, ///< 待流水线延迟的数组单元个数
   parameter int                                            ARRAYSIZ  = 2, ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0]  INITVAL   = {(ARRAYSIZ){{(AUNITSIZ){{(DATABITW){1'b0}}}}}},
   parameter int                                            EXTDBITW  = 1, ///< 待流水线延迟的额外数据位宽
   parameter bit[EXTDBITW-1:0]                              INITEXTD  = {(EXTDBITW){1'b0}},
   parameter int signed                                     DELAYTAPS = 0  ///< 延迟输出时钟拍数，必须大于等于0
) (clk, aclr, sclr, clken, x, ex, pipe_x, pipe_ex);
   input  bit                 clk;                                ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                aclr;                               ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                sclr;                               ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                clken;                             ///< 模块使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] x     [ARRAYSIZ-1:0][AUNITSIZ-1:0]; ///< 流水线待同步的数组数据信号
   input  wire [EXTDBITW-1:0] ex;                                 ///< 流水线待同步的额外数据信号
   output wire [DATABITW-1:0] pipe_x[ARRAYSIZ-1:0][AUNITSIZ-1:0]; ///< 经流水线同步后的数组数据信号
   output wire [EXTDBITW-1:0] pipe_ex;                            ///< 经流水线同步后的额外数据信号

   wire[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:0]ix, px;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) cmbi(
      .in   (x                                  ),
      .out  (ix[ARRAYSIZ*AUNITSIZ*DATABITW-1:0] )
   );
   assign ix[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW] = ex;
   pipedelay_taps #(
      .DATABITW   (EXTDBITW+DATABITW*AUNITSIZ*ARRAYSIZ),
      .INITVAL    ({INITEXTD, INITVAL}                ),
      .DELAYTAPS  (DELAYTAPS                          )
   ) pdti(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .x       (ix      ),
      .pipe_x  (px      )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) splti(
      .in   (px[ARRAYSIZ*AUNITSIZ*DATABITW-1:0] ),
      .out  (pipe_x                             )
   );
   assign pipe_ex = px[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW];
endmodule

module pipedelay_msk_packedarray #(
   parameter int                             DATABITW  = 8,    ///< 待流水线延迟的数据位宽
   parameter int                             ARRAYSIZ  = 2,    ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][DATABITW-1:0] INITVAL   = {(ARRAYSIZ){{(DATABITW){1'b0}}}},
   parameter int unsigned                    DELAY_MSK = 0     ///< 延迟输出计划比特位图，从低至高每一比特对应一层处理是否需要延迟的标志，1-延迟，0-不延迟
) (clk, aclr, sclr, clken, x, pipe_x);
   input  bit                             clk;     ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            aclr;    ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            sclr;    ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                            clken;  ///< 模块使能信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]x;       ///< 流水线待同步的数据信号
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]pipe_x;  ///< 经流水线同步后的数据信号

   pipedelay_taps_packedarray #(
      .DATABITW(DATABITW), .ARRAYSIZ(ARRAYSIZ), .INITVAL(INITVAL),.DELAYTAPS(miscs::bitcnt_of_integer(DELAY_MSK, 32, 1))
   ) pd_taps(
      .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),  .x(x),.pipe_x(pipe_x)
   );
endmodule
module pipedelay_msk_unpackedarray #(
   parameter int                             DATABITW  = 8,    ///< 待流水线延迟的数据位宽
   parameter int                             ARRAYSIZ  = 2,    ///< 待流水线延迟的数组元素个数
   parameter bit[ARRAYSIZ-1:0][DATABITW-1:0] INITVAL   = {(ARRAYSIZ){{(DATABITW){1'b0}}}},
   parameter int unsigned                    DELAY_MSK = 0     ///< 延迟输出计划比特位图，从低至高每一比特对应一层处理是否需要延迟的标志，1-延迟，0-不延迟
) (clk, aclr, sclr, clken, x, pipe_x);
   input  bit                 clk;                 ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                clken;              ///< 模块使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] x[ARRAYSIZ-1:0];     ///< 流水线待同步的数据信号
   output logic[DATABITW-1:0] pipe_x[ARRAYSIZ-1:0];///< 经流水线同步后的数据信号

   wire[ARRAYSIZ-1:0][DATABITW-1:0]xc, pipe_xc;
   array_unpacked2packed #(.UNITBITW(DATABITW),  .ARRAYSIZ(ARRAYSIZ))aci(.in(x),  .out(xc));
   pipedelay_msk_packedarray #(
      .DATABITW(DATABITW), .ARRAYSIZ(ARRAYSIZ), .INITVAL(INITVAL),.DELAY_MSK(DELAY_MSK)
   ) pdmpi(
      .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),  .x(xc),.pipe_x(pipe_xc)
   );
   array_packed2unpacked #(.UNITBITW(DATABITW),  .ARRAYSIZ(ARRAYSIZ))aco(.in(pipe_xc), .out(pipe_x));
endmodule
module pipedelay_msk #(
   parameter int              DATABITW  = 8,       ///< 待流水线延迟的数据位宽
   parameter bit[DATABITW-1:0]INITVAL   = {(DATABITW){1'b0}},
   parameter int unsigned     DELAY_MSK = 0        ///< 延迟输出计划比特位图，从低至高每一比特对应一层处理是否需要延迟的标志，1-延迟，0-不延迟
) (clk, aclr, sclr, clken, x, pipe_x);
   input  bit                 clk;                 ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                clken;              ///< 模块使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] x;                   ///< 流水线待同步的数据信号
   output logic[DATABITW-1:0] pipe_x;              ///< 经流水线同步后的数据信号

   pipedelay_taps #(
      .DATABITW(DATABITW), .INITVAL(INITVAL),.DELAYTAPS(miscs::bitcnt_of_integer(DELAY_MSK, 32, 1))
   ) pdmpi(
      .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),  .x(x),.pipe_x(pipe_x)
   );
endmodule

