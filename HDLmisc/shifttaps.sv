/*!
 * \license SPDX-License-Identifier: MIT
 * \file shiftfixtaps.sv
 * \brief 自动选择资源类型的移阶寄存器
 * \details 本移阶寄存器根据例化参数自动选择RAM或寄存器资源来例化移阶寄存器
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, rams, pipedelay, packconv
 */
`include "miscs.svh"
`include "rams.svh"
`define __INC_FROM_SHIFTTAPS__
`include "shifttaps.svh"
/*!
 * \brief 自动选择资源类型的移阶寄存器
 * \details 移阶时钟数小于 #SHIFTTAPS_TAPS2RAM ，或者移阶寄存器总比特位数小于 #ALLBITS2RAM_GATE 时，使用寄存器资源，否则使用RAM资源例化移阶寄存器。
 */
module shiftfixtaps #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                 clk,                 ///< 驱动时钟
   input  wire                aclr,                ///< 异步复位信号，高电平(1)有效
   input  wire                sclr,                ///< 同步复位信号，高电平(1)有效
   input  wire                clken,               ///< 移阶使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] shiftin,             ///< 移阶器输入
   output wire [DATABITW-1:0] shiftout,            ///< 移阶器输出
   output logic               reseting             ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略
);
   initial if (DATABITW <= 0) $error("shiftfixtaps: got bad DATABITW(%0d)", DATABITW);
   localparam int shifttaps_taps2ram = miscs::taps2ram + int'(SCLR_ONRAM);
   genvar i; generate if (TAP_DIST <= 0) begin
      assign shiftout = shiftin, reseting = 1'b0;
   end else if (TAP_DIST < shifttaps_taps2ram || (TAP_DIST*DATABITW < miscs::allbits2ram)) begin
      pipedelay_taps #(
         .DATABITW   (DATABITW            ),
         .INITVAL    ({(DATABITW){1'b0}}  ),
         .DELAYTAPS  (TAP_DIST            )
      ) st_i(
         .clk     (clk     ),
         .aclr    (aclr    ),
         .sclr    (sclr    ),
         .clken   (clken   ),
         .x       (shiftin ),
         .pipe_x  (shiftout)
      );
      assign reseting = 1'b0;
   end else begin
      initial if (TAP_DIST < 3 + int'(SCLR_ONRAM)) $error("shiftfixtaps : parameter TAP_DIST(%0d) should not be less than %0d, for macro `SHIFTTAPS_TAPS2RAM (%0d) and parameter SCLR_ONRAM(%0d)", TAP_DIST, 3 + int'(SCLR_ONRAM), miscs::taps2ram, SCLR_ONRAM);
      localparam int lat4blkram_addrq2addrw = 2;
      localparam int implmod = (IMPLBYLOGIC == 1'b1 || rams_pkg::recommend_ramstyle(TAP_DIST-2 + lat4blkram_addrq2addrw, DATABITW) == 0) ? 0 : 2;
      localparam int lat_addrq2addrw = implmod == 0 ? 0 : lat4blkram_addrq2addrw;// 对BlockRam，读写地址相同时读写结果可能出错，必须错开
      localparam int ram_addrlen = TAP_DIST - 2 + lat_addrq2addrw;
      logic[DATABITW-1:0]ram_q, out_q;
      localparam int addrBitw = miscs::minbitw_of_integer(ram_addrlen - 1, 31);
      logic                sclr_on_ram_bgn, sclr_on_ram_ongoing, sclr_on_ram_done, sclr_on_ramq;
      logic [DATABITW-1:0] data4w;
      logic[addrBitw-1:0]baseAddr;
      wire zeroAddr = ~(|baseAddr);
      if (SCLR_ONRAM) begin: RAMSCLR
         initial begin
            sclr_on_ram_ongoing = 1'b0;
            sclr_on_ramq = 1'b0;
         end
         logic prev_sclr = 1'b0;
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) prev_sclr <= aclr ? '0 : sclr;
         logic prev_aclr = 1'b0;
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) prev_aclr <= aclr;
         assign sclr_on_ram_bgn = ((~prev_sclr)&sclr)|(prev_aclr&(~aclr)); // 同步复位开始、或者异步复位结束后，开始内部RAM的复位操作
         always @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if     (aclr)           sclr_on_ram_ongoing <= '0;
            else if(sclr_on_ram_bgn)sclr_on_ram_ongoing <= '1;
            else                    sclr_on_ram_ongoing <= sclr_on_ram_done ? '0 : sclr_on_ram_ongoing;
         end
         assign sclr_on_ram_done = sclr_on_ram_ongoing&zeroAddr;
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr)                baseAddr <= (addrBitw)'(ram_addrlen - 1);
            else if (sclr_on_ram_bgn)     baseAddr <= (addrBitw)'(ram_addrlen - 1);
            else if (sclr_on_ram_ongoing) baseAddr <= zeroAddr ? (addrBitw)'(ram_addrlen - 1) : baseAddr - (addrBitw)'(1);
            else if (sclr)                baseAddr <= (addrBitw)'(ram_addrlen - 1);
            else if (~clken)              baseAddr <= baseAddr;
            else                          baseAddr <= zeroAddr ? (addrBitw)'(ram_addrlen - 1) : baseAddr - (addrBitw)'(1);
         end
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if     (aclr)                                data4w <= '0;
            else if(sclr_on_ram_bgn|sclr_on_ram_ongoing) data4w <= '0;
            else if(sclr)                                data4w <= '0;
            else                                         data4w <= clken ? shiftin : data4w;
         end
         always @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if     (aclr)           sclr_on_ramq <= '0;
            else if(sclr_on_ram_bgn)sclr_on_ramq <= '1;
            else                    sclr_on_ramq <= sclr_on_ram_ongoing ? sclr_on_ram_ongoing : '0;
         end
         assign reseting = sclr_on_ram_ongoing;
      end else begin: RAMNOSCLR
         assign sclr_on_ram_bgn = 1'b0, sclr_on_ram_ongoing = 1'b0, sclr_on_ram_done = 1'b0, sclr_on_ramq = 1'b0, reseting = 1'b0;
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if     (aclr)  baseAddr <= (addrBitw)'(ram_addrlen - 1);
            else if(sclr)  baseAddr <= (addrBitw)'(ram_addrlen - 1);
            else if(~clken)baseAddr <= baseAddr;
            else           baseAddr <= zeroAddr ? (addrBitw)'(ram_addrlen - 1) : baseAddr - (addrBitw)'(1);
         end
         assign data4w = shiftin;
      end
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if     (aclr)        out_q <= '0;
         else if(sclr)        out_q <= '0;
         else if(sclr_on_ramq)out_q <= '0;
         else if(clken)       out_q <= ram_q;
         else                 out_q <= out_q;
      end
      logic [addrBitw-1:0] addrQ;
      if (lat_addrq2addrw > 0 || SCLR_ONRAM == 1'b1) begin: QADDR
         localparam bit[addrBitw-1:0] lat_addrq2addrw_addrq = (addrBitw)'(lat_addrq2addrw+1+int'(SCLR_ONRAM)*2);
         wire[addrBitw-1:0]addrQ2upd1 = baseAddr - lat_addrq2addrw_addrq;
         wire[addrBitw-1:0]addrQ2upd2 = baseAddr + ((addrBitw)'(ram_addrlen) - lat_addrq2addrw_addrq);
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if     (aclr)  addrQ <= '0;
            else if(sclr)  addrQ <= '0;
            else if(~clken)addrQ <= addrQ;
            else           addrQ <= (baseAddr < lat_addrq2addrw_addrq) ? addrQ2upd2 : addrQ2upd1;
         end
      end
      else assign addrQ = baseAddr;
      sdpram #(
         .DATABITW(DATABITW   ),
         .ADDRLEN (ram_addrlen),
         .IMPLMOD (implmod    ),
         .REGOUTP (SCLR_ONRAM )
      ) sdprpai(
         .clk     (clk                                         ),
         .aclr    (aclr                                        ),
         .sclr    (sclr|sclr_on_ramq                           ),
         .we      ((clken&(~(aclr|sclr)))|sclr_on_ram_ongoing  ),
         .clken_w (clken                                       ),
         .addr_w  (baseAddr                                    ),
         .data_w  (data4w                                      ),
         .clken_q (clken                                       ),
         .addr_q  (addrQ                                       ),
         .data_q  (ram_q                                       )
      );
      assign shiftout = out_q;
   end endgenerate
