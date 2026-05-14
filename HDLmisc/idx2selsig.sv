/*!
 * \license SPDX-License-Identifier: MIT
 * \file idx2selsig.sv
 * \brief 索引至选通信号转换器
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs
 */
`include "miscs.svh"
module idx2selsig #(
   parameter int SELSIG_CNT = 4,
   parameter int DELAYTAPS  = 0
) (clk, aclr, sclr, clken, idx, cs);
   input  bit                   clk;
   input  wire                  aclr;
   input  wire                  sclr;
   input  wire                  clken;
   localparam int bitwof_idx = miscs::minbitw_of_integer(SELSIG_CNT-1, 31);
   input  wire [bitwof_idx-1:0] idx;
   output logic[SELSIG_CNT-1:0] cs;

   wire[SELSIG_CNT-1:0] cs2p;
   genvar i; generate for (i = 0; i < SELSIG_CNT; i++) begin: SELSIG_OFIDX
      assign cs2p[i] = (idx == (bitwof_idx)'(i)) ? 1'b1 : 1'b0;
   end endgenerate
   pipedelay_taps #(
      .DATABITW(SELSIG_CNT          ),
      .INITVAL ({(SELSIG_CNT){1'b0}}),
      .DELAYTAPS(DELAYTAPS          )
   ) pipe_cs(
      .clk  (clk  ),
      .aclr (aclr ),
      .sclr (sclr ),
      .clken(clken),
      .x    (cs2p ),
      .pipe_x(cs  )
   );
endmodule

