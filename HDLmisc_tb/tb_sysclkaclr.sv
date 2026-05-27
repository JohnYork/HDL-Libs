`timescale 1ps/1ps
module tb_sysclkaclr #(
   parameter int ACLR_WIDTH = 4
) (
   output logic clk,aclr,sclr
);
   initial clk = 0;
   always #1 clk = ~clk;

   initial begin
      aclr = 0;
      sclr = 0;
      # 1 aclr = 1;
      # (ACLR_WIDTH) aclr = 0;
   end
   always @(posedge clk) sclr <= aclr;
endmodule

module tb_checkres #(
   parameter int FLOWCNT  = 1,
   parameter int AUSIZ    = 1,
   parameter int BITW     = 10,
   parameter bit SIGNED   = 1'b0,
   parameter int REFDELAY = 10
) (
   input  wire                                  clk,
   input  wire                                  sclr, 
   input  wire                                  clken,
   input  wire[FLOWCNT-1:0][AUSIZ-1:0][BITW-1:0]refv,
   input  wire[FLOWCNT-1:0][AUSIZ-1:0][BITW-1:0]res,
   output wire[FLOWCNT-1:0][AUSIZ-1:0][BITW-1:0]err
);
   wire[FLOWCNT-1:0][AUSIZ-1:0][BITW-1:0] pref;
   pipedelay_taps_packedunit_packedarray #(
      .DATABITW   (BITW                         ),
      .ARRAYSIZ   (FLOWCNT                      ),
      .INITVAL    ({(FLOWCNT){{(BITW){1'b0}}}}  ),
      .DELAYTAPS  (REFDELAY                     )
   ) piperefs(
      .clk(clk),
      .aclr(1'b0),
      .sclr(sclr),
      .clken(clken),
      .x(refv),
      .pipe_x(pref)
   );
   genvar i, j; 
   generate
      for (i = 0; i < FLOWCNT; i++) begin
         for (j = 0; j < AUSIZ; j++) begin
            if (SIGNED) assign err[i][j] = signed'(res[i][j]) - signed'(pref[i][j]);
            else        assign err[i][j] = res[i][j] - pref[i][j];
         end
      end
   endgenerate
endmodule
