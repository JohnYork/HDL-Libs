`timescale 1ps/1ps
`include "miscs.svh"
module tb_fifos;

   localparam int depth = 10;
   reg clk, mdlrst, wi, ri, sclri;
   initial clk = 0;
   always # 1 clk = ~clk;
   initial begin
      mdlrst = 0;
      wi = 0;
      ri = 0;
      sclri = 0;
      # 1 mdlrst = 1;
      # 4 mdlrst = 0;
      // 测试读写同时有效
      # 4 wi = 1;
          ri = 1;
      # 2 wi = 0;
          ri = 0;
      // 测试连续读写同时有效
      # 2 wi = 1;
          ri = 1;
      # 4 wi = 0;
          ri = 0;
      // 测试读紧跟着写
      # 2 wi = 1;
      # 2 wi = 0;
          ri = 1;
      # 2 ri = 0;
      // 测试写2次读3次
      # 2 wi = 1;
      # 4 wi = 0;
          ri = 1;
      # 6 ri = 0;
      // 测试写溢出
      # 6 wi = 1;
//    # 20 wi = 0;
      # (depth*2) wi = 0;
      # 2 wi = 1;
      # 2 wi = 0;
      // 检验写溢出时是否破坏内部数据
      # 2 ri = 1;
//    # 22 ri = 0;
      # ((depth+1)*2) ri = 0;
   end

   localparam int databitw = 8;
   reg[databitw-1:0] datacntr;
   always_ff @(posedge clk, posedge mdlrst)
      if (mdlrst) datacntr <= '0;
      else        datacntr <= datacntr + (databitw)'(1);
   reg w, r, sclr;
   always_ff @(posedge clk) begin
      w <= wi;
      r <= ri;
      sclr <= sclri;
   end

   localparam bit chk_q = 1'b1;
   localparam bit chk_empty = 1'b1;
   localparam bit chk_full = 1'b1;
   localparam bit chk_usedw = 1'b1;

   localparam int addrBitw = miscs::bits_of_integer(depth-1, 32);
   wire[addrBitw-1:0]uwn, uwnr, uwh, uwhr;
   wire[databitw-1:0]q_n, q_nr, q_h, q_hr;
   wire en, enr, eh, ehr, fn, fnr, fh, fhr;
   basic_fifo #(
      .DUALCLK(1'b0),
      .UNITBITW(databitw),
      .DEPTH(depth),
      .SHOWAHEAD(1'b0)
   ) scfifo_i(
      .clk(clk),
      .aclr(mdlrst),
      .sclr(sclr),
      .wrreq(w),
      .rdreq(r),
      .data(datacntr),
      .q(q_n),
      .usedw(uwn),
      .empty(en),
      .full(fn),
      .undrflow(),
      .overflow()
   );

   basic_fifo #(
      .DUALCLK(1'b0),
      .UNITBITW(databitw),
      .DEPTH(depth),
      .SHOWAHEAD(1'b1)
   ) scfifo_i_sah(
      .clk(clk),
      .aclr(mdlrst),
      .sclr(sclr),
      .wrreq(w),
      .rdreq(r),
      .data(datacntr),
      .q(q_h),
      .usedw(uwh),
      .empty(eh),
      .full(fh),
      .undrflow(),
      .overflow()
   );

   reg clkw, clkr;
   initial clkw = 0;
   always #3 clkw = ~clkw;
   initial clkr = 0;
   always #2 clkr = ~clkr;
   wire[databitw-1:0]dq, dqr, dqh, dqhr;
   wire[1:0]         de, der, deh, dehr;
   wire[1:0]         df, dfr, dfh, dfhr;
   wire[1:0][addrBitw-1:0]duw, duwr, duwh, duwhr;

   basic_fifo #(
      .DUALCLK(1'b1),
      .CLKDSYNCTAPS({32'd2,32'd2}),
      .UNITBITW(databitw),
      .DEPTH(depth),
      .SHOWAHEAD(1'b0),
      .USEDWDLYTAPS({32'd1,32'd1})
   ) dcfifo_i(
      .clk({clkw, clkr}),
      .aclr(mdlrst),
      .sclr('0),
      .wrreq(w),
      .rdreq(r),
      .data(datacntr),
      .q(dq),
      .usedw(duw),
      .empty(de),
      .full(df),
      .overflow(),
      .undrflow()
   );
   basic_fifo #(
      .DUALCLK(1'b1),
      .CLKDSYNCTAPS({32'd2,32'd2}),
      .UNITBITW(databitw),
      .DEPTH(depth),
      .SHOWAHEAD(1'b1),
      .USEDWDLYTAPS({32'd1,32'd1})
   ) dcfifo_sahi(
      .clk({clkw, clkr}),
      .aclr(mdlrst),
      .sclr('0),
      .wrreq(w),
      .rdreq(r),
      .data(datacntr),
      .q(dqh),
      .usedw(duwh),
      .empty(deh),
      .full(dfh),
      .overflow(),
      .undrflow()
   );
endmodule

