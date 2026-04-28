/*!
 * \license SPDX-License-Identifier: MIT
 * \file packconv.sv
 * \brief 合并数组信号与非合并数组信号之间的转换
 * \author JohnYork <johnyork@yeah.net>
 */
module array_packed2unpacked #(
   parameter int UNITBITW = 32,
   parameter int ARRAYSIZ = 2
) (
   input  wire [ARRAYSIZ-1:0][UNITBITW-1:0]in,
   output logic              [UNITBITW-1:0]out[ARRAYSIZ-1:0]
);
   always_comb for(int i = 0; i < ARRAYSIZ; i++) out[i] = in[i];
endmodule

module array_unpacked2packed #(
   parameter int UNITBITW = 32,
   parameter int ARRAYSIZ = 2
) (
   input  wire               [UNITBITW-1:0]in[ARRAYSIZ-1:0],
   output logic[ARRAYSIZ-1:0][UNITBITW-1:0]out
);
   always_comb for(int i = 0; i < ARRAYSIZ; i++) out[i] = in[i];
endmodule

module unpackedarrayunit_packed2unpacked #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]in [ARRAYSIZ-1:0],
   output logic              [UNITBITW-1:0]out[ARRAYSIZ-1:0][AUNITSIZ-1:0]
);
   always_comb for(int i = 0; i < ARRAYSIZ; i++) begin
      for (int j = 0; j < AUNITSIZ; j++) out[i][j] = in[i][j];
   end
endmodule

module unpackedarrayunit_unpacked2packed #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire               [UNITBITW-1:0]in [ARRAYSIZ-1:0][AUNITSIZ-1:0],
   output logic[AUNITSIZ-1:0][UNITBITW-1:0]out[ARRAYSIZ-1:0]
);
   always_comb for(int i = 0; i < ARRAYSIZ; i++) begin
      for (int j = 0; j < AUNITSIZ; j++) out[i][j] = in[i][j];
   end
endmodule

module packedarray_combine2unit #(
   parameter int UNITBITW = 32,
   parameter int ARRAYSIZ = 2
) (
   input  wire [ARRAYSIZ-1:0][UNITBITW-1:0]in,
   output logic[UNITBITW*ARRAYSIZ-1:0]     out
);
   genvar i; generate for (i = 0; i < ARRAYSIZ; i += 1) begin: AC
      assign out[(i+1)*UNITBITW-1:i*UNITBITW] = in[i];
   end endgenerate
endmodule

module unit_split2packedarray #(
   parameter int UNITBITW = 32,
   parameter int ARRAYSIZ = 2
) (
   input  wire [UNITBITW*ARRAYSIZ-1:0]     in,
   output logic[ARRAYSIZ-1:0][UNITBITW-1:0]out
);
   genvar j; generate for (j = 0; j < ARRAYSIZ; j += 1) begin: AC
      assign out[j] = in[(j+1)*UNITBITW-1:j*UNITBITW];
   end endgenerate
endmodule

module unpackedarray_combine2unit #(
   parameter int UNITBITW = 32,
   parameter int ARRAYSIZ = 2
) (
   input  wire [UNITBITW-1:0]          in[ARRAYSIZ-1:0],
   output logic[UNITBITW*ARRAYSIZ-1:0] out
);
   genvar i; generate for (i = 0; i < ARRAYSIZ; i += 1) begin: AC
      assign out[(i+1)*UNITBITW-1:i*UNITBITW] = in[i];
   end endgenerate
endmodule

module unit_split2unpackedarray #(
   parameter int UNITBITW = 32,
   parameter int ARRAYSIZ = 2
) (
   input  wire  [UNITBITW*ARRAYSIZ-1:0] in,
   output logic [UNITBITW-1:0]          out[ARRAYSIZ-1:0]
);
   genvar i; generate for (i = 0; i < ARRAYSIZ; i+= 1) begin: AC
      assign out[i] = in[(i+1)*UNITBITW-1:i*UNITBITW];
   end endgenerate
endmodule

module packedarray_packedunitarray_combine2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] in,
   output logic[ARRAYSIZ-1:0][AUNITSIZ*UNITBITW-1:0]      out
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         packedarray_combine2unit #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j]   ),
            .out  (out[j]  )
         );
      end
   endgenerate
endmodule

