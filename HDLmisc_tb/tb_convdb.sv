`timescale 1ps/1ps
`include "convdb.svh"
module tb_convdb;
   wire clk, sclr;
   tb_sysclkaclr #(
      .ACLR_WIDTH(4)
   ) sclkaclri(
      .clk(clk),  .aclr(), .sclr(sclr)
   );
   reg[32:0]ival;
   reg[3:0] lsh;
   initial begin
      ival = 0;
      lsh = 0;
      # 10
      ival = 33'd489387508;   // 86dB
      # 10
      ival = 33'd377892724;
      # 10
      ival = 33'd12345;
      # 10
      lsh = 1;
      # 10
      lsh = 2;
      # 10
      lsh = 9;
      # 10
      lsh = 10;
   end
   initial $display("convdb_lshfix: delaytaps = %0d", convdb_pkg::delaytaps_lshfix(.ivalbitw(33),.maxprelsh(10)));
   convdb_lshfix #(
      .DUALCHNL(1'b1),
      .IVALBITW(33),
      .SCALDB(1),
      .MAXPRELSH(10),
      .DBFIX(0),
      .DBBITW(8)
   ) cdblshi(
      .clk(clk),
      .aclr(1'b0),
      .sclr(sclr),
      .clken(1'b1),
      .ival({ival, ival}),
      .prelsh({lsh, lsh}),
      .odb()
   );
   initial $display("convdb: delaytaps = %0d", convdb_pkg::delaytaps(.ivalbitw(33)));
   convdb #(
      .DUALCHNL(1'b1),
      .IVALBITW(33),
      .SCALDB(1),
      .DBFIX(0),
      .DBBITW(8)
   ) cdbi(
      .clk(clk),
      .aclr(1'b0),
      .sclr(sclr),
      .clken(1'b1),
      .ival({ival, ival}),
      .odb()
   );
endmodule