endmodule
module shiftfixtaps_packedarray #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int        ARRAYSIZ    = 2,           ///< 数组元素个数
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                             clk,     ///< 驱动时钟
   input  wire                            aclr,    ///< 异步复位信号，高电平(1)有效
   input  wire                            sclr,    ///< 同步复位信号，高电平(1)有效
   input  wire                            clken,   ///< 移阶使能信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]shiftin, ///< 移阶器输入
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]shiftout,///< 移阶器输出
   output wire                            reseting             ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
);
   wire[DATABITW*ARRAYSIZ-1:0]sin, sout;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) si_cmbi(
      .in   (shiftin ),
      .out  (sin     )
   );
   assign sin[0] = shiftin;
   shiftfixtaps #(
      .DATABITW   (DATABITW*ARRAYSIZ),
      .TAP_DIST   (TAP_DIST         ),
      .SCLR_ONRAM (SCLR_ONRAM       ),
      .IMPLBYLOGIC(IMPLBYLOGIC      )
   ) stapai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (sin     ),
      .shiftout(sout    ),
      .reseting(reseting)
   );
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) so_spliti(
      .in   (sout    ),
      .out  (shiftout)
   );
endmodule
module shiftfixtaps_unpackedarray #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int        ARRAYSIZ    = 2,           ///< 数组元素个数
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                 clk,                    ///< 驱动时钟
   input  wire                aclr,                   ///< 异步复位信号，高电平(1)有效
   input  wire                sclr,                   ///< 同步复位信号，高电平(1)有效
   input  wire                clken,                  ///< 移阶使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] shiftin [ARRAYSIZ-1:0], ///< 移阶器输入
   output wire [DATABITW-1:0] shiftout[ARRAYSIZ-1:0], ///< 移阶器输出
   output wire                reseting                ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
);
   wire[ARRAYSIZ-1:0][DATABITW-1:0]sin, sout;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aci(
      .in   (shiftin ),
      .out  (sin     )
   );
   shiftfixtaps_packedarray #(
      .DATABITW   (DATABITW   ),
      .ARRAYSIZ   (ARRAYSIZ   ),
      .TAP_DIST   (TAP_DIST   ),
      .SCLR_ONRAM (SCLR_ONRAM ),
      .IMPLBYLOGIC(IMPLBYLOGIC)
   ) stapai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (sin     ),
      .shiftout(sout    ),
      .reseting(reseting)
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aco(
      .in   (sout    ),
      .out  (shiftout)
   );
endmodule
module shiftfixtaps_packedarray_extd #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int        ARRAYSIZ    = 2,           ///< 数组元素个数
   parameter int        EXTDBITW    = 5,           ///< 额外数据位宽
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                             clk,     ///< 驱动时钟
   input  wire                            aclr,    ///< 异步复位信号，高电平(1)有效
   input  wire                            sclr,    ///< 同步复位信号，高电平(1)有效
   input  wire                            clken,   ///< 移阶使能信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]shiftin, ///< 移阶器数组输入
   input  wire[EXTDBITW-1:0]              extdin,  ///< 移阶器额外数据输入
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]shiftout,///< 移阶器数组输出
   output wire[EXTDBITW-1:0]              extdout, ///< 移阶器额外数据输出
   output wire                            reseting ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
);
   wire[DATABITW*ARRAYSIZ+EXTDBITW-1:0]si, so;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in   (shiftin                   ),
      .out  (si[DATABITW*ARRAYSIZ-1:0] )
   );
   assign si[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ] = extdin;
   shiftfixtaps #(
      .DATABITW   (DATABITW*ARRAYSIZ+EXTDBITW),
      .TAP_DIST   (TAP_DIST                  ),
      .SCLR_ONRAM (SCLR_ONRAM                ),
      .IMPLBYLOGIC(IMPLBYLOGIC               )
   ) stai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (si      ),
      .shiftout(so      ),
      .reseting(reseting)
   );
   unit_split2packedarray #(.UNITBITW(DATABITW),.ARRAYSIZ(ARRAYSIZ))u2a(.in(so[DATABITW*ARRAYSIZ-1:0]),  .out(shiftout));
   assign extdout = so[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ];
endmodule
module shiftfixtaps_unpackedarray_extd #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int        ARRAYSIZ    = 2,           ///< 数组元素个数
   parameter int        EXTDBITW    = 5,           ///< 额外数据位宽
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                 clk,                    ///< 驱动时钟
   input  wire                aclr,                   ///< 异步复位信号，高电平(1)有效
   input  wire                sclr,                   ///< 同步复位信号，高电平(1)有效
   input  wire                clken,                  ///< 移阶使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] shiftin [ARRAYSIZ-1:0], ///< 移阶器数组输入
   input  wire [EXTDBITW-1:0] extdin,                 ///< 移阶器额外数据输入
   output wire [DATABITW-1:0] shiftout[ARRAYSIZ-1:0], ///< 移阶器数组输出
   output wire [EXTDBITW-1:0] extdout,                ///< 移阶器额外数据输出
   output wire                reseting                ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
);
   wire[DATABITW*ARRAYSIZ+EXTDBITW-1:0]si, so;
   unpackedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in   (shiftin                   ),
      .out  (si[DATABITW*ARRAYSIZ-1:0] )
   );
   assign si[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ] = extdin;
   shiftfixtaps #(
      .DATABITW   (DATABITW*ARRAYSIZ+EXTDBITW),
      .TAP_DIST   (TAP_DIST                  ),
      .SCLR_ONRAM (SCLR_ONRAM                ),
      .IMPLBYLOGIC(IMPLBYLOGIC               )
   ) stai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (si      ),
      .shiftout(so      ),
      .reseting(reseting)
   );
   unit_split2unpackedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in   (so[DATABITW*ARRAYSIZ-1:0] ),
      .out  (shiftout                  )
   );
   assign extdout = so[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ];
endmodule
module shiftfixtaps_packedunit_packedarray #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                                            clk,     ///< 驱动时钟
   input  wire                                           aclr,    ///< 异步复位信号，高电平(1)有效
   input  wire                                           sclr,    ///< 同步复位信号，高电平(1)有效
   input  wire                                           clken,   ///< 移阶使能信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] shiftin, ///< 移阶器输入
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] shiftout,///< 移阶器输出
   output wire                                           reseting ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
);
   wire[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) si_cmbi(
      .in   (shiftin ),
      .out  (sin     )
   );
   shiftfixtaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ),
      .TAP_DIST   (TAP_DIST                  ),
      .SCLR_ONRAM (SCLR_ONRAM                ),
      .IMPLBYLOGIC(IMPLBYLOGIC               )
   ) stapai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (sin     ),
      .shiftout(sout    ),
      .reseting(reseting)
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) so_spliti(
      .in   (sout    ),
      .out  (shiftout)
   );
endmodule
module shiftfixtaps_packedunit_packedarray_extd #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int        EXTDBITW    = 6,           ///< 同步选取的额外数据位宽
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                                            clk,     ///< 驱动时钟
   input  wire                                           aclr,    ///< 异步复位信号，高电平(1)有效
   input  wire                                           sclr,    ///< 同步复位信号，高电平(1)有效
   input  wire                                           clken,   ///< 移阶使能信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] shiftin, ///< 移阶器输入
   input  wire[EXTDBITW-1:0]                             extdin,  ///< 移阶器额外数据输入
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] shiftout,///< 移阶器输出
   output wire[EXTDBITW-1:0]                             extdout, ///< 移阶器额外数据输出
   output wire                                           reseting ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
);
   wire[EXTDBITW+DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) si_cmbi(
      .in   (shiftin                            ),
      .out  (sin[ARRAYSIZ*AUNITSIZ*DATABITW-1:0])
   );
   assign sin[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW] = extdin;
   shiftfixtaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .TAP_DIST   (TAP_DIST                           ),
      .SCLR_ONRAM (SCLR_ONRAM                         ),
      .IMPLBYLOGIC(IMPLBYLOGIC                        )
   ) stapai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (sin     ),
      .shiftout(sout    ),
      .reseting(reseting)
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) so_spliti(
      .in   (sout[ARRAYSIZ*AUNITSIZ*DATABITW-1:0]  ),
      .out  (shiftout                              )
   );
   assign extdout = sout[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW];
