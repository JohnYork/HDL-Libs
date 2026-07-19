/*!
 * \license SPDX-License-Identifier: MIT
 * \file crc.sv
 * \brief 循环冗余码校验模块
 * \author JohnYork <johnyork@yeah.net>
 */
`include "miscs.svh"
`define __INC_FROM_CRC__
`include "crc.svh"
/*! \brief 串行带阻塞信号的CRC校验 */
module scrc #(
   parameter crc_pkg::crcCfg CC      = crc_pkg::crc16ccittfalse,  ///< CRC算法配置参数
   parameter int             BW      = 8,                         ///< 待校验单位数据位宽，当 #BW = 1 时可实现无阻塞的流水线
   parameter int             FLOWCNT = 1                          ///< 数据通路数
) (clk, aclr, sclr, clken, ida, ivld, isop, cs, ovld, pvld, blki);
   input  bit                          clk;  ///< 驱动时钟
   input  wire                         aclr; ///< 异步复位信号，高电平(1)有效
   input  wire                         sclr; ///< 同步复位信号，高电平(1)有效
   input  wire                         clken;///< 时序电路翻转使能信号，高电平(1)有效
   input  wire [FLOWCNT-1:0][BW-1:0]   ida;  ///< 输入被校验单位数据
   input  wire                         ivld; ///< 输入数据有效标志，高电平(1)有效
   input  wire                         isop; ///< 输入被校验单位数据序列头部标志，高电平(1)有效，迫使CRC校验和从初始状态开始
   localparam int csbw = crc_pkg::csbits_ofcrcCfg(CC);
   output logic[FLOWCNT-1:0][csbw-1:0] cs;   ///< 输出CRC校验和
   output logic                        ovld; ///< 输出CRC校验和有效标志
   output logic                        pvld; ///< 输出CRC校验和有效预先通知标志，比 #ovld 提前一拍置位
   output logic                        blki; ///< 输入阻塞请求信号，高电平(1)阻塞

   genvar i, j; generate
   initial begin
      if (csbw < 8)
         $error("scrc: CC.csbits(%0d) that less than 8 currently is not supported", csbw);
      if (BW > csbw)
         $error("scrc: CC.csbits(%0d) must not be less than BW(%0d)", csbw, BW);
   end
   localparam bit[csbw-1:0] endxorv = crc_pkg::endxorv_ofcrcCfg(CC);
   localparam int infpip_msb = ((|endxorv)
                                ? 1
                                : 0)+BW-1;
   logic [infpip_msb:0] infpip, infpip2upd;
   wire  [BW-1:0] infpip_part_2upd;
   if (BW > 1) assign infpip_part_2upd = (~(|infpip[BW-2:0]))
                                         ? {{(BW-1){1'b0}}, ivld}
                                         : {infpip[BW-2:0], 1'b0};
   else        assign infpip_part_2upd = ivld;
   if (infpip_msb < BW) assign infpip2upd = infpip_part_2upd;
   else                 assign infpip2upd = {infpip[infpip_msb-1:BW-1], infpip_part_2upd};
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) infpip <=  {(infpip_msb+1){1'b0}};
      else if (sclr) infpip <= {{(infpip_msb  ){1'b0}}, ivld};
      else           infpip <= clken
                               ? infpip2upd
                               : infpip;
   end
   if (BW > 1) begin
      wire blki2upd;
      if (BW > 2) assign blki2upd = (|infpip[BW-2:0])
                                    ? (|infpip[BW-3:0])
                                    : ivld;
      else        assign blki2upd = (|infpip[BW-2:0])
                                    ? 1'b0
                                    : ivld;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) blki <= 1'b0;
         else if (sclr) blki <= 1'b0;
         else           blki <= clken
                                ? blki2upd
                                : blki;
      end
   end
   else assign blki = 1'b0;
   logic[FLOWCNT-1:0][csbw-1:0]  csreg;
   localparam bit[csbw-1:0] initval = crc_pkg::initval_ofcrcCfg(CC);
   localparam bit[csbw-1:0] poly    = crc_pkg::poly_ofcrcCfg(CC);
   localparam bit           ibr     = crc_pkg::ibitrev_ofcrcCfg(CC);
   logic[FLOWCNT-1:0][csbw-1:0]  csr_ida, csr2use4upd, csreg2upd;
   if (csbw == BW) always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
      if (isop) csr_ida[ii] = (initval  [BW-1:0]^ida[ii]);
      else      csr_ida[ii] = (csreg[ii][BW-1:0]^ida[ii]);
   end
   else if (ibr == 1'b1) always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
      if (isop) csr_ida[ii] = {initval  [csbw-1:BW], (initval  [BW-1:0]^ida[ii])};
      else      csr_ida[ii] = {csreg[ii][csbw-1:BW], (csreg[ii][BW-1:0]^ida[ii])};
   end
   else always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
      if (isop) csr_ida[ii] = {initval  [csbw-1:csbw-BW]^ida[ii], initval  [csbw-BW-1:0]};
      else      csr_ida[ii] = {csreg[ii][csbw-1:csbw-BW]^ida[ii], csreg[ii][csbw-BW-1:0]};
   end
   if (BW > 1) assign csr2use4upd = ((~(|infpip[BW-2:0])))
                                    ? csr_ida
                                    : csreg;
   else        assign csr2use4upd = csr_ida;
   if (ibr == 1'b1) always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
      csreg2upd[ii] = csr2use4upd[ii][0]
                      ? ({1'b0, csr2use4upd[ii][csbw-1:1]}^poly)
                      :  {1'b0, csr2use4upd[ii][csbw-1:1]};
   end
   else always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
      csreg2upd[ii] = csr2use4upd[ii][csbw-1]
                      ? ({csr2use4upd[ii][csbw-2:0], 1'b0}^poly)
                      :  {csr2use4upd[ii][csbw-2:0], 1'b0};
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) csreg <= {(FLOWCNT){initval}};
      else if (sclr) csreg <= {(FLOWCNT){initval}};
      else           csreg <= (clken&(|infpip2upd[BW-1:0]))
                              ? csreg2upd
                              : csreg;
   end
   wire[FLOWCNT-1:0][csbw-1:0]csreg2o;
   if (crc_pkg::ibitrev_ofcrcCfg(CC)^crc_pkg::obitrev_ofcrcCfg(CC)) begin
      for (i = 0; i < FLOWCNT; i++) begin
         for (j = 0; j < csbw; j++)
            assign csreg2o[i][csbw-1-j] = csreg[i][j];
      end
   end
   else assign csreg2o = csreg;
   if (|endxorv) always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) cs <= {(FLOWCNT){{(csbw){1'b0}}}};
      else if (sclr) cs <= {(FLOWCNT){{(csbw){1'b0}}}};
      else           cs <= clken
                           ? (csreg2o^{(FLOWCNT){endxorv}})
                           : cs;
   end
   else assign cs = csreg2o;
   assign ovld = infpip[infpip_msb],
          pvld = infpip2upd[infpip_msb];
   endgenerate
endmodule
/*! \brief 并行CRC校验用码表 */
module lut4pcrc #(
   parameter crc_pkg::crcCfg CC   = crc_pkg::crc16ccittfalse,  ///< CRC算法配置参数
   parameter int             PCBW = 8,                         ///< 并行校验位宽
   parameter bit             DUCH = 1'b0                       ///< 双通道查找表模式
) (clk, clken, dc2v, lutc);
   input  bit                    clk;
   input  wire                   clken;
   input  wire [DUCH:0][PCBW-1:0]dc2v;
   localparam int csbw = crc_pkg::csbits_ofcrcCfg(CC);
   output logic[DUCH:0][csbw-1:0]lutc;

   localparam bit[csbw-1:0] poly = crc_pkg::poly_ofcrcCfg(CC);
   localparam bit           ibr  = crc_pkg::ibitrev_ofcrcCfg(CC);
   reg [csbw-1:0] rom[2**PCBW-1:0];
   initial begin
      automatic bit[csbw-1:0]crc;
      automatic int i, j;
      for (i = 0; i < 2**PCBW; i++) begin
         if (ibr == 1'b1) begin
            crc = (csbw)'(i);
            for (j = 0; j < PCBW; j++) begin
               if (crc&1)
                  crc = ((crc>>1)^poly);
               else
                  crc = (crc>>1);
            end
         end else begin
            crc = (csbw)'(i<<(csbw-PCBW));
            for (j = 0; j < PCBW; j++) begin
               if (crc&(2**(csbw-1)))
                  crc = ((crc<<1)^poly);
               else
                  crc = (crc<<1);
            end
         end
         rom[i] = crc;
      end
   end
   genvar i; generate
      for (i = 0; i <= int'(DUCH); i++) begin
         always @(posedge clk) lutc[i] <= rom[dc2v[i]];
      end
   endgenerate
endmodule
/*! \brief 并行CRC校验 */
module pcrc #(
   parameter crc_pkg::crcCfg CC      = crc_pkg::crc16ccittfalse,  ///< CRC算法配置参数
   parameter int             BW      = 8,                         ///< 待校验单位数据位宽
   parameter int             PCBW    = 8,                         ///< 并行校验的数据位宽，必须可以整除 #BW
   parameter int             FLOWCNT = 1                          ///< 数据通路数
) (clk, aclr, sclr, clken, ida, ivld, isop, cs, ovld, pvld, blki);
   input  bit                          clk;  ///< 驱动时钟
   input  wire                         aclr; ///< 异步复位信号，高电平(1)有效
   input  wire                         sclr; ///< 同步复位信号，高电平(1)有效
   input  wire                         clken;///< 时序电路翻转使能信号，高电平(1)有效
   input  wire [FLOWCNT-1:0][BW-1:0]   ida;  ///< 输入被校验单位数据
   input  wire                         ivld; ///< 输入数据有效标志，高电平(1)有效
   input  wire                         isop; ///< 输入被校验单位数据序列头部标志，高电平(1)有效，迫使CRC校验和从初始状态开始
   localparam int csbw = crc_pkg::csbits_ofcrcCfg(CC);
   output logic[FLOWCNT-1:0][csbw-1:0] cs;   ///< 输出CRC校验和
   output logic                        ovld; ///< 输出CRC校验和有效标志
   output logic                        pvld; ///< 输出CRC校验和有效预先通知标志，比 #ovld 提前一拍置位
   output logic                        blki; ///< 输入阻塞请求信号，高电平(1)阻塞

   initial begin
      if (BW < PCBW)
         $error("pcrc: BW(%0d) should not be less than PCBW(%0d)", BW, PCBW);
      if (BW % PCBW != 0)
         $error("pcrc: BW(%0d) must be divided by PCBW(%0d) completely", BW, PCBW);
   end
   genvar i, j; generate
      localparam int lutc = (FLOWCNT+1)/2;
      wire[FLOWCNT-1:0][PCBW-1:0]dc2v;
      wire[FLOWCNT-1:0][csbw-1:0]crcc;
      for (i = 0; i < lutc; i++) begin: LUT
         localparam int ileft = i*2;
         localparam int irigt = (i*2+1 < lutc)
                                ? (i*2+1)
                                : (lutc-1);
         localparam bit duch = (irigt > ileft)
                               ? 1'b1
                               : 1'b0;
         lut4pcrc #(
            .CC   (CC   ),
            .PCBW (PCBW ),
            .DUCH (duch )
         ) luti(
            .clk  (clk              ),
            .clken(clken            ),
            .dc2v (dc2v[ileft:irigt]),
            .lutc (crcc[ileft:irigt])
         );
      end
      localparam int csitc   = BW/PCBW;
      localparam int csitcbw = (csitc > 1)
                               ? miscs::minbitw_of_integer(
                                         .value   (csitc - 1  ),
                                         .maxbitw ($bits(int) ))
                               : 0;
      logic [1:0] csitpflg;
      wire  [1:0] csitpflg2upd;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) csitpflg <= 2'b00;
         else if (sclr) csitpflg <= 2'b00;
         else           csitpflg <= clken
                                    ? csitpflg2upd
                                    : csitpflg;
      end
      wire csitc_rstsig, csitc_initstat, polyshftstat, csreg_updsig;
      if (csitc > 1) begin
         logic[csitcbw-1:0]csitcntr;
         wire[csitcbw-1:0] csitcntr2upd = csitcntr + (csitcbw)'(1);
         assign csitpflg2upd   = (~(|csitpflg[1:0]))
                                 ? ((~(|csitcntr))
                                    ? {1'b0, ivld}
                                    : {1'b0, 1'b1})
                                 : {csitpflg[0], 1'b0},
                csitc_rstsig   = (csitcntr2upd == (csitcbw)'(csitc) && csitpflg2upd == 2'b00)
                                 ? 1'b1
                                 : 1'b0,
                csitc_initstat = ~(|csitcntr),
                polyshftstat   = (|csitpflg),
                csreg_updsig   = csitpflg[1];
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr)                                   csitcntr <= {(csitcbw){1'b0}};
            else if (sclr)                                   csitcntr <= {(csitcbw){1'b0}};
            else if (csitpflg2upd == 2'b00 && clken == 1'b1) csitcntr <= ((~csitpflg[1])|csitc_rstsig)
                                                                         ? {(csitcbw){1'b0}}
                                                                         : csitcntr2upd;
            else                                             csitcntr <= csitcntr;
         end
      end
      else assign csitpflg2upd   = (~(|csitpflg[1:0]))
                                   ? {1'b0, ivld}
                                   : {csitpflg[0], 1'b0},
                  csitc_rstsig   = (csitpflg2upd == 2'b00)
                                   ? 1'b1
                                   : 1'b0,
                  csitc_initstat = 1'b1,
                  polyshftstat   = (|csitpflg),
                  csreg_updsig   = csitpflg[1];
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr)               blki <= 1'b0;
         else if (sclr)               blki <= 1'b0;
         else if (clken&csitc_rstsig) blki <= 1'b0;
         else if (clken&ivld)         blki <= 1'b1;
         else                         blki <= blki;
      end
      logic[FLOWCNT-1:0][csbw-1:0]  csreg, csr2use4upd, csreg2upd;
      logic[FLOWCNT-1:0][PCBW-1:0]  csrida4idx, csr4idx;
      localparam bit ibr = crc_pkg::ibitrev_ofcrcCfg(CC);
      if (csitc > 1) begin: IDA4IDX
         logic[FLOWCNT-1:0][PCBW*(csitc-int'(ibr))-1:PCBW-int'(ibr)*PCBW]  ida4idx, ida4idx2upd, ida4idx2u1;
         if (ibr == 1'b0) begin
            if (csitc > 2) always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
               ida4idx2u1[ii] = {ida4idx[ii][PCBW*(csitc-1)-1:PCBW], {(PCBW){1'b0}}};
            end
            else assign ida4idx2u1 = {(FLOWCNT){{(PCBW){1'b0}}}};
            always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
               ida4idx2upd[ii] = (~csitc_initstat)
                                 ? ida4idx2u1[ii]
                                 : ida       [ii][PCBW*(csitc-1)-1:0];
               csrida4idx [ii] = (~csitc_initstat)
                                 ? ida4idx[ii][PCBW*csitc-1:PCBW*(csitc-1)]
                                 : ida    [ii][PCBW*csitc-1:PCBW*(csitc-1)];
            end
         end
         else begin
            if (csitc > 2)always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
               ida4idx2u1[ii] = {{(PCBW){1'b0}}, ida4idx[ii][PCBW*(csitc-1)-1:PCBW]};
            end
            else assign ida4idx2u1 = {(FLOWCNT){{(PCBW){1'b0}}}};
            always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
               ida4idx2upd[ii] = (~csitc_initstat)
                                 ? ida4idx2u1[ii]
                                 : ida       [ii][PCBW*csitc-1:PCBW];
               csrida4idx [ii] = (~csitc_initstat)
                                 ? ida4idx[ii][PCBW-1:0]
                                 : ida    [ii][PCBW-1:0];
            end
         end
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr) ida4idx <= {(FLOWCNT){{(csitc-1){{(PCBW){1'b0}}}}}};
            else if (sclr) ida4idx <= {(FLOWCNT){{(csitc-1){{(PCBW){1'b0}}}}}};
            else           ida4idx <= (clken&(~polyshftstat))
                                      ? ida4idx2upd
                                      : ida4idx;
         end
      end
      else assign csrida4idx = ida;
      logic[1:2]isop_pip;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) isop_pip <= 2'b00;
         else if (sclr) isop_pip <= 2'b00;
         else           isop_pip <= clken
                                    ? {isop, isop_pip[1]}
                                    : isop_pip;
      end
      localparam bit[csbw-1:0] initval = crc_pkg::initval_ofcrcCfg(CC);
      if (ibr == 1'b0) always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
         if (csitc_initstat&isop       ) csr4idx    [ii] =  initval  [csbw-1:csbw-PCBW];
         else                            csr4idx    [ii] =  csreg[ii][csbw-1:csbw-PCBW];
         if (csitc_initstat&isop_pip[2]) csr2use4upd[ii] = {initval  [csbw-PCBW-1:0], {(PCBW){1'b0}}};
         else                            csr2use4upd[ii] = {csreg[ii][csbw-PCBW-1:0], {(PCBW){1'b0}}};
      end
      else always_comb for (int ii = 0; ii < FLOWCNT; ii++) begin
         if (csitc_initstat&isop       ) csr4idx    [ii] =                  initval  [PCBW-1:0];
         else                            csr4idx    [ii] =                  csreg[ii][PCBW-1:0];
         if (csitc_initstat&isop_pip[2]) csr2use4upd[ii] = {{(PCBW){1'b0}}, initval  [csbw-1:PCBW]};
         else                            csr2use4upd[ii] = {{(PCBW){1'b0}}, csreg[ii][csbw-1:PCBW]};
      end
      logic[FLOWCNT-1:0][PCBW-1:0] lutidx;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr)                  lutidx <= {(BW){1'b0}};
         else if (sclr)                  lutidx <= {(BW){1'b0}};
         else if ((~clken)|polyshftstat) lutidx <= lutidx;
         else                            lutidx <= csrida4idx^csr4idx;
      end
      assign dc2v = lutidx;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) csreg <= {(FLOWCNT){initval}};
         else if (sclr) csreg <= {(FLOWCNT){initval}};
         else           csreg <= (clken&csreg_updsig)
                                 ? (csr2use4upd^crcc)
                                 : csreg;
      end
      localparam bit[csbw-1:0] endxorv = crc_pkg::endxorv_ofcrcCfg(CC);
      wire[FLOWCNT-1:0][csbw-1:0]csreg2o;
      if (crc_pkg::ibitrev_ofcrcCfg(CC)^crc_pkg::obitrev_ofcrcCfg(CC)) begin
         for (i = 0; i < FLOWCNT; i++) begin
            for (j = 0; j < csbw; j++)
               assign csreg2o[i][csbw-1-j] = csreg[i][j];
         end
      end
      else assign csreg2o = csreg;
      if (|endxorv) always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) cs <= {(FLOWCNT){{(csbw){1'b0}}}};
         else if (sclr) cs <= {(FLOWCNT){{(csbw){1'b0}}}};
         else           cs <= clken
                              ? (csreg2o^{(FLOWCNT){endxorv}})
                              : cs;
      end
      else assign cs = csreg2o;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) ovld <= 1'b0;
         else if (sclr) ovld <= 1'b0;
         else           ovld <= clken
                                ? csitc_rstsig
                                : ovld;
      end
      assign pvld = csitc_rstsig;
   endgenerate
endmodule
