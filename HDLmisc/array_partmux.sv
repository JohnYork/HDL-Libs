/*!
 * \license SPDX-License-Identifier: MIT
 * \file array_partmux.sv
 * \brief 数组元素分块多路复用器
 * \author JohnYork <johnyork@yeah.net>
 * \depends mux
 */
`include "mux.svh"
`define __INC_FROM_ARRAY_PARTMUX__
`include "array_partmux.svh"
/*! \brief 基于索引选通的合并数组分块多路复用选择器 */
module partmux_byidx_packedarray #(
   parameter int                                                                                   UNITBITW  = 8, ///< 数组元素位宽
   parameter int                                                                                   ARRAYSIZ  = 3, ///< 数组元素个数
   parameter int                                                                                   MUXCOUNT  = 2, ///< 数组元素复用分块数
   parameter bit[array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)-1:0][UNITBITW-1:0] INITNOCS  = {(array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)*UNITBITW){1'b0}},
   parameter int                                                                                   DELAYTAPS = 0  ///< 延迟输出拍数
) (clk, aclr, sclr, clken, array_in, part4nocs, idx, mux_out);
   input  bit                                clk;        ///< 时钟信号
   input  wire                               aclr;       ///< 异步复位信号，高电平(1)有效
   input  wire                               sclr;       ///< 同步复位信号，高电平(1)有效
   input  wire                               clken;      ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire [ARRAYSIZ-1:0][UNITBITW-1:0]  array_in;   ///< 输入待分块复用的数组
   localparam int bitwOfIdx = mux_pkg::idxbitw_ofmux(MUXCOUNT);
   input  wire [bitwOfIdx-1:0]               idx;        ///< 输入数据阵列选通索引。
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT);
   input  wire [cntPerPart-1:0][UNITBITW-1:0]part4nocs;  ///< 无待选通数据数组分块被选通时选择输出的数据数组分块
   output logic[cntPerPart-1:0][UNITBITW-1:0]mux_out;    ///< 复用输出的数组分块

   wire [cntPerPart-1:0][UNITBITW-1:0] part4mux[MUXCOUNT-1:0];
   genvar i; generate for (i = 0; i < MUXCOUNT; i++) begin: ARRAY4MUX
      if      ( i   *cntPerPart >= ARRAYSIZ) assign part4mux[i] = part4nocs;
      else if ((i+1)*cntPerPart <= ARRAYSIZ) assign part4mux[i] = array_in[(i+1)*cntPerPart-1:i*cntPerPart];
      else                                   assign part4mux[i] = {part4nocs[cntPerPart-1:ARRAYSIZ-i*cntPerPart], array_in[ARRAYSIZ-1:i*cntPerPart]};
   end endgenerate
   mux_byidx_packedarray #(
      .UNITBITW   (UNITBITW   ),
      .ARRAYSIZ   (cntPerPart ),
      .INITNOCS   (INITNOCS   ),
      .INPUTCNT   (MUXCOUNT   ),
      .DELAYTAPS  (DELAYTAPS  )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .array_in   (part4mux   ),
      .array4nocs (part4nocs  ),
      .idx        (idx        ),
      .array_out  (mux_out    )
   );
endmodule
module partmux_byidx_packedunit_packedarray #(
   parameter int                                                                                                  UNITBITW  = 8, ///< 数组数据位宽
   parameter int                                                                                                  AUNITSIZ  = 1, ///< 数组单元元素个数
   parameter int                                                                                                  ARRAYSIZ  = 3, ///< 数组单元个数
   parameter int                                                                                                  MUXCOUNT  = 2, ///< 数组元素复用分块数
   parameter bit[array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)*AUNITSIZ*UNITBITW){1'b0}},
   parameter int                                                                                                  DELAYTAPS = 0  ///< 延迟输出拍数
) (clk, aclr, sclr, clken, array_in, part4nocs, idx, mux_out);
   input  bit                                               clk;        ///< 时钟信号
   input  wire                                              aclr;       ///< 异步复位信号，高电平(1)有效
   input  wire                                              sclr;       ///< 同步复位信号，高电平(1)有效
   input  wire                                              clken;      ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire [ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]   array_in;   ///< 输入待分块复用的数组
   localparam int bitwOfIdx = mux_pkg::idxbitw_ofmux(MUXCOUNT);
   input  wire [bitwOfIdx-1:0]                              idx;        ///< 输入数据阵列选通索引。
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT);
   input  wire [cntPerPart-1:0][AUNITSIZ-1:0][UNITBITW-1:0] part4nocs;  ///< 无待选通数据数组分块被选通时选择输出的数据数组分块
   output logic[cntPerPart-1:0][AUNITSIZ-1:0][UNITBITW-1:0] mux_out;    ///< 复用输出的数组分块

   wire[ARRAYSIZ-1:0][UNITBITW*AUNITSIZ-1:0] ain;
   packedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) packin(
      .in   (array_in),
      .out  (ain     )
   );
   wire[cntPerPart-1:0][UNITBITW*AUNITSIZ-1:0]  nocs;
   packedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) packnocs(
      .in   (part4nocs  ),
      .out  (nocs       )
   );
   wire[cntPerPart-1:0][UNITBITW*AUNITSIZ-1:0]out;
   partmux_byidx_packedarray #(
      .UNITBITW   (UNITBITW*AUNITSIZ),
      .ARRAYSIZ   (ARRAYSIZ         ),
      .MUXCOUNT   (MUXCOUNT         ),
      .INITNOCS   (INITNOCS         ),
      .DELAYTAPS  (DELAYTAPS        )
   ) muxi(
      .clk        (clk  ),
      .aclr       (aclr ),
      .sclr       (sclr ),
      .clken      (clken),
      .array_in   (ain  ),
      .idx        (idx  ),
      .part4nocs  (nocs ),
      .mux_out    (out  )
   );
   packedarray_unit_split2packedunitarray #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) spltout(
      .in   (out     ),
      .out  (mux_out )
   );
endmodule
/*! \brief 基于索引选通的非合并数组分块多路复用选择器 */
module partmux_byidx_unpackedarray #(
   parameter int                                                                                   UNITBITW  = 8, ///< 数组元素位宽
   parameter int                                                                                   ARRAYSIZ  = 3, ///< 数组元素个数
   parameter int                                                                                   MUXCOUNT  = 2, ///< 数组元素复用分块数
   parameter bit[array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)-1:0][UNITBITW-1:0] INITNOCS  = {(array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)*UNITBITW){1'b0}},
   parameter int                                                                                   DELAYTAPS = 0  ///< 延迟输出拍数
) (clk, aclr, sclr, clken, array_in, part4nocs, idx, mux_out);
   input  bit                 clk;                       ///< 时钟信号
   input  wire                aclr;                      ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                      ///< 同步复位信号，高电平(1)有效
   input  wire                clken;                     ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire [UNITBITW-1:0] array_in[ARRAYSIZ-1:0];    ///< 输入待分块复用的数组
   localparam int bitwOfIdx = mux_pkg::idxbitw_ofmux(MUXCOUNT);
   input  wire [bitwOfIdx-1:0]idx;                       ///< 输入数据阵列选通索引。
                                                         ///< \attention 当例化参数 #PIPELINE 为 1'b0 时， #idx 信号至少须保持到数据输出的前一拍
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT);
   input  wire [UNITBITW-1:0] part4nocs[cntPerPart-1:0]; ///< 无待选通数据数组分块被选通时选择输出的数据数组分块
   output logic[UNITBITW-1:0] mux_out[cntPerPart-1:0];   ///< 复用输出的数组分块

   wire [UNITBITW-1:0] part4mux[MUXCOUNT-1:0][cntPerPart-1:0];
   genvar i, j; generate for (i = 0; i < MUXCOUNT; i++) begin: ARRAY4MUX
      for (j = 0; j < cntPerPart; j++) begin: UNPACK_ASSIGN
         localparam int idx_array_in = i*cntPerPart + j;
         if (idx_array_in >= ARRAYSIZ) assign part4mux[i][j] = part4nocs[j];
         else                          assign part4mux[i][j] = array_in[idx_array_in];
      end
   end endgenerate
   mux_byidx_unpackedarray #(
      .UNITBITW   (UNITBITW   ),
      .ARRAYSIZ   (cntPerPart ),
      .INITNOCS   (INITNOCS   ),
      .INPUTCNT   (MUXCOUNT   ),
      .DELAYTAPS  (DELAYTAPS  )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .array_in   (part4mux   ),
      .array4nocs (part4nocs  ),
      .idx        (idx        ),
      .array_out  (mux_out    )
   );
endmodule
module partmux_byidx_packedunit_unpackedarray #(
   parameter int                                                                                                  UNITBITW  = 8, ///< 数组数据位宽
   parameter int                                                                                                  AUNITSIZ  = 1, ///< 数组单元元素个数
   parameter int                                                                                                  ARRAYSIZ  = 3, ///< 数组单元个数
   parameter int                                                                                                  MUXCOUNT  = 2, ///< 数组元素复用分块数
   parameter bit[array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)*AUNITSIZ*UNITBITW){1'b0}},
   parameter int                                                                                                  DELAYTAPS = 0  ///< 延迟输出拍数
) (clk, aclr, sclr, clken, array_in, part4nocs, idx, mux_out);
   input  bit                                clk;                       ///< 时钟信号
   input  wire                               aclr;                      ///< 异步复位信号，高电平(1)有效
   input  wire                               sclr;                      ///< 同步复位信号，高电平(1)有效
   input  wire                               clken;                     ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]  array_in[ARRAYSIZ-1:0];    ///< 输入待分块复用的数组
   localparam int bitwOfIdx = mux_pkg::idxbitw_ofmux(MUXCOUNT);
   input  wire [bitwOfIdx-1:0]               idx;                       ///< 输入数据阵列选通索引。
                                                                        ///< \attention 当例化参数 #PIPELINE 为 1'b0 时， #idx 信号至少须保持到数据输出的前一拍
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT);
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]  part4nocs[cntPerPart-1:0]; ///< 无待选通数据数组分块被选通时选择输出的数据数组分块
   output logic[AUNITSIZ-1:0][UNITBITW-1:0]  mux_out[cntPerPart-1:0];   ///< 复用输出的数组分块

   wire[UNITBITW*AUNITSIZ-1:0]ain[ARRAYSIZ-1:0];
   unpackedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) packin(
      .in   (array_in),
      .out  (ain     )
   );
   wire[UNITBITW*AUNITSIZ-1:0]nocs[cntPerPart-1:0];
   unpackedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) packnocs(
      .in   (part4nocs  ),
      .out  (nocs       )
   );
   wire[UNITBITW*AUNITSIZ-1:0]out[cntPerPart-1:0];
   partmux_byidx_unpackedarray #(
      .UNITBITW   (UNITBITW*AUNITSIZ),
      .ARRAYSIZ   (ARRAYSIZ         ),
      .MUXCOUNT   (MUXCOUNT         ),
      .INITNOCS   (INITNOCS         ),
      .DELAYTAPS  (DELAYTAPS        )
   ) muxi(
      .clk        (clk  ),
      .aclr       (aclr ),
      .sclr       (sclr ),
      .clken      (clken),
      .array_in   (ain  ),
      .idx        (idx  ),
      .part4nocs  (nocs ),
      .mux_out    (out  )
   );
   unpackedarray_unit_split2packedunitarray #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) spltout(
      .in   (out     ),
      .out  (mux_out )
   );
endmodule
module partmux_byidx_unpackedunit_unpackedarray #(
   parameter int                                                                                                  UNITBITW  = 8, ///< 数组数据位宽
   parameter int                                                                                                  AUNITSIZ  = 1, ///< 数组单元元素个数
   parameter int                                                                                                  ARRAYSIZ  = 3, ///< 数组单元个数
   parameter int                                                                                                  MUXCOUNT  = 2, ///< 数组元素复用分块数
   parameter bit[array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)*AUNITSIZ*UNITBITW){1'b0}},
   parameter int                                                                                                  DELAYTAPS = 0  ///< 延迟输出拍数
) (clk, aclr, sclr, clken, array_in, part4nocs, idx, mux_out);
   input  bit                 clk;                                      ///< 时钟信号
   input  wire                aclr;                                     ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                                     ///< 同步复位信号，高电平(1)有效
   input  wire                clken;                                    ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire [UNITBITW-1:0] array_in[ARRAYSIZ-1:0][AUNITSIZ-1:0];     ///< 输入待分块复用的数组
   localparam int bitwOfIdx = mux_pkg::idxbitw_ofmux(MUXCOUNT);
   input  wire [bitwOfIdx-1:0]idx;                                      ///< 输入数据阵列选通索引。
                                                                        ///< \attention 当例化参数 #PIPELINE 为 1'b0 时， #idx 信号至少须保持到数据输出的前一拍
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT);
   input  wire [UNITBITW-1:0] part4nocs[cntPerPart-1:0][AUNITSIZ-1:0];  ///< 无待选通数据数组分块被选通时选择输出的数据数组分块
   output logic[UNITBITW-1:0] mux_out[cntPerPart-1:0][AUNITSIZ-1:0];    ///< 复用输出的数组分块

   wire[UNITBITW*AUNITSIZ-1:0]ain[ARRAYSIZ-1:0];
   unpackedarray_unpackedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) packin(
      .in   (array_in),
      .out  (ain     )
   );
   wire[UNITBITW*AUNITSIZ-1:0]nocs[cntPerPart-1:0];
   unpackedarray_unpackedunitarray_combine2unit #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) packnocs(
      .in   (part4nocs  ),
      .out  (nocs       )
   );
   wire[UNITBITW*AUNITSIZ-1:0]out[cntPerPart-1:0];
   partmux_byidx_unpackedarray #(
      .UNITBITW   (UNITBITW*AUNITSIZ),
      .ARRAYSIZ   (ARRAYSIZ         ),
      .MUXCOUNT   (MUXCOUNT         ),
      .INITNOCS   (INITNOCS         ),
      .DELAYTAPS  (DELAYTAPS        )
   ) muxi(
      .clk        (clk  ),
      .aclr       (aclr ),
      .sclr       (sclr ),
      .clken      (clken),
      .array_in   (ain  ),
      .idx        (idx  ),
      .part4nocs  (nocs ),
      .mux_out    (out  )
   );
   unpackedarray_unit_split2unpackedunitarray #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) spltout(
      .in   (out     ),
      .out  (mux_out )
   );
endmodule
/*! \brief 基于选通信号选通的合并数组分块多路复用器 */
module partmux_bycs_packedarray #(
   parameter int                                                                                   UNITBITW  = 8, ///< 数组元素位宽
   parameter int                                                                                   ARRAYSIZ  = 3, ///< 数组元素个数
   parameter int                                                                                   MUXCOUNT  = 2, ///< 数组元素复用分块数
   parameter bit[array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)-1:0][UNITBITW-1:0] INITNOCS  = {(array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)){{(UNITBITW){1'b0}}}},
   parameter int                                                                                   DELAYTAPS = 0  ///< 多路复用器延迟输出拍数
) (clk, aclr, sclr, clken, array_in, part4nocs, ocs, mux_out);
   input  bit                                clk;        ///< 时钟信号
   input  wire                               aclr;       ///< 异步复位信号，高电平(1)有效
   input  wire                               sclr;       ///< 同步复位信号，高电平(1)有效
   input  wire                               clken;      ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire [ARRAYSIZ-1:0][UNITBITW-1:0]  array_in;   ///< 输入待分块复用的数组
   input  wire [MUXCOUNT-1:0]                ocs;        ///< 选通信号阵列。
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT);
   input  wire [cntPerPart-1:0][UNITBITW-1:0]part4nocs;  ///< 无待选通数据数组分块被选通时选择输出的数据数组分块
   output logic[cntPerPart-1:0][UNITBITW-1:0]mux_out;    ///< 复用输出的数组分块

   wire [cntPerPart-1:0][UNITBITW-1:0] part4mux[MUXCOUNT-1:0];
   genvar i; generate for (i = 0; i < MUXCOUNT; i++) begin: ARRAY4MUX
      if ((i+1)*cntPerPart > ARRAYSIZ) assign part4mux[i] = {part4nocs[cntPerPart-1:ARRAYSIZ-i*cntPerPart], array_in[ARRAYSIZ-1:i*cntPerPart]};
      else                             assign part4mux[i] = array_in[(i+1)*cntPerPart-1:i*cntPerPart];
   end endgenerate
   mux_bycs_packedarray #(
      .UNITBITW   (UNITBITW   ),
      .ARRAYSIZ   (cntPerPart ),
      .INITNOCS   (INITNOCS   ),
      .INPUTCNT   (MUXCOUNT   ),
      .DELAYTAPS  (DELAYTAPS  )
   ) muxcpa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .array_in   (part4mux   ),
      .array4nocs (part4nocs  ),
      .cs         (ocs        ),
      .array_out  (mux_out    )
   );
endmodule
module partmux_bycs_packedunit_packedarray #(
   parameter int                                                                                                  UNITBITW  = 8, ///< 数组数据位宽
   parameter int                                                                                                  AUNITSIZ  = 1, ///< 数组单元元素个数
   parameter int                                                                                                  ARRAYSIZ  = 3, ///< 数组单元个数
   parameter int                                                                                                  MUXCOUNT  = 2, ///< 数组元素复用分块数
   parameter bit[array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)*AUNITSIZ*UNITBITW){1'b0}},
   parameter int                                                                                                  DELAYTAPS = 0  ///< 延迟输出拍数
) (clk, aclr, sclr, clken, array_in, part4nocs, ocs, mux_out);
   input  bit                                               clk;        ///< 时钟信号
   input  wire                                              aclr;       ///< 异步复位信号，高电平(1)有效
   input  wire                                              sclr;       ///< 同步复位信号，高电平(1)有效
   input  wire                                              clken;      ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire [ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]   array_in;   ///< 输入待分块复用的数组
   input  wire [MUXCOUNT-1:0]                               ocs;        ///< 选通信号阵列。
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT);
   input  wire [cntPerPart-1:0][AUNITSIZ-1:0][UNITBITW-1:0] part4nocs;  ///< 无待选通数据数组分块被选通时选择输出的数据数组分块
   output logic[cntPerPart-1:0][AUNITSIZ-1:0][UNITBITW-1:0] mux_out;    ///< 复用输出的数组分块

   wire[ARRAYSIZ-1:0][UNITBITW*AUNITSIZ-1:0] ain;
   packedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) packin(
      .in   (array_in),
      .out  (ain     )
   );
   wire[cntPerPart-1:0][UNITBITW*AUNITSIZ-1:0]  nocs;
   packedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) packnocs(
      .in   (part4nocs  ),
      .out  (nocs       )
   );
   wire[cntPerPart-1:0][UNITBITW*AUNITSIZ-1:0]out;
   partmux_bycs_packedarray #(
      .UNITBITW   (UNITBITW*AUNITSIZ),
      .ARRAYSIZ   (ARRAYSIZ         ),
      .MUXCOUNT   (MUXCOUNT         ),
      .INITNOCS   (INITNOCS         ),
      .DELAYTAPS  (DELAYTAPS        )
   ) muxi(
      .clk        (clk  ),
      .aclr       (aclr ),
      .sclr       (sclr ),
      .clken      (clken),
      .array_in   (ain  ),
      .ocs        (ocs  ),
      .part4nocs  (nocs ),
      .mux_out    (out  )
   );
   packedarray_unit_split2packedunitarray #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) spltout(
      .in   (out     ),
      .out  (mux_out )
   );
endmodule
/*! \brief 基于选通信号选通的非合并数组分块多路复用器 */
module partmux_bycs_unpackedarray #(
   parameter int                                                                                   UNITBITW    = 8,  ///< 数组元素位宽
   parameter int                                                                                   ARRAYSIZ    = 3,  ///< 数组元素个数
   parameter int                                                                                   MUXCOUNT    = 2,  ///< 数组元素复用分块数
   parameter bit[array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)-1:0][UNITBITW-1:0] INITNOCS  = {(array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)){{(UNITBITW){1'b0}}}},
   parameter int                                                                                   DELAYTAPS   = 0   ///< 多路复用器延迟输出拍数
) (clk, aclr, sclr, clken, array_in, part4nocs, ocs, mux_out);
   input  bit                 clk;                       ///< 时钟信号
   input  wire                aclr;                      ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                      ///< 同步复位信号，高电平(1)有效
   input  wire                clken;                     ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire [UNITBITW-1:0] array_in[ARRAYSIZ-1:0];    ///< 输入待分块复用的数组
   input  wire [MUXCOUNT-1:0] ocs;                       ///< 选通信号阵列。
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT);
   input  wire [UNITBITW-1:0] part4nocs[cntPerPart-1:0]; ///< 无待选通数据数组分块被选通时选择输出的数据数组分块
   output logic[UNITBITW-1:0] mux_out[cntPerPart-1:0];   ///< 复用输出的数组分块

   wire [UNITBITW-1:0] part4mux[MUXCOUNT-1:0][cntPerPart-1:0];
   genvar i, j; generate for (i = 0; i < MUXCOUNT; i++) begin: ARRAY4MUX
      for (j = 0; j < cntPerPart; j++) begin: UNPACK_ASSIGN
         localparam int idx_array_in = i*cntPerPart + j;
         if (idx_array_in >= ARRAYSIZ) assign part4mux[i][j] = part4nocs[j];
         else                          assign part4mux[i][j] = array_in[idx_array_in];
      end
   end endgenerate
   mux_bycs_unpackedarray #(
      .UNITBITW   (UNITBITW   ),
      .ARRAYSIZ   (cntPerPart ),
      .INITNOCS   (INITNOCS   ),
      .INPUTCNT   (MUXCOUNT   ),
      .DELAYTAPS  (DELAYTAPS  )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .array_in   (part4mux   ),
      .array4nocs (part4nocs  ),
      .cs         (ocs        ),
      .array_out  (mux_out    )
   );
endmodule
module partmux_bycs_packedunit_unpackedarray #(
   parameter int                                                                                                  UNITBITW  = 8, ///< 数组数据位宽
   parameter int                                                                                                  AUNITSIZ  = 1, ///< 数组单元元素个数
   parameter int                                                                                                  ARRAYSIZ  = 3, ///< 数组单元个数
   parameter int                                                                                                  MUXCOUNT  = 2, ///< 数组元素复用分块数
   parameter bit[array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)*AUNITSIZ*UNITBITW){1'b0}},
   parameter int                                                                                                  DELAYTAPS = 0  ///< 延迟输出拍数
) (clk, aclr, sclr, clken, array_in, part4nocs, ocs, mux_out);
   input  bit                                clk;                       ///< 时钟信号
   input  wire                               aclr;                      ///< 异步复位信号，高电平(1)有效
   input  wire                               sclr;                      ///< 同步复位信号，高电平(1)有效
   input  wire                               clken;                     ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]  array_in[ARRAYSIZ-1:0];    ///< 输入待分块复用的数组
   input  wire [MUXCOUNT-1:0]                ocs;                       ///< 选通信号阵列。
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT);
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]  part4nocs[cntPerPart-1:0]; ///< 无待选通数据数组分块被选通时选择输出的数据数组分块
   output logic[AUNITSIZ-1:0][UNITBITW-1:0]  mux_out[cntPerPart-1:0];   ///< 复用输出的数组分块

   wire[UNITBITW*AUNITSIZ-1:0]ain[ARRAYSIZ-1:0];
   unpackedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) packin(
      .in   (array_in),
      .out  (ain     )
   );
   wire[UNITBITW*AUNITSIZ-1:0]nocs[cntPerPart-1:0];
   unpackedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) packnocs(
      .in   (part4nocs  ),
      .out  (nocs       )
   );
   wire[UNITBITW*AUNITSIZ-1:0]out[cntPerPart-1:0];
   partmux_bycs_unpackedarray #(
      .UNITBITW   (UNITBITW*AUNITSIZ),
      .ARRAYSIZ   (ARRAYSIZ         ),
      .MUXCOUNT   (MUXCOUNT         ),
      .INITNOCS   (INITNOCS         ),
      .DELAYTAPS  (DELAYTAPS        )
   ) muxi(
      .clk        (clk  ),
      .aclr       (aclr ),
      .sclr       (sclr ),
      .clken      (clken),
      .array_in   (ain  ),
      .ocs        (ocs  ),
      .part4nocs  (nocs ),
      .mux_out    (out  )
   );
   unpackedarray_unit_split2packedunitarray #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) spltout(
      .in   (out     ),
      .out  (mux_out )
   );
endmodule
module partmux_bycs_unpackedunit_unpackedarray #(
   parameter int                                                                                                  UNITBITW  = 8, ///< 数组数据位宽
   parameter int                                                                                                  AUNITSIZ  = 1, ///< 数组单元元素个数
   parameter int                                                                                                  ARRAYSIZ  = 3, ///< 数组单元个数
   parameter int                                                                                                  MUXCOUNT  = 2, ///< 数组元素复用分块数
   parameter bit[array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT)*AUNITSIZ*UNITBITW){1'b0}},
   parameter int                                                                                                  DELAYTAPS = 0  ///< 延迟输出拍数
) (clk, aclr, sclr, clken, array_in, part4nocs, ocs, mux_out);
   input  bit                 clk;                                      ///< 时钟信号
   input  wire                aclr;                                     ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                                     ///< 同步复位信号，高电平(1)有效
   input  wire                clken;                                    ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire [UNITBITW-1:0] array_in[ARRAYSIZ-1:0][AUNITSIZ-1:0];     ///< 输入待分块复用的数组
   localparam int bitwOfIdx = mux_pkg::idxbitw_ofmux(MUXCOUNT);
   input  wire [MUXCOUNT-1:0] ocs;                                      ///< 选通信号阵列。
   localparam int cntPerPart = array_partmux_pkg::cntPerPart_ofArrayParts(ARRAYSIZ, MUXCOUNT);
   input  wire [UNITBITW-1:0] part4nocs[cntPerPart-1:0][AUNITSIZ-1:0];  ///< 无待选通数据数组分块被选通时选择输出的数据数组分块
   output logic[UNITBITW-1:0] mux_out[cntPerPart-1:0][AUNITSIZ-1:0];    ///< 复用输出的数组分块

   wire[UNITBITW*AUNITSIZ-1:0]ain[ARRAYSIZ-1:0];
   unpackedarray_unpackedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) packin(
      .in   (array_in),
      .out  (ain     )
   );
   wire[UNITBITW*AUNITSIZ-1:0]nocs[cntPerPart-1:0];
   unpackedarray_unpackedunitarray_combine2unit #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) packnocs(
      .in   (part4nocs  ),
      .out  (nocs       )
   );
   wire[UNITBITW*AUNITSIZ-1:0]out[cntPerPart-1:0];
   partmux_bycs_unpackedarray #(
      .UNITBITW   (UNITBITW*AUNITSIZ),
      .ARRAYSIZ   (ARRAYSIZ         ),
      .MUXCOUNT   (MUXCOUNT         ),
      .INITNOCS   (INITNOCS         ),
      .DELAYTAPS  (DELAYTAPS        )
   ) muxi(
      .clk        (clk  ),
      .aclr       (aclr ),
      .sclr       (sclr ),
      .clken      (clken),
      .array_in   (ain  ),
      .ocs        (ocs  ),
      .part4nocs  (nocs ),
      .mux_out    (out  )
   );
   unpackedarray_unit_split2unpackedunitarray #(
      .UNITBITW(UNITBITW   ),
      .AUNITSIZ(AUNITSIZ   ),
      .ARRAYSIZ(cntPerPart )
   ) spltout(
      .in   (out     ),
      .out  (mux_out )
   );
endmodule