endmodule
module shiftfixtaps_packedunit_unpackedarray #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                              clk,                   ///< 驱动时钟
   input  wire                             aclr,                  ///< 异步复位信号，高电平(1)有效
   input  wire                             sclr,                  ///< 同步复位信号，高电平(1)有效
   input  wire                             clken,                 ///< 移阶使能信号，高电平(1)有效
   input  wire[AUNITSIZ-1:0][DATABITW-1:0] shiftin [ARRAYSIZ-1:0],///< 移阶器输入
   output wire[AUNITSIZ-1:0][DATABITW-1:0] shiftout[ARRAYSIZ-1:0],///< 移阶器输出
   output wire                             reseting               ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
);
   wire[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) si_cmbi(
      .in   (shiftin ),
      .out  (sin     )
   );
   shiftfixtaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ),
      .TAP_DIST   (TAP_DIST                  ),
      .SCLR_ONRAM (SCLR_ONRAM                ),
      .IMPLBYLOGIC(IMPLBYLOGIC               )
   ) stapai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (sin     ),
      .shiftout(sout    ),
      .reseting(reseting)
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) so_spliti(
      .in   (sout    ),
      .out  (shiftout)
   );
endmodule
module shiftfixtaps_packedunit_unpackedarray_extd #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int        EXTDBITW    = 6,           ///< 同步选取的额外数据位宽
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                             clk,                    ///< 驱动时钟
   input  wire                            aclr,                   ///< 异步复位信号，高电平(1)有效
   input  wire                            sclr,                   ///< 同步复位信号，高电平(1)有效
   input  wire                            clken,                  ///< 移阶使能信号，高电平(1)有效
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]shiftin [ARRAYSIZ-1:0], ///< 移阶器输入
   input  wire[EXTDBITW-1:0]              extdin,                 ///< 移阶器额外数据输入
   output wire[AUNITSIZ-1:0][DATABITW-1:0]shiftout[ARRAYSIZ-1:0], ///< 移阶器输出
   output wire[EXTDBITW-1:0]              extdout,                ///< 移阶器额外数据输出
   output wire                            reseting                ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
);
   wire[EXTDBITW+DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) si_cmbi(
      .in   (shiftin                            ),
      .out  (sin[ARRAYSIZ*AUNITSIZ*DATABITW-1:0])
   );
   assign sin[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW] = extdin;
   shiftfixtaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .TAP_DIST   (TAP_DIST                           ),
      .SCLR_ONRAM (SCLR_ONRAM                         ),
      .IMPLBYLOGIC(IMPLBYLOGIC                        )
   ) stapai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (sin     ),
      .shiftout(sout    ),
      .reseting(reseting)
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) so_spliti(
      .in   (sout[ARRAYSIZ*AUNITSIZ*DATABITW-1:0]  ),
      .out  (shiftout                              )
   );
   assign extdout = sout[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW];
endmodule
module shiftfixtaps_unpackedunit_unpackedarray #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                clk,                                 ///< 驱动时钟
   input  wire               aclr,                                ///< 异步复位信号，高电平(1)有效
   input  wire               sclr,                                ///< 同步复位信号，高电平(1)有效
   input  wire               clken,                               ///< 移阶使能信号，高电平(1)有效
   input  wire[DATABITW-1:0] shiftin [ARRAYSIZ-1:0][AUNITSIZ-1:0],///< 移阶器输入
   output wire[DATABITW-1:0] shiftout[ARRAYSIZ-1:0][AUNITSIZ-1:0],///< 移阶器输出
   output wire               reseting                             ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
);
   wire[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) si_cmbi(
      .in   (shiftin ),
      .out  (sin     )
   );
   shiftfixtaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ),
      .TAP_DIST   (TAP_DIST                  ),
      .SCLR_ONRAM (SCLR_ONRAM                ),
      .IMPLBYLOGIC(IMPLBYLOGIC               )
   ) stapai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (sin     ),
      .shiftout(sout    ),
      .reseting(reseting)
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) so_spliti(
      .in   (sout    ),
      .out  (shiftout)
   );
endmodule
module shiftfixtaps_unpackedunit_unpackedarray_extd #(
   parameter int        DATABITW    = 43,          ///< 数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int        EXTDBITW    = 6,           ///< 同步选取的额外数据位宽
   parameter int signed TAP_DIST    = 4,           ///< 移阶时钟数，当为0时则输入输出信号直通
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (
   input  bit                 clk,                                   ///< 驱动时钟
   input  wire                aclr,                                  ///< 异步复位信号，高电平(1)有效
   input  wire                sclr,                                  ///< 同步复位信号，高电平(1)有效
   input  wire                clken,                                 ///< 移阶使能信号，高电平(1)有效
   input  wire[DATABITW-1:0]  shiftin [ARRAYSIZ-1:0][AUNITSIZ-1:0],  ///< 移阶器输入
   input  wire[EXTDBITW-1:0]  extdin,                                ///< 移阶器额外数据输入
   output wire[DATABITW-1:0]  shiftout[ARRAYSIZ-1:0][AUNITSIZ-1:0],  ///< 移阶器输出
   output wire[EXTDBITW-1:0]  extdout,                               ///< 移阶器额外数据输出
   output wire                reseting                               ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
);
   wire[EXTDBITW+DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) si_cmbi(
      .in   (shiftin                            ),
      .out  (sin[ARRAYSIZ*AUNITSIZ*DATABITW-1:0])
   );
   assign sin[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW] = extdin;
   shiftfixtaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .TAP_DIST   (TAP_DIST                           ),
      .SCLR_ONRAM (SCLR_ONRAM                         ),
      .IMPLBYLOGIC(IMPLBYLOGIC                        )
   ) stapai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (sin     ),
      .shiftout(sout    ),
      .reseting(reseting)
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) so_spliti(
      .in   (sout[ARRAYSIZ*AUNITSIZ*DATABITW-1:0]  ),
      .out  (shiftout                              )
   );
   assign extdout = sout[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW];
endmodule
/*!
 * \brief 自动选择资源类型的可变阶数移阶寄存器
 * \details 移阶时钟数小于 #SHIFTTAPS_TAPS2RAM ，或者移阶寄存器总比特位数小于 #ALLBITS2RAM_GATE 时，使用寄存器资源，否则使用RAM资源例化移阶寄存器。
 */
