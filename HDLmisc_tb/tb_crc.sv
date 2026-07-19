`timescale 1ps/1ps
`include "crc.svh"
module tb_crc;
   wire clk, aclr, sclr;
   tb_sysclkaclr #(
      .ACLR_WIDTH(5)
   ) clkaclrgen(
      .clk(clk),
      .aclr(aclr),
      .sclr(sclr)
   );
   reg clken, clken2o;
   initial begin
      clken = 0;
      # 7
      clken = 1;
   end
   always @(posedge clk) begin
      clken2o <= clken;
   end
   localparam bit[0:4][7:0] val = {8'h12, 8'h34, 8'h56, 8'h78, 8'h09};
   reg[7:0] dcntr, di;
   wire blki;
   always_ff @(posedge clk) begin
      if      (aclr) dcntr <= 1;
      else if (sclr) dcntr <= 1;
      else           dcntr <= (clken2o&(~blki))
                              ? ((dcntr < 4)
                                 ? dcntr + 1
                                 : 0)
                              : dcntr;
   end
   always_ff @(posedge clk) begin
      if      (aclr) di <= val[0];
      else if (sclr) di <= val[0];
      else           di <= (clken2o&(~blki))
                           ? val[dcntr]
                           : di;
   end
   reg vld, vld2o;
   initial begin
      vld = 0;
      # 6
         vld = 1;
      # 208
         vld = 0;
   end
   always_ff @(posedge clk ) begin
      vld2o <= vld;
   end
   scrc #(
      .CC(crc_pkg::crc16modbus),
      .BW(8                   )
   ) crc16modbus(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(clken2o ),
      .ida  (di      ),
      .ivld (vld2o   ),
      .isop (1'b0    ),
      .cs   (        ),
      .ovld (        ),
      .pvld (        ),
      .blki (blki    )
   );
   scrc #(
      .CC(crc_pkg::crc16ccittfalse  ),
      .BW(8                         )
   ) crc16ccittfalse(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(clken2o ),
      .ida  (di      ),
      .isop (1'b0    ),
      .ivld (vld2o   ),
      .cs   (        ),
      .ovld (        ),
      .pvld (        ),
      .blki (blki    )
   );

   reg[10:0] bcntr;
   wire blki1, blki1f;
   always @(posedge clk) begin
      if      (aclr) bcntr <= 1;
      else if (sclr) bcntr <= 1;
      else           bcntr <= (clken2o&(~blki1))
                              ? ((bcntr < 5*8-1)
                                 ? (bcntr + 1)
                                 : 0)
                              : bcntr;
   end
   reg di1;
   always_ff @( posedge clk ) begin
      if      (aclr) di1 <= val[0][0];
      else if (sclr) di1 <= val[0][0];
      else           di1 <= (clken2o&(~blki1))
                            ? val[bcntr[10:3]][bcntr[2:0]]
                            : di1;
   end
   reg di1f;
   always_ff @( posedge clk ) begin
      if      (aclr) di1f <= val[0][7];
      else if (sclr) di1f <= val[0][7];
      else           di1f <= (clken2o&(~blki1f))
                            ? val[bcntr[10:3]][~bcntr[2:0]]
                            : di1f;
   end
   scrc #(
      .CC(crc_pkg::crc16modbus),
      .BW(1                   )
   ) crc16modbus1(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(clken2o ),
      .ida  (di1     ),
      .ivld (vld2o   ),
      .isop (1'b0    ),
      .cs   (        ),
      .ovld (        ),
      .pvld (        ),
      .blki (blki1   )
   );
   scrc #(
      .CC(crc_pkg::crc16ccittfalse  ),
      .BW(1                         )
   ) crc16ccittfalse1(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(clken2o ),
      .ida  (di1f     ),
      .ivld (vld2o   ),
      .isop (1'b0    ),
      .cs   (        ),
      .ovld (        ),
      .pvld (        ),
      .blki (blki1f   )
   );

   logic pcrcisop, pcrcisop2o;
   initial begin
      pcrcisop = 0;
      # 71
         pcrcisop = 1;
      # 9
         pcrcisop = 0;
   end
   always @(posedge clk) begin
      pcrcisop2o <= pcrcisop;
   end
   pcrc #(
      .CC   (crc_pkg::crc16modbus),
      .BW   (8                   ),
      .PCBW (8                   )// 每个数据的校验要比下面的正确模块多算一次，因而结果不正确
   ) pcr16modbus(
      .clk  (clk        ),
      .aclr (aclr       ),
      .sclr (sclr       ),
      .clken(clken2o    ),
      .ida  (di         ),
      .ivld (vld2o      ),
      .isop (pcrcisop2o ),
      .cs   (           ),
      .ovld (           ),
      .pvld (           ),
      .blki (           )
   );
   pcrc #(
      .CC   (crc_pkg::crc16modbus),
      .BW   (8                   ),
      .PCBW (4                   )
   ) pcr16modbus1(
      .clk  (clk        ),
      .aclr (aclr       ),
      .sclr (sclr       ),
      .clken(clken2o    ),
      .ida  (di         ),
      .ivld (vld2o      ),
      .isop (pcrcisop2o ),
      .cs   (           ),
      .ovld (           ),
      .pvld (           ),
      .blki (           )
   );
   pcrc #(
      .CC   (crc_pkg::crc16ccittfalse  ),
      .BW   (8                         ),
      .PCBW (8                         )
   ) pcr16ccittfalse(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(clken2o ),
      .ida  (di      ),
      .ivld (vld2o   ),
      .isop (1'b0    ),
      .cs   (        ),
      .ovld (        ),
      .pvld (        ),
      .blki (        )
   );
   pcrc #(
      .CC   (crc_pkg::crc16ccittfalse  ),
      .BW   (8                         ),
      .PCBW (4                         )
   ) pcr16ccittfalse1(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(clken2o ),
      .ida  (di      ),
      .ivld (vld2o   ),
      .isop (1'b0    ),
      .cs   (        ),
      .ovld (        ),
      .pvld (        ),
      .blki (        )
   );
endmodule
