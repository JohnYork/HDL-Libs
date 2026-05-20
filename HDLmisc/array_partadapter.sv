/*!
 * \license SPDX-License-Identifier: MIT
 * \file array_partadapter.sv
 * \brief 数组元素分块合路适配器
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, dff_latch, idx2selsig, array_partmux
 */
`include "miscs.svh"
`include "array_partmux.svh"
`define __INC_FROM_ARRAY_PARTADAPTER__
`include "array_partadapter.svh"
/*! \brief 数组元素分块合路适配器 */
module packedarray_partadapter_bycs #(
   parameter int UNITBITW = 8,                     ///< 数组元素位宽
   parameter int ARRAYSIZ = 3,                     ///< 数组元素个数
   parameter int ADAPTCNT = 2,                     ///< 数组元素适配分块数
   parameter int OUTMODE  = 2                      ///< 输出模式：
                                                   ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                                                   ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                                                   ///< 2-ADAPTCNT > 1时延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
) (clk, aclr, sclr, part_in, wcs, we, array_out, prevalid, valid);
   input  bit                                clk;        ///< 驱动时钟
   input  wire                               aclr;       ///< 异步复位信号，高电平(1)有效
   input  wire                               sclr;       ///< 同步复位信号，高电平(1)有效
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, ADAPTCNT);
   input  wire[cntPerPart-1:0][UNITBITW-1:0] part_in;    ///< 输入待适配矩阵分块
   input  wire [ADAPTCNT-1:0]                wcs;        ///< 分块适配选通信号
   input  wire                               we;         ///< 矩阵分块适配写使能信号，高电平(1)有效
   output logic[ARRAYSIZ-1:0][UNITBITW-1:0]  array_out;  ///< 输出经适配后的矩阵
   output logic                              prevalid;   ///< 适配后矩阵输出有效预报标识，高电平(1)有效，当例化参数 #ADAPTCNT 为1时，本信号保持常0
   output logic                              valid;      ///< 适配后矩阵输出有效标志，高电平(1)有效

   genvar i, j; generate for (i = 0; i < ADAPTCNT; i++) begin: ASSIGN_ADAPT_IDX
      localparam int cntOfPart = (i == (ADAPTCNT - 1)) ? (ARRAYSIZ - i*cntPerPart) : cntPerPart;
      localparam int ileft  = i * cntPerPart;
      if (ADAPTCNT > 1 && (i < ADAPTCNT - 1 || OUTMODE == 2)) begin
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr) array_out[ileft+cntOfPart-1:ileft] <= {(cntOfPart){{(UNITBITW){1'b0}}}};
            else if (sclr) array_out[ileft+cntOfPart-1:ileft] <= {(cntOfPart){{(UNITBITW){1'b0}}}};
            else           array_out[ileft+cntOfPart-1:ileft] <= (wcs[i]&we)
                                                                 ? part_in[cntOfPart-1:0]
                                                                 : array_out[ileft+cntOfPart-1:ileft];
         end
      end
      else if (ADAPTCNT > 1 && OUTMODE == 1) begin
         wire [cntOfPart*UNITBITW-1:0] pin2dff, dffpout;
         packedarray_combine2unit #(
            .UNITBITW(UNITBITW   ),
            .ARRAYSIZ(cntOfPart  )
         ) pincmb(
            .in   (part_in[cntOfPart-1:0] ),
            .out  (pin2dff                )
         );
         dff_latch #(
            .UNITBITW(UNITBITW*cntOfPart  )
         ) data_latcher(
            .clk  (clk        ),
            .aclr (aclr       ),
            .sclr (sclr       ),
            .d    (pin2dff    ),
            .we   (wcs[i]&we  ),
            .q    (dffpout    )
         );
         unit_split2packedarray #(
            .UNITBITW(UNITBITW   ),
            .ARRAYSIZ(cntOfPart  )
         ) spltpout(
            .in  (dffpout                             ),
            .out  (array_out[ileft+cntOfPart-1:ileft] )
         );
      end
      else assign array_out[ileft+cntOfPart-1:ileft] = part_in[cntOfPart-1:0];
   end
   if      (ADAPTCNT < 2) assign prevalid = wcs[ADAPTCNT-1]&we;
   else if (OUTMODE == 2) always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) prevalid <= '0;
      else if (sclr) prevalid <= '0;
      else if (we)   prevalid <= wcs[ADAPTCNT-2]&we;
      else           prevalid <= prevalid;
   end else if (OUTMODE == 1) begin
      dff_latch #(
         .UNITBITW(1)
      )prevalid_latcher(
         .clk  (clk              ),
         .aclr (aclr             ),
         .sclr (sclr             ),
         .d    (wcs[ADAPTCNT-2]  ),
         .we   (we               ),
         .q    (prevalid         )
      );
   end else assign prevalid = wcs[ADAPTCNT-2]&we;
   if (ADAPTCNT > 1 && OUTMODE == 2)
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) valid <= '0;
         else if (sclr) valid <= '0;
         else if (we)   valid <= wcs[ADAPTCNT-1]&we;
         else           valid <= valid;
      end
   else if (OUTMODE == 1) begin
      dff_latch #(
         .UNITBITW(1)
      )valid_latcher(
         .clk  (clk              ),
         .aclr (aclr             ),
         .sclr (sclr             ),
         .d    (wcs[ADAPTCNT-1]  ),
         .we   (we               ),
         .q    (valid            )
      );
   end
   else assign valid = wcs[ADAPTCNT-1]&we;
   endgenerate
endmodule
module unpackedarray_partadapter_bycs #(
   parameter int UNITBITW = 8,                     ///< 数组元素位宽
   parameter int ARRAYSIZ = 3,                     ///< 数组元素个数
   parameter int ADAPTCNT = 2,                     ///< 数组元素适配分块数
   parameter int OUTMODE  = 2                      ///< 输出模式：
                                                   ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                                                   ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                                                   ///< 2-延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
) (clk, aclr, sclr, part_in, wcs, we, array_out, prevalid, valid);
   input  bit                 clk;                    ///< 驱动时钟
   input  wire                aclr;                   ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                   ///< 同步复位信号，高电平(1)有效
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, ADAPTCNT);
   input  wire [UNITBITW-1:0] part_in[cntPerPart-1:0];///< 输入待适配矩阵分块
   input  wire [ADAPTCNT-1:0] wcs;                    ///< 分块适配选通信号
   input  wire                we;                     ///< 矩阵分块适配写使能信号，高电平(1)有效
   output logic[UNITBITW-1:0] array_out[ARRAYSIZ-1:0];///< 输出经适配后的矩阵
   output logic               prevalid;               ///< 适配后矩阵输出有效预报标识，高电平(1)有效，当例化参数 #ADAPTCNT 为1时，本信号保持常0
   output logic               valid;                  ///< 适配后矩阵输出有效标志，高电平(1)有效

   wire [cntPerPart-1:0][UNITBITW-1:0] ain;
   array_unpacked2packed #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) pci(
      .in   (part_in ),
      .out  (ain     )
   );
   wire[ARRAYSIZ-1:0][UNITBITW-1:0] out;
   packedarray_partadapter_bycs #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADAPTCNT(ADAPTCNT),
      .OUTMODE (OUTMODE )
   ) adaptri(
      .clk        (clk     ),
      .aclr       (aclr    ),
      .sclr       (sclr    ),
      .part_in    (ain     ),
      .wcs        (wcs     ),
      .we         (we      ),
      .array_out  (out     ),
      .prevalid   (prevalid),
      .valid      (valid   )
   );
   array_packed2unpacked #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) pco(
      .in   (out        ),
      .out  (array_out  )
   );