module shiftvartaps #(
   parameter int        DATABITW    = 43,          ///< 移阶数据位宽
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
) (clk, aclr, sclr, clken, intap, shiftin, outtap, shiftout, illegal_tap, reseting);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效
   input  wire                clken;               ///< 移阶使能信号，高电平(1)有效
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire [tapsbitw-1:0] intap;               ///< 输入数据对应输入端移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire [DATABITW-1:0] shiftin;             ///< 移阶器数据输入
   input  wire [tapsbitw-1:0] outtap;              ///< 输入数据对应输出端移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。
                                                   ///< \attention  #outtap 将延迟 #shifttaps_pkg::delaytaps_onouttap_of_shiftvartaps (3) 拍后在 #shiftout 生效
   output wire [DATABITW-1:0] shiftout;            ///< 移阶器数据输出
   output logic               illegal_tap;         ///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                   ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic               reseting;            ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   localparam int shifttaps_taps2ram = miscs::taps2ram + int'(SCLR_ONRAM);
   genvar i; generate if (MAX_TAP <= 0) assign shiftout = shiftin, illegal_tap = 1'b0, reseting = 1'b0;
   else begin
      // outtap pipe for mux
      logic[2:1][tapsbitw-1:0]outtap_pipe;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) outtap_pipe <= '0;
         else if (sclr) outtap_pipe <= '0;
         else           outtap_pipe <= clken ? {outtap_pipe[1], outtap} : outtap_pipe;
      end
      // intap for check
      localparam int tapsbitw4chk = miscs::minbitw_of_integer(MAX_TAP + 3, 32);
      logic[3:0][tapsbitw-1:0]intap_pipe;
      assign intap_pipe[0] = intap;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) intap_pipe[3:1] <= '0;
         else if (sclr) intap_pipe[3:1] <= '0;
         else           intap_pipe[3:1] <= clken ? intap_pipe[2:0] : intap_pipe[3:1];
      end
      // outtap for check
      logic [3:0][tapsbitw4chk-1:0] outtap4chk;
      assign outtap4chk[0] = (tapsbitw4chk)'(outtap);
      assign outtap4chk[1] = (tapsbitw4chk)'(outtap_pipe[1]);
      assign outtap4chk[2] = (tapsbitw4chk)'(outtap_pipe[2]);
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) outtap4chk[3] <= '0;
         else if (sclr) outtap4chk[3] <= '0;
         else           outtap4chk[3] <= clken ? outtap4chk[2] : outtap4chk[3];
      end
      // illegal_tap signal
      wire illegal_tap_in = (outtap <= intap) ? 1'b1 : 1'b0;
      pipedelay_taps #(
         .DATABITW(1),  .DELAYTAPS(3)
      ) illegal_tap_pipe(
         .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),
         .x(illegal_tap_in),     .pipe_x(illegal_tap)
      );
      if (MAX_TAP < shifttaps_taps2ram) begin: D_P_O
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr) illegal_tap <= '0;
            else if (sclr) illegal_tap <= '0;
            else           illegal_tap <= clken ? illegal_tap_in : illegal_tap;
         end
         logic [DATABITW-1:0] pipe_array[MAX_TAP:0];
         assign pipe_array[0] = shiftin;
         for (i = 1; i <= MAX_TAP; i++) begin: PIPE_REGS
            wire[DATABITW:0]pipein;
            assign pipein = (intap == (tapsbitw)'(i-1)) ? shiftin : pipe_array[i-1];
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if      (aclr) pipe_array[i] <= '0;
               else if (sclr) pipe_array[i] <= '0;
               else if (clken)pipe_array[i] <= pipein;
               else           pipe_array[i] <= pipe_array[i];
            end
         end
         wire[DATABITW-1:0]mux_out;
         mux_byidx #(
            .UNITBITW(DATABITW),  .INPUTCNT(MAX_TAP+1),  .DELAYTAPS(2)
         ) pipe_mux(
            .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken), .data_in(pipe_array),
            .data4nocs({(DATABITW){1'b0}}),     .idx(outtap),  .data_out(mux_out)
         );
         logic [2:1][DATABITW-1:0] ind;
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr) ind <= '0;
            else if (sclr) ind <= '0;
            else           ind <= clken ? {ind[1], shiftin} : ind;
         end
         logic[DATABITW-1:0] d2o;
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr)                                                                d2o <= '0;
            else if (sclr)                                                                d2o <= '0;
            else if (~clken)                                                              d2o <= d2o;
            else if (outtap4chk[2] == (tapsbitw4chk)'(intap_pipe[0]) + (tapsbitw4chk)'(1))d2o <= shiftin;
            else if (outtap4chk[2] == (tapsbitw4chk)'(intap_pipe[1]) + (tapsbitw4chk)'(2))d2o <= ind[1];
            else if (outtap4chk[2] == (tapsbitw4chk)'(intap_pipe[2]) + (tapsbitw4chk)'(3))d2o <= ind[2];
            else                                                                          d2o <= mux_out;
         end
         assign shiftout = d2o[DATABITW-1:0], reseting = 1'b0;
      end else begin: RAM_O
         initial if (MAX_TAP < 3) $error("shiftvartaps : parameter MAX_TAP(%0d) should not be less than 3, for macro `SHIFTTAPS_TAPS2RAM (%0d)", MAX_TAP, miscs::taps2ram);
         localparam int lat4blkram_addrq2addrw = 2;
         localparam int lasttapbyreg = 1;
         localparam int implmod = (IMPLBYLOGIC == 1'b1 || rams_pkg::recommend_ramstyle(MAX_TAP - 1 - int'(lasttapbyreg) + lat4blkram_addrq2addrw, DATABITW) == 0) ? 0 : 2;
         localparam int lat_addrq2addrw = implmod == 0 ? 0 : lat4blkram_addrq2addrw;// 对BlockRam，读写地址相同时读写结果可能出错，必须错开
         localparam int ram_len = MAX_TAP - 1 - int'(lasttapbyreg) - int'(SCLR_ONRAM);// + lat_addrq2addrw;
         localparam int addrBitw = miscs::minbitw_of_integer(ram_len-1, 31);
         logic                sclr_on_ram_bgn, sclr_on_ram_ongoing, sclr_on_ram_done, sclr_on_ramq;
         logic [DATABITW-1:0] ram_w, ram_o;
         logic [addrBitw-1:0] baseAddr, addr2W, addr2Q, addrW, addrQ;
         wire  [addrBitw-1:0] nxt_baseAddr = (|baseAddr) ? baseAddr - (addrBitw)'(1) : (addrBitw)'(ram_len-1);
         if (SCLR_ONRAM) begin
            logic prev_sclr;
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) prev_sclr <= aclr ? '0 : sclr;
            logic prev_aclr = 1'b0;
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) prev_aclr <= aclr;
            assign sclr_on_ram_bgn = ((~prev_sclr)&sclr)|(prev_aclr&(~aclr));
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if     (aclr)           sclr_on_ram_ongoing <= '0;
               else if(sclr_on_ram_bgn)sclr_on_ram_ongoing <= '1;
               else                    sclr_on_ram_ongoing <= sclr_on_ram_done ? '0 : sclr_on_ram_ongoing;
            end
            assign sclr_on_ram_done = sclr_on_ram_ongoing&(~(|baseAddr));
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if      (aclr)                baseAddr <= (addrBitw)'(ram_len-1);
               else if (sclr_on_ram_bgn)     baseAddr <= (addrBitw)'(ram_len-1);
               else if (sclr_on_ram_ongoing) baseAddr <= nxt_baseAddr;
               else if (sclr)                baseAddr <= (addrBitw)'(ram_len-1);
               else                          baseAddr <= clken ? nxt_baseAddr : baseAddr;
            end
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if     (aclr)           sclr_on_ramq <= '0;
               else if(sclr_on_ram_bgn)sclr_on_ramq <= '1;
               else                    sclr_on_ramq <= sclr_on_ram_ongoing ? sclr_on_ram_ongoing : '0;
            end
            assign reseting = sclr_on_ram_ongoing;
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if      (aclr)                addrW <= (addrBitw)'(ram_len-1);
               else if (sclr_on_ram_ongoing) addrW <= addr2W;
               else if (sclr)                addrW <= (addrBitw)'(ram_len-1);
               else                          addrW <= clken ? addr2W : addrW;
            end
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if      (aclr)                ram_w <= '0;
               else if (sclr_on_ram_ongoing) ram_w <= '0;
               else if (sclr)                ram_w <= '0;
               else                          ram_w <= clken ? shiftin : ram_w;
            end
         end else begin
            assign sclr_on_ram_bgn = 1'b0, sclr_on_ram_ongoing = 1'b0, sclr_on_ram_done = 1'b0, sclr_on_ramq = 1'b0, reseting = 1'b0;
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if      (aclr) baseAddr <= (addrBitw)'(ram_len-1);
               else if (sclr) baseAddr <= (addrBitw)'(ram_len-1);
               else if (clken)baseAddr <= nxt_baseAddr;
               else           baseAddr <= baseAddr;
            end
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if      (aclr) addrW <= '0;
               else if (sclr) addrW <= '0;
               else           addrW <= clken ? addr2W : addrW;
            end
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if      (aclr) ram_w <= '0;
               else if (sclr) ram_w <= '0;
               else           ram_w <= clken ? shiftin : ram_w;
            end
         end
         wire[tapsbitw-1:0]baseAddr_taps = (tapsbitw)'(baseAddr);
         assign   addr2W = (addrBitw)'((baseAddr < (addrBitw)'(ram_len) - (addrBitw)'(intap)) ?
                                      (baseAddr + (addrBitw)'(intap)) :
                                      ((addrBitw+1)'(baseAddr) + (addrBitw+1)'(intap) - (addrBitw+1)'(ram_len)));
         /*
          * 计算 #addrQ 时应避免加/减法溢出( #LASTTAPBYREG == 1'b1 时)：
          * 基本的 #addrQ 计算公式为 baseAddr_taps + (outtap - 2) ，其中的-2是因为(1)读地址 #addrQ 置位后延迟一个时钟才能得到结果；(2)RAM输出数据再被延迟一个时钟才输出。
          * 上面的公式需要防止上溢和下溢：
          * #- 对上溢的情况，考察条件 baseAddr_taps + (outtap - 2) < ram_len 是否成立来决定是否对上面的公式做等效变换。即：
          * 满足 ram_len - baseAddr_taps > outtap - 2 时， addrQ = baseAddr_taps + (outtap - 2) 。为避免无符号数outtap做减产生
          * 溢出造成判断错误，需要进一步拆分条件：
          *    - outtap < 2 ，上面条件绝对满足， addrQ = baseAddr_taps + outtap - 2 ；
          *    - outtap >= 2 ，则当 outtap - 2 < ram_len - baseAddr_taps 时， addrQ = baseAddr_taps + outtap - 2 ；
          *      否则当 outtap - 2 >= ram_len - baseAddr_taps 时， addrQ = baseAddr_taps + outtaps - ramlen - 2 。
          * #- 对下溢的情况，考察条件 baseAddr_taps + (outtap - 2) >= 0 是否成立来决定是否对公式做等效变换。即：
          * 满足 baseAddr_taps + outtap >= 2 时， addrQ = baeAddr_taps + outtap - 2 ，否则 addrQ = baseAddr_taps + outtap + ram_len - 2 ；
          * 进一步的，由于 baseAddr_taps 和 outtap 都是无符号数，不满足 baseAddr_taps + outtap >= 2 的情况只可能是：
          * baseAddr_taps == outtap < 2 ，因此该条件可以改为： baseAddr_taps == outtap < 2 时， addrQ = ram_len - 1 ；
          * 否则 addrQ = baseAddr_taps + outtap - 2 。
          * 
          * 综上，可以归纳 #addrQ 的赋值条件逻辑为：
          * - outtap < 2 ：
          *    - baseAddr_taps <  2 时， addrQ = ram_len - 1;
          *    - baseAddr_taps >= 2 时， addrQ = baseAddr_taps + outtap - 2;
          * - outtap >= 2 ：
          *    - outtap - 2 <  ram_len - baseAddr_taps 时， addrQ = baseAddr_taps + outtap - 2;
          *    - outtap - 2 >= ram_len - baseAddr_taps 时， addrQ = baseAddr_taps + outtaps - ramlen - 2;
          */
         localparam int addr2q_fix4ramlen = 2;
         localparam int tapsbitw4chk = miscs::minbitw_of_integer(MAX_TAP + (((addr2q_fix4ramlen + int'(lasttapbyreg) + int'(SCLR_ONRAM) + lat_addrq2addrw) < 3) ? 3 : (addr2q_fix4ramlen + int'(lasttapbyreg) + lat_addrq2addrw)), 32);
         logic [tapsbitw4chk-1:0] outtap4q;
         assign addr2Q = (addrBitw)'((outtap4q < (tapsbitw4chk)'(addr2q_fix4ramlen + int'(lasttapbyreg) + int'(SCLR_ONRAM) + lat_addrq2addrw)) ?
                                    ((baseAddr < (addrBitw)'(addr2q_fix4ramlen + int'(lasttapbyreg) + int'(SCLR_ONRAM) + lat_addrq2addrw)) ?
                                     (addrBitw)'(ram_len - 1) :
                                     (addrBitw)'(baseAddr + outtap4q - (addrBitw)'(addr2q_fix4ramlen + int'(lasttapbyreg) + int'(SCLR_ONRAM) + lat_addrq2addrw))) :
                                    (((addrBitw)'(outtap4q) - (addrBitw)'(addr2q_fix4ramlen + int'(lasttapbyreg) + int'(SCLR_ONRAM) + lat_addrq2addrw) < (addrBitw)'(ram_len) - baseAddr) ?
                                     (baseAddr + ((addrBitw)'(outtap4q) - (addrBitw)'(addr2q_fix4ramlen + int'(lasttapbyreg) + int'(SCLR_ONRAM) + lat_addrq2addrw))) :
                                     ((addrBitw+1)'(baseAddr) + (addrBitw+1)'(outtap4q) - (addrBitw+1)'(ram_len + addr2q_fix4ramlen + int'(lasttapbyreg) + int'(SCLR_ONRAM) + lat_addrq2addrw))));
         assign outtap4q = (tapsbitw4chk)'(outtap);
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr) addrQ <= '0;
            else if (sclr) addrQ <= '0;
            else           addrQ <= clken ? addr2Q : addrQ;
         end
         sdpram #(
            .DATABITW(DATABITW   ),
            .ADDRLEN (ram_len    ),
            .IMPLMOD (implmod    ),
            .REGOUTP (SCLR_ONRAM )
         ) sdprpai(
            .clk     (clk                                         ),
            .aclr    (aclr                                        ),
            .sclr    (sclr|sclr_on_ramq                           ),
            .we      ((clken&(~(aclr|sclr)))|sclr_on_ram_ongoing  ),
            .clken_w (clken                                       ),
            .addr_w  (addrW                                       ),
            .data_w  (ram_w                                       ),
            .clken_q (clken                                       ),
            .addr_q  (addrQ                                       ),
            .data_q  (ram_o                                       )
         );
         logic [DATABITW-1:0] ram_wd;
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr)             ram_wd <= '0;
            else if (sclr|sclr_on_ramq)ram_wd <= '0;
            else                       ram_wd <= clken ? ram_w : ram_wd;
         end
         logic [DATABITW-1:0] reg2out;
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr)                                                                reg2out <= '0;
            else if (sclr|sclr_on_ramq)                                                   reg2out <= '0;
            else if (~clken)                                                              reg2out <= reg2out;
            else if (outtap4chk[2] == (tapsbitw4chk)'(intap_pipe[0]) + (tapsbitw4chk)'(1))reg2out <= shiftin;
            else if (outtap4chk[2] == (tapsbitw4chk)'(intap_pipe[1]) + (tapsbitw4chk)'(2))reg2out <= ram_w;
            else if (outtap4chk[2] == (tapsbitw4chk)'(intap_pipe[2]) + (tapsbitw4chk)'(3))reg2out <= ram_wd;
            else                                                                          reg2out <= ram_o[DATABITW-1:0];
         end
         assign shiftout = reg2out[DATABITW-1:0];
      end
   end endgenerate
endmodule
module shiftvartaps_packedarray #(
   parameter int        DATABITW    = 43,          ///< 待移阶数组元素数据位宽
   parameter int        ARRAYSIZ    = 2,           ///< 数组元素个数
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
                                                   ///< \attention 当 #REG_PRI == 1'b1 时， #MAX_TAP 设置过大的值会使设计不得不使用过多输入的多选一复选器，从而可能会导致时序性能恶化
) (clk, aclr, sclr, clken, intap, shiftin, outtap, shiftout, illegal_tap, reseting);
   input  bit                             clk;              ///< 驱动时钟
   input  wire                            aclr, sclr, clken;///< aclr－异步复位信号，sclr-同步复位信号，clken－移阶使能信号
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire[tapsbitw-1:0]              intap;            ///< 输入数据对应移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]shiftin;          ///< 移阶器数组输入
   input  wire[tapsbitw-1:0]              outtap;           ///< 输出移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。 \attention 
                                                            ///< - 当 #LASTTAPBYREG == 1'b0 时，本信号仅需要相对输出时刻提前1拍置位；
                                                            ///< - 当 #LASTTAPBYREG == 1'b1 时，本信号则必须相对输出时刻提前2拍置位。
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]shiftout;         ///< 移阶器数组输出
   output logic                           illegal_tap;      ///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                            ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic                           reseting;         ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                            ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   wire[DATABITW*ARRAYSIZ-1:0]sin, sout;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) c2u(
      .in   (shiftin ),
      .out  (sin     )
   );
   shiftvartaps #(
      .DATABITW   (DATABITW*ARRAYSIZ),
      .MAX_TAP    (MAX_TAP          ),
      .SCLR_ONRAM (SCLR_ONRAM       ),
      .IMPLBYLOGIC(IMPLBYLOGIC      )
   ) stvtpai(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .intap      (intap      ),
      .shiftin    (sin        ),
      .outtap     (outtap     ),
      .shiftout   (sout       ),
      .illegal_tap(illegal_tap),
      .reseting   (reseting   )
   );
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) s2p(
      .in   (sout    ),
      .out  (shiftout)
   );
endmodule
module shiftvartaps_unpackedarray #(
   parameter int        DATABITW    = 43,          ///< 待移阶数组元素数据位宽
   parameter int        ARRAYSIZ    = 2,           ///< 数组元素个数
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
                                                   ///< \attention 当 #REG_PRI == 1'b1 时， #MAX_TAP 设置过大的值会使设计不得不使用过多输入的多选一复选器，从而可能会导致时序性能恶化
) (clk, aclr, sclr, clken, intap, shiftin, outtap, shiftout, illegal_tap, reseting);
   input  bit                 clk;                    ///< 驱动时钟
   input  wire                aclr;                   ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                   ///< 同步复位信号，高电平(1)有效
   input  wire                clken;                  ///< 移阶使能信号，高电平(1)有效
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire [tapsbitw-1:0] intap;                  ///< 输入数据对应移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire [DATABITW-1:0] shiftin[ARRAYSIZ-1:0];  ///< 移阶器数据输入
   input  wire [tapsbitw-1:0] outtap;                 ///< 输出移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。 \attention 
                                                      ///< - 当 #LASTTAPBYREG == 1'b0 时，本信号仅需要相对输出时刻提前1拍置位；
                                                      ///< - 当 #LASTTAPBYREG == 1'b1 时，本信号则必须相对输出时刻提前2拍置位。
   output wire [DATABITW-1:0] shiftout[ARRAYSIZ-1:0]; ///< 移阶器数据输出
   output logic               illegal_tap;            ///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                      ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic               reseting;               ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                      ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   wire[ARRAYSIZ-1:0][DATABITW-1:0]sin, sout;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aci(
      .in   (shiftin ),
      .out  (sin     )
   );
   shiftvartaps_packedarray #(
      .DATABITW   (DATABITW   ),
      .ARRAYSIZ   (ARRAYSIZ   ),
      .MAX_TAP    (MAX_TAP    ),
      .SCLR_ONRAM (SCLR_ONRAM ),
      .IMPLBYLOGIC(IMPLBYLOGIC)
   ) stvtpai(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .intap      (intap      ),
      .shiftin    (sin        ),
      .outtap     (outtap     ),
      .shiftout   (sout       ),
      .illegal_tap(illegal_tap),
      .reseting   (reseting   )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aco(
      .in   (sout    ),
      .out  (shiftout)
   );
endmodule
module shiftvartaps_packedarray_extd #(
   parameter int        DATABITW    = 43,          ///< 待移阶数组元素数据位宽
   parameter int        ARRAYSIZ    = 2,           ///< 数组元素个数
   parameter int        EXTDBITW    = 5,           ///< 扩展的非数组数据位宽
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
                                                   ///< \attention 当 #REG_PRI == 1'b1 时， #MAX_TAP 设置过大的值会使设计不得不使用过多输入的多选一复选器，从而可能会导致时序性能恶化
) (clk, aclr, sclr, clken, intap, shiftin, extdin, outtap, shiftout, extdout, illegal_tap, reseting);
   input  bit                             clk;        ///< 驱动时钟
   input  wire                            aclr;       ///< 异步复位信号，高电平(1)有效
   input  wire                            sclr;       ///< 同步复位信号，高电平(1)有效
   input  wire                            clken;      ///< 移阶使能信号，高电平(1)有效
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire[tapsbitw-1:0]              intap;      ///< 输入数据对应移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]shiftin;    ///< 移阶器数据输入
   input  wire[EXTDBITW-1:0]              extdin;     ///< 移阶器额外数据输入
   input  wire[tapsbitw-1:0]              outtap;     ///< 输出移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。 \attention 
                                                      ///< - 当 #LASTTAPBYREG == 1'b0 时，本信号仅需要相对输出时刻提前1拍置位；
                                                      ///< - 当 #LASTTAPBYREG == 1'b1 时，本信号则必须相对输出时刻提前2拍置位。
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]shiftout;   ///< 移阶器数据输出
   output wire[EXTDBITW-1:0]              extdout;    ///< 移阶器额外数据输出
   output logic                           illegal_tap;///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                      ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic                           reseting;   ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                      ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   wire[DATABITW*ARRAYSIZ+EXTDBITW-1:0]si, so;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in   (shiftin                   ),
      .out  (si[DATABITW*ARRAYSIZ-1:0] )
   );
   assign si[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ] = extdin;
   shiftvartaps #(
      .DATABITW   (DATABITW*ARRAYSIZ+EXTDBITW),
      .MAX_TAP    (MAX_TAP                   ),
      .SCLR_ONRAM (SCLR_ONRAM                ),
      .IMPLBYLOGIC(IMPLBYLOGIC               )
   ) stvti(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .intap      (intap      ),
      .shiftin    (si         ),
      .outtap     (outtap     ),
      .shiftout   (so         ),
      .illegal_tap(illegal_tap),
      .reseting   (reseting   )
   );
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in   (so[DATABITW*ARRAYSIZ-1:0] ),
      .out  (shiftout                  )
   );
   assign extdout = so[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ];
