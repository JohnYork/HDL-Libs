`timescale 1ps/1ps
module tb_paral_add;
   reg clk;
   initial begin
      clk = 0;
      forever # 1 clk = ~clk;
   end
   reg aclr;
   initial begin
      aclr = 1;
      # 4 aclr = 0;
   end
   localparam int databitw = 8;
   localparam int paralcnt = 9;
   reg[databitw-1:0] data2i;
   always_ff @(posedge clk)
      if (aclr)data2i <= '0;
      else     data2i <= data2i + 1;
   paral_add_packedarray #(
      .DATABITW(databitw), .FPEBITW(0),.PARALCNT(paralcnt), .RESBITW(0),.DELAYTAPS(1'b0)
   ) pau(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(1'b1),
      .x({(paralcnt){data2i}}),           .r()
   );
   paral_add_packedarray #(
      .DATABITW(databitw), .FPEBITW(1),.PARALCNT(paralcnt), .RESBITW(0),.DELAYTAPS(1'b0)
   ) pai(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(1'b1),
      .x({(paralcnt){data2i}}),           .r()
   );
   paral_add_packedarray #(
      .DATABITW(databitw), .FPEBITW(0),.PARALCNT(paralcnt), .RESBITW(databitw),  .DELAYTAPS(1'b0)
   ) paum(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(1'b1),
      .x({(paralcnt){data2i}}),           .r()
   );
   paral_add_packedarray #(
      .DATABITW(databitw), .FPEBITW(1),.PARALCNT(paralcnt), .RESBITW(databitw),  .DELAYTAPS(1'b0)
   ) paim(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(1'b1),
      .x({(paralcnt){data2i}}),           .r()
   );
   paral_add_packedarray #(
      .DATABITW(databitw), .FPEBITW(0),.PARALCNT(paralcnt), .RESBITW(-databitw), .DELAYTAPS(1'b0)
   ) paul(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(1'b1),
      .x({(paralcnt){data2i}}),           .r()
   );
   paral_add_packedarray #(
      .DATABITW(databitw), .FPEBITW(1),.PARALCNT(paralcnt), .RESBITW(-databitw), .DELAYTAPS(1'b0)
   ) pail(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(1'b1),
      .x({(paralcnt){data2i}}),           .r()
   );
   localparam int delaytaps = 3;
   paral_add_packedarray #(
      .DATABITW(databitw), .FPEBITW(1),.PARALCNT(paralcnt), .RESBITW(-databitw), .DELAYTAPS(delaytaps)
   ) pail_dn(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(1'b1),
      .x({(paralcnt){data2i}}),           .r()
   );

   localparam int delaytaps_t = paral_add_pkg::delaytaps_recommend(.paralcnt(32), .fpebitw(1));
   localparam signed [1:32][47:0] ccc ={48'h0000153f2f26, 48'h00000c5faf08, 48'hffffec9cde0b, 48'h00004be70a74, 48'h00000634a0c0, 48'h000005043a8f, 48'hfffffd5144a3, 48'hffffffc85855,
                                 48'hfffffff8dc4f, 48'h0000032460d0, 48'h000008f89b5c, 48'h000004f6a927, 48'hffffffbdfbd4, 48'hfffff7398438, 48'hfffffc0f29f3, 48'h0000007c4dbf,
                                 48'hfffff933bc70, 48'hffffff14d5d6, 48'hfffffeeeef55, 48'h00000438ef72, 48'hfffff2a82e0c, 48'h000000a3e9a2, 48'hffffff723212, 48'hfffff4db2a1f,
                                 48'hfffff7223843, 48'h00000361e24d, 48'hfffff8e715c3, 48'hfffffd39781a, 48'h0000011185b3, 48'hffffff8afeea, 48'hfffffcaf2809, 48'h000003854dd7};
   initial begin
      automatic longint signed res, ii;
      res = 0;
      for (ii = 1; ii <= 32; ii++) res += signed'(ccc[ii]);
      $display("sum = %0d, 0x%0h", res, res);
   end
   wire[32:1][47:0] testdi;
   genvar i; generate for (i = 1; i <= 32; i++) begin
      assign testdi[i] = ccc[i];
   end endgenerate
   paral_add_packedarray #(
      .DATABITW(48), .FPEBITW(1),.PARALCNT(32), .RESBITW(0),.DELAYTAPS(delaytaps_t)
   ) pail_tt(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(1'b1),
      .x(testdi), .r()
   );
   logic signed[4:1][15:0] pcnt;
   assign pcnt = {16'd1, 16'd2, 16'd3, 16'd4};
   logic signed[15:0] ccntr;
   always_ff @(posedge clk) ccntr <= aclr ? '0 : ccntr + 1;
   logic signed[4:1][31:0]pccntr, pcfi;
   generate for (i = 1; i <= 4; i++) begin
      always_ff @(posedge clk) pccntr[i] <= aclr ? '0 : pcnt[i]*ccntr;
      fix2fp #(
         .INT_BITW(31),
         .FRACBITW(1),
         .FP_BITW(32),
         .FE_BITW(8)
      ) fix2fpi(
         .clk(clk),
         .aclr(aclr),
         .clken(1'b1),
         .dataa(pccntr[i]),
         .res(pcfi[i])
      );
   end endgenerate
   paral_add_packedarray #(
      .DATABITW(32), .FPEBITW(8),.PARALCNT(4),  .RESBITW(32),  .DELAYTAPS(7*2+2)
   ) pafi(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(1'b1),
      .x(pcfi),   .r()
   );

endmodule
