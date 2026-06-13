`timescale 1ns/1ns
module tb_rmbd;

reg clk, mdl_rst;
localparam varbitw = 16;
reg[varbitw-1:0] test_8bits, test_8bits2test;
initial begin
   clk = 0;
   test_8bits = '0;
   mdl_rst = 1;
   #6 mdl_rst = 0;
   #4 test_8bits = 16'b10000000;
   #4 test_8bits = 16'b11000000;
   #4 test_8bits = 16'b10100000;
   #4 test_8bits = 16'b01000000;
   #4 test_8bits = 16'b01000001;
   #4 test_8bits = 16'b01100001;
   #4 test_8bits = 16'b00111110;
end
always_ff @(posedge clk) test_8bits2test <= test_8bits;
wire[19:0] test_10bits = {{(4){test_8bits2test[7]}}, test_8bits2test};

always # 1 clk = ~clk;

rmbd #(.DATABITW(varbitw), .POSBITW(5), .IDXFRMMSB(1'b0), .DELAYTAPS(0),.PIPELINE(0), .PIPEINPUT(0)) rmbd_1(  .clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw), .POSBITW(5), .IDXFRMMSB(1'b0), .DELAYTAPS(2),.PIPELINE(0), .PIPEINPUT(0)) rmbd_1d( .clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw), .POSBITW(5), .IDXFRMMSB(1'b0), .DELAYTAPS(2),.PIPELINE(1), .PIPEINPUT(0)) rmbd_1dp(.clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw), .POSBITW(5), .IDXFRMMSB(1'b0), .DELAYTAPS(2),.PIPELINE(1), .PIPEINPUT(1)) rmbd_1dq(.clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());

rmbd #(.DATABITW(varbitw+4), .POSBITW(6), .IDXFRMMSB(1'b0), .DELAYTAPS(0), .PIPELINE(0), .PIPEINPUT(0)) rmbd_2(  .clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw+4), .POSBITW(6), .IDXFRMMSB(1'b0), .DELAYTAPS(2), .PIPELINE(0), .PIPEINPUT(0)) rmbd_2d( .clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw+4), .POSBITW(6), .IDXFRMMSB(1'b0), .DELAYTAPS(2), .PIPELINE(1), .PIPEINPUT(0)) rmbd_2dp(.clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw+4), .POSBITW(6), .IDXFRMMSB(1'b0), .DELAYTAPS(2), .PIPELINE(1), .PIPEINPUT(1)) rmbd_2dq(.clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());

rmbd #(.DATABITW(varbitw), .POSBITW(5), .IDXFRMMSB(1'b1), .DELAYTAPS(0),.PIPELINE(0), .PIPEINPUT(0)) rmbd_1m(  .clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw), .POSBITW(5), .IDXFRMMSB(1'b1), .DELAYTAPS(2),.PIPELINE(0), .PIPEINPUT(0)) rmbd_1md( .clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw), .POSBITW(5), .IDXFRMMSB(1'b1), .DELAYTAPS(2),.PIPELINE(1), .PIPEINPUT(0)) rmbd_1mdp(.clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw), .POSBITW(5), .IDXFRMMSB(1'b1), .DELAYTAPS(2),.PIPELINE(1), .PIPEINPUT(1)) rmbd_1mdq(.clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());

rmbd #(.DATABITW(varbitw+4), .POSBITW(6), .IDXFRMMSB(1'b1), .DELAYTAPS(0), .PIPELINE(0), .PIPEINPUT(0)) rmbd_2m(  .clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw+4), .POSBITW(6), .IDXFRMMSB(1'b1), .DELAYTAPS(2), .PIPELINE(0), .PIPEINPUT(0)) rmbd_2md( .clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw+4), .POSBITW(6), .IDXFRMMSB(1'b1), .DELAYTAPS(2), .PIPELINE(1), .PIPEINPUT(0)) rmbd_2mdp(.clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
rmbd #(.DATABITW(varbitw+4), .POSBITW(6), .IDXFRMMSB(1'b1), .DELAYTAPS(2), .PIPELINE(1), .PIPEINPUT(1)) rmbd_2mdq(.clk(clk), .aclr(mdl_rst), .sclr('0), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());

endmodule

