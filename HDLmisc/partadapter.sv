/*!
 * \license SPDX-License-Identifier: MIT
 * \file partadapter.sv
 * \brief 数据分块合路适配器
 * \author JohnYork <johnyork@yeah.net>
 * \depends partmux, dff_latch, idx2selsig
 */
`include "mux.svh"
`include "partmux.svh"
/*! \brief 数据分块合路适配器 */
module partadapter #(
   parameter int DATABITW  = 32,                   ///< 待分块数据位宽
   parameter int PARTBITW  = 8,                    ///< 分块输出数据位宽
   parameter bit DELAY_OUT = 0                     ///< 延迟输出标志，1-延迟一拍输出，0-不延迟输出
) (clk, aclr, sclr, part_in, wcs, we, data_out, prevalid, valid);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效
   input  wire [PARTBITW-1:0] part_in;             ///< 输入待适配的数据分块
   localparam int partCnt = partmux_pkg::partCntOfDataBitw(DATABITW, PARTBITW);
   input  wire [partCnt-1:0]  wcs;                 ///< 分块适配选通信号
   input  wire                we;                  ///< 分块适配写使能信号，高电平(1)有效
   output logic[DATABITW-1:0] data_out;            ///< 输出适配后的数据
   output logic               prevalid;            ///< 适配后数据输出有效预报标志，高电平(1)有效
   output logic               valid;               ///< 适配后数据输出有效标志，高电平(1)有效

   genvar i; generate for (i = 0; i < partCnt; i++) begin: ADAPT
      localparam int iLsbOfPart = i*PARTBITW;
      localparam int iMsbOfPart = (((i + i)*PARTBITW > DATABITW) ? DATABITW : (i + 1)*PARTBITW) - 1;
      if (i < partCnt - 1 || DELAY_OUT == 1'b1) begin
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr)       data_out[iMsbOfPart:iLsbOfPart] <= '0;
            else if (sclr)       data_out[iMsbOfPart:iLsbOfPart] <= '0;
            else if (wcs[i] & we)data_out[iMsbOfPart:iLsbOfPart] <= part_in;
            else                 data_out[iMsbOfPart:iLsbOfPart] <= data_out[iMsbOfPart:iLsbOfPart];
         end
      end
      else dff_latch #(
         .UNIT_BITW(iMsbOfPart - iLsbOfPart + 1)
      ) part_latch(
         .clk(clk),
         .aclr(aclr),
         .sclr(sclr),
         .d(part_in),
         .we(wcs[i] & we),
         .q(data_out[iMsbOfPart:iLsbOfPart])
      );
   end
   if (partCnt < 2) assign prevalid = '0;
   else if (DELAY_OUT == 1'b1) always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) prevalid <= '0;
      else if (sclr) prevalid <= '0;
      else if (we)   prevalid <= wcs[partCnt-2];
      else           prevalid <= prevalid;
   end
   else dff_latch #(
      .UNIT_BITW(1)
   ) prevalid_latcher(
      .clk(clk),
      .aclr(aclr),
      .sclr(sclr),
      .d(wcs[partCnt-2]),
      .we(we),
      .q(prevalid)
   );
   if (DELAY_OUT == 1'b1) always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) valid <= '0;
         else if (sclr) valid <= '0;
         else if (we)   valid <= wcs[partCnt-1];
         else           valid <= valid;
   end
   else dff_latch #(
      .UNIT_BITW(1)
   )valid_latcher(
      .clk(clk),
      .aclr(aclr),
      .sclr(sclr),
      .d(wcs[partCnt-1]),
      .we(we),
      .q(valid)
   );
   endgenerate
endmodule
/*! \brief 基于索引选通适配的数据分块合路适配器 */
module partadapter_byidx #(
   parameter int DATABITW  = 32,                   ///< 待分块数据位宽
   parameter int PARTBITW  = 8,                    ///< 分块输出数据位宽
   parameter bit DELAY_OUT = 0                     ///< 延迟输出标志，1-延迟一拍输出，0-不延迟输出
) (clk, aclr, sclr, part_in, idx, we, data_out, prevalid, valid);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效
   input  wire [PARTBITW-1:0] part_in;             ///< 输入待适配的数据分块
   localparam int partCnt = partmux_pkg::partCntOfDataBitw(DATABITW, PARTBITW);
   localparam int bitwofidx = mux_pkg::idxbitw_ofmux(partCnt);
   input  wire [bitwofidx-1:0]idx;                 ///< 分块适配选通索引
   input  wire                we;                  ///< 分块适配写使能信号，高电平(1)有效
   output logic[DATABITW-1:0] data_out;            ///< 输出适配后的数据
   output logic               prevalid;            ///< 适配后数据输出有效预报标志，高电平(1)有效
   output logic               valid;               ///< 适配后数据输出有效标志，高电平(1)有效

   wire[partCnt-1:0] selsig;
   idx2selsig #(
      .SELSIG_CNT (partCnt),
      .DELAYTAPS  (0       )
   ) idx2selsigi(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(1'b1    ),
      .idx  (idx     ),
      .cs   (selsig  )
   );
   partadapter #(
      .DATABITW(DATABITW),
      .PARTBITW(PARTBITW),
      .DELAY_OUT(DELAY_OUT)
   ) partadapteri(
      .clk(clk),
      .aclr(aclr),
      .sclr(sclr),
      .part_in(part_in),
      .wcs(selsig),
      .we(we),
      .data_out(data_out),
      .prevalid(prevalid),
      .valid(valid)
   );
endmodule

