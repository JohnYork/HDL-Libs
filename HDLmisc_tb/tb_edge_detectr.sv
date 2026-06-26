`timescale 1ps/1ps
module tb_edge_detectr;

reg clk;
initial begin
   clk = 0;
end
always # 1 clk = ~clk;
reg mdl_rst, test_sig;
initial begin
   mdl_rst = 0;
   test_sig = 0;
   # 1 mdl_rst = 1;
   # 4 mdl_rst = 0;
   # 10 test_sig = 1;
end

clkrst_if crifi(
   .clk(clk),
   .aclr(mdl_rst),
   .sclr('0)
);

reg sig2in;
always_ff @(posedge clk) sig2in <= test_sig;

credge_detectr #(
   .EDGE_WANT(-1),
   .DELAY_OUT(0)
) edge_det_fallen_0(
   .crifi(crifi),
   .srst('0),
   .insig(sig2in),
   .edgsig()
);

credge_detectr #(
   .EDGE_WANT(-1),
   .DELAY_OUT(0)
) edge_det_fallen_1(
   .crifi(crifi),
   .srst('0),
   .insig(~sig2in),
   .edgsig()
);

credge_detectr #(
   .EDGE_WANT(1),
   .DELAY_OUT(0)
) edge_det_rising_0(
   .crifi(crifi),
   .srst('0),
   .insig(sig2in),
   .edgsig()
);

credge_detectr #(
   .EDGE_WANT(1),
   .DELAY_OUT(0)
) edge_det_rising_1(
   .crifi(crifi),
   .srst('0),
   .insig(~sig2in),
   .edgsig()
);

endmodule