endmodule
module packedarray_packedunit_partadapter_bycs #(
   parameter int UNITBITW = 8,                     ///< 数组元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 3,                     ///< 数组单元个数
   parameter int ADAPTCNT = 2,                     ///< 数组元素适配分块数
   parameter int OUTMODE  = 2                      ///< 输出模式：
                                                   ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                                                   ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                                                   ///< 2-延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
) (clk, aclr, sclr, part_in, wcs, we, array_out, prevalid, valid);
   input  bit                                               clk;        ///< 驱动时钟
   input  wire                                              aclr;       ///< 异步复位信号，高电平(1)有效
   input  wire                                              sclr;       ///< 同步复位信号，高电平(1)有效
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, ADAPTCNT);
   input  wire[cntPerPart-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  part_in;    ///< 输入待适配矩阵分块
   input  wire[ADAPTCNT-1:0]                                wcs;        ///< 分块适配选通信号
   input  wire                                              we;         ///< 矩阵分块适配写使能信号，高电平(1)有效
   output logic[ARRAYSIZ -1:0][AUNITSIZ-1:0][UNITBITW-1:0]  array_out;  ///< 输出经适配后的矩阵
   output logic                                             prevalid;   ///< 适配后矩阵输出有效预报标识，高电平(1)有效，当例化参数 #ADAPTCNT 为1时，本信号保持常0
   output logic                                             valid;      ///< 适配后矩阵输出有效标志，高电平(1)有效

   wire[cntPerPart-1:0][UNITBITW*AUNITSIZ-1:0] ain;
   packedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) packin(
      .in   (part_in ),
      .out  (ain     )
   );
   wire[ARRAYSIZ-1:0][UNITBITW*AUNITSIZ-1:0] out;
   packedarray_partadapter_bycs #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         ),
      .ADAPTCNT(ADAPTCNT         ),
      .OUTMODE (OUTMODE          )
   ) adaptri(
      .clk        (clk     ),
      .aclr       (aclr    ),
      .sclr       (sclr    ),
      .part_in    (ain     ),
      .wcs        (wcs     ),
      .we         (we      ),
      .array_out  (out     ),
      .prevalid   (prevalid),
      .valid      (valid   )
   );
   packedarray_unit_split2packedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) spltout(
      .in   (out        ),
      .out  (array_out  )
   );