module packedarray_unit_split2packedunitarray #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [ARRAYSIZ-1:0][AUNITSIZ*UNITBITW-1:0]      in,
   output logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] out
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         unit_split2packedarray #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j]   ),
            .out  (out[j]  )
         );
      end
   endgenerate
endmodule

module packedarray_packedunitarray_extd_combine2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]    in,
   input  wire [ARRAYSIZ-1:0][(EXTDBITW>0?EXTDBITW:1)-1:0]   ex,
   output logic[ARRAYSIZ-1:0][AUNITSIZ*UNITBITW+EXTDBITW-1:0]out
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         packedarray_combine2unit #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j]                        ),
            .out  (out[j][AUNITSIZ*UNITBITW-1:0])
         );
         if (EXTDBITW > 0) assign out[j][AUNITSIZ*UNITBITW+EXTDBITW-1:AUNITSIZ*UNITBITW] = ex[j];
      end
   endgenerate
endmodule

module packedarray_unit_split2packedunitarray_extd #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [ARRAYSIZ-1:0][AUNITSIZ*UNITBITW+EXTDBITW-1:0]in,
   output logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]    out,
   output logic[ARRAYSIZ-1:0][(EXTDBITW>0?EXTDBITW:1)-1:0]   ex
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         unit_split2packedarray #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j][AUNITSIZ*UNITBITW-1:0] ),
            .out  (out[j]                       )
         );
         if (EXTDBITW > 0) assign ex[j] = in[j][AUNITSIZ*UNITBITW+EXTDBITW-1:AUNITSIZ*UNITBITW];
         else              assign ex[j] = 1'b0;
      end
   endgenerate
endmodule

module packedarray_packedunitarray_combineall2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] in,
   output logic[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]           out
);
   logic[ARRAYSIZ-1:0][AUNITSIZ*UNITBITW-1:0] d;
   packedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) idc(
      .in   (in),
      .out  (d )
   );
   packedarray_combine2unit #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         )
   ) doc(
      .in   (d    ),
      .out  (out  )
   );
endmodule

module packedarray_unit_split2allpackedunitarray #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]           in,
   output logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] out
);
   logic[ARRAYSIZ-1:0][AUNITSIZ*UNITBITW-1:0] d;
   unit_split2packedarray #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         )
   ) idc(
      .in   (in),
      .out  (d )
   );
   packedarray_unit_split2packedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) doc(
      .in   (d    ),
      .out  (out  )
   );
endmodule

module packedarray_packedunitarray_extd_combineall2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] in,
   input  wire [ARRAYSIZ-1:0][(EXTDBITW>0?EXTDBITW:1)-1:0]ex,
   output logic[ARRAYSIZ*(AUNITSIZ*UNITBITW+EXTDBITW)-1:0]out
);
   logic[ARRAYSIZ-1:0][AUNITSIZ*UNITBITW+EXTDBITW-1:0] d;
   packedarray_packedunitarray_extd_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .EXTDBITW(EXTDBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) idc(
      .in   (in),
      .ex   (ex),
      .out  (d )
   );
   packedarray_combine2unit #(
      .UNITBITW(UNITBITW*AUNITSIZ+EXTDBITW),
      .ARRAYSIZ(ARRAYSIZ                  )
   ) doc(
      .in   (d    ),
      .out  (out  )
   );
endmodule

module packedarray_unit_split2allpackedunitarray_extd #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [ARRAYSIZ*(AUNITSIZ*UNITBITW+EXTDBITW)-1:0]in,
   output logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] out,
   output logic[ARRAYSIZ-1:0][(EXTDBITW>0?EXTDBITW:1)-1:0]ex
);
   logic[ARRAYSIZ-1:0][AUNITSIZ*UNITBITW+EXTDBITW-1:0] d;
   unit_split2packedarray #(
      .UNITBITW(UNITBITW*AUNITSIZ+EXTDBITW),
      .ARRAYSIZ(ARRAYSIZ                  )
   ) idc(
      .in   (in),
      .out  (d )
   );
   packedarray_unit_split2packedunitarray_extd #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .EXTDBITW(EXTDBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) doc(
      .in   (d    ),
      .out  (out  ),
      .ex   (ex   )
   );
endmodule

module unpackedarray_packedunitarray_combine2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0] in[ARRAYSIZ-1:0],
   output logic[AUNITSIZ*UNITBITW-1:0]      out[ARRAYSIZ-1:0]
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         packedarray_combine2unit #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j]   ),
            .out  (out[j]  )
         );
      end
   endgenerate
