`default_nettype none
`timescale 1ps/1ps
`include "bitcnt.svh"
module tb_bitcnt;

   wire clk, aclr, sclr;
   tb_sysclkaclr #(.ACLR_WIDTH(4)) sysclkaclri(.clk(clk),.aclr(aclr),.sclr(sclr));

   localparam int bitw = 5;
   logic[bitw-1:0]testcntr;
   always_ff @( posedge clk ) begin 
      if (sclr) testcntr <= '0;
      else      testcntr <= testcntr + 1;
   end
   bitcnt #(
      .DATABITW(bitw),  .DELAYTAPS(bitcnt_pkg::delaytaps_recommend(bitw))
   ) bc1i(
      .clk(clk),  .aclr(aclr),.sclr(sclr),   .clken(1'b1),
      .val2cnt(testcntr),     .bit2cnt(1'b1),.ocnt()
   );
   bitcnt #(
      .DATABITW(bitw),  .DELAYTAPS(bitcnt_pkg::delaytaps_recommend(bitw))
   ) bc0i(
      .clk(clk),  .aclr(aclr),.sclr(sclr),   .clken(1'b1),
      .val2cnt(testcntr),     .bit2cnt(1'b0),.ocnt()
   );

endmodule