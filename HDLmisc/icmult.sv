/*!
 * \license SPDX-License-Identifier: MIT
 * \file icmult.sv
 * \brief 整型复数乘法器
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, pipedelay
 */
`include "miscs.svh"
`define __INC_FROM_ICMULT__
`include "icmult.svh"
module icmult #(
   parameter int        PARTBITW_A = 8,            ///< 输入复数A的实部和虚部位宽
   parameter int        PARTBITW_B = 8,            ///< 输入复数B的实部和虚部位宽
   parameter int signed PARTBITW_R = 17,           ///< 输出结果R的实部和虚部位宽 = 0 时表示自动计算最佳位宽， > 0 表示计算结果按高位对齐，< 0 表示计算结果按低位对齐
   parameter bit        ROUNDLSB   = 1'b0,         ///< 对结果低位做四舍五入处理标志，仅当 #PARTBITW_R > 0 时有效，1'b1-对结果做四舍五入处理，1'b0-对结果直接截位
   parameter bit        USE3MULTP  = 1'b0,         ///< 使用三乘法器实现，1'b1-以增加加法器和延迟拍数为代价减少乘法器资源的消耗，1'b0-以增加乘法器资源消耗为代价减少计算延迟拍数
   parameter int        DELAYTAPS  = 2             ///< 模块运算时延
) (clk, aclr, sclr, clken, ar, ai, acnj, br, bi, bcnj, rr, ri);
   input  bit                          clk;        ///< 驱动时钟
   input  wire                         aclr;       ///< 异步复位信号，高电平(1)有效
   input  wire                         sclr;       ///< 同步复位信号，高电平(1)有效
   input  wire                         clken;      ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire signed[PARTBITW_A-1:0]  ar, ai;     ///< 输入复数A的实部、虚部
   input  wire                         acnj;       ///< 复数A以共轭数参与运算标志，1'b0-复数A以原形式参与运算，1'b1-复数A以共轭数参与运算
   input  wire signed[PARTBITW_B-1:0]  br, bi;     ///< 输入复数B的实部、虚部
   input                               bcnj;       ///< 复数B以共轭数参与运算标志，1'b0-复数B以原形式参与运算，1'b1-复数B以共轭数参与运算
   localparam int minPartBitwNoCut = icmult_pkg::resPartBitw(.aPartBitw(PARTBITW_A), .bPartBitw(PARTBITW_B));
   localparam int partbitw_r = (PARTBITW_R == 0) ? minPartBitwNoCut : (PARTBITW_R > 0 ? PARTBITW_R : -PARTBITW_R);
   output wire signed[partbitw_r-1:0]  rr, ri;     ///< 输出结果R的实部、虚部

   wire signed[PARTBITW_A-1:0]ar2c, ai2c;
   wire signed[PARTBITW_B-1:0]br2c, bi2c;
   wire                       acnj2c, bcnj2c;
   localparam int post_add_taps  = (DELAYTAPS + 2 + int'(USE3MULTP))/(3 + int'(USE3MULTP));
   localparam int post_mult_taps = (DELAYTAPS - post_add_taps + 1 + int'(USE3MULTP))/(2 + int'(USE3MULTP));
   localparam int pre_add_taps   = USE3MULTP ? (DELAYTAPS - post_add_taps - post_mult_taps + 1)/2 : 0;
   localparam int entry_taps     = DELAYTAPS - post_add_taps - post_mult_taps - pre_add_taps;
   pipedelay_taps #(
      .DATABITW   (PARTBITW_A*2 + PARTBITW_B*2 + 2 ),
      .DELAYTAPS  (entry_taps                      )
   ) entry_delay(
      .clk     (clk                                      ),
      .aclr    (aclr                                     ),
      .sclr    (sclr                                     ),
      .clken   (clken                                    ),
      .x       ({ai, ar, bi, br, acnj, bcnj}             ),
      .pipe_x  ({ai2c, ar2c, bi2c, br2c, acnj2c, bcnj2c} )
   );
   wire signed[minPartBitwNoCut-1:0] rrnc, rinc;
   localparam int partbitw_r_2p = partbitw_r > minPartBitwNoCut ? minPartBitwNoCut : partbitw_r;
   /* partbitw_r_2p <= minPartBitwNoCut, partbitw_r_2p <= partbitw_r */
   generate if (USE3MULTP) begin: CPLX3MULTP
      /* 节省一个乘法器的算法：
       *   (ar + j*ai)*(br + j*bi)
       * = ar*br - ai*bi + (ar*bi + br*ai)*j
       * = ar*br - ar*bi + ar*bi - ai*bi + (ar*bi - ai*bi + ai*bi + br*ai)*j
       * = ar*(br - bi) + (ar - ai)*bi + [(ar - ai)*bi + ai*(br + bi)]*j
       */
      logic signed[PARTBITW_B:0] br_sub_bi, br_sub_bi_s, br_sub_bi_p, br_add_bi, br_add_bi_s, br_add_bi_p;
      logic signed[PARTBITW_A:0] /*ar_sub_ai, */ar_sub_ai_p;
      wire  signed[PARTBITW_A-1:0]ar2c_p, ai2c_p;
      wire  signed[PARTBITW_B-1:0]bi2c_p;
      wire                       acnj2c_p, bcnj2c_p;
      assign br_sub_bi = (PARTBITW_B+1)'(br2c) - (PARTBITW_B+1)'(bi2c),
             br_add_bi = (PARTBITW_B+1)'(br2c) + (PARTBITW_B+1)'(bi2c),
             br_sub_bi_s = bcnj ? br_add_bi : br_sub_bi,
             br_add_bi_s = bcnj ? br_sub_bi : br_add_bi;
      pipedelay_taps #(
         .DATABITW   ((PARTBITW_B + 1)*2 + PARTBITW_A*2 + PARTBITW_B + 2),
         .DELAYTAPS  (pre_add_taps                                      )
      ) pre_add_delay(
         .clk     (clk                                                                    ),
         .aclr    (aclr                                                                   ),
         .sclr    (sclr                                                                   ),
         .clken   (clken                                                                  ),
         .x       ({br_sub_bi, br_add_bi, ar2c, ai2c, bi2c, acnj2c, bcnj2c}               ),
         .pipe_x  ({br_sub_bi_p, br_add_bi_p, ar2c_p, ai2c_p, bi2c_p, acnj2c_p, bcnj2c_p} )
      );
      // assign ar_sub_ai = (PARTBITW_A+1)'(ar2c) - (PARTBITW_A+1)'(ai2c);
      iaddsub #(
         .BITW    (PARTBITW_A + 1),
         .INSTMODE(0             ),
         .SIGNED  (1'b1          ),
         .DEFTCIN (1'b1          ),
         .PIPELINE(pre_add_taps  )
      ) ar_sub_ai(
         .clk     (clk                       ),
         .aclr    (aclr|sclr                 ),
         .clken   (clken                     ),
         .add_sub (acnj2c                    ),
         .dataa   ({ar2c[PARTBITW_A-1], ar2c}),
         .datab   ({ai2c[PARTBITW_A-1], ai2c}),
         .cin     (1'b0                      ),
         .result  (ar_sub_ai_p               ),
         .overflow(                          ),
         .cout    (                          )
      );
      localparam int pmbitw = miscs::minresbitw_of_signedint_multiply(.bitwofA(PARTBITW_A),.bitwofB(PARTBITW_B+1));
      wire signed [pmbitw-1:0]ar_mul_br_sub_bi, ar_mul_br_sub_bi_p, ai_mul_br_add_bi, ai_mul_br_add_bi_p;
      wire signed [pmbitw-1:0]ar_sub_ai_mul_bi, ar_sub_ai_mul_bi_p;
      wire                    acnj2m_p, bcnj2m_p;
      assign ar_mul_br_sub_bi = ar2c_p * br_sub_bi_p;
      assign ai_mul_br_add_bi = ai2c_p * br_add_bi_p;
      assign ar_sub_ai_mul_bi = ar_sub_ai_p * bi2c_p;
      pipedelay_taps #(
         .DATABITW   ((PARTBITW_B+PARTBITW_A)*2 + (PARTBITW_A+PARTBITW_B) + 2 ),
         .DELAYTAPS  (post_mult_taps                                          )
      ) post_mult_delay(
         .clk     (clk                                                                             ),
         .aclr    (aclr                                                                            ),
         .sclr    (sclr                                                                            ),
         .clken   (clken                                                                           ),
         .x       ({ar_mul_br_sub_bi, ai_mul_br_add_bi, ar_sub_ai_mul_bi, acnj2c_p, bcnj2c_p}      ),
         .pipe_x  ({ar_mul_br_sub_bi_p, ai_mul_br_add_bi_p, ar_sub_ai_mul_bi_p, acnj2m_p, bcnj2m_p})
      );
      initial assert((PARTBITW_A - 1) + (PARTBITW_B - 1) + 1 + 1 == minPartBitwNoCut);
      wire[pmbitw-1:0] rinc2s;
      // assign rrnc = ar_mul_br_sub_bi_p + ar_sub_ai_mul_bi_p;
      iaddsub #(
         .BITW    (pmbitw  ),
         .INSTMODE(0       ),
         .SIGNED  (1'b1    ),
         .DEFTCIN (1'b1    ),
         .PIPELINE(0       )
      ) ar_mul_br_sub_bi_p_add_ar_sub_ai_mul_bi_p(
         .clk     (clk                 ),
         .aclr    (aclr|sclr           ),
         .clken   (clken               ),
         .add_sub (~bcnj2m_p           ),
         .dataa   (ar_mul_br_sub_bi_p  ),
         .datab   (ar_sub_ai_mul_bi_p  ),
         .cin     (1'b0                ),
         .result  (rrnc                ),
         .overflow(                    ),
         .cout    (                    )
      );
      // assign rinc = ar_sub_ai_mul_bi_p + ai_mul_br_add_bi_p;
      iaddsub #(
         .BITW    (pmbitw  ),
         .INSTMODE(0       ),
         .SIGNED  (1'b1    ),
         .DEFTCIN (1'b1    ),
         .PIPELINE(0       )
      ) ar_sub_ai_mul_bi_p_add_ai_mul_br_add_bi_p(
         .clk     (clk                 ),
         .aclr    (aclr|sclr           ),
         .clken   (clken               ),
         .add_sub (~(acnj2m_p^bcnj2m_p)),
         .dataa   (ar_sub_ai_mul_bi_p  ),
         .datab   (ai_mul_br_add_bi_p  ),
         .cin     (1'b0                ),
         .result  (rinc2s              ),
         .overflow(                    ),
         .cout    (                    )
      );
      assign rinc = bcnj2m_p ? (~rinc2s) + {{(pmbitw-1){1'b0}}, 1'b1} : rinc2s;
   end else begin: CPLX4MULTP
      /* 标准算法
       *   (ar + j*ai)*(br + j*bi)
       * = ar*br - ai*bi + (ar*bi + br*ai)*j
       */
      initial assert(pre_add_taps == 0);
      localparam int pmbitw = miscs::minresbitw_of_signedint_multiply(.bitwofA(PARTBITW_A),.bitwofB(PARTBITW_B));
      wire signed[pmbitw-1:0] ar_m_br, ai_m_bi, ar_m_bi, br_m_ai, ar_m_br_p, ai_m_bi_p, ar_m_bi_p, br_m_ai_p;
      wire                    acnj2c_p, bcnj2c_p;
      assign ar_m_br = ar2c*br2c;
      assign ai_m_bi = ai2c*bi2c;
      assign ar_m_bi = ar2c*bi2c;
      assign br_m_ai = br2c*ai2c;
      pipedelay_taps #(
         .DATABITW   (pmbitw*4 + 2  ),
         .DELAYTAPS  (post_mult_taps)
      ) post_mult_delay(
         .clk     (clk                                                              ),
         .aclr    (aclr                                                             ),
         .sclr    (sclr                                                             ),
         .clken   (clken                                                            ),
         .x       ({ar_m_br, ai_m_bi, ar_m_bi, br_m_ai, acnj2c, bcnj2c}             ),
         .pipe_x  ({ar_m_br_p, ai_m_bi_p, ar_m_bi_p, br_m_ai_p, acnj2c_p, bcnj2c_p} )
      );
      // assign rrnc = ar_m_br_p - ai_m_bi_p;
      iaddsub #(
         .BITW    (minPartBitwNoCut ),
         .INSTMODE(0                ),
         .SIGNED  (1'b1             ),
         .DEFTCIN (1'b1             ),
         .PIPELINE(0                )
      ) ar_m_br_p_sub_ai_m_bi_p(
         .clk     (clk                             ),
         .aclr    (aclr|sclr                       ),
         .clken   (clken                           ),
         .add_sub (acnj2c_p^bcnj2c_p               ),
         .dataa   ({ar_m_br_p[pmbitw-1], ar_m_br_p}),
         .datab   ({ai_m_bi_p[pmbitw-1], ai_m_bi_p}),
         .cin     (1'b0                            ),
         .result  (rrnc                            ),
         .overflow(                                ),
         .cout    (                                )
      );
      // assign rinc = ar_m_bi_p + br_m_ai_p;
      wire signed[minPartBitwNoCut-1:0]rinc2s;
      iaddsub #(
         .BITW    (minPartBitwNoCut ),
         .INSTMODE(0                ),
         .SIGNED  (1'b1             ),
         .DEFTCIN (1'b1             ),
         .PIPELINE(0                )
      ) ar_m_bi_p_add_br_m_ai_p(
         .clk     (clk                             ),
         .aclr    (aclr|sclr                       ),
         .clken   (clken                           ),
         .add_sub (~(acnj2c_p^bcnj2c_p)            ),
         .dataa   ({ar_m_bi_p[pmbitw-1], ar_m_bi_p}),
         .datab   ({br_m_ai_p[pmbitw-1], br_m_ai_p}),
         .cin     (1'b0                            ),
         .result  (rinc2s                          ),
         .overflow(                                ),
         .cout    (                                )
      );
      assign rinc = bcnj2c_p ? (~rinc2s) + {{(minPartBitwNoCut-1){1'b0}}, 1'b1} : rinc2s;
   end
   wire signed[partbitw_r_2p-1:0]rrc, ric;
   /* partbitw_r_2p 取值为 minPartBitwNoCut 和 partbitw_r 中的最小者，意味着 partbitw_r_2p 必定与二者中某一个相等，      *
    * 因此不必担心在 minPartBitwNoCut 向 partbitw_r_2p 以及 partbitw_r_2p 向 partbitw_r 两个过程中重复产生四舍五入电路。 *
    * 另外，因为 partbitw_r_2p <= minPartBitwNoCut ，当 partbitw_r_2p < minPartBitwNoCut 时执行四舍五入，否则直通。     */
   if (PARTBITW_R > 0) begin: ALIGN_MSB
      if (ROUNDLSB == 1'b1 && minPartBitwNoCut > partbitw_r_2p)
         assign rrc = rrnc[minPartBitwNoCut-1-:partbitw_r_2p] + {{(partbitw_r_2p-1){1'b0}}, rrnc[minPartBitwNoCut-1-partbitw_r_2p]},
                ric = rinc[minPartBitwNoCut-1-:partbitw_r_2p] + {{(partbitw_r_2p-1){1'b0}}, rinc[minPartBitwNoCut-1-partbitw_r_2p]};
      else
         assign rrc = rrnc[minPartBitwNoCut-1-:partbitw_r_2p], ric = rinc[minPartBitwNoCut-1-:partbitw_r_2p];
   end else begin: ALIGN_LSB
      assign rrc = rrnc[partbitw_r_2p-1:0];
      assign ric = rinc[partbitw_r_2p-1:0];
   end
   wire signed[partbitw_r_2p-1:0]rrp, rip;
   pipedelay_taps #(
      .DATABITW   (partbitw_r_2p*2  ),
      .DELAYTAPS  (post_add_taps    )
   ) post_add_delay(
      .clk     (clk        ),
      .aclr    (aclr       ),
      .sclr    (sclr       ),
      .clken   (clken      ),
      .x       ({ric, rrc} ),
      .pipe_x  ({rip, rrp} )
   );
   /* partbitw_r_2p 取值为 minPartBitwNoCut 和 partbitw_r 中的最小者，意味着 partbitw_r_2p <= partbitw_r ，                      *
    * 当 partbitw_r_2p <  partbitw_r 时，必定有 partbitw_r_2p == minPartBitwNoCut ，此时运算不应产生四舍五入电路，结果应直通输出； *
    * 当 partbitw_r_2p == partbitw_r 时，必定有 partbitw_r_2p <  minPartBitwNoCut ，此时四舍五入电路已在 minPartBitwNoCut 向     *
    * partbitw_r_2p 截位的过程中实现，结果应该直通输出。                                                                         */
   if (PARTBITW_R >= 0) begin
      assign rr[partbitw_r-1:partbitw_r-partbitw_r_2p] = rrp, ri[partbitw_r-1:partbitw_r-partbitw_r_2p] = rip;
      if (partbitw_r_2p < partbitw_r)  assign rr[partbitw_r-partbitw_r_2p-1:0] = '0, ri[partbitw_r-partbitw_r_2p-1:0] = '0;
   end else begin
      assign rr[partbitw_r_2p-1:0] = rrp, ri[partbitw_r_2p-1:0] = rip;
      if (partbitw_r_2p < partbitw_r)
         assign rr[partbitw_r-1:partbitw_r_2p] = {(partbitw_r-partbitw_r_2p){rrp[partbitw_r_2p-1]}}, 
                ri[partbitw_r-1:partbitw_r_2p] = {(partbitw_r-partbitw_r_2p){rip[partbitw_r_2p-1]}};
   end
   endgenerate
endmodule