endmodule

module unpackedarray_unit_split2packedunitarray #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ*UNITBITW-1:0]      in[ARRAYSIZ-1:0],
   output logic[AUNITSIZ-1:0][UNITBITW-1:0] out[ARRAYSIZ-1:0]
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         unit_split2packedarray #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j]   ),
            .out  (out[j]  )
         );
      end
   endgenerate
endmodule

module unpackedarray_packedunitarray_extd_combine2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]      in[ARRAYSIZ-1:0],
   input  wire [(EXTDBITW>0?EXTDBITW:1)-1:0]     ex[ARRAYSIZ-1:0],
   output logic[AUNITSIZ*UNITBITW+EXTDBITW-1:0]  out[ARRAYSIZ-1:0]
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         packedarray_combine2unit #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j]                        ),
            .out  (out[j][AUNITSIZ*UNITBITW-1:0])
         );
         if (EXTDBITW > 0) assign out[j][AUNITSIZ*UNITBITW+EXTDBITW-1:AUNITSIZ*UNITBITW] = ex[j];
      end
   endgenerate
endmodule

module unpackedarray_unit_split2packedunitarray_extd #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ*UNITBITW+EXTDBITW-1:0]  in[ARRAYSIZ-1:0],
   output logic[AUNITSIZ-1:0][UNITBITW-1:0]      out[ARRAYSIZ-1:0],
   output logic[(EXTDBITW>0?EXTDBITW:1)-1:0]     ex[ARRAYSIZ-1:0]
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         unit_split2packedarray #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j][AUNITSIZ*UNITBITW-1:0] ),
            .out  (out[j]                       )
         );
         if (EXTDBITW > 0) assign ex[j] = in[j][AUNITSIZ*UNITBITW+EXTDBITW-1:AUNITSIZ*UNITBITW];
      end
   endgenerate
endmodule

module unpackedarray_packedunitarray_combineall2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]      in[ARRAYSIZ-1:0],
   output logic[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]  out
);
   logic[AUNITSIZ*UNITBITW-1:0]d[ARRAYSIZ-1:0];
   unpackedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) idc(
      .in   (in),
      .out  (d )
   );
   unpackedarray_combine2unit #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         )
   ) doc(
      .in   (d    ),
      .out  (out  )
   );
endmodule

module unpackedarray_unit_split2allpackedunitarray #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]  in,
   output logic[AUNITSIZ-1:0][UNITBITW-1:0]      out[ARRAYSIZ-1:0]
);
   logic[AUNITSIZ*UNITBITW-1:0]d[ARRAYSIZ-1:0];
   unit_split2unpackedarray #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         )
   ) idc(
      .in   (in),
      .out  (d )
   );
   unpackedarray_unit_split2packedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) doc(
      .in   (d    ),
      .out  (out  )
   );
endmodule

module unpackedarray_packedunitarray_extd_combineall2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]      in[ARRAYSIZ-1:0],
   input  wire [(EXTDBITW>0?EXTDBITW:1)-1:0]     ex[ARRAYSIZ-1:0],
   output logic[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]  out
);
   logic[AUNITSIZ*UNITBITW+EXTDBITW-1:0]d[ARRAYSIZ-1:0];
   unpackedarray_packedunitarray_extd_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .EXTDBITW(EXTDBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) idc(
      .in   (in),
      .ex   (ex),
      .out  (d )
   );
   unpackedarray_combine2unit #(
      .UNITBITW(UNITBITW*AUNITSIZ+EXTDBITW),
      .ARRAYSIZ(ARRAYSIZ                  )
   ) doc(
      .in   (d    ),
      .out  (out  )
   );
endmodule

module unpackedarray_unit_split2allpackedunitarray_extd #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [ARRAYSIZ*(AUNITSIZ*UNITBITW+EXTDBITW)-1:0]in,
   output logic[AUNITSIZ-1:0][UNITBITW-1:0]               out[ARRAYSIZ-1:0],
   output logic[(EXTDBITW>0?EXTDBITW:1)-1:0]              ex[ARRAYSIZ-1:0]
);
   logic[AUNITSIZ*UNITBITW+EXTDBITW-1:0]d[ARRAYSIZ-1:0];
   unit_split2unpackedarray #(
      .UNITBITW(UNITBITW*AUNITSIZ+EXTDBITW),
      .ARRAYSIZ(ARRAYSIZ                  )
   ) idc(
      .in   (in),
      .out  (d )
   );
   unpackedarray_unit_split2packedunitarray_extd #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .EXTDBITW(EXTDBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) doc(
      .in   (d    ),
      .out  (out  ),
      .ex   (ex   )
   );
