/*!
 * \license SPDX-License-Identifier: MIT
 * \file bitcnt.sv
 * \brief 比特位统计
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, pipedelay
 */
`include "miscs.svh"
`define __INC_FROM_BITCNT__
`include "bitcnt.svh"
module bitcnt #(
   parameter int DATABITW  = 10,
   parameter int DELAYTAPS = 1
) (clk, aclr, sclr, clken, val2cnt, bit2cnt, ocnt);
   input  bit               clk;
   input  wire              aclr;
   input  wire              sclr;
   input  wire              clken;
   input  wire[DATABITW-1:0]val2cnt;
   input  wire              bit2cnt;
   localparam int cntbitw = miscs::minbitw_of_integer(DATABITW, 32);
   output wire[cntbitw -1:0]ocnt;

   localparam int stgcnt = miscs::minbitw_of_integer(DATABITW, 32);
   genvar i, j; generate
      for (i = 1; i <= stgcnt; i++) begin: STG
         localparam int prevaddbitw = 2**(i-1);
         localparam int prevbcbitw = i;
         localparam int prevstg_arraysz = ((DATABITW + prevaddbitw - 1)/prevaddbitw);
         localparam int thisaddbitw = 2**i;
         localparam int thisbcbitw = i+1;
         localparam int thisstg_arraysz = ((DATABITW + thisaddbitw - 1)/thisaddbitw);
         wire[prevstg_arraysz-1:0][prevbcbitw-1:0] istgbc;
         wire[thisstg_arraysz-1:0][thisbcbitw-1:0] stgbc2o, ostgbc;
         if (i == 1) unit_split2packedarray #(
                        .UNITBITW(1       ),
                        .ARRAYSIZ(DATABITW)
                     ) val2cnt2istgbc(
                        .in   (val2cnt ),
                        .out  (istgbc  )
                     );
         else        assign istgbc = STG[i-1].ostgbc;
         for (j = 0; j < thisstg_arraysz; j++) begin
            wire[thisbcbitw-1:0] evnbc, oddbc;
            if (i == 1) begin
               // if (j*2+1 <= DATABITW)
                  assign evnbc = {1'b0, istgbc[j*2]^(~bit2cnt)};
               // else
                  // assign evnbc = 2'b00;
               if (j*2+2 <= DATABITW)
                  assign oddbc = {1'b0, istgbc[j*2+1]^(~bit2cnt)};
               else
                  assign oddbc = 2'b00;
            end else begin
               assign evnbc = {1'b0, STG[i-1].ostgbc[2*j]};
               if (j*2+1 >= prevstg_arraysz) assign oddbc = {(thisbcbitw){1'b0}};
               else                          assign oddbc = {1'b0, STG[i-1].ostgbc[j*2+1]};
            end
            assign stgbc2o[j] = evnbc + oddbc;
         end
         pipedelay_taps_packedarray #(
            .DATABITW(thisbcbitw),
            .ARRAYSIZ(thisstg_arraysz),
            .DELAYTAPS(miscs::delaytaps4stage(
                                 .stagecnt   (stgcnt     ),
                                 .istage     (i - 1      ),
                                 .totaltaps  (DELAYTAPS  ),
                                 .top_first  (1'b0       )))
         ) pipe_stgbc(
            .clk     (clk     ),
            .aclr    (aclr    ),
            .sclr    (sclr    ),
            .clken   (clken   ),
            .x       (stgbc2o ),
            .pipe_x  (ostgbc  )
         );
      end
   endgenerate
   assign ocnt = STG[stgcnt].ostgbc[0][cntbitw-1:0];
endmodule