endmodule
module shiftvartaps_unpackedarray_extd #(
   parameter int        DATABITW    = 43,          ///< 待移阶数组元素数据位宽
   parameter int        ARRAYSIZ    = 2,           ///< 数组元素个数
   parameter int        EXTDBITW    = 5,           ///< 扩展的非数组数据位宽
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
                                                   ///< \attention 当 #REG_PRI == 1'b1 时， #MAX_TAP 设置过大的值会使设计不得不使用过多输入的多选一复选器，从而可能会导致时序性能恶化
) (clk, aclr, sclr, clken, intap, shiftin, extdin, outtap, shiftout, extdout, illegal_tap, reseting);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效
   input  wire                clken;               ///< 移阶使能信号，高电平(1)有效
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire [tapsbitw-1:0] intap;               ///< 输入数据对应移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire [DATABITW-1:0] shiftin[ARRAYSIZ-1:0];///< 移阶器数据输入
   input  wire [EXTDBITW-1:0] extdin;              ///< 移阶器额外数据输入
   input  wire [tapsbitw-1:0] outtap;              ///< 输出移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。 \attention 
                                                   ///< - 当 #LASTTAPBYREG == 1'b0 时，本信号仅需要相对输出时刻提前1拍置位；
                                                   ///< - 当 #LASTTAPBYREG == 1'b1 时，本信号则必须相对输出时刻提前2拍置位。
   output wire [DATABITW-1:0] shiftout[ARRAYSIZ-1:0];///< 移阶器数据输出
   output wire [EXTDBITW-1:0] extdout;             ///< 移阶器额外数据输出
   output logic               illegal_tap;         ///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                   ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic               reseting;            ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   wire[DATABITW*ARRAYSIZ+EXTDBITW-1:0]si, so;
   unpackedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in   (shiftin                   ),
      .out  (si[DATABITW*ARRAYSIZ-1:0] )
   );
   assign si[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ] = extdin;
   shiftvartaps #(
      .DATABITW   (DATABITW*ARRAYSIZ+EXTDBITW),
      .MAX_TAP    (MAX_TAP                   ),
      .SCLR_ONRAM (SCLR_ONRAM                ),
      .IMPLBYLOGIC(IMPLBYLOGIC               )
   ) stvti(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .intap      (intap      ),
      .shiftin    (si         ),
      .outtap     (outtap     ),
      .shiftout   (so         ),
      .illegal_tap(illegal_tap),
      .reseting   (reseting   )
   );
   unit_split2unpackedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in   (so[DATABITW*ARRAYSIZ-1:0] ),
      .out  (shiftout                  )
   );
   assign extdout = so[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ];
