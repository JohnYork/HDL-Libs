/*!
 * \license SPDX-License-Identifier: MIT
 * \file paral_add.sv
 * \brief 并行加法器
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, pipedelay, packconv
 */
`define __INC_FROM_PARAL_ADD__
`include "paral_add.svh"
/*! \brief 合并数组并行加法器 */
module paral_add_packedarray #(
   parameter int unsigned DATABITW  = 8,           ///< 输入数据位宽
   parameter int unsigned FPEBITW   = 1,           ///< 浮点数据指数位宽，0-表示输入和输出均是无符号数，1-表示输入和输出均是有符号数，>1-表示输入和输出均是IEEE754浮点数
   parameter int          PARALCNT  = 7,           ///< 并行加法输入数据路数
   parameter int signed   RESBITW   = 0,           ///< 指定结果位宽， = 0 时表示自动计算最佳位宽， > 0 表示计算结果按高位对齐，< 0 表示计算结果按低位对齐
   parameter int          DELAYTAPS = 0            ///< 结果延迟输出拍数
) (clk, aclr, sclr, clken, x, r);
   input  bit                             clk;
   input  wire                            aclr;
   input  wire                            sclr;
   input  wire                            clken;
   input  wire[PARALCNT-1:0][DATABITW-1:0]x;
   localparam int resbitw_e = FPEBITW > 1 ? DATABITW : paral_add_pkg::bitwof_fixedres(DATABITW, PARALCNT);
   localparam int resbitw   = FPEBITW > 1 ? DATABITW : ((RESBITW == 0) ? resbitw_e : (RESBITW < 0 ? -RESBITW : RESBITW));
   output wire[resbitw-1:0]               r;

   initial if (FPEBITW > 1 && RESBITW > 0 && DATABITW != RESBITW)
      $error("paral_add_packedarray: DATABITW(%0d) and RESBITW(%0d) should be equal because of FPEBITW(%0d) > 1 and RESBITW(%0d) not zero", DATABITW, RESBITW, FPEBITW, RESBITW);
   initial if (FPEBITW > 1)
      $error("paral_add_packedarray: floating point addition (FPEBITW(%0d) > 1) currently does not support yet.", FPEBITW);
   localparam bit signedvar = (FPEBITW == 1'b1)
                              ? 1'b1
                              : 1'b0;
   localparam int stgcnt = miscs::minbitw_of_integer(PARALCNT - 1, 32);
   localparam int fpadd_taps = (FPEBITW > 1)
                               ? 0
                               : 0;
   localparam int mintaps_want = fpadd_taps*stgcnt;
   initial if (DELAYTAPS < mintaps_want)
      $error("paral_add_packedarray: DELAYTAPS(%0d) is not enough due to FPEBITW(%0d), at least %0d is required!", DELAYTAPS, FPEBITW, mintaps_want);
   localparam int dlytaps_outofadd = DELAYTAPS - mintaps_want;
   localparam int dlytaps4stg = (dlytaps_outofadd <= stgcnt)
                                ? ((dlytaps_outofadd > 0)
                                   ? (dlytaps_outofadd - 1)
                                   : 0)
                                : stgcnt;
   localparam int maxbits_intladd = (FPEBITW > 1)
                                    ? DATABITW
                                    : ((RESBITW < 0 && resbitw < resbitw_e)
                                       ? resbitw
                                       : resbitw_e);
   genvar istg, iadd; generate for (istg = 1; istg <= stgcnt; istg++) begin: STAGE
      localparam int cntof_add_i = (istg == 1)
                                   ? PARALCNT
                                   : (PARALCNT + 2**(istg-1) - 1)/(2**(istg-1));
      localparam int bitwof_xi = (istg == 1 || FPEBITW > 1)
                                 ? DATABITW
                                 : (((DATABITW + istg - 1) < maxbits_intladd)
                                    ? (DATABITW + istg - 1)
                                    : maxbits_intladd);
      localparam int bitwof_xo = (FPEBITW > 1)
                                 ? DATABITW
                                 : (((DATABITW + istg) < maxbits_intladd)
                                    ? (DATABITW + istg)
                                    : maxbits_intladd);
      localparam int cntof_add_o = (PARALCNT + 2**istg - 1)/(2**istg);
      wire[cntof_add_i-1:0][bitwof_xi-1:0]xi;
      wire[cntof_add_i-1:0][bitwof_xo-1:0]xi2a;
      wire[cntof_add_o-1:0][bitwof_xo-1:0]xo, xo2o;
      if (istg == 1) assign xi = x;
      else           assign xi = STAGE[istg-1].xo;
      for (iadd = 0; iadd < cntof_add_i; iadd++) begin: SIGNEXT
         if (FPEBITW == 1 && bitwof_xo > bitwof_xi)assign xi2a[iadd] = {{(bitwof_xo-bitwof_xi){xi[iadd][bitwof_xi-1]&signedvar}}, xi[iadd]};
         /* #maxbits_intladd 在 #RESBITW > 0 时赋值为 #resbitw_e ，确保了 #RESBITW < #DATABITW 时 #maxbits_intladd 仍然可以使加法结果寄存器保留足够的比特位避免溢出；
          * 且由于并行加法器的并行累加通道数不止2，意味着数据低位比特经并行累加后不一定只会进位到上一比特，为确保精度必须把低位比特及其累加结果保留。
          * 因此下面的在 #RESBITW > 0 且 #bitwof_xo > #bitwof_xi 时按高位截取的操作变得没有必要保留了，因为 #maxbits_intladd 的赋值保证了 #bitwof_xo >= #bitwof_xi必定成立。
          */
         // else if(RESBITW > 0)          assign xi2a[iadd] = xi[iadd][bitwof_xi-1:bitwof_xi-bitwof_xo];
         else                                      assign xi2a[iadd] = xi[iadd];
      end
      localparam int delay_judge_1 = (istg + 1)*dlytaps4stg/stgcnt;
      localparam int delay_judge_0 = (istg + 0)*dlytaps4stg/stgcnt;
      localparam bit delay_stage = (delay_judge_1 > delay_judge_0)
                                   ? 1'b1
                                   : 1'b0;
      for (iadd = 0; iadd < cntof_add_o; iadd++) begin: ADD
         if (iadd*2 + 2 <= cntof_add_i) begin
            if (FPEBITW <= 1) assign xo2o[iadd] = xi2a[iadd*2] + xi2a[iadd*2+1];
            else begin
               assign xo2o[iadd] = {(bitwof_xo){1'b0}};
            end
         end
         else assign xo2o[iadd] = xi2a[iadd*2];
      end
      pipedelay_taps_packedarray #(
         .DATABITW(bitwof_xo           ),
         .ARRAYSIZ(cntof_add_o         ),
         .DELAYTAPS(int'(delay_stage)  )
      ) pipe_xo(
         .clk  (clk  ),
         .aclr (aclr ),
         .sclr (sclr ),
         .clken(clken),
         .x    (xo2o ),
         .pipe_x(xo  )
      );
   end
   localparam int pipe_bitw = (maxbits_intladd < resbitw)
                              ? maxbits_intladd
                              : resbitw;
   pipedelay_taps #(
      .DATABITW(pipe_bitw                       ),
      .DELAYTAPS(dlytaps_outofadd - dlytaps4stg )
   ) pipe_res(
      .clk  (clk  ),
      .aclr (aclr ),
      .sclr (sclr ),
      .clken(clken),
      .x    (STAGE[stgcnt].xo[0][((RESBITW > 0)
                                  ? (maxbits_intladd-1)
                                  : (pipe_bitw-1))
                                :((RESBITW > 0)
                                  ? (maxbits_intladd-pipe_bitw)
                                  : 0)]),
      .pipe_x(r[((RESBITW > 0)
                 ? (resbitw-1)
                 : (pipe_bitw-1))
               :((RESBITW > 0)
                 ? (resbitw-pipe_bitw)
                 : 0)])
   );
   if (resbitw > pipe_bitw) begin
      if     (RESBITW >  0)assign r[resbitw-pipe_bitw-1:        0] = '0;
      else if(FPEBITW == 1)assign r[resbitw          -1:pipe_bitw] = {(resbitw-pipe_bitw){r[pipe_bitw-1]}};
      else                 assign r[resbitw          -1:pipe_bitw] = '0;
   end endgenerate
endmodule
/*! \brief 非合并数组并行加法器 */
module paral_add_unpackedarray #(
   parameter int unsigned DATABITW  = 8,           ///< 输入数据位宽
   parameter int unsigned FPEBITW   = 1,           ///< 浮点数据指数位宽，0-表示输入和输出均是无符号数，1-表示输入和输出均是有符号数，>1-表示输入和输出均是IEEE754浮点数
   parameter int          PARALCNT  = 7,           ///< 并行加法输入数据路数
   parameter int signed   RESBITW = 0,             ///< 指定结果位宽， = 0 时表示自动计算最佳位宽， > 0 表示计算结果按高位对齐，< 0 表示计算结果按低位对齐
   parameter int          DELAYTAPS = 0            ///< 结果延迟输出拍数
) (clk, aclr, sclr, clken, x, r);
   input  bit                 clk;
   input  wire                aclr;
   input  wire                sclr;
   input  wire                clken;
   input  wire [DATABITW-1:0] x[PARALCNT-1:0];
   localparam int resbitw_e = (FPEBITW > 1)
                              ? DATABITW
                              : paral_add_pkg::bitwof_fixedres(DATABITW, PARALCNT);
   localparam int resbitw   = (FPEBITW > 1)
                              ? DATABITW
                              : ((RESBITW == 0)
                                 ? resbitw_e
                                 : ((RESBITW < 0)
                                    ? (-RESBITW)
                                    : RESBITW));
   output wire [resbitw-1:0]  r;

   wire[PARALCNT-1:0][DATABITW-1:0] xc;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(PARALCNT)
   ) ac (
      .in   (x ),
      .out  (xc)
   );

   paral_add_packedarray #(
      .DATABITW(DATABITW   ),
      .FPEBITW (FPEBITW    ),
      .PARALCNT(PARALCNT   ),
      .RESBITW (RESBITW    ),
      .DELAYTAPS(DELAYTAPS )
   ) papai(
      .clk  (clk  ),
      .aclr (aclr ),
      .sclr (sclr ),
      .clken(clken),
      .x    (xc   ),
      .r    (r    )
   );
endmodule

