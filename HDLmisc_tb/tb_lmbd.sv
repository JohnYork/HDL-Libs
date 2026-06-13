`timescale 1ns/1ns
module tb_lmbd;

reg clk, mdl_rst;
localparam varbitw = 8;
reg[varbitw-1:0] test_8bits, test_8bits2test;
initial begin
   clk = 0;
   test_8bits = '0;
   mdl_rst = 1;
   #5 mdl_rst = 0;
   #4 test_8bits = 8'b10000000;
   #4 test_8bits = 8'b11000000;
   #4 test_8bits = 8'b10100000;
   #4 test_8bits = 8'b01000000;
   #4 test_8bits = 8'b01000001;
   #4 test_8bits = 8'b01100001;
   #4 test_8bits = 8'b00111110;
end
always_ff @(posedge clk) test_8bits2test <= test_8bits;
wire[varbitw+1:0] test_10bits = {{(2){test_8bits2test[7]}}, test_8bits2test};

always # 1 clk = ~clk;

lmbd #(.DATABITW(varbitw), .POSBITW(4), .IDXFRMLSB(1'b0), .DELAYTAPS(0),.PIPELINE(0), .PIPEINPUT(0)) lmbd_1(  .clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw), .POSBITW(4), .IDXFRMLSB(1'b0), .DELAYTAPS(2),.PIPELINE(0), .PIPEINPUT(0)) lmbd_1d( .clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw), .POSBITW(4), .IDXFRMLSB(1'b0), .DELAYTAPS(2),.PIPELINE(1), .PIPEINPUT(0)) lmbd_1dp(.clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw), .POSBITW(4), .IDXFRMLSB(1'b0), .DELAYTAPS(2),.PIPELINE(1), .PIPEINPUT(1)) lmbd_1dq(.clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());

lmbd #(.DATABITW(varbitw+2), .POSBITW(5), .IDXFRMLSB(1'b0), .DELAYTAPS(0), .PIPELINE(0), .PIPEINPUT(0)) lmbd_2(  .clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw+2), .POSBITW(5), .IDXFRMLSB(1'b0), .DELAYTAPS(2), .PIPELINE(0), .PIPEINPUT(0)) lmbd_2d( .clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw+2), .POSBITW(5), .IDXFRMLSB(1'b0), .DELAYTAPS(2), .PIPELINE(1), .PIPEINPUT(0)) lmbd_2dp(.clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw+2), .POSBITW(5), .IDXFRMLSB(1'b0), .DELAYTAPS(2), .PIPELINE(1), .PIPEINPUT(1)) lmbd_2dq(.clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());

lmbd #(.DATABITW(varbitw), .POSBITW(4), .IDXFRMLSB(1'b1), .DELAYTAPS(0),.PIPELINE(0), .PIPEINPUT(0)) lmbd_1l(  .clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw), .POSBITW(4), .IDXFRMLSB(1'b1), .DELAYTAPS(2),.PIPELINE(0), .PIPEINPUT(0)) lmbd_1ld( .clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw), .POSBITW(4), .IDXFRMLSB(1'b1), .DELAYTAPS(2),.PIPELINE(1), .PIPEINPUT(0)) lmbd_1ldp(.clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw), .POSBITW(4), .IDXFRMLSB(1'b1), .DELAYTAPS(2),.PIPELINE(1), .PIPEINPUT(1)) lmbd_1mdq(.clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_8bits2test), .bit2s(1'b1), .ipos(), .pipe_x());

lmbd #(.DATABITW(varbitw+2), .POSBITW(5), .IDXFRMLSB(1'b1), .DELAYTAPS(0), .PIPELINE(0), .PIPEINPUT(0)) lmbd_2l(  .clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw+2), .POSBITW(5), .IDXFRMLSB(1'b1), .DELAYTAPS(2), .PIPELINE(0), .PIPEINPUT(0)) lmbd_2ld( .clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw+2), .POSBITW(5), .IDXFRMLSB(1'b1), .DELAYTAPS(2), .PIPELINE(1), .PIPEINPUT(0)) lmbd_2ldp(.clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());
lmbd #(.DATABITW(varbitw+2), .POSBITW(5), .IDXFRMLSB(1'b1), .DELAYTAPS(2), .PIPELINE(1), .PIPEINPUT(1)) lmbd_2ldq(.clk(clk), .aclr('0), .sclr(mdl_rst), .clken(1'b1), .x(test_10bits), .bit2s(1'b1), .ipos(), .pipe_x());

endmodule

