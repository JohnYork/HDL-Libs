/*!
 * \license SPDX-License-Identifier: MIT
 * \file partmux.sv
 * \brief 数据分块多路复用选择器
 * \author JohnYork <johnyork@yeah.net>
 * \depends mux
 */
`include "mux.svh"
`define __INC_FROM_PARTMUX__
`include "partmux.svh"
/*! \brief 基于索引选通的数据分块多路复用选择器 */
module partmux_byidx #(
   parameter int              DATABITW   = 32,     ///< 待分块数据位宽
   parameter int              PARTBITW   = 8,      ///< 分块输出数据位宽
   parameter bit              SIGNEXTEND = 1'b0,   ///< 分块时是否作符号位扩展，1'b1-符号位扩展，1'b0-不做符号位扩展
   parameter bit[PARTBITW-1:0]INITNOCS   = {(PARTBITW){1'b0}},
   parameter int              DELAYTAPS  = 0       ///< 多路复用延迟输出拍数
) (clk, aclr, sclr, clken, data_in, part4nocs, idx, mux_out);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效
   input  wire                clken;               ///< 时序逻辑翻转使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] data_in;             ///< 输入待分块选通的数据
   input  wire [PARTBITW-1:0] part4nocs;           ///< 无数据分块被选通时输出的分块数据
   localparam int partCnt = partmux_pkg::partCntOfDataBitw(DATABITW, PARTBITW);
   localparam int idxbitw = mux_pkg::idxbitw_ofmux(partCnt);
   input  wire [idxbitw -1:0] idx;                 ///< 输入数据分块选通索引
   output logic[PARTBITW-1:0] mux_out;             ///< 输出被选通的数据分块

   wire[PARTBITW-1:0]parts2sel[partCnt-1:0];
   genvar i; generate for (i = 0; i < partCnt; i++) begin: PART
      localparam int partlsb_indata  = i*PARTBITW;
      localparam int partbits2assign = (i + 1)*PARTBITW <= DATABITW ? PARTBITW : (DATABITW - i*PARTBITW);
      assign parts2sel[i][partbits2assign-1:0] = data_in[partlsb_indata+partbits2assign-1:partlsb_indata];
      if (partbits2assign < PARTBITW) begin
         wire bit2ext;
         if (SIGNEXTEND)assign bit2ext = data_in[partlsb_indata+partbits2assign-1];
         else           assign bit2ext = '0;
         assign parts2sel[i][PARTBITW-1:partbits2assign] = {(PARTBITW-partbits2assign){bit2ext}};
      end
   end endgenerate
   mux_byidx #(
      .UNITBITW   (PARTBITW   ),
      .INPUTCNT   (partCnt    ),
      .INITNOCS   (INITNOCS   ),
      .DELAYTAPS  (DELAYTAPS  )
   ) partmuxi(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (parts2sel  ),
      .data4nocs  (part4nocs  ),
      .idx        (idx        ),
      .data_out   (mux_out    )
   );
endmodule
/*! \brief 基于选通信号选通的数据分块多路复用选择器 */
module partmux_bycs #(
   parameter int              DATABITW   = 32,     ///< 待分块数据位宽
   parameter int              PARTBITW   = 8,      ///< 分块输出数据位宽
   parameter bit[PARTBITW-1:0]INITNOCS   = {(PARTBITW){1'b0}},
   parameter bit              SIGNEXTEND = 1'b0,   ///< 分块时是否作符号位扩展，1'b1-符号位扩展，1'b0-不做符号位扩展
   parameter int              DELAYTAPS  = 0       ///< 多路复用选择器延迟输出拍数
) (clk, aclr, sclr, clken, data_in, part4nocs, cs, mux_out);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效
   input  wire                clken;               ///< 时序逻辑翻转使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] data_in;             ///< 输入待分块选通的数据
   input  wire [PARTBITW-1:0] part4nocs;           ///< 无数据分块被选通时输出的分块数据
   localparam int partCnt = partmux_pkg::partCntOfDataBitw(DATABITW, PARTBITW);
   input  wire [partCnt -1:0] cs;                  ///< 输入数据分块选通信号阵列
   output logic[PARTBITW-1:0] mux_out;             ///< 输出被选通的数据分块

   wire[PARTBITW-1:0]parts2sel[partCnt-1:0];
   genvar i; generate for (i = 0; i < partCnt; i++) begin: PART
      localparam int partlsb_indata  = i*PARTBITW;
      localparam int partbits2assign = (i + 1)*PARTBITW <= DATABITW ? PARTBITW : (DATABITW - i*PARTBITW);
      assign parts2sel[i][partbits2assign-1:0] = data_in[partlsb_indata+partbits2assign-1:partlsb_indata];
      if (partbits2assign < PARTBITW) begin
         wire bit2ext;
         if (SIGNEXTEND)assign bit2ext = data_in[partlsb_indata+partbits2assign-1];
         else           assign bit2ext = '0;
         assign parts2sel[i][PARTBITW-1:partbits2assign] = {(PARTBITW-partbits2assign){bit2ext}};
      end
   end endgenerate
   mux_bycs #(
      .UNITBITW   (PARTBITW   ),
      .INITNOCS   (INITNOCS   ),
      .INPUTCNT   (partCnt    ),
      .DELAYTAPS  (DELAYTAPS  )
   ) partmuxi(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ), 
      .data_in    (parts2sel  ),
      .data4nocs  (part4nocs  ),
      .cs         (cs         ),
      .data_out   (mux_out    )
   );
endmodule

