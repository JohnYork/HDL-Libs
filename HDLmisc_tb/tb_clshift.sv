`timescale 1ps/1ps
module tb_clshift;
   reg clk;
   reg mdl_rst;
   reg[31:0]val2shf, vsf;
   reg[4:0] shbits, shb;
   initial begin
      clk = 0;
      mdl_rst = 1;
      vsf = 0;
      # 1 mdl_rst = 1;
      # 4 mdl_rst = 0;
      # 2 vsf = 32'h1fa036;
      shb = 5'ha;
      # 2 vsf = 32'h3f60;
      shb = 5'h11;
   end
   always # 1 clk = ~clk;
   localparam int log2_bitw_2test = 3;
   localparam bit flip_enable = 1'b1;
   reg [(1<<log2_bitw_2test)-1:0] lcshift_data;
   reg clken;
   always_ff @(posedge clk) begin
      if (mdl_rst) lcshift_data <= '0;
      else lcshift_data <= lcshift_data + (1<<log2_bitw_2test)'(1);
      if (mdl_rst) clken <= '0;
      else         clken <= flip_enable ? ~clken : '1;
   end

   always @(posedge clk) val2shf <= vsf;
   always @(posedge clk) shbits <= shb;
   clshift #(
      .BITWIDTH(32),
      .DIRECTION(0),
      .ARITHMATIC(0),
      .DELAYTAPS(2),
      .PIPELINE(1'b1),
      .PIPEINPUT(1'b0),
      .PIPEDISTANCE(1'b0)
   ) shift31(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr(1'b0),
      .clken(1'b1),
      .x(val2shf),
      .distance(shbits),
      .result(),
      .pipe_x(),
      .pipe_distance()
   );

   localparam int bitwof_notpow2_data = 2**log2_bitw_2test - 1;
   // 组合逻辑输出
   genvar ish;
   generate
      for (ish = 0; ish <= (1<<log2_bitw_2test); ish++) begin:LCSR
         wire[(1<<log2_bitw_2test)-1:0] res;
         clshift #(
            .BITWIDTH(2**log2_bitw_2test),
            .DIRECTION(1),
            .ARITHMATIC(0),
            .DELAYTAPS(0),
            .PIPELINE(0),
            .PIPEINPUT(0),
            .PIPEDISTANCE(0)
         ) sr(
            .clk(1'b1), 
            .aclr(1'b0),
            .sclr(1'b0),
            .clken(clken),
            .x(lcshift_data),
            .distance((log2_bitw_2test)'(ish)),
            .result(res),
            .pipe_x(),
            .pipe_distance());
         clshift #(
            .BITWIDTH(bitwof_notpow2_data), 
            .DIRECTION(1), 
            .ARITHMATIC(0), 
            .DELAYTAPS(0),
            .PIPELINE(0), 
            .PIPEINPUT(0), 
            .PIPEDISTANCE(0)
         ) np2_sr(
            .clk(1'b1), 
            .aclr(1'b0),
            .sclr(1'b0),
            .clken(clken),
            .x((bitwof_notpow2_data)'(lcshift_data)),
            .distance((log2_bitw_2test)'(ish)),
            .result(),
            .pipe_x(),
            .pipe_distance()
         );
      end
      for (ish = 0; ish <= (1<<log2_bitw_2test); ish++) begin:LCSL 
         wire[(1<<log2_bitw_2test)-1:0] res;
         clshift #(
            .BITWIDTH(2**log2_bitw_2test),
            .DIRECTION(0),
            .ARITHMATIC(0),
            .DELAYTAPS(0),
            .PIPELINE(0),
            .PIPEINPUT(0),
            .PIPEDISTANCE(0)
         ) sl(
            .clk(1'b1), 
            .aclr(1'b0),
            .sclr(1'b0),
            .clken(clken),
            .x(lcshift_data),
            .distance((log2_bitw_2test)'(ish)),
            .result(res),
            .pipe_x(),
            .pipe_distance()
         );
         clshift #(
            .BITWIDTH(bitwof_notpow2_data),
            .DIRECTION(0),
            .ARITHMATIC(0),
            .DELAYTAPS(0),
            .PIPELINE(0),
            .PIPEINPUT(0),
            .PIPEDISTANCE(0)
         ) np2_sl(
            .clk(1'b1), 
            .aclr(1'b0),
            .sclr(1'b0),
            .clken(clken),
            .x((bitwof_notpow2_data)'(lcshift_data)),
            .distance((log2_bitw_2test)'(ish)),
            .result(),
            .pipe_x(),
            .pipe_distance()
         );
      end
   endgenerate
   // 时序逻辑输出
   genvar idelay;
   generate
      for (idelay = 1; idelay <log2_bitw_2test; idelay++) begin: DELAYR
         wire[2**log2_bitw_2test - 1:0] res;
         clshift #(
            .BITWIDTH(2**log2_bitw_2test),
            .DIRECTION(1),
            .ARITHMATIC(0),
            .DELAYTAPS(idelay),
            .PIPELINE(0),
            .PIPEINPUT(0),
            .PIPEDISTANCE(0)
         ) srd(
            .clk(clk),
            .aclr(mdl_rst),
            .sclr('0),
            .clken(clken),
            .x(lcshift_data),
            .distance((log2_bitw_2test)'(2)),
            .result(res),
            .pipe_x(),
            .pipe_distance()
         );
      end
      for (idelay = 1; idelay <log2_bitw_2test; idelay++) begin: DELAYL
         wire[2**log2_bitw_2test - 1:0] res;
         clshift #(
            .BITWIDTH(2**log2_bitw_2test),
            .DIRECTION(0),
            .ARITHMATIC(0),
            .DELAYTAPS(idelay),
            .PIPELINE(0),
            .PIPEINPUT(0),
            .PIPEDISTANCE(0)
         ) sld(
            .clk(clk),
            .aclr(mdl_rst),
            .sclr('0),
            .clken(clken),
            .x(lcshift_data),
            .distance((log2_bitw_2test)'(2)),
            .result(res),
            .pipe_x(),
            .pipe_distance()
         );
      end
   endgenerate
   // 流水线输出
   generate
      for (idelay = 1; idelay <log2_bitw_2test; idelay++) begin: DELAYRP
         wire[2**log2_bitw_2test - 1:0] res;
         clshift #(
            .BITWIDTH(2**log2_bitw_2test),
            .DIRECTION(1),
            .ARITHMATIC(0),
            .DELAYTAPS(idelay),
            .PIPELINE(1),
            .PIPEINPUT(0),
            .PIPEDISTANCE(0)
         ) srdp(
            .clk(clk),
            .aclr(mdl_rst),
            .sclr(1'b0),
            .clken(clken),
            .x(lcshift_data),
            .distance((log2_bitw_2test)'(2)),
            .result(res),
            .pipe_x(),
            .pipe_distance()
         );
      end
      for (idelay = 1; idelay <log2_bitw_2test; idelay++) begin: DELAYLP
         wire[2**log2_bitw_2test - 1:0] res;
         clshift #(
            .BITWIDTH(2**log2_bitw_2test),
            .DIRECTION(0),
            .ARITHMATIC(0),
            .DELAYTAPS(idelay),
            .PIPELINE(1),
            .PIPEINPUT(1),
            .PIPEDISTANCE(1)
         ) sldp(
            .clk(clk),
            .aclr(mdl_rst),
            .sclr(1'b0),
            .clken(clken),
            .x(lcshift_data),
            .distance((log2_bitw_2test)'(2)),
            .result(res),
            .pipe_x(),
            .pipe_distance()
         );
      end
   endgenerate

   // 检查结果
   generate
      for (idelay = 1; idelay < log2_bitw_2test; idelay++) begin
         always_ff @(posedge clk) begin
            if (~mdl_rst) begin
               assert(DELAYL[idelay].res == DELAYLP[idelay].res);
               assert(DELAYR[idelay].res == DELAYRP[idelay].res);
            end
         end
      end
   endgenerate
endmodule