endmodule
module shiftvartaps_packedunit_packedarray #(
   parameter int        DATABITW    = 43,          ///< 待移阶数组元素数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
                                                   ///< \attention 当 #REG_PRI == 1'b1 时， #MAX_TAP 设置过大的值会使设计不得不使用过多输入的多选一复选器，从而可能会导致时序性能恶化
) (clk, aclr, sclr, clken, intap, shiftin, outtap, shiftout, illegal_tap, reseting);
   input  bit                                            clk;              ///< 驱动时钟
   input  wire                                           aclr, sclr, clken;///< aclr－异步复位信号，sclr-同步复位信号，clken－移阶使能信号
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire[tapsbitw-1:0]                             intap;            ///< 输入数据对应移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] shiftin;          ///< 移阶器数组输入
   input  wire[tapsbitw-1:0]                             outtap;           ///< 输出移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。 \attention 
                                                                           ///< - 当 #LASTTAPBYREG == 1'b0 时，本信号仅需要相对输出时刻提前1拍置位；
                                                                           ///< - 当 #LASTTAPBYREG == 1'b1 时，本信号则必须相对输出时刻提前2拍置位。
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] shiftout;         ///< 移阶器数组输出
   output logic                                          illegal_tap;      ///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                                           ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic                                          reseting;         ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                                           ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   wire[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) c2u(
      .in   (shiftin ),
      .out  (sin     )
   );
   shiftvartaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ),
      .MAX_TAP    (MAX_TAP                   ),
      .SCLR_ONRAM (SCLR_ONRAM                ),
      .IMPLBYLOGIC(IMPLBYLOGIC               )
   ) stvtpai(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .intap      (intap      ),
      .shiftin    (sin        ),
      .outtap     (outtap     ),
      .shiftout   (sout       ),
      .illegal_tap(illegal_tap),
      .reseting   (reseting   )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) s2p(
      .in   (sout    ),
      .out  (shiftout)
   );
endmodule
module shiftvartaps_packedunit_packedarray_extd #(
   parameter int        DATABITW    = 43,          ///< 待移阶数组元素数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int        EXTDBITW    = 6,           ///< 同步选取的额外数据位宽
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
                                                   ///< \attention 当 #REG_PRI == 1'b1 时， #MAX_TAP 设置过大的值会使设计不得不使用过多输入的多选一复选器，从而可能会导致时序性能恶化
) (clk, aclr, sclr, clken, intap, shiftin, extdin, outtap, shiftout, extdout, illegal_tap, reseting);
   input  bit                                            clk;              ///< 驱动时钟
   input  wire                                           aclr, sclr, clken;///< aclr－异步复位信号，sclr-同步复位信号，clken－移阶使能信号
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire[tapsbitw-1:0]                             intap;            ///< 输入数据对应移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] shiftin;          ///< 移阶器数组输入
   input  wire[EXTDBITW-1:0]                             extdin;           ///< 移阶器额外数据输入
   input  wire[tapsbitw-1:0]                             outtap;           ///< 输出移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。 \attention 
                                                                           ///< - 当 #LASTTAPBYREG == 1'b0 时，本信号仅需要相对输出时刻提前1拍置位；
                                                                           ///< - 当 #LASTTAPBYREG == 1'b1 时，本信号则必须相对输出时刻提前2拍置位。
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] shiftout;         ///< 移阶器数组输出
   output wire[EXTDBITW-1:0]                             extdout;          ///< 移阶器额外数据输出
   output logic                                          illegal_tap;      ///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                                           ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic                                          reseting;         ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                                           ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   wire[EXTDBITW+DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) c2u(
      .in   (shiftin                            ),
      .out  (sin[ARRAYSIZ*AUNITSIZ*DATABITW-1:0])
   );
   assign sin[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW] = extdin;
   shiftvartaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .MAX_TAP    (MAX_TAP                            ),
      .SCLR_ONRAM (SCLR_ONRAM                         ),
      .IMPLBYLOGIC(IMPLBYLOGIC                        )
   ) stvtpai(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .intap      (intap      ),
      .shiftin    (sin        ),
      .outtap     (outtap     ),
      .shiftout   (sout       ),
      .illegal_tap(illegal_tap),
      .reseting   (reseting   )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) s2p(
      .in   (sout[ARRAYSIZ*AUNITSIZ*DATABITW-1:0]  ),
      .out  (shiftout                              )
   );
   assign extdout = sout[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW];
endmodule
module shiftvartaps_packedunit_unpackedarray #(
   parameter int        DATABITW    = 43,          ///< 待移阶数组元素数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
                                                   ///< \attention 当 #REG_PRI == 1'b1 时， #MAX_TAP 设置过大的值会使设计不得不使用过多输入的多选一复选器，从而可能会导致时序性能恶化
) (clk, aclr, sclr, clken, intap, shiftin, outtap, shiftout, illegal_tap, reseting);
   input  bit                             clk;                    ///< 驱动时钟
   input  wire                            aclr, sclr, clken;      ///< aclr－异步复位信号，sclr-同步复位信号，clken－移阶使能信号
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire[tapsbitw-1:0]              intap;                  ///< 输入数据对应移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]shiftin [ARRAYSIZ-1:0]; ///< 移阶器数组输入
   input  wire[tapsbitw-1:0]              outtap;                 ///< 输出移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。 \attention 
                                                                  ///< - 当 #LASTTAPBYREG == 1'b0 时，本信号仅需要相对输出时刻提前1拍置位；
                                                                  ///< - 当 #LASTTAPBYREG == 1'b1 时，本信号则必须相对输出时刻提前2拍置位。
   output wire[AUNITSIZ-1:0][DATABITW-1:0]shiftout[ARRAYSIZ-1:0]; ///< 移阶器数组输出
   output logic                           illegal_tap;            ///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                                  ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic                           reseting;               ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                                  ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   wire[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) c2u(
      .in   (shiftin ),
      .out  (sin     )
   );
   shiftvartaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ),
      .MAX_TAP    (MAX_TAP                   ),
      .SCLR_ONRAM (SCLR_ONRAM                ),
      .IMPLBYLOGIC(IMPLBYLOGIC               )
   ) stvtpai(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .intap      (intap      ),
      .shiftin    (sin        ),
      .outtap     (outtap     ),
      .shiftout   (sout       ),
      .illegal_tap(illegal_tap),
      .reseting   (reseting   )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) s2p(
      .in   (sout    ),
      .out  (shiftout)
   );