endmodule

module unpackedarray_unpackedunitarray_combine2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [UNITBITW-1:0]           in[ARRAYSIZ-1:0][AUNITSIZ-1:0],
   output logic[AUNITSIZ*UNITBITW-1:0]  out[ARRAYSIZ-1:0]
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         unpackedarray_combine2unit #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j]   ),
            .out  (out[j]  )
         );
      end
   endgenerate
endmodule

module unpackedarray_unit_split2unpackedunitarray #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ*UNITBITW-1:0]  in[ARRAYSIZ-1:0],
   output logic[UNITBITW-1:0]           out[ARRAYSIZ-1:0][AUNITSIZ-1:0]
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         unit_split2unpackedarray #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j]   ),
            .out  (out[j]  )
         );
      end
   endgenerate
endmodule

module unpackedarray_unpackedunitarray_extd_combine2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [UNITBITW-1:0]                    in[ARRAYSIZ-1:0][AUNITSIZ-1:0],
   input  wire [(EXTDBITW>0?EXTDBITW:1)-1:0]     ex[ARRAYSIZ-1:0],
   output logic[AUNITSIZ*UNITBITW+EXTDBITW-1:0]  out[ARRAYSIZ-1:0]
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         unpackedarray_combine2unit #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j]                        ),
            .out  (out[j][AUNITSIZ*UNITBITW-1:0])
         );
         if (EXTDBITW > 0) assign out[j][AUNITSIZ*UNITBITW+EXTDBITW-1:AUNITSIZ*UNITBITW] = ex[j];
      end
   endgenerate
endmodule

module unpackedarray_unit_split2unpackedunitarray_extd #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ*UNITBITW+EXTDBITW-1:0]  in[ARRAYSIZ-1:0],
   output logic[UNITBITW-1:0]                    out[ARRAYSIZ-1:0][AUNITSIZ-1:0],
   output logic[(EXTDBITW>0?EXTDBITW:1)-1:0]     ex[ARRAYSIZ-1:0]
);
   genvar j; generate
      for (j = 0; j < ARRAYSIZ; j++) begin: AC
         unit_split2unpackedarray #(
            .UNITBITW(UNITBITW),
            .ARRAYSIZ(AUNITSIZ)
         ) uac(
            .in   (in[j][AUNITSIZ*UNITBITW-1:0] ),
            .out  (out[j]                       )
         );
         if (EXTDBITW > 0) assign ex[j] = in[j][AUNITSIZ*UNITBITW+EXTDBITW-1:AUNITSIZ*UNITBITW];
      end
   endgenerate
endmodule

module unpackedarray_unpackedunitarray_combineall2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [UNITBITW-1:0]                    in[ARRAYSIZ-1:0][AUNITSIZ-1:0],
   output logic[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]  out
);
   logic[AUNITSIZ*UNITBITW-1:0]d[ARRAYSIZ-1:0];
   unpackedarray_unpackedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) idc(
      .in   (in),
      .out  (d )
   );
   unpackedarray_combine2unit #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         )
   ) doc(
      .in   (d    ),
      .out  (out  )
   );
endmodule

module unpackedarray_unit_split2allunpackedunitarray #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ*UNITBITW*ARRAYSIZ-1:0] in,
   output logic[UNITBITW-1:0]           out[ARRAYSIZ-1:0][AUNITSIZ-1:0]
);
   logic[AUNITSIZ*UNITBITW-1:0]d[ARRAYSIZ-1:0];
   unit_split2unpackedarray #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         )
   ) idc(
      .in   (in),
      .out  (d )
   );
   unpackedarray_unit_split2unpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) doc(
      .in   (d    ),
      .out  (out  )
   );
endmodule

module unpackedarray_unpackedunitarray_extd_combineall2unit #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [UNITBITW-1:0]                    in[ARRAYSIZ-1:0][AUNITSIZ-1:0],
   input  wire [(EXTDBITW>0?EXTDBITW:1)-1:0]     ex[ARRAYSIZ-1:0],
   output logic[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]  out
);
   logic[AUNITSIZ*UNITBITW+EXTDBITW-1:0]d[ARRAYSIZ-1:0];
   unpackedarray_unpackedunitarray_extd_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .EXTDBITW(EXTDBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) idc(
      .in   (in),
      .ex   (ex),
      .out  (d )
   );
   unpackedarray_combine2unit #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         )
   ) doc(
      .in   (d    ),
      .out  (out  )
   );
