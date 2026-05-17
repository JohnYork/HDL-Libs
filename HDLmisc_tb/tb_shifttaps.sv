`timescale 1ps/1ps
//`include "miscs.svh"
module tb_shifttaps;

reg clk, mdlrst, clken_i, preout_i, sclr, sclro;
initial clk = 0;
always # 1 clk = ~clk;
initial begin
   mdlrst = 0;
   clken_i = 1;
   preout_i = 0;
   sclr = 0;
   # 1 mdlrst = 1;
   # 4 mdlrst = 0;
   # 8 clken_i = 0;
   # 4 clken_i = 1;
   # 60 sclr = 1;
   # 4 sclr = 0;
   # 10 preout_i = 1;
   # 30 preout_i = 0;
end
always @(posedge clk) sclro <= sclr;
localparam int databitw = 8;
localparam int tap_dist = 10;

reg[databitw-1:0] datacntr;
always_ff @(posedge clk, posedge mdlrst) begin
   if (mdlrst) datacntr <= '0;
   else        datacntr <= datacntr + (databitw)'(1);
end

reg clk_en;
always_ff @(posedge clk) clk_en <= clken_i;

shiftfixtaps #(
   .DATABITW   (databitw),
   .TAP_DIST   (tap_dist),
   .SCLR_ONRAM (1'b1    ),
   .IMPLBYLOGIC(1'b0    )
) stai(
   .clk(clk),
   .aclr(mdlrst),
   .sclr(sclro),
   .clken(clk_en),
   .shiftin(datacntr),
   .shiftout(),
   .reseting()
);
pipedelay_taps #(
   .DATABITW(databitw), .DELAYTAPS(tap_dist)
) pipei(
   .clk(clk),  .aclr(mdlrst), .sclr('0),  .clken(clk_en),  .x(datacntr),  .pipe_x()
);

localparam int tapidx_bitw = miscs::bits_of_integer(tap_dist, 31);
reg[tapidx_bitw-1:0] tap2in, tap2out;
initial begin
   tap2in = 0;
   tap2out = tap_dist-1;
   #5
   # 20 tap2in = 1;
   # 20 tap2in = 2;
   # 20 tap2in = 3;
   # 20 tap2in = 4;
   # 20 tap2in = 5;
   # 20 tap2in = 0;
   # 20 tap2in = 2;
   # 20 tap2in = 4;
   # 20 tap2in = 0;
   # 20 tap2in = 3;
   # 20 tap2in = 5;
   # 20 tap2in = 0;
   // # 20 tap2in = 4;
   # 20 tap2out = 5;
   # 20 tap2out = 4;
   # 20 tap2out = 3;
   # 20 tap2out = 2;
   # 20 tap2out = 1;
   # 20 tap2out = 0;
   # 20 tap2out = 1;
   # 20 tap2out = 2;
end

reg[tapidx_bitw-1:0] tapin, tapout;
always @(posedge clk) begin
   tapin <= tap2in;
   tapout <= tap2out;
end

localparam bit vartap_reg_pri = 1'b0;
shiftvartaps #(
   .DATABITW(databitw),
   .MAX_TAP(tap_dist),
   .SCLR_ONRAM(1'b1),
   .IMPLBYLOGIC(vartap_reg_pri)
) stvi0(
   .clk(clk),
   .aclr(mdlrst),
   .sclr(sclro),
   .clken(clk_en),
   .intap(tapin),
   .shiftin(datacntr),
   .outtap(tapout),
   .shiftout(),
   .illegal_tap(),
   .reseting()
);

shiftvartaps #(
   .DATABITW(databitw),
   .MAX_TAP(tap_dist),
   .SCLR_ONRAM(1'b0),
   .IMPLBYLOGIC(vartap_reg_pri)
) stvi1(
   .clk(clk),
   .aclr(mdlrst),
   .sclr(sclro),
   .clken(clk_en),
   .intap(tapin),
   .shiftin(datacntr),
   .outtap(tapout),
   .shiftout(),
   .illegal_tap(),
   .reseting()
);

shiftvartaps #(
   .DATABITW(databitw),
   .MAX_TAP(tap_dist),
   .SCLR_ONRAM(1'b1),
   .IMPLBYLOGIC(vartap_reg_pri)
) stvi2(
   .clk(clk),
   .aclr(mdlrst),
   .sclr(sclro),
   .clken(clk_en),
   .intap(tapin),
   .shiftin(datacntr),
   .outtap(tapout),
   .shiftout(),
   .illegal_tap(),
   .reseting()
);

shiftvartaps #(
   .DATABITW(databitw),
   .MAX_TAP(tap_dist),
   .SCLR_ONRAM(1'b1),
   .IMPLBYLOGIC(vartap_reg_pri)
) stvi3(
   .clk(clk),
   .aclr(mdlrst),
   .sclr(sclro),
   .clken(clk_en),
   .intap(tapin),
   .shiftin(datacntr),
   .outtap(tapout),
   .shiftout(),
   .illegal_tap(),
   .reseting()
);

endmodule