endmodule
module unpackedarray_packedunit_partadapter_bycs #(
   parameter int UNITBITW = 8,                     ///< 数组元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 3,                     ///< 数组单元个数
   parameter int ADAPTCNT = 2,                     ///< 数组元素适配分块数
   parameter int OUTMODE  = 2                      ///< 输出模式：
                                                   ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                                                   ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                                                   ///< 2-延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
) (clk, aclr, sclr, part_in, wcs, we, array_out, prevalid, valid);
   input  bit                                clk;                       ///< 驱动时钟
   input  wire                               aclr;                      ///< 异步复位信号，高电平(1)有效
   input  wire                               sclr;                      ///< 同步复位信号，高电平(1)有效
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, ADAPTCNT);
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]  part_in[cntPerPart-1:0];   ///< 输入待适配矩阵分块
   input  wire [ADAPTCNT-1:0]                wcs;                       ///< 分块适配选通信号
   input  wire                               we;                        ///< 矩阵分块适配写使能信号，高电平(1)有效
   output logic[AUNITSIZ-1:0][UNITBITW-1:0]  array_out[ARRAYSIZ -1:0];  ///< 输出经适配后的矩阵
   output logic                              prevalid;                  ///< 适配后矩阵输出有效预报标识，高电平(1)有效，当例化参数 #ADAPTCNT 为1时，本信号保持常0
   output logic                              valid;                     ///< 适配后矩阵输出有效标志，高电平(1)有效

   wire[UNITBITW*AUNITSIZ-1:0]ain[cntPerPart-1:0];
   unpackedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) packin(
      .in   (part_in ),
      .out  (ain     )
   );
   wire[UNITBITW*AUNITSIZ-1:0]out[ARRAYSIZ-1:0];
   unpackedarray_partadapter_bycs #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         ),
      .ADAPTCNT(ADAPTCNT         ),
      .OUTMODE (OUTMODE          )
   ) adaptri(
      .clk        (clk     ),
      .aclr       (aclr    ),
      .sclr       (sclr    ),
      .part_in    (ain     ),
      .wcs        (wcs     ),
      .we         (we      ),
      .array_out  (out     ),
      .prevalid   (prevalid),
      .valid      (valid   )
   );
   unpackedarray_unit_split2packedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) spltout(
      .in   (out        ),
      .out  (array_out  )
   );