endmodule

module unpackedarray_unit_split2allunpackedunitarray_extd #(
   parameter int UNITBITW = 32,
   parameter int AUNITSIZ = 2,
   parameter int EXTDBITW = 0,
   parameter int ARRAYSIZ = 3
) (
   input  wire [AUNITSIZ*UNITBITW*ARRAYSIZ-1:0] in,
   output logic[UNITBITW-1:0]                   out[ARRAYSIZ-1:0][AUNITSIZ-1:0],
   output logic[(EXTDBITW>0?EXTDBITW:1)-1:0]    ex[ARRAYSIZ-1:0]
);
   logic[AUNITSIZ*UNITBITW+EXTDBITW-1:0]d[ARRAYSIZ-1:0];
   unit_split2unpackedarray #(
      .UNITBITW(UNITBITW*AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ         )
   ) idc(
      .in   (in),
      .out  (d )
   );
   unpackedarray_unit_split2unpackedunitarray_extd #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .EXTDBITW(EXTDBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) doc(
      .in   (d    ),
      .out  (out  ),
      .ex   (ex   )
   );
endmodule

module unpackedarray_assign #(
   parameter int UNITBITW = 32,
   parameter int ARRAYSIZ = 2
) (
   input  wire  [UNITBITW-1:0] in[ARRAYSIZ-1:0],
   output logic [UNITBITW-1:0] out[ARRAYSIZ-1:0]
);
   always_comb for(int i = 0; i < ARRAYSIZ; i++) out[i] = in[i];
endmodule

module unpackedarray_fill #(
   parameter int UNITBITW = 32,
   parameter int ARRAYSIZ = 2
) (
   input  wire  [UNITBITW-1:0] val2fill,
   output logic [UNITBITW-1:0] out[ARRAYSIZ-1:0]
);
   always_comb for(int i = 0; i < ARRAYSIZ; i++) out[i] = val2fill;
endmodule

module packedarray_fill #(
   parameter int UNITBITW = 32,
   parameter int ARRAYSIZ = 2
) (
   input  wire [UNITBITW-1:0]              val2fill,
   output logic[ARRAYSIZ-1:0][UNITBITW-1:0]out
);
   always_comb for(int i = 0; i < ARRAYSIZ; i++) out[i] = val2fill;
endmodule

module packedarray_combine2unit_inpackedarray #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [ARRAYSIZ2-1:0][ARRAYSIZ1-1:0][UNITBITW-1:0] in,
   output logic[ARRAYSIZ2-1:0][ARRAYSIZ1*UNITBITW-1:0]      out
);
   genvar i; generate for (i = 0; i < ARRAYSIZ2; i += 1) begin: AC
      packedarray_combine2unit #(
         .UNITBITW(UNITBITW),
         .ARRAYSIZ(ARRAYSIZ1)
      ) pac2u(
         .in   (in[i]   ),
         .out  (out[i]  )
      );
   end endgenerate
endmodule

module unit_split2packedarray_inpackedarray #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [ARRAYSIZ2-1:0][ARRAYSIZ1*UNITBITW-1:0]      in,
   output logic[ARRAYSIZ2-1:0][ARRAYSIZ1-1:0][UNITBITW-1:0] out
);
   genvar i; generate for (i = 0; i < ARRAYSIZ2; i += 1) begin: AC
      unit_split2packedarray #(
         .UNITBITW(UNITBITW),
         .ARRAYSIZ(ARRAYSIZ1)
      ) pac2u(
         .in   (in[i]   ),
         .out  (out[i]  )
      );
   end endgenerate
endmodule

module packedarray_combine2unit_inunpackedarray #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [ARRAYSIZ1-1:0][UNITBITW-1:0] in[ARRAYSIZ2-1:0],
   output logic[ARRAYSIZ1*UNITBITW-1:0]      out[ARRAYSIZ2-1:0]
);
   genvar i; generate for (i = 0; i < ARRAYSIZ2; i += 1) begin: AC
      packedarray_combine2unit #(
         .UNITBITW(UNITBITW),
         .ARRAYSIZ(ARRAYSIZ1)
      ) pac2u(
         .in   (in[i]   ),
         .out  (out[i]  )
      );
   end endgenerate
