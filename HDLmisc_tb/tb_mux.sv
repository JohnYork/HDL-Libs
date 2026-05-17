`timescale 1ps/1ps
`include "mux.svh"
module tb_mux;

   reg clk;
   initial begin
      clk = 0;
   //   forever # 1 clk = ~clk;
   end
   always # 1 clk = ~clk;

   reg mdl_rst;
   initial begin
      mdl_rst = 0;
      # 1 mdl_rst = 1;
      # 4 mdl_rst = 0;
   end

   localparam logic[7:0] array[6:0] = '{
      8'd1,
      8'd2,
      8'd4,
      8'd8,
      8'd16,
      8'd32,
      8'd64
   };
   reg[6:0] cs, cs2use;
   always_ff @(posedge clk, posedge mdl_rst) begin
      if (mdl_rst) cs2use <= '0;
      else         cs2use <= cs;
   end
   import mux_pkg::*;
   initial begin
      cs = '0;
      # 6 cs = 7'h1;
      # 2 cs = 7'h2;
      # 2 cs = 7'h3;
      # 2 cs = 7'h4;
      # 2 cs = 7'h8;
      # 2 cs = 7'ha;
      # 2 cs = 7'h10;
      # 2 cs = 7'h21;
      # 2 cs = 7'h20;
      # 2 cs = 7'h40;
   end
   localparam bit cs_pri_msb = 1'b0;
   mux_bycs #(
      .UNITBITW(8),
      .INITNOCS(8'hFF),
      .INPUTCNT(7),
      // .CS2IDX_PRI_MSB(cs_pri_msb),
      // .CS_PRESET_FLAG(1'b0),
      // .MUX_DELAYTAPS(1)
      .DELAYTAPS(1)
   )mcs_i(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr('0),
      .clken(1'b1),
      .cs(cs2use),
      .data_in(array),
      .data4nocs(8'hFF),
      .data_out()
   );
   mux_bycs #(
      .UNITBITW(8),
      .INITNOCS(8'hFF),
      .INPUTCNT(7),
      // .CS2IDX_PRI_MSB(cs_pri_msb),
      // .CS_PRESET_FLAG(1'b0),
      // .MUX_DELAYTAPS(2)
      .DELAYTAPS(2)
   )mcs_di(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr('0),
      .clken(1'b1),
      .cs(cs2use),
      .data_in(array),
      .data4nocs(8'hFF),
      .data_out()
   );
   localparam int idxbitw = miscs::bits_of_integer(6, 31);
   wire[idxbitw-1:0] idx2use;
   wire              valid2use;
   selsig2idx #(
      .SELSIGBITW(7),
      .PRI_MSB(cs_pri_msb),
      .DLYTAPS(0)
   ) cs2idx(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr('0),
      .clken(1'b1),
      .selsig(cs2use),
      .idx(idx2use),
      .valid(valid2use)
   );
   wire[7:0]array2use[7:0];
   genvar i; generate for (i = 0; i < 8; i++) begin: ARRAY_ASSIGN
      if (i < 7) assign array2use[i] = array[i];
      else       assign array2use[i] = '0;
   end endgenerate
   mux_byidx #(
      .UNITBITW(8),
      .INPUTCNT(8),
      .DELAYTAPS(1)
   ) m_i(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr('0),
      .clken(1'b1),
      .data_in(array2use),
      .data4nocs('1),
      .idx(idx2use),
      .data_out()
   );
   mux_byidx #(
      .UNITBITW(8),
      .INPUTCNT(8),
      .DELAYTAPS(2)
   ) m_di(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr('0),
      .clken(1'b1),
      .data_in(array2use),
      .data4nocs('1),
      .idx(idx2use),
      .data_out()
   );
   bit[87:0][63:0] darray;
   generate begin for (i = 0; i < 88; i++) begin: DARRAY_ASSIGN
      assign darray[i] = 64'(i);
   end end endgenerate
   bit[2:0] idx2o, idx;
   initial begin
      idx2o = 0;
      # 4 idx2o = 1;
      # 2 idx2o = 0;
      # 2 idx2o = 1;
      # 2 idx2o = 2;
      # 2 idx2o = 3;
      # 2 idx2o = 4;
      # 2 idx2o = 5;
      # 2 idx2o = 6;
      # 2 idx2o = 7;
   end
   always_ff @(posedge clk) idx <= idx2o;
   partmux_byidx_packedarray #(
      .UNITBITW(64),
      .ARRAYSIZ(88),
      .MUXCOUNT(8),
      .DELAYTAPS(2)
   ) mbi_pai(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr(1'b0),
      .clken(1'b1),
      .array_in(darray),
      .part4nocs('0),
      .idx(idx),
      .mux_out()
   );
   reg[9:0][7:0] dcntr;
   always_ff @(posedge clk) begin
      if (mdl_rst) dcntr[0] <= 8'd0;
      else         dcntr[0] <= dcntr[0] + 8'd1;
   end
   always_ff @(posedge clk) dcntr[9:1] <= dcntr[8:0];
   reg[1:0]cs4mbc_pai, cs4mbc_paio;
   initial begin
      cs4mbc_pai = 0;
      # 20
         cs4mbc_pai = 1;
      # 20
         cs4mbc_pai = 2;
      # 20
         cs4mbc_pai = 0;
   end
   always_ff @(posedge clk) cs4mbc_paio <= cs4mbc_pai;
   wire[2:0][8:0]array2sel[1:0];
   assign array2sel[0][0] = {1'b0, dcntr[0]},
          array2sel[0][1] = {1'b0, dcntr[1]},
          array2sel[0][2] = {1'b0, dcntr[2]},
          array2sel[1][0] = {1'b1, dcntr[0]},
          array2sel[1][1] = {1'b1, dcntr[1]},
          array2sel[1][2] = {1'b1, dcntr[2]};
   wire[2:0][8:0]arrayout;
   mux_bycs_packedarray #(
      .UNITBITW(9),
      .ARRAYSIZ(3),
      .INPUTCNT(2),
      .DELAYTAPS(1),
      .BALNCDLY(1'b0)
   ) mbc_pai(
      .clk(clk),
      .aclr(1'b0),
      .sclr(mdl_rst),
      .clken(1'b1),
      .array_in   (array2sel  ),
      .array4nocs ('0),
      .cs(cs4mbc_paio),
      .array_out  ()
   );
endmodule
