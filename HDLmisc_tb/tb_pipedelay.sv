`timescale 1ns/1ns
module tb_pipedelay;
   reg clk, mdl_rst;
   reg[4:0] test_8bits;
   initial begin
      clk = 0;
      mdl_rst = 1;
      test_8bits = 8'b10000000;
      #5 mdl_rst = 0;
         test_8bits = 8'b10000000;
      #6 test_8bits = 8'b11000000;
      #4 test_8bits = 8'b11100000;
      #4 test_8bits = 8'b01000000;
      #4 test_8bits = 8'b00100001;
      #4 test_8bits = 8'b00011001;
      #4 test_8bits = 8'b00001110;
      #4 test_8bits = 8'b00000000;
   end
   always # 1 clk = ~clk;
   reg[4:0] test_8bits2test;
   always @(posedge clk)
      test_8bits2test <= test_8bits;

   pipedelay_taps #(
      .DATABITW(5),
      .DELAYTAPS(1)
   ) pipei(
      .clk(clk),
      .aclr(1'b0),
      .sclr(1'b0),
      .clken(1'b1),
      .x (test_8bits2test),
      .pipe_x()
   );

endmodule