endmodule

module unit_split2packedarray_inunpackedarray #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [ARRAYSIZ1*UNITBITW-1:0]      in[ARRAYSIZ2-1:0],
   output logic[ARRAYSIZ1-1:0][UNITBITW-1:0] out[ARRAYSIZ2-1:0]
);
   genvar i; generate for (i = 0; i < ARRAYSIZ2; i += 1) begin: AC
      unit_split2packedarray #(
         .UNITBITW(UNITBITW   ),
         .ARRAYSIZ(ARRAYSIZ1  )
      ) pac2u(
         .in(in[i]),
         .out(out[i])
      );
   end endgenerate
endmodule

module unpackedarray_combine2unit_inunpackedarray #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [UNITBITW-1:0]           in[ARRAYSIZ2-1:0][ARRAYSIZ1-1:0],
   output logic[ARRAYSIZ1*UNITBITW-1:0] out[ARRAYSIZ2-1:0]
);
   genvar i; generate for (i = 0; i < ARRAYSIZ2; i += 1) begin: AC
      unpackedarray_combine2unit #(
         .UNITBITW(UNITBITW   ),
         .ARRAYSIZ(ARRAYSIZ1  )
      ) pac2u(
         .in   (in[i]   ),
         .out  (out[i]  )
      );
   end endgenerate
endmodule

module unit_split2unpackedarray_inunpackedarray #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [ARRAYSIZ1*UNITBITW-1:0] in[ARRAYSIZ2-1:0],
   output logic[UNITBITW-1:0]           out[ARRAYSIZ2-1:0][ARRAYSIZ1-1:0]
);
   genvar i; generate for (i = 0; i < ARRAYSIZ2; i += 1) begin: AC
      unit_split2unpackedarray #(
         .UNITBITW(UNITBITW   ),
         .ARRAYSIZ(ARRAYSIZ1  )
      ) pac2u(
         .in   (in[i]   ),
         .out  (out[i]  )
      );
   end endgenerate
endmodule

module packedarrayinunpackedarray_assign #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [ARRAYSIZ1-1:0][UNITBITW-1:0] in[ARRAYSIZ2-1:0],
   output logic[ARRAYSIZ1-1:0][UNITBITW-1:0] out[ARRAYSIZ2-1:0]
);
   always_comb for(int i = 0; i < ARRAYSIZ2; i++) out[i] = in[i];
endmodule

module unpackedarrayinunpackedarray_assign #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [UNITBITW-1:0] in[ARRAYSIZ2-1:0][ARRAYSIZ1-1:0],
   output logic[UNITBITW-1:0] out[ARRAYSIZ2-1:0][ARRAYSIZ1-1:0]
);
   always_comb for(int i = 0; i < ARRAYSIZ2; i++) begin
      for (int j = 0; j < ARRAYSIZ1; j++) out[i][j] = in[i][j];
   end
endmodule

module packedarrayinunpackedarray_fill #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [ARRAYSIZ1-1:0][UNITBITW-1:0] val2fill,
   output logic[ARRAYSIZ1-1:0][UNITBITW-1:0] out[ARRAYSIZ2-1:0]
);
   always_comb for(int i = 0; i < ARRAYSIZ2; i++) out[i] = val2fill;
endmodule

module packedarrayinpackedarray_fill #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [ARRAYSIZ1-1:0][UNITBITW-1:0]               val2fill,
   output logic[ARRAYSIZ2-1:0][ARRAYSIZ1-1:0][UNITBITW-1:0]out
);
   always_comb for(int i = 0; i < ARRAYSIZ2; i++) out[i] = val2fill;
endmodule

module unpackedarrayinunpackedarray_fill #(
   parameter int UNITBITW  = 32,
   parameter int ARRAYSIZ1 = 2,
   parameter int ARRAYSIZ2 = 2
) (
   input  wire [UNITBITW-1:0] val2fill[ARRAYSIZ1-1:0],
   output logic[UNITBITW-1:0] out[ARRAYSIZ2-1:0][ARRAYSIZ1-1:0]
);
   always_comb for(int i = 0; i < ARRAYSIZ2; i++) begin
      for (int j = 0; j < ARRAYSIZ1; j++) out[i][j] = val2fill[j];
   end
endmodule