endmodule
module unpackedarray_unpackedunit_partadapter_bycs #(
   parameter int UNITBITW = 8,                     ///< 数组元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 3,                     ///< 数组单元个数
   parameter int ADAPTCNT = 2,                     ///< 数组元素适配分块数
   parameter int OUTMODE  = 2                      ///< 输出模式：
                                                   ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                                                   ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                                                   ///< 2-延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
) (clk, aclr, sclr, part_in, wcs, we, array_out, prevalid, valid);
   input  bit                 clk;                                   ///< 驱动时钟
   input  wire                aclr;                                  ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                                  ///< 同步复位信号，高电平(1)有效
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, ADAPTCNT);
   input  wire [UNITBITW-1:0] part_in[cntPerPart-1:0][AUNITSIZ-1:0]; ///< 输入待适配矩阵分块
   input  wire [ADAPTCNT-1:0] wcs;                                   ///< 分块适配选通信号
   input  wire                we;                                    ///< 矩阵分块适配写使能信号，高电平(1)有效
   output logic[UNITBITW-1:0] array_out[ARRAYSIZ -1:0][AUNITSIZ-1:0];///< 输出经适配后的矩阵
   output logic               prevalid;                              ///< 适配后矩阵输出有效预报标识，高电平(1)有效，当例化参数 #ADAPTCNT 为1时，本信号保持常0
   output logic               valid;                                 ///< 适配后矩阵输出有效标志，高电平(1)有效

   wire[UNITBITW*AUNITSIZ-1:0]ain[cntPerPart-1:0];
   unpackedarray_unpackedunitarray_combine2unit #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) packin(
      .in   (part_in ),
      .out  (ain     )
   );
   wire[UNITBITW*AUNITSIZ-1:0]out[ARRAYSIZ-1:0];
   unpackedarray_partadapter_bycs #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         ),
      .ADAPTCNT(ADAPTCNT         ),
      .OUTMODE (OUTMODE          )
   ) adaptri(
      .clk        (clk     ),
      .aclr       (aclr    ),
      .sclr       (sclr    ),
      .part_in    (ain     ),
      .wcs        (wcs     ),
      .we         (we      ),
      .array_out  (out     ),
      .prevalid   (prevalid),
      .valid      (valid   )
   );
   unpackedarray_unit_split2unpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) spltout(
      .in   (out        ),
      .out  (array_out  )
   );
endmodule
/*! \brief 基于索引选通适配的数组元素分块合路适配器 */
module packedarray_partadapter_byidx #(
   parameter int UNITBITW = 8,                     ///< 数组元素位宽
   parameter int ARRAYSIZ = 3,                     ///< 数组元素个数
   parameter int ADAPTCNT = 2,                     ///< 数组元素适配分块数
   parameter int OUTMODE  = 2                      ///< 输出模式：
                                                   ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                                                   ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                                                   ///< 2-延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
) (clk, aclr, sclr, part_in, idx, we, array_out, prevalid, valid);
   input  bit                                clk;        ///< 驱动时钟
   input  wire                               aclr;       ///< 异步复位信号，高电平(1)有效
   input  wire                               sclr;       ///< 同步复位信号，高电平(1)有效
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, ADAPTCNT);
   input  wire[cntPerPart-1:0][UNITBITW-1:0] part_in;    ///< 输入待适配矩阵分块
   localparam int bitsof_idx = miscs::minbitw_of_integer(ADAPTCNT-1, 31);
   input  wire[bitsof_idx-1:0]               idx;        ///< 输入待适配矩阵分块的索引
   input  wire                               we;         ///< 矩阵分块适配写使能信号，高电平(1)有效
   output logic[ARRAYSIZ-1:0][UNITBITW-1:0]  array_out;  ///< 输出经适配后的矩阵
   output logic                              prevalid;   ///< 适配后矩阵输出有效预报标识，高电平(1)有效，当例化参数 #ADAPTCNT 为1时，本信号保持常0
   output logic                              valid;      ///< 适配后矩阵输出有效标志，高电平(1)有效

   wire[ADAPTCNT-1:0] selsig;
   idx2selsig #(
      .SELSIG_CNT (ADAPTCNT),
      .DELAYTAPS  (0       )
   ) idx2selsigi(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(1'b1    ),
      .idx  (idx     ),
      .cs   (selsig  )
   );
   packedarray_partadapter_bycs #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADAPTCNT(ADAPTCNT),
      .OUTMODE (OUTMODE )
   ) partadapter(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .part_in    (part_in    ),
      .wcs        (selsig     ),
      .we         (we         ),
      .array_out  (array_out  ),
      .prevalid   (prevalid   ),
      .valid      (valid      )
   );