endmodule
module shiftvartaps_packedunit_unpackedarray_extd #(
   parameter int        DATABITW    = 43,          ///< 待移阶数组元素数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int        EXTDBITW    = 6,           ///< 同步选取的额外数据位宽
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
                                                   ///< \attention 当 #REG_PRI == 1'b1 时， #MAX_TAP 设置过大的值会使设计不得不使用过多输入的多选一复选器，从而可能会导致时序性能恶化
) (clk, aclr, sclr, clken, intap, shiftin, extdin, outtap, shiftout, extdout, illegal_tap, reseting);
   input  bit                             clk;                    ///< 驱动时钟
   input  wire                            aclr, sclr, clken;      ///< aclr－异步复位信号，sclr-同步复位信号，clken－移阶使能信号
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire[tapsbitw-1:0]              intap;                  ///< 输入数据对应移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]shiftin [ARRAYSIZ-1:0]; ///< 移阶器数组输入
   input  wire[EXTDBITW-1:0]              extdin;                 ///< 移阶器额外数据输入
   input  wire[tapsbitw-1:0]              outtap;                 ///< 输出移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。 \attention 
                                                                  ///< - 当 #LASTTAPBYREG == 1'b0 时，本信号仅需要相对输出时刻提前1拍置位；
                                                                  ///< - 当 #LASTTAPBYREG == 1'b1 时，本信号则必须相对输出时刻提前2拍置位。
   output wire[AUNITSIZ-1:0][DATABITW-1:0]shiftout[ARRAYSIZ-1:0]; ///< 移阶器数组输出
   output wire[EXTDBITW-1:0]              extdout;                ///< 移阶器额外数据输出
   output logic                           illegal_tap;            ///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                                  ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic                           reseting;               ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                                  ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   wire[EXTDBITW+DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) c2u(
      .in   (shiftin                            ),
      .out  (sin[ARRAYSIZ*AUNITSIZ*DATABITW-1:0])
   );
   assign sin[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW] = extdin;
   shiftvartaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .MAX_TAP    (MAX_TAP                            ),
      .SCLR_ONRAM (SCLR_ONRAM                         ),
      .IMPLBYLOGIC(IMPLBYLOGIC                        )
   ) stvtpai(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .intap      (intap      ),
      .shiftin    (sin        ),
      .outtap     (outtap     ),
      .shiftout   (sout       ),
      .illegal_tap(illegal_tap),
      .reseting   (reseting   )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) s2p(
      .in   (sout[ARRAYSIZ*AUNITSIZ*DATABITW-1:0]  ),
      .out  (shiftout                              )
   );
   assign extdout = sout[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW];
endmodule
module shiftvartaps_unpackedunit_unpackedarray #(
   parameter int        DATABITW    = 43,          ///< 待移阶数组元素数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
                                                   ///< \attention 当 #REG_PRI == 1'b1 时， #MAX_TAP 设置过大的值会使设计不得不使用过多输入的多选一复选器，从而可能会导致时序性能恶化
) (clk, aclr, sclr, clken, intap, shiftin, outtap, shiftout, illegal_tap, reseting);
   input  bit                 clk;                                   ///< 驱动时钟
   input  wire                aclr, sclr, clken;                     ///< aclr－异步复位信号，sclr-同步复位信号，clken－移阶使能信号
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire[tapsbitw-1:0]  intap;                                 ///< 输入数据对应移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire[DATABITW-1:0]  shiftin [ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< 移阶器数组输入
   input  wire[tapsbitw-1:0]  outtap;                                ///< 输出移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。 \attention 
                                                                     ///< - 当 #LASTTAPBYREG == 1'b0 时，本信号仅需要相对输出时刻提前1拍置位；
                                                                     ///< - 当 #LASTTAPBYREG == 1'b1 时，本信号则必须相对输出时刻提前2拍置位。
   output wire[DATABITW-1:0]  shiftout[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< 移阶器数组输出
   output logic               illegal_tap;                           ///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                                     ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic               reseting;                              ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                                     ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   wire[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) c2u(
      .in   (shiftin ),
      .out  (sin     )
   );
   shiftvartaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ),
      .MAX_TAP    (MAX_TAP                   ),
      .SCLR_ONRAM (SCLR_ONRAM                ),
      .IMPLBYLOGIC(IMPLBYLOGIC               )
   ) stvtpai(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .intap      (intap      ),
      .shiftin    (sin        ),
      .outtap     (outtap     ),
      .shiftout   (sout       ),
      .illegal_tap(illegal_tap),
      .reseting   (reseting   )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) s2p(
      .in   (sout    ),
      .out  (shiftout)
   );
endmodule
module shiftvartaps_unpackedunit_unpackedarray_extd #(
   parameter int        DATABITW    = 43,          ///< 待移阶数组元素数据位宽
   parameter int        AUNITSIZ    = 2,           ///< 数组单元元素个数
   parameter int        ARRAYSIZ    = 2,           ///< 数组单元个数
   parameter int        EXTDBITW    = 6,           ///< 同步选取的额外数据位宽
   parameter int signed MAX_TAP     = 4,           ///< 最大移阶拍数
   parameter bit        SCLR_ONRAM  = 1'b0,        ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        IMPLBYLOGIC = 1'b0         ///< 优先使用逻辑资源实现移阶标志，1'b1:优先使用逻辑资源实现移阶寄存器，1'b0:按配置自动选择逻辑资源或者RAM资源实现移阶寄存器
                                                   ///< \attention 当 #REG_PRI == 1'b1 时， #MAX_TAP 设置过大的值会使设计不得不使用过多输入的多选一复选器，从而可能会导致时序性能恶化
) (clk, aclr, sclr, clken, intap, shiftin, extdin, outtap, shiftout, extdout, illegal_tap, reseting);
   input  bit                 clk;                                   ///< 驱动时钟
   input  wire                aclr, sclr, clken;                     ///< aclr－异步复位信号，sclr-同步复位信号，clken－移阶使能信号
   localparam int tapsbitw = miscs::minbitw_of_integer(MAX_TAP, 31);
   input  wire[tapsbitw-1:0]  intap;                                 ///< 输入数据对应移阶拍数，0:输入数据置位时刻对应未输入移阶寄存器时刻，1～n:输入数据置位时刻对应已被移阶寄存器移阶拍数
   input  wire[DATABITW-1:0]  shiftin [ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< 移阶器数组输入
   input  wire[EXTDBITW-1:0]  extdin;                                ///< 移阶器额外数据输入
   input  wire[tapsbitw-1:0]  outtap;                                ///< 输出移阶拍数，输出数据相对从移阶寄存器头输入时刻的延迟拍数。 \attention 
                                                                     ///< - 当 #LASTTAPBYREG == 1'b0 时，本信号仅需要相对输出时刻提前1拍置位；
                                                                     ///< - 当 #LASTTAPBYREG == 1'b1 时，本信号则必须相对输出时刻提前2拍置位。
   output wire[DATABITW-1:0]  shiftout[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< 移阶器数组输出
   output wire[EXTDBITW-1:0]  extdout;                               ///< 移阶器额外数据输出
   output logic               illegal_tap;                           ///< 移阶器阶数设置错误标志，高电平(1)表示 #intap 、 #outtap 设置错误
                                                                     ///< \attention #outtap 的设置值应大于 #intap 的值，否则 #illegal_tap 信号将被置位
   output logic               reseting;                              ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                                     ///< \attention 当模块处于正在复位状态时， #shiftin 上所有的输入都将被忽略

   wire[EXTDBITW+DATABITW*AUNITSIZ*ARRAYSIZ-1:0]sin, sout;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) c2u(
      .in   (shiftin                            ),
      .out  (sin[ARRAYSIZ*AUNITSIZ*DATABITW-1:0])
   );
   assign sin[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW] = extdin;
   shiftvartaps #(
      .DATABITW   (DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .MAX_TAP    (MAX_TAP                            ),
      .SCLR_ONRAM (SCLR_ONRAM                         ),
      .IMPLBYLOGIC(IMPLBYLOGIC                        )
   ) stvtpai(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .intap      (intap      ),
      .shiftin    (sin        ),
      .outtap     (outtap     ),
      .shiftout   (sout       ),
      .illegal_tap(illegal_tap),
      .reseting   (reseting   )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) s2p(
      .in   (sout[ARRAYSIZ*AUNITSIZ*DATABITW-1:0]  ),
      .out  (shiftout                              )
   );
   assign extdout = sout[EXTDBITW+ARRAYSIZ*AUNITSIZ*DATABITW-1:ARRAYSIZ*AUNITSIZ*DATABITW];
endmodule