endmodule
module unpackedarray_partadapter_byidx #(
   parameter int UNITBITW = 8,                     ///< 数组元素位宽
   parameter int ARRAYSIZ = 3,                     ///< 数组元素个数
   parameter int ADAPTCNT = 2,                     ///< 数组元素适配分块数
   parameter int OUTMODE  = 2                      ///< 输出模式：
                                                   ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                                                   ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                                                   ///< 2-延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
) (clk, aclr, sclr, part_in, idx, we, array_out, prevalid, valid);
   input  bit                 clk;                    ///< 驱动时钟
   input  wire                aclr;                   ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                   ///< 同步复位信号，高电平(1)有效
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, ADAPTCNT);
   input  wire [UNITBITW-1:0] part_in[cntPerPart-1:0];///< 输入待适配矩阵分块
   localparam int bitsof_idx = miscs::minbitw_of_integer(ADAPTCNT-1, 31);
   input  wire[bitsof_idx-1:0]idx;                    ///< 输入待适配矩阵分块的索引
   input  wire                we;                     ///< 矩阵分块适配写使能信号，高电平(1)有效
   output logic[UNITBITW-1:0] array_out[ARRAYSIZ-1:0];///< 输出经适配后的矩阵
   output logic               prevalid;               ///< 适配后矩阵输出有效预报标识，高电平(1)有效，当例化参数 #ADAPTCNT 为1时，本信号保持常0
   output logic               valid;                  ///< 适配后矩阵输出有效标志，高电平(1)有效

   wire[ADAPTCNT-1:0] selsig;
   idx2selsig #(
      .SELSIG_CNT (ADAPTCNT),
      .DELAYTAPS  (0       )
   ) idx2selsigi(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(1'b1    ),
      .idx  (idx     ),
      .cs   (selsig  )
   );
   unpackedarray_partadapter_bycs #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADAPTCNT(ADAPTCNT),
      .OUTMODE (OUTMODE )
   ) partadapter(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .part_in    (part_in    ),
      .wcs        (selsig     ),
      .we         (we         ),
      .array_out  (array_out  ),
      .prevalid   (prevalid   ),
      .valid      (valid      )
   );
endmodule
module packedarray_packedunit_partadapter_byidx #(
   parameter int UNITBITW = 8,                     ///< 数组元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 3,                     ///< 数组单元个数
   parameter int ADAPTCNT = 2,                     ///< 数组元素适配分块数
   parameter int OUTMODE  = 2                      ///< 输出模式：
                                                   ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                                                   ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                                                   ///< 2-延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
) (clk, aclr, sclr, part_in, idx, we, array_out, prevalid, valid);
   input  bit                                               clk;        ///< 驱动时钟
   input  wire                                              aclr;       ///< 异步复位信号，高电平(1)有效
   input  wire                                              sclr;       ///< 同步复位信号，高电平(1)有效
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, ADAPTCNT);
   input  wire[cntPerPart-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  part_in;    ///< 输入待适配矩阵分块
   localparam int bitsof_idx = miscs::minbitw_of_integer(ADAPTCNT-1, 31);
   input  wire[bitsof_idx-1:0]                              idx;        ///< 输入待适配矩阵分块的索引
   input  wire                                              we;         ///< 矩阵分块适配写使能信号，高电平(1)有效
   output logic[ARRAYSIZ -1:0][AUNITSIZ-1:0][UNITBITW-1:0]  array_out;  ///< 输出经适配后的矩阵
   output logic                                             prevalid;   ///< 适配后矩阵输出有效预报标识，高电平(1)有效，当例化参数 #ADAPTCNT 为1时，本信号保持常0
   output logic                                             valid;      ///< 适配后矩阵输出有效标志，高电平(1)有效

   wire[ADAPTCNT-1:0] selsig;
   idx2selsig #(
      .SELSIG_CNT (ADAPTCNT),
      .DELAYTAPS  (0       )
   ) idx2selsigi(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(1'b1    ),
      .idx  (idx     ),
      .cs   (selsig  )
   );
   packedarray_packedunit_partadapter_bycs #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADAPTCNT(ADAPTCNT),
      .OUTMODE (OUTMODE )
   ) adaptri(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .part_in    (part_in    ),
      .wcs        (selsig     ),
      .we         (we         ),
      .array_out  (array_out  ),
      .prevalid   (prevalid   ),
      .valid      (valid      )
   );
endmodule
module unpackedarray_packedunit_partadapter_byidx #(
   parameter int UNITBITW = 8,                     ///< 数组元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 3,                     ///< 数组单元个数
   parameter int ADAPTCNT = 2,                     ///< 数组元素适配分块数
   parameter int OUTMODE  = 2                      ///< 输出模式：
                                                   ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                                                   ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                                                   ///< 2-延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
) (clk, aclr, sclr, part_in, idx, we, array_out, prevalid, valid);
   input  bit                                clk;                       ///< 驱动时钟
   input  wire                               aclr;                      ///< 异步复位信号，高电平(1)有效
   input  wire                               sclr;                      ///< 同步复位信号，高电平(1)有效
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, ADAPTCNT);
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]  part_in[cntPerPart-1:0];   ///< 输入待适配矩阵分块
   localparam int bitsof_idx = miscs::minbitw_of_integer(ADAPTCNT-1, 31);
   input  wire[bitsof_idx-1:0]               idx;                       ///< 输入待适配矩阵分块的索引
   input  wire                               we;                        ///< 矩阵分块适配写使能信号，高电平(1)有效
   output logic[AUNITSIZ-1:0][UNITBITW-1:0]  array_out[ARRAYSIZ -1:0];  ///< 输出经适配后的矩阵
   output logic                              prevalid;                  ///< 适配后矩阵输出有效预报标识，高电平(1)有效，当例化参数 #ADAPTCNT 为1时，本信号保持常0
   output logic                              valid;                     ///< 适配后矩阵输出有效标志，高电平(1)有效

   wire[ADAPTCNT-1:0] selsig;
   idx2selsig #(
      .SELSIG_CNT (ADAPTCNT),
      .DELAYTAPS  (0       )
   ) idx2selsigi(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(1'b1    ),
      .idx  (idx     ),
      .cs   (selsig  )
   );
   unpackedarray_packedunit_partadapter_bycs #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADAPTCNT(ADAPTCNT),
      .OUTMODE (OUTMODE )
   ) adaptri(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .part_in    (part_in    ),
      .wcs        (selsig     ),
      .we         (we         ),
      .array_out  (array_out  ),
      .prevalid   (prevalid   ),
      .valid      (valid      )
   );
endmodule
module unpackedarray_unpackedunit_partadapter_byidx #(
   parameter int UNITBITW = 8,                     ///< 数组元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 3,                     ///< 数组单元个数
   parameter int ADAPTCNT = 2,                     ///< 数组元素适配分块数
   parameter int OUTMODE  = 2                      ///< 输出模式：
                                                   ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                                                   ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                                                   ///< 2-延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
) (clk, aclr, sclr, part_in, idx, we, array_out, prevalid, valid);
   input  bit                 clk;                                   ///< 驱动时钟
   input  wire                aclr;                                  ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                                  ///< 同步复位信号，高电平(1)有效
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, ADAPTCNT);
   input  wire [UNITBITW-1:0] part_in[cntPerPart-1:0][AUNITSIZ-1:0]; ///< 输入待适配矩阵分块
   localparam int bitsof_idx = miscs::minbitw_of_integer(ADAPTCNT-1, 31);
   input  wire[bitsof_idx-1:0]idx;                                   ///< 输入待适配矩阵分块的索引
   input  wire                we;                                    ///< 矩阵分块适配写使能信号，高电平(1)有效
   output logic[UNITBITW-1:0] array_out[ARRAYSIZ -1:0][AUNITSIZ-1:0];///< 输出经适配后的矩阵
   output logic               prevalid;                              ///< 适配后矩阵输出有效预报标识，高电平(1)有效，当例化参数 #ADAPTCNT 为1时，本信号保持常0
   output logic               valid;                                 ///< 适配后矩阵输出有效标志，高电平(1)有效

   wire[ADAPTCNT-1:0] selsig;
   idx2selsig #(
      .SELSIG_CNT (ADAPTCNT),
      .DELAYTAPS  (0       )
   ) idx2selsigi(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(1'b1    ),
      .idx  (idx     ),
      .cs   (selsig  )
   );
   unpackedarray_unpackedunit_partadapter_bycs #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADAPTCNT(ADAPTCNT),
      .OUTMODE (OUTMODE )
   ) adaptri(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .part_in    (part_in    ),
      .wcs        (selsig     ),
      .we         (we         ),
      .array_out  (array_out  ),
      .prevalid   (prevalid   ),
      .valid      (valid      )
   );
endmodule
