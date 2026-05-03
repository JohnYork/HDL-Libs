/*!
 * \license SPDX-License-Identifier: MIT
 * \file mux.sv
 * \brief 多路复用选择器
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, packconv, pipedelay
 */
`include "miscs.svh"
`define __INC_FROM_MUX__
`include "mux.svh"
/*! \brief 多路复用选择器输入信号按索引位宽扩展 */
module muxinput_fit2idx #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int INPUTCNT = 5,                     ///< 待选通数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire [UNITBITW-1:0] data_in[INPUTCNT-1:0],  ///< 输入待选通数据阵列
   input  wire [UNITBITW-1:0] data4nocs,              ///< 无待选通数据阵列被选通时选择输出的数据
   output wire [UNITBITW-1:0] data_out[2**IDXBITW-1:0]///< 输出按索引位宽扩展后的待选通数据阵列
);
   initial if (INPUTCNT > 2**IDXBITW)
      $error("muxinput_fit2idx: parameter INPUTCNT(%0d) should not be greator than which can be hold(%0d) by index of IDXBITW(%0d) bits", INPUTCNT, 2**IDXBITW, IDXBITW);
   genvar i; generate for (i = 0; i < (2**IDXBITW); i += 1) begin: FILLINPUT
      if (i < INPUTCNT) assign data_out[i] = data_in[i];
      else              assign data_out[i] = data4nocs;
   end endgenerate
endmodule
module muxinput_fit2idx_packedarray #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int INPUTCNT = 5,                     ///< 待选通数组数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]array_in[INPUTCNT-1:0],    ///< 输入待选通数据数组阵列
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]array4nocs,                ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]array_out[2**IDXBITW-1:0]  ///< 输出按索引位宽扩展后的待选通数据数组阵列
);
   initial if (INPUTCNT > 2**IDXBITW)
      $error("muxinput_fit2idx_packedarray : parameter INPUTCNT(%0d) should not be greator than which can be hold(%0d) by index of IDXBITW(%0d) bits", INPUTCNT, 2**IDXBITW, IDXBITW);
   genvar i; generate for (i = 0; i < (2**IDXBITW); i++) begin: FILLINPUT
      if (i < INPUTCNT) assign array_out[i] = array_in[i];
      else              assign array_out[i] = array4nocs;
   end endgenerate
endmodule
/*! \brief 非合并数组数据多路复用选择器输入信号按索引位宽扩展 */
module muxinput_fit2idx_unpackedarray #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int INPUTCNT = 5,                     ///< 待选通数组数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire [UNITBITW-1:0] array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],  ///< 输入待选通数据数组阵列
   input  wire [UNITBITW-1:0] array4nocs[ARRAYSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   output wire [UNITBITW-1:0] array_out[2**IDXBITW-1:0][ARRAYSIZ-1:0]///< 输出按索引位宽扩展后的待选通数据数组阵列
);
   initial if (INPUTCNT > 2**IDXBITW)
      $error("muxinput_fit2idx_unpackedarray : parameter INPUTCNT(%0d) should not be greator than which can be hold(%0d) by index of IDXBITW(%0d) bits", INPUTCNT, 2**IDXBITW, IDXBITW);
   genvar i, j; generate for (i = 0; i < (2**IDXBITW); i++) begin: FILLINPUT
      for (j = 0; j < ARRAYSIZ; j++) begin: ARRAY
         if (i < INPUTCNT) assign array_out[i][j] = array_in[i][j];
         else              assign array_out[i][j] = array4nocs[j];
      end
   end endgenerate
endmodule
module muxinput_fit2idx_packedunit_packedarray #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素格式
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int INPUTCNT = 5,                     ///< 待选通数组数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]array_in[INPUTCNT-1:0],    ///< 输入待选通数据数组阵列
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]array4nocs,                ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]array_out[2**IDXBITW-1:0]  ///< 输出按索引位宽扩展后的待选通数据数组阵列
);
   initial if (INPUTCNT > 2**IDXBITW)
      $error("muxinput_fit2idx_packedarray : parameter INPUTCNT(%0d) should not be greator than which can be hold(%0d) by index of IDXBITW(%0d) bits", INPUTCNT, 2**IDXBITW, IDXBITW);
   genvar i; generate for (i = 0; i < (2**IDXBITW); i++) begin: FILLINPUT
      if (i < INPUTCNT) assign array_out[i] = array_in[i];
      else              assign array_out[i] = array4nocs;
   end endgenerate
endmodule
/*! \brief 非合并数组数据多路复用选择器输入信号按索引位宽扩展 */
module muxinput_fit2idx_packedunit_unpackedarray #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素格式
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int INPUTCNT = 5,                     ///< 待选通数组数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],  ///< 输入待选通数据数组阵列
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]array4nocs[ARRAYSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]array_out[2**IDXBITW-1:0][ARRAYSIZ-1:0]///< 输出按索引位宽扩展后的待选通数据数组阵列
);
   initial if (INPUTCNT > 2**IDXBITW)
      $error("muxinput_fit2idx_unpackedarray : parameter INPUTCNT(%0d) should not be greator than which can be hold(%0d) by index of IDXBITW(%0d) bits", INPUTCNT, 2**IDXBITW, IDXBITW);
   genvar i, j; generate for (i = 0; i < (2**IDXBITW); i++) begin: FILLINPUT
      for (j = 0; j < ARRAYSIZ; j++) begin: ARRAY
         if (i < INPUTCNT) assign array_out[i][j] = array_in[i][j];
         else              assign array_out[i][j] = array4nocs[j];
      end
   end endgenerate
endmodule
module muxinput_fit2idx_unpackedunit_unpackedarray #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素格式
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int INPUTCNT = 5,                     ///< 待选通数组数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire [UNITBITW-1:0] array_in[INPUTCNT-1:0][ARRAYSIZ-1:0][AUNITSIZ-1:0],  ///< 输入待选通数据数组阵列
   input  wire [UNITBITW-1:0] array4nocs[ARRAYSIZ-1:0][AUNITSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   output wire [UNITBITW-1:0] array_out[2**IDXBITW-1:0][ARRAYSIZ-1:0][AUNITSIZ-1:0]///< 输出按索引位宽扩展后的待选通数据数组阵列
);
   initial if (INPUTCNT > 2**IDXBITW)
      $error("muxinput_fit2idx_unpackedarray : parameter INPUTCNT(%0d) should not be greator than which can be hold(%0d) by index of IDXBITW(%0d) bits", INPUTCNT, 2**IDXBITW, IDXBITW);
   genvar i, j, k; generate for (i = 0; i < (2**IDXBITW); i++) begin: FILLINPUT
      for (j = 0; j < ARRAYSIZ; j++) begin: ARRAY
         for (k = 0; k < AUNITSIZ; k++) begin: AUNIT
            if (i < INPUTCNT) assign array_out[i][j][k] = array_in[i][j][k];
            else              assign array_out[i][j][k] = array4nocs[j][k];
         end
      end
   end endgenerate
endmodule
module muxinput_fit2idx_packedarray_extd #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 0,                     ///< 额外数据位宽
   parameter int INPUTCNT = 5,                     ///< 待选通数组数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]   array_in[INPUTCNT-1:0],    ///< 输入待选通数据数组阵列
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]   array4nocs,                ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]   array_out[2**IDXBITW-1:0], ///< 输出按索引位宽扩展后的待选通数据数组阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_in[INPUTCNT-1:0],     ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd4nocs,                 ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_out[2**IDXBITW-1:0]   ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   muxinput_fit2idx_packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (IDXBITW )
   ) mifi_pa(
      .array_in   (array_in   ),
      .array4nocs (array4nocs ),
      .array_out  (array_out  )
   );
   muxinput_fit2idx #(
      .UNITBITW(EXTDBITW),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (IDXBITW )
   ) mifi_ed(
      .data_in    (extd_in    ),
      .data4nocs  (extd4nocs  ),
      .data_out   (extd_out   )
   );
endmodule
module muxinput_fit2idx_unpackedarray_extd #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 0,                     ///< 额外数据位宽
   parameter int INPUTCNT = 5,                     ///< 待选通数组数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire [UNITBITW-1:0]                array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],     ///< 输入待选通数据数组阵列
   input  wire [UNITBITW-1:0]                array4nocs[ARRAYSIZ-1:0],                 ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   output wire [UNITBITW-1:0]                array_out[2**IDXBITW-1:0][ARRAYSIZ-1:0],  ///< 输出按索引位宽扩展后的待选通数据数组阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_in[INPUTCNT-1:0],                    ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd4nocs,                                ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_out[2**IDXBITW-1:0]                  ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   muxinput_fit2idx_unpackedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (IDXBITW )
   ) mifi_pa(
      .array_in   (array_in   ),
      .array4nocs (array4nocs ),
      .array_out  (array_out  )
   );
   muxinput_fit2idx #(
      .UNITBITW(EXTDBITW),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (IDXBITW )
   ) mifi_ed(
      .data_in    (extd_in    ),
      .data4nocs  (extd4nocs  ),
      .data_out   (extd_out   )
   );
endmodule
module muxinput_fit2idx_packedunit_packedarray_extd #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单位元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单位个数
   parameter int EXTDBITW = 0,                     ///< 额外数据位宽
   parameter int INPUTCNT = 5,                     ///< 待选通数组数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array_in[INPUTCNT-1:0],    ///< 输入待选通数据数组阵列
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array4nocs,                ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array_out[2**IDXBITW-1:0], ///< 输出按索引位宽扩展后的待选通数据数组阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]              extd_in[INPUTCNT-1:0],     ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]              extd4nocs,                 ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]              extd_out[2**IDXBITW-1:0]   ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   muxinput_fit2idx_packedunit_packedarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (IDXBITW )
   ) mifi_pa(
      .array_in   (array_in   ),
      .array4nocs (array4nocs ),
      .array_out  (array_out  )
   );
   muxinput_fit2idx #(
      .UNITBITW(EXTDBITW),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (IDXBITW )
   ) mifi_ed(
      .data_in    (extd_in    ),
      .data4nocs  (extd4nocs  ),
      .data_out   (extd_out   )
   );
endmodule
module muxinput_fit2idx_packedunit_unpackedarray_extd #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单位元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单位个数
   parameter int EXTDBITW = 0,                     ///< 额外数据位宽
   parameter int INPUTCNT = 5,                     ///< 待选通数组数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]  array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],     ///< 输入待选通数据数组阵列
   input  wire [AUNITSIZ-1:0][UNITBITW-1:0]  array4nocs[ARRAYSIZ-1:0],                 ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   output wire [AUNITSIZ-1:0][UNITBITW-1:0]  array_out[2**IDXBITW-1:0][ARRAYSIZ-1:0],  ///< 输出按索引位宽扩展后的待选通数据数组阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_in[INPUTCNT-1:0],                    ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd4nocs,                                ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_out[2**IDXBITW-1:0]                  ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   muxinput_fit2idx_packedunit_unpackedarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (IDXBITW )
   ) mifi_pa(
      .array_in   (array_in   ),
      .array4nocs (array4nocs ),
      .array_out  (array_out  )
   );
   muxinput_fit2idx #(
      .UNITBITW(EXTDBITW),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (IDXBITW )
   ) mifi_ed(
      .data_in    (extd_in    ),
      .data4nocs  (extd4nocs  ),
      .data_out   (extd_out   )
   );
endmodule
module muxinput_fit2idx_unpackedunit_unpackedarray_extd #(
   parameter int UNITBITW = 8,                     ///< 单位数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单位元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单位个数
   parameter int EXTDBITW = 0,                     ///< 额外数据位宽
   parameter int INPUTCNT = 5,                     ///< 待选通数组数据路数及选通信号阵列位宽
   parameter int IDXBITW  = 2                      ///< 选通用索引位宽
) (
   input  wire [UNITBITW-1:0]                array_in[INPUTCNT-1:0][ARRAYSIZ-1:0][AUNITSIZ-1:0],     ///< 输入待选通数据数组阵列
   input  wire [UNITBITW-1:0]                array4nocs[ARRAYSIZ-1:0][AUNITSIZ-1:0],                 ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   output wire [UNITBITW-1:0]                array_out[2**IDXBITW-1:0][ARRAYSIZ-1:0][AUNITSIZ-1:0],  ///< 输出按索引位宽扩展后的待选通数据数组阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_in[INPUTCNT-1:0],                    ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd4nocs,                                ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_out[2**IDXBITW-1:0]                  ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   muxinput_fit2idx_unpackedunit_unpackedarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (IDXBITW )
   ) mifi_pa(
      .array_in   (array_in   ),
      .array4nocs (array4nocs ),
      .array_out  (array_out  )
   );
   muxinput_fit2idx #(
      .UNITBITW(EXTDBITW),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (IDXBITW )
   ) mifi_ed(
      .data_in    (extd_in    ),
      .data4nocs  (extd4nocs  ),
      .data_out   (extd_out   )
   );
endmodule
/*! \brief 基于索引选通的基本数据多路复用选择器 */
module basic_mux_byidx #(
   parameter int              UNITBITW  = 8,       ///< 单位数据位宽
   parameter int              INPUTCNT  = 5,       ///< 待选通数据数组路数
   parameter bit[UNITBITW-1:0]INITNOCS  = {(UNITBITW){1'b0}},
   parameter int              DELAYTAPS = 0,       ///< 延迟输出拍数
   parameter bit              BALNCDLY  = 1'b0     ///< 在各级复选器间平均分配延迟拍数标志：
                                                   ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                   ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (clk, aclr, sclr,clken, data_in, data4nocs, idx, data_out);
   input  bit                 clk;                    ///< 驱动时钟
   input  wire                aclr;                   ///< 异步复位信号
   input  wire                sclr;                   ///< 同步复位信号
   input  wire                clken;                  ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[UNITBITW-1:0]  data_in[INPUTCNT-1:0];  ///< 待选通的数组阵列
   input  wire[UNITBITW-1:0]  data4nocs;              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   localparam int idxbitw = mux_pkg::idxbitw_ofmux(INPUTCNT);
   input  wire[idxbitw -1:0]  idx;                    ///< 输入数组阵列选通索引。
   output wire[UNITBITW-1:0]  data_out;               ///< 输出数据

   wire[UNITBITW-1:0]data2sel[2**idxbitw-1:0];
   muxinput_fit2idx #(
      .UNITBITW(UNITBITW),
      .INPUTCNT(INPUTCNT),
      .IDXBITW (idxbitw )
   ) input_fit2idx(
      .data_in    (data_in    ),
      .data4nocs  (data4nocs  ),
      .data_out   (data2sel   )
   );
   wire[2**idxbitw-1:0][UNITBITW-1:0]data4in;
   array_unpacked2packed #(
      .UNITBITW(UNITBITW   ),
      .ARRAYSIZ(2**idxbitw )
   ) data4in_genr(
      .in   (data2sel),
      .out  (data4in )
   );
   localparam int taps4stgs_recmd = mux_pkg::delaytaps4mux_recommend(.inputcnt(INPUTCNT));
   localparam int taps4stgs       = (taps4stgs_recmd < DELAYTAPS && BALNCDLY == 1'b0) ? taps4stgs_recmd : DELAYTAPS;
   genvar i,j; generate for (i = idxbitw-1; i >= 0; i--) begin: STAGE
      localparam int delaytaps_stage = miscs::delaytaps4stage(idxbitw, i, taps4stgs, 1'b0);
      logic[(2**(i+1))-1:0][UNITBITW-1:0] stage_in ;
      logic[(2**i)    -1:0][UNITBITW-1:0] stage_out;
      if (i == idxbitw - 1)assign stage_in = data4in;
      else                 assign stage_in = STAGE[i+1].stage_out;
      logic [i:0] idx_in;
      if (i > 0) begin: IDX2NS
         logic[i-1:0]idx_out;
         pipedelay_taps #(
            .DATABITW   (i                ),
            .DELAYTAPS  (delaytaps_stage  )
         ) pipe_idx(
            .clk     (clk           ),
            .aclr    (aclr          ),
            .sclr    (sclr          ),
            .clken   (clken         ),
            .x       (idx_in[i-1:0] ),
            .pipe_x  (idx_out       )
         );
      end: IDX2NS
      if (i == idxbitw - 1)assign idx_in = idx;
      else                 assign idx_in = STAGE[i+1].IDX2NS.idx_out;
      wire[(2**i)-1:0][UNITBITW-1:0]stage_2o, stgin_hi, stgin_lo;
      assign stgin_hi = stage_in[2**(i+1)-1:2**i];
      assign stgin_lo = stage_in[2**i-1:0];
      assign stage_2o = idx_in[i] ? stgin_hi : stgin_lo;
      pipedelay_taps_packedarray #(
         .DATABITW   (UNITBITW            ),
         .ARRAYSIZ   (2**i                ),
         .INITVAL    ({(2**i){INITNOCS}}  ),
         .DELAYTAPS  (delaytaps_stage     )
      ) pipe_stage_out(
         .clk     (clk        ),
         .aclr    (aclr       ),
         .sclr    (sclr       ),
         .clken   (clken      ),
         .x       (stage_2o   ),
         .pipe_x  (stage_out  )
      );
   end: STAGE
   shiftfixtaps #(
      .DATABITW   (UNITBITW            ),
      .TAP_DIST   (DELAYTAPS-taps4stgs ),
      .SCLR_ONRAM (1'b0                ),
      .IMPLBYLOGIC(1'b0                )
   ) pipe4out(
      .clk     (clk                    ),
      .aclr    (aclr                   ),
      .sclr    (sclr                   ),
      .clken   (clken                  ),
      .shiftin (STAGE[0].stage_out[0]  ),
      .shiftout(data_out               ),
      .reseting(                       )
   );
   endgenerate
endmodule
/*! \brief 基于索引选通的数据多路复用选择器 */
module mux_byidx #(
   parameter int              UNITBITW  = 8,       ///< 单位数据位宽
   parameter int              INPUTCNT  = 5,       ///< 待选通数据数组路数
   parameter bit[UNITBITW-1:0]INITNOCS  = {(UNITBITW){1'b0}},
   parameter int              DELAYTAPS = 0,       ///< 延迟输出拍数
   parameter bit              BALNCDLY  = 1'b0     ///< 在各级复选器间平均分配延迟拍数标志：
                                                   ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                   ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (clk, aclr, sclr,clken, data_in, data4nocs, idx, data_out);
   input  bit                 clk;                    ///< 驱动时钟
   input  wire                aclr;                   ///< 异步复位信号
   input  wire                sclr;                   ///< 同步复位信号
   input  wire                clken;                  ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[UNITBITW-1:0]  data_in[INPUTCNT-1:0];  ///< 待选通的数组阵列
   input  wire[UNITBITW-1:0]  data4nocs;              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   localparam int idxbitw = mux_pkg::idxbitw_ofmux(INPUTCNT);
   input  wire[idxbitw -1:0]  idx;                    ///< 输入数组阵列选通索引。
   output wire[UNITBITW-1:0]  data_out;               ///< 输出数据

   localparam int maxoutbits_ofbasicmux =
   `ifdef   MUX_MAXOUTBITS
      `MUX_MAXOUTBITS
   `else
      4096
   `endif
   ;
   localparam int mux_count = (UNITBITW + maxoutbits_ofbasicmux - 1)/maxoutbits_ofbasicmux;
   localparam int bitw_pmux = (UNITBITW + mux_count - 1)/mux_count;
   genvar imux, ii; generate for (imux = 0; imux < mux_count; imux++) begin: MUX_ARRAY
      localparam int ibtm = imux*bitw_pmux;
      localparam int itop = ((imux+1)*bitw_pmux > UNITBITW ? UNITBITW : (imux+1)*bitw_pmux) - 1;
      localparam int mux_bitw = itop - ibtm + 1;
      wire[mux_bitw-1:0]mux_in[INPUTCNT-1:0],mux_out, mux4nocs;
      for (ii = 0; ii < INPUTCNT; ii++) begin: SPLIT
         assign mux_in[ii] = data_in[ii][itop:ibtm];
      end
      assign mux4nocs = data4nocs[itop:ibtm];
      assign data_out[itop:ibtm] = mux_out;
      basic_mux_byidx #(
         .UNITBITW   (mux_bitw   ),
         .INPUTCNT   (INPUTCNT   ),
         .INITNOCS   (INITNOCS   ),
         .DELAYTAPS  (DELAYTAPS  ),
         .BALNCDLY   (BALNCDLY   )
      ) mxi(
         .clk        (clk     ),
         .aclr       (aclr    ),
         .sclr       (sclr    ),
         .clken      (clken   ),
         .data_in    (mux_in  ),
         .data4nocs  (mux4nocs),
         .idx        (idx     ),
         .data_out   (mux_out )
      );
   end endgenerate
endmodule
module mux_byidx_packedarray #(
   parameter int                             UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                             ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                             INPUTCNT  = 5,    ///< 待选通数据数组路数
   parameter bit[ARRAYSIZ-1:0][UNITBITW-1:0] INITNOCS  = {(ARRAYSIZ){{(UNITBITW){1'b0}}}},
   parameter int                             DELAYTAPS = 0,    ///< 延迟输出拍数
   parameter bit                             BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                               ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                               ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                         clk,                    ///< 驱动时钟
   input  wire                                        aclr,                   ///< 异步复位信号
   input  wire                                        sclr,                   ///< 同步复位信号
   input  wire                                        clken,                  ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]            array_in[INPUTCNT-1:0], ///< 待选通的数组阵列
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]            array4nocs,             ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[mux_pkg::idxbitw_ofmux(INPUTCNT) -1:0] idx,                    ///< 输入数组阵列选通索引。
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]            array_out               ///< 输出数据
);
   wire[UNITBITW*ARRAYSIZ-1:0]data_in[INPUTCNT-1:0], data4nocs, data_out;
   packedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acui(
      .in   (array4nocs ),
      .out  (data4nocs  )
   );
   unpackedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(ARRAYSIZ),
      .ARRAYSIZ(INPUTCNT)
   ) acuii(
      .in   (array_in),
      .out  (data_in)
   );
   mux_byidx #(
      .UNITBITW   (UNITBITW*ARRAYSIZ),
      .INPUTCNT   (INPUTCNT         ),
      .INITNOCS   (INITNOCS         ),
      .DELAYTAPS  (DELAYTAPS        ),
      .BALNCDLY   (BALNCDLY         )
   ) muxi(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (data_in    ),
      .data4nocs  (data4nocs  ),
      .idx        (idx        ),
      .data_out   (data_out   )
   );
   unit_split2packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) usai(
      .in   (data_out   ),
      .out  (array_out  )
   );
endmodule
module mux_byidx_unpackedarray #(
   parameter int                             UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                             ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                             INPUTCNT  = 5,    ///< 待选通数据数组路数
   parameter bit[ARRAYSIZ-1:0][UNITBITW-1:0] INITNOCS  = {(ARRAYSIZ){{(UNITBITW){1'b0}}}},
   parameter int                             DELAYTAPS = 0,    ///< 延迟输出拍数
   parameter bit                             BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                               ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                               ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                         clk,                                   ///< 驱动时钟
   input  wire                                        aclr,                                  ///< 异步复位信号
   input  wire                                        sclr,                                  ///< 同步复位信号
   input  wire                                        clken,                                 ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[UNITBITW-1:0]                          array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],  ///< 待选通的数组阵列
   input  wire[UNITBITW-1:0]                          array4nocs[ARRAYSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[mux_pkg::idxbitw_ofmux(INPUTCNT) -1:0] idx,                                   ///< 输入数组阵列选通索引。
   output wire[UNITBITW-1:0]                          array_out[ARRAYSIZ-1:0]                ///< 输出数据
);
   wire[ARRAYSIZ-1:0][UNITBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   unpackedarrayunit_unpacked2packed #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(ARRAYSIZ),
      .ARRAYSIZ(INPUTCNT)
   ) aup2p(
      .in   (array_in   ),
      .out  (parray_in  )
   );
   array_unpacked2packed #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) nocsup2p(
      .in   (array4nocs ),
      .out  (parray4nocs)
   );
   mux_byidx_packedarray #(
      .UNITBITW   (UNITBITW   ),
      .ARRAYSIZ   (ARRAYSIZ   ),
      .INPUTCNT   (INPUTCNT   ),
      .INITNOCS   (INITNOCS   ),
      .DELAYTAPS  (DELAYTAPS  ),
      .BALNCDLY   (BALNCDLY   )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .array_in   (parray_in  ),
      .array4nocs (parray4nocs),
      .idx        (idx        ),
      .array_out  (parray_out )
   );
   array_packed2unpacked #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) op2up(
      .in   (parray_out ),
      .out  (array_out  )
   );
endmodule
module mux_byidx_packedunit_packedarray #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组单位个数
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据数组路数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter int                                            DELAYTAPS = 0,    ///< 延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                               ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                               ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                            clk,                    ///< 驱动时钟
   input  wire                                           aclr,                   ///< 异步复位信号
   input  wire                                           sclr,                   ///< 同步复位信号
   input  wire                                           clken,                  ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array_in[INPUTCNT-1:0], ///< 待选通的数组阵列
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array4nocs,             ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[mux_pkg::idxbitw_ofmux(INPUTCNT) -1:0]    idx,                    ///< 输入数组阵列选通索引。
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array_out               ///< 输出数据
);
   wire[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]data_in[INPUTCNT-1:0], data4nocs, data_out;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) acui(
      .in   (array4nocs ),
      .out  (data4nocs  )
   );
   genvar i; generate for (i = 0; i < INPUTCNT; i++) begin
      packedarray_packedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) acuii(
         .in   (array_in[i]),
         .out  (data_in[i] )
      );
   end endgenerate
   mux_byidx #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .INPUTCNT   (INPUTCNT                  ),
      .INITNOCS   (INITNOCS                  ),
      .DELAYTAPS  (DELAYTAPS                 ),
      .BALNCDLY   (BALNCDLY                  )
   ) muxi(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (data_in    ),
      .data4nocs  (data4nocs  ),
      .idx        (idx        ),
      .data_out   (data_out   )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) usai(
      .in   (data_out   ),
      .out  (array_out  )
   );
endmodule
module mux_byidx_packedunit_unpackedarray #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组单位个数
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据数组路数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter int                                            DELAYTAPS = 0,    ///< 延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                                              ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                              ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                         clk,                                   ///< 驱动时钟
   input  wire                                        aclr,                                  ///< 异步复位信号
   input  wire                                        sclr,                                  ///< 同步复位信号
   input  wire                                        clken,                                 ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]            array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],  ///< 待选通的数组阵列
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]            array4nocs[ARRAYSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[mux_pkg::idxbitw_ofmux(INPUTCNT) -1:0] idx,                                   ///< 输入数组阵列选通索引。
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]            array_out[ARRAYSIZ-1:0]                ///< 输出数据
);
   wire[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   genvar i; generate
   for (i = 0; i < INPUTCNT; i++) begin
      unpackedarray_packedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) aup2p(
         .in   (array_in[i]   ),
         .out  (parray_in[i]  )
      );
   end
   endgenerate
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ncsup2p(
      .in   (array4nocs ),
      .out  (parray4nocs)
   );
   mux_byidx #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .INPUTCNT   (INPUTCNT                  ),
      .INITNOCS   (INITNOCS                  ),
      .DELAYTAPS  (DELAYTAPS                 ),
      .BALNCDLY   (BALNCDLY                  )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (parray_in  ),
      .data4nocs  (parray4nocs),
      .idx        (idx        ),
      .data_out   (parray_out )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ap2up(
      .in   (parray_out ),
      .out  (array_out  )
   );
endmodule
module mux_byidx_unpackedunit_unpackedarray #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组单位个数
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据数组路数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter int                                            DELAYTAPS = 0,    ///< 延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                                              ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                              ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                         clk,                                               ///< 驱动时钟
   input  wire                                        aclr,                                              ///< 异步复位信号
   input  wire                                        sclr,                                              ///< 同步复位信号
   input  wire                                        clken,                                             ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[UNITBITW-1:0]                          array_in[INPUTCNT-1:0][ARRAYSIZ-1:0][AUNITSIZ-1:0],///< 待选通的数组阵列
   input  wire[UNITBITW-1:0]                          array4nocs[ARRAYSIZ-1:0][AUNITSIZ-1:0],            ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[mux_pkg::idxbitw_ofmux(INPUTCNT) -1:0] idx,                                               ///< 输入数组阵列选通索引。
   output wire[UNITBITW-1:0]                          array_out[ARRAYSIZ-1:0][AUNITSIZ-1:0]              ///< 输出数据
);
   wire[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   genvar i; generate
   for (i = 0; i < INPUTCNT; i++) begin
      unpackedarray_unpackedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) aup2p(
         .in   (array_in[i]   ),
         .out  (parray_in[i]  )
      );
   end
   endgenerate
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ncsup2p(
      .in   (array4nocs ),
      .out  (parray4nocs)
   );
   mux_byidx #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .INPUTCNT   (INPUTCNT                  ),
      .INITNOCS   (INITNOCS                  ),
      .DELAYTAPS  (DELAYTAPS                 ),
      .BALNCDLY   (BALNCDLY                  )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (parray_in  ),
      .data4nocs  (parray4nocs),
      .idx        (idx        ),
      .data_out   (parray_out )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ap2up(
      .in(parray_out),
      .out(array_out)
   );
endmodule
module mux_byidx_packedarray_extd #(
   parameter int                             UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                             ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                             EXTDBITW  = 0,    ///< 额外数据位宽
   parameter int                             INPUTCNT  = 5,    ///< 待选通数据数组路数
   parameter bit[ARRAYSIZ-1:0][UNITBITW-1:0] AINITNOCS = {(ARRAYSIZ){{(UNITBITW){1'b0}}}},
   parameter bit[(EXTDBITW>0?EXTDBITW:1)-1:0]EINITNOCS = {(EXTDBITW>0?EXTDBITW:1){1'b0}},
   parameter int                             DELAYTAPS = 0,    ///< 延迟输出拍数
   parameter bit                             BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                               ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                               ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                         clk,                    ///< 驱动时钟
   input  wire                                        aclr,                   ///< 异步复位信号
   input  wire                                        sclr,                   ///< 同步复位信号
   input  wire                                        clken,                  ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]            array_in[INPUTCNT-1:0], ///< 待选通的数组阵列
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]            array4nocs,             ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd_in[INPUTCNT-1:0],  ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd4nocs,              ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   input  wire[mux_pkg::idxbitw_ofmux(INPUTCNT) -1:0] idx,                    ///< 输入数组阵列选通索引。
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]            array_out,              ///< 输出数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd_out                ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   generate
   wire[UNITBITW*ARRAYSIZ+EXTDBITW-1:0]data_in[INPUTCNT-1:0], data4nocs, data_out;
   packedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acui(
      .in   (array4nocs                      ),
      .out  (data4nocs[UNITBITW*ARRAYSIZ-1:0])
   );
   if (EXTDBITW > 0) assign data4nocs[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ] = extd4nocs;
   unpackedarray_packedunitarray_extd_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ARRAYSIZ(INPUTCNT)
   ) acuii(
      .in   (array_in),
      .ex   (extd_in ),
      .out  (data_in )
   );
   mux_byidx #(
      .UNITBITW   (UNITBITW*ARRAYSIZ+EXTDBITW),
      .INPUTCNT   (INPUTCNT                  ),
      .INITNOCS   ({EINITNOCS, AINITNOCS}    ),
      .DELAYTAPS  (DELAYTAPS                 ),
      .BALNCDLY   (BALNCDLY                  )
   ) muxi(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (data_in    ),
      .data4nocs  (data4nocs  ),
      .idx        (idx        ),
      .data_out   (data_out   )
   );
   unit_split2packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) usai(
      .in   (data_out[UNITBITW*ARRAYSIZ-1:0] ),
      .out  (array_out                       )
   );
   if (EXTDBITW > 0) assign extd_out = data_out[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ];
   else              assign extd_out = 1'b0;
   endgenerate
endmodule
module mux_byidx_unpackedarray_extd #(
   parameter int                             UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                             ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                             EXTDBITW  = 0,    ///< 额外数据位宽
   parameter int                             INPUTCNT  = 5,    ///< 待选通数据数组路数
   parameter bit[ARRAYSIZ-1:0][UNITBITW-1:0] AINITNOCS = {(ARRAYSIZ){{(UNITBITW){1'b0}}}},
   parameter bit[(EXTDBITW>0?EXTDBITW:1)-1:0]EINITNOCS = {(EXTDBITW>0?EXTDBITW:1){1'b0}},
   parameter int                             DELAYTAPS = 0,    ///< 延迟输出拍数
   parameter bit                             BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                               ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                               ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                         clk,                                   ///< 驱动时钟
   input  wire                                        aclr,                                  ///< 异步复位信号
   input  wire                                        sclr,                                  ///< 同步复位信号
   input  wire                                        clken,                                 ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[UNITBITW-1:0]                          array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],  ///< 待选通的数组阵列
   input  wire[UNITBITW-1:0]                          array4nocs[ARRAYSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd_in[INPUTCNT-1:0],                 ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd4nocs,                             ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   input  wire[mux_pkg::idxbitw_ofmux(INPUTCNT) -1:0] idx,                                   ///< 输入数组阵列选通索引。
   output wire[UNITBITW-1:0]                          array_out[ARRAYSIZ-1:0],               ///< 输出数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd_out                               ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   generate
   wire[ARRAYSIZ-1:0][UNITBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   unpackedarrayunit_unpacked2packed #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(ARRAYSIZ),
      .ARRAYSIZ(INPUTCNT)
   ) aup2p(
      .in   (array_in   ),
      .out  (parray_in  )
   );
   array_unpacked2packed #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) nocsup2p(
      .in   (array4nocs ),
      .out  (parray4nocs)
   );
   mux_byidx_packedarray_extd #(
      .UNITBITW   (UNITBITW   ),
      .ARRAYSIZ   (ARRAYSIZ   ),
      .EXTDBITW   (EXTDBITW   ),
      .INPUTCNT   (INPUTCNT   ),
      .AINITNOCS  (AINITNOCS  ),
      .EINITNOCS  (EINITNOCS  ),
      .DELAYTAPS  (DELAYTAPS  ),
      .BALNCDLY   (BALNCDLY   )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .array_in   (parray_in  ),
      .array4nocs (parray4nocs),
      .extd_in    (extd_in    ),
      .extd4nocs  (extd4nocs  ),
      .idx        (idx        ),
      .array_out  (parray_out ),
      .extd_out   (extd_out   )
   );
   array_packed2unpacked #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) op2up(
      .in   (parray_out ),
      .out  (array_out  )
   );
   endgenerate
endmodule
module mux_byidx_packedunit_packedarray_extd #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组单位个数
   parameter int                                            EXTDBITW  = 0,    ///< 额外数据位宽
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据数组路数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  AINITNOCS = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter bit[(EXTDBITW>0?EXTDBITW:1)-1:0]               EINITNOCS = {(EXTDBITW>0?EXTDBITW:1){1'b0}},
   parameter int                                            DELAYTAPS = 0,    ///< 延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                               ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                               ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                            clk,                    ///< 驱动时钟
   input  wire                                           aclr,                   ///< 异步复位信号
   input  wire                                           sclr,                   ///< 同步复位信号
   input  wire                                           clken,                  ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array_in[INPUTCNT-1:0], ///< 待选通的数组阵列
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array4nocs,             ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]              extd_in[INPUTCNT-1:0],  ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]              extd4nocs,              ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   input  wire[mux_pkg::idxbitw_ofmux(INPUTCNT) -1:0]    idx,                    ///< 输入数组阵列选通索引。
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array_out,              ///< 输出数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]              extd_out                ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   genvar i; generate 
   wire[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:0]data_in[INPUTCNT-1:0], data4nocs, data_out;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) acui(
      .in   (array4nocs                               ),
      .out  (data4nocs[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   if (EXTDBITW > 0) assign data4nocs[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ] = extd4nocs;
   for (i = 0; i < INPUTCNT; i++) begin
      packedarray_packedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) acuii(
         .in   (array_in[i]                                 ),
         .out  (data_in[i][UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]  )
      );
      if (EXTDBITW > 0) assign data_in[i][UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ] = extd_in[i];
   end
   mux_byidx #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .INPUTCNT   (INPUTCNT                           ),
      .INITNOCS   ({EINITNOCS, AINITNOCS}             ),
      .DELAYTAPS  (DELAYTAPS                          ),
      .BALNCDLY   (BALNCDLY                           )
   ) muxi(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (data_in    ),
      .data4nocs  (data4nocs  ),
      .idx        (idx        ),
      .data_out   (data_out   )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) usai(
      .in   (data_out[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0] ),
      .out  (array_out                                )
   );
   if (EXTDBITW > 0) assign extd_out = data_out[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
   else              assign extd_out = 1'b0;
   endgenerate
endmodule
module mux_byidx_packedunit_unpackedarray_extd #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组单位个数
   parameter int                                            EXTDBITW  = 0,    ///< 额外数据位宽
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据数组路数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  AINITNOCS = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter bit[(EXTDBITW>0?EXTDBITW:1)-1:0]               EINITNOCS = {(EXTDBITW>0?EXTDBITW:1){1'b0}},
   parameter int                                            DELAYTAPS = 0,    ///< 延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                                              ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                              ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                         clk,                                   ///< 驱动时钟
   input  wire                                        aclr,                                  ///< 异步复位信号
   input  wire                                        sclr,                                  ///< 同步复位信号
   input  wire                                        clken,                                 ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]            array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],  ///< 待选通的数组阵列
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]            array4nocs[ARRAYSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd_in[INPUTCNT-1:0],                 ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd4nocs,                             ///< 无待选通额外数据阵列被选通时选择输出的额外数据

   input  wire[mux_pkg::idxbitw_ofmux(INPUTCNT) -1:0] idx,                                   ///< 输入数组阵列选通索引。
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]            array_out[ARRAYSIZ-1:0],               ///< 输出数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd_out                               ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   genvar i; generate
   wire[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   for (i = 0; i < INPUTCNT; i++) begin
      unpackedarray_packedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) aup2p(
         .in   (array_in[i]                                 ),
         .out  (parray_in[i][ARRAYSIZ*AUNITSIZ*UNITBITW-1:0])
      );
      if (EXTDBITW > 0) assign parray_in[i][ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW] = extd_in[i];
   end
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ncsup2p(
      .in   (array4nocs                                  ),
      .out  (parray4nocs[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0] )
   );
   if (EXTDBITW > 0) assign parray4nocs[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW] = extd4nocs;
   mux_byidx #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .INPUTCNT   (INPUTCNT                           ),
      .INITNOCS   ({EINITNOCS, AINITNOCS}             ),
      .DELAYTAPS  (DELAYTAPS                          ),
      .BALNCDLY   (BALNCDLY                           )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (parray_in  ),
      .data4nocs  (parray4nocs),
      .idx        (idx        ),
      .data_out   (parray_out )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ap2up(
      .in   (parray_out[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]  ),
      .out  (array_out                                   )
   );
   if (EXTDBITW > 0) assign extd_out = parray_out[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW];
   else              assign extd_out = 1'b0;
   endgenerate
endmodule
module mux_byidx_unpackedunit_unpackedarray_extd #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组单位个数
   parameter int                                            EXTDBITW  = 0,    ///< 额外数据位宽
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据数组路数
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  AINITNOCS = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter bit[(EXTDBITW>0?EXTDBITW:1)-1:0]               EINITNOCS = {(EXTDBITW>0?EXTDBITW:1){1'b0}},
   parameter int                                            DELAYTAPS = 0,    ///< 延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                                              ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                              ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                         clk,                                               ///< 驱动时钟
   input  wire                                        aclr,                                              ///< 异步复位信号
   input  wire                                        sclr,                                              ///< 同步复位信号
   input  wire                                        clken,                                             ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[UNITBITW-1:0]                          array_in[INPUTCNT-1:0][ARRAYSIZ-1:0][AUNITSIZ-1:0],///< 待选通的数组阵列
   input  wire[UNITBITW-1:0]                          array4nocs[ARRAYSIZ-1:0][AUNITSIZ-1:0],            ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd_in[INPUTCNT-1:0],                             ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd4nocs,                                         ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   input  wire[mux_pkg::idxbitw_ofmux(INPUTCNT) -1:0] idx,                                               ///< 输入数组阵列选通索引。
   output wire[UNITBITW-1:0]                          array_out[ARRAYSIZ-1:0][AUNITSIZ-1:0],             ///< 输出数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]           extd_out                                           ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   wire[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   genvar i; generate
   for (i = 0; i < INPUTCNT; i++) begin
      unpackedarray_unpackedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) aup2p(
         .in   (array_in[i]                                 ),
         .out  (parray_in[i][ARRAYSIZ*AUNITSIZ*UNITBITW-1:0])
      );
      if (EXTDBITW > 0) assign parray_in[i][ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW] = extd_in[i];
   end
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ncsup2p(
      .in   (array4nocs                                  ),
      .out  (parray4nocs[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0] )
   );
   if (EXTDBITW > 0) assign parray4nocs[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW] = extd4nocs;
   mux_byidx #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .INPUTCNT   (INPUTCNT                           ),
      .INITNOCS   ({EINITNOCS, AINITNOCS}             ),
      .DELAYTAPS  (DELAYTAPS                          ),
      .BALNCDLY   (BALNCDLY                           )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (parray_in  ),
      .data4nocs  (parray4nocs),
      .idx        (idx        ),
      .data_out   (parray_out )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ap2up(
      .in   (parray_out[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]  ),
      .out  (array_out                                   )
   );
   if (EXTDBITW > 0) assign extd_out = parray_out[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW];
   else              assign extd_out = 1'b0;
   endgenerate
endmodule
/*! \brief 基于选通信号选通的多路复用选择器 */
module mux_bycs #(
   parameter int              UNITBITW  = 8,       ///< 单位数据位宽
   parameter int              INPUTCNT  = 5,       ///< 待选通数据路数及选通信号阵列位宽
   parameter bit[UNITBITW-1:0]INITNOCS  = {(UNITBITW){1'b0}},
   parameter int              DELAYTAPS = 0,       ///< 多路复用选择器延迟输出拍数
   parameter bit              BALNCDLY  = 1'b0     ///< 在各级复选器间平均分配延迟拍数标志：
                                                   ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                   ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                 clk,
   input  wire                aclr,
   input  wire                sclr,
   input  wire                clken,
   input  wire [UNITBITW-1:0] data_in[INPUTCNT-1:0],
   input  wire [UNITBITW-1:0] data4nocs,
   input  wire [INPUTCNT-1:0] cs,
   output logic[UNITBITW-1:0] data_out
);
   wire[INPUTCNT-1:0][UNITBITW-1:0] din;
   array_unpacked2packed #(
      .UNITBITW(UNITBITW), .ARRAYSIZ(INPUTCNT)
   ) datain_pack(
      .in(data_in),  .out(din)
   );
   localparam int taps4stgs_recmd = mux_pkg::delaytaps4mux_recommend(.inputcnt(INPUTCNT));
   localparam int taps4stgs       = (taps4stgs_recmd < DELAYTAPS && BALNCDLY == 1'b0) ? taps4stgs_recmd : DELAYTAPS;
   localparam int stgcnt = mux_pkg::idxbitw_ofmux(INPUTCNT);
   genvar i, j; generate
      for (i = stgcnt-1; i >= 0; i--) begin: STAGE
         localparam int delaytaps_stage = miscs::delaytaps4stage(stgcnt, i, taps4stgs, 1'b0);
         localparam int ocnt = (INPUTCNT + 2**(stgcnt-i) - 1)/(2**(stgcnt-i));
         localparam int icnt = (i == stgcnt-1) ? INPUTCNT : (INPUTCNT + 2**(stgcnt-i-1) - 1)/(2**(stgcnt-i-1));
         logic          [UNITBITW-1:0] nocs_in;
         logic[icnt-1:0][UNITBITW-1:0] stage_in;
         logic[ocnt-1:0][UNITBITW-1:0] stage_2o, stage_out;
         logic[icnt-1:0]               stgcs_in;
         if (i == stgcnt - 1) assign stage_in = din,
                                     stgcs_in = cs,
                                     nocs_in  = data4nocs;
         else                 assign stage_in = STAGE[i+1].stage_out,
                                     stgcs_in = STAGE[i+1].CS2NS.stgcs_out,
                                     nocs_in  = STAGE[i+1].CS2NS.nocs_out;
         if (i > 0) begin: CS2NS
            logic[ocnt    -1:0]stgcs_2o, stgcs_out;
            logic[UNITBITW-1:0]nocs_out;
            pipedelay_taps #(
               .DATABITW   (UNITBITW + ocnt           ),
               .INITVAL    ({INITNOCS, {(ocnt){1'b0}}}),
               .DELAYTAPS  (delaytaps_stage           )
            ) pipe_cs(
               .clk     (clk                 ),
               .aclr    (aclr                ),
               .sclr    (sclr                ),
               .clken   (clken               ),
               .x       ({nocs_in, stgcs_2o} ),
               .pipe_x  ({nocs_out,stgcs_out})
            );
         end
         for (j = 0; j < ocnt; j++) begin: STGELEM
            if((j+1)*2 > icnt)assign stage_2o[j] = stgcs_in[j*2]
                                                   ? stage_in[j*2]
                                                   : nocs_in;
            else if (ocnt > 1)assign stage_2o[j] = stgcs_in[j*2]
                                                   ? stage_in[j*2]
                                                   : stage_in[j*2+1];
            else              assign stage_2o[j] = stgcs_in[j*2]
                                                   ? stage_in[j*2]
                                                   : (stgcs_in[j*2+1]
                                                      ? stage_in[j*2+1]
                                                      : nocs_in);
            if (i > 0) begin
               if((j+1)*2 > icnt)assign CS2NS.stgcs_2o[j] = stgcs_in[j*2];
               else              assign CS2NS.stgcs_2o[j] = |stgcs_in[j*2+1:j*2+0];
            end
         end
         pipedelay_taps_packedarray #(
            .DATABITW   (UNITBITW            ),
            .ARRAYSIZ   (ocnt                ),
            .INITVAL    ({(ocnt){INITNOCS}}  ),
            .DELAYTAPS  (delaytaps_stage     )
         ) pipe_stage_out(
            .clk     (clk        ),
            .aclr    (aclr       ),
            .sclr    (sclr       ),
            .clken   (clken      ),
            .x       (stage_2o   ),
            .pipe_x  (stage_out  )
         );
      end
      shiftfixtaps #(
         .DATABITW   (UNITBITW            ),
         .TAP_DIST   (DELAYTAPS-taps4stgs ),
         .SCLR_ONRAM (1'b0                ),
         .IMPLBYLOGIC(1'b0                )
      ) pipe4out(
         .clk     (clk                    ),
         .aclr    (aclr                   ),
         .sclr    (sclr                   ),
         .clken   (clken                  ),
         .shiftin (STAGE[0].stage_out[0]  ),
         .shiftout(data_out               ),
         .reseting(                       )
      );
   endgenerate
endmodule
module mux_bycs_packedarray #(
   parameter int                             UNITBITW  = 8,       ///< 单位数据位宽
   parameter int                             ARRAYSIZ  = 2,       ///< 数组元素个数
   parameter bit[ARRAYSIZ-1:0][UNITBITW-1:0] INITNOCS  = {(ARRAYSIZ){{(UNITBITW){1'b0}}}},
   parameter int                             INPUTCNT  = 5,       ///< 待选通数据路数及选通信号阵列位宽
   parameter int                             DELAYTAPS = 0,       ///< 多路复用选择器延迟输出拍数
   parameter bit                             BALNCDLY  = 1'b0     ///< 在各级复选器间平均分配延迟拍数标志：
                                                                  ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                  ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                             clk,                    ///< 驱动时钟
   input  wire                            aclr,                   ///< 异步复位信号
   input  wire                            sclr,                   ///< 同步复位信号
   input  wire                            clken,                  ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]array_in[INPUTCNT-1:0], ///< 待选通的数组阵列
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]array4nocs,             ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[INPUTCNT-1:0]              cs,                     ///< 选通信号阵列。
                                                                  ///< \attention 当例化参数 #CS2IDX_DELAYOUT 为 1'b1 时， #cs 信号应比 #data_in 、 #data4_nocs 信号提前一拍置位
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]array_out               ///< 输出数据
);
   wire[UNITBITW*ARRAYSIZ-1:0]data_in[INPUTCNT-1:0], data4nocs, data_out;
   packedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acui(
      .in(array4nocs),
      .out(data4nocs)
   );
   unpackedarray_packedunitarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(ARRAYSIZ),
      .ARRAYSIZ(INPUTCNT)
   ) acuii(
      .in   (array_in),
      .out  (data_in)
   );
   mux_bycs #(
      .UNITBITW   (UNITBITW*ARRAYSIZ),
      .INITNOCS   (INITNOCS         ),
      .INPUTCNT   (INPUTCNT         ),
      .DELAYTAPS  (DELAYTAPS        ),
      .BALNCDLY   (BALNCDLY         )
   ) muxi(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (data_in    ),
      .data4nocs  (data4nocs  ),
      .cs         (cs         ),
      .data_out   (data_out   )
   );
   unit_split2packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) usai(
      .in   (data_out   ),
      .out  (array_out  )
   );
endmodule
module mux_bycs_unpackedarray #(
   parameter int                             UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                             ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter bit[ARRAYSIZ-1:0][UNITBITW-1:0] INITNOCS  = {(ARRAYSIZ){{(UNITBITW){1'b0}}}},
   parameter int                             INPUTCNT  = 5,    ///< 待选通数据路数及选通信号阵列位宽
   parameter int                             DELAYTAPS = 0,    ///< 多路复用选择器延迟输出拍数
   parameter bit                             BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                               ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                               ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                 clk,                                   ///< 驱动时钟
   input  wire                aclr,                                  ///< 异步复位信号
   input  wire                sclr,                                  ///< 同步复位信号
   input  wire                clken,                                 ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[UNITBITW-1:0]  array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],  ///< 待选通的数组阵列
   input  wire[UNITBITW-1:0]  array4nocs[ARRAYSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[INPUTCNT-1:0]  cs,                                    ///< 选通信号阵列。
                                                                     ///< \attention 当例化参数 #CS2IDX_DELAYOUT 为 1'b1 时， #cs 信号应比 #data_in 、 #data4_nocs 信号提前一拍置位
   output wire[UNITBITW-1:0]  array_out[ARRAYSIZ-1:0]                ///< 输出数据
);
   wire[ARRAYSIZ-1:0][UNITBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   unpackedarrayunit_unpacked2packed #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(ARRAYSIZ),
      .ARRAYSIZ(INPUTCNT)
   ) aup2p(
      .in   (array_in   ),
      .out  (parray_in  )
   );
   array_unpacked2packed #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) nocsup2p(
      .in   (array4nocs ),
      .out  (parray4nocs)
   );
   mux_bycs_packedarray #(
      .UNITBITW   (UNITBITW   ),
      .ARRAYSIZ   (ARRAYSIZ   ),
      .INITNOCS   (INITNOCS   ),
      .INPUTCNT   (INPUTCNT   ),
      .DELAYTAPS  (DELAYTAPS  ),
      .BALNCDLY   (BALNCDLY   )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .array_in   (parray_in  ),
      .array4nocs (parray4nocs),
      .cs         (cs         ),
      .array_out  (parray_out )
   );
   array_packed2unpacked #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) op2up(
      .in   (parray_out ),
      .out  (array_out  )
   );
endmodule
module mux_bycs_packedunit_packedarray #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据路数及选通信号阵列位宽
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter int                                            DELAYTAPS = 0,    ///< 多路复用选择器延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                                              ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                              ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                            clk,                    ///< 驱动时钟
   input  wire                                           aclr,                   ///< 异步复位信号
   input  wire                                           sclr,                   ///< 同步复位信号
   input  wire                                           clken,                  ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array_in[INPUTCNT-1:0], ///< 待选通的数组阵列
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array4nocs,             ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[INPUTCNT-1:0]                             cs,                     ///< 选通信号阵列。
                                                                                 ///< \attention 当例化参数 #CS2IDX_DELAYOUT 为 1'b1 时， #cs 信号应比 #data_in 、 #data4_nocs 信号提前一拍置位
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array_out               ///< 输出数据
);
   wire[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]data_in[INPUTCNT-1:0], data4nocs, data_out;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) acui(
      .in   (array4nocs ),
      .out  (data4nocs  )
   );
   genvar i; generate for (i = 0; i < ARRAYSIZ; i++) begin
      packedarray_packedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) acuii(
         .in   (array_in[i]),
         .out  (data_in[i] )
      );
   end endgenerate
   mux_bycs #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .INITNOCS   (INITNOCS                  ),
      .INPUTCNT   (INPUTCNT                  ),
      .DELAYTAPS  (DELAYTAPS                 ),
      .BALNCDLY   (BALNCDLY                  )
   ) muxi(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (data_in    ),
      .data4nocs  (data4nocs  ),
      .cs         (cs         ),
      .data_out   (data_out   )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) usai(
      .in   (data_out   ),
      .out  (array_out  )
   );
endmodule
module mux_bycs_packedunit_unpackedarray #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据路数及选通信号阵列位宽
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter int                                            DELAYTAPS = 0,    ///< 多路复用选择器延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                                              ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                              ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                             clk,                                   ///< 驱动时钟
   input  wire                            aclr,                                  ///< 异步复位信号
   input  wire                            sclr,                                  ///< 同步复位信号
   input  wire                            clken,                                 ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],  ///< 待选通的数组阵列
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]array4nocs[ARRAYSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[INPUTCNT-1:0]              cs,                                    ///< 选通信号阵列。
                                                                                 ///< \attention 当例化参数 #CS2IDX_DELAYOUT 为 1'b1 时， #cs 信号应比 #data_in 、 #data4_nocs 信号提前一拍置位
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]array_out[ARRAYSIZ-1:0]                ///< 输出数据
);
   wire[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   genvar i; generate
   for (i = 0; i < INPUTCNT; i++) begin
      unpackedarray_packedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) aup2p(
         .in   (array_in[i]   ),
         .out  (parray_in[i]  )
      );
   end
   endgenerate
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ncsup2p(
      .in   (array4nocs ),
      .out  (parray4nocs)
   );
   mux_bycs #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .INITNOCS   (INITNOCS                  ),
      .INPUTCNT   (INPUTCNT                  ),
      .DELAYTAPS  (DELAYTAPS                 ),
      .BALNCDLY   (BALNCDLY                  )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (parray_in  ),
      .data4nocs  (parray4nocs),
      .cs         (cs         ),
      .data_out   (parray_out )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ap2up(
      .in   (parray_out ),
      .out  (array_out  )
   );
endmodule
module mux_bycs_unpackedunit_unpackedarray #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据路数及选通信号阵列位宽
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  INITNOCS  = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter int                                            DELAYTAPS = 0,    ///< 多路复用选择器延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                                              ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                              ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                 clk,                                               ///< 驱动时钟
   input  wire                aclr,                                              ///< 异步复位信号
   input  wire                sclr,                                              ///< 同步复位信号
   input  wire                clken,                                             ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[UNITBITW-1:0]  array_in[INPUTCNT-1:0][ARRAYSIZ-1:0][AUNITSIZ-1:0],///< 待选通的数组阵列
   input  wire[UNITBITW-1:0]  array4nocs[ARRAYSIZ-1:0][AUNITSIZ-1:0],            ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[INPUTCNT-1:0]  cs,                                                ///< 选通信号阵列。
                                                                                 ///< \attention 当例化参数 #CS2IDX_DELAYOUT 为 1'b1 时， #cs 信号应比 #data_in 、 #data4_nocs 信号提前一拍置位
   output wire[UNITBITW-1:0]  array_out[ARRAYSIZ-1:0][AUNITSIZ-1:0]              ///< 输出数据
);
   wire[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   genvar i; generate
   for (i = 0; i < INPUTCNT; i++) begin
      unpackedarray_unpackedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) aup2p(
         .in   (array_in[i]   ),
         .out  (parray_in[i]  )
      );
   end
   endgenerate
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ncsup2p(
      .in   (array4nocs ),
      .out  (parray4nocs)
   );
   mux_bycs #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .INITNOCS   (INITNOCS                  ),
      .INPUTCNT   (INPUTCNT                  ),
      .DELAYTAPS  (DELAYTAPS                 ),
      .BALNCDLY   (BALNCDLY                  )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (parray_in  ),
      .data4nocs  (parray4nocs),
      .cs         (cs         ),
      .data_out   (parray_out )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ap2up(
      .in   (parray_out ),
      .out  (array_out  )
   );
endmodule
module mux_bycs_packedarray_extd #(
   parameter int                             UNITBITW  = 8,       ///< 单位数据位宽
   parameter int                             ARRAYSIZ  = 2,       ///< 数组元素个数
   parameter int                             EXTDBITW  = 0,    ///< 额外数据位宽
   parameter bit[ARRAYSIZ-1:0][UNITBITW-1:0] AINITNOCS = {(ARRAYSIZ){{(UNITBITW){1'b0}}}},
   parameter bit[(EXTDBITW>0?EXTDBITW:1)-1:0]EINITNOCS = {(EXTDBITW>0?EXTDBITW:1){1'b0}},
   parameter int                             INPUTCNT  = 5,       ///< 待选通数据路数及选通信号阵列位宽
   parameter int                             DELAYTAPS = 0,       ///< 多路复用选择器延迟输出拍数
   parameter bit                             BALNCDLY  = 1'b0     ///< 在各级复选器间平均分配延迟拍数标志：
                                                                  ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                  ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                clk,                    ///< 驱动时钟
   input  wire                               aclr,                   ///< 异步复位信号
   input  wire                               sclr,                   ///< 同步复位信号
   input  wire                               clken,                  ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]   array_in[INPUTCNT-1:0], ///< 待选通的数组阵列
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]   array4nocs,             ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_in[INPUTCNT-1:0],  ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd4nocs,              ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   input  wire[INPUTCNT-1:0]                 cs,                     ///< 选通信号阵列。
                                                                     ///< \attention 当例化参数 #CS2IDX_DELAYOUT 为 1'b1 时， #cs 信号应比 #data_in 、 #data4_nocs 信号提前一拍置位
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]   array_out,              ///< 输出数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_out                ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   generate
   wire[UNITBITW*ARRAYSIZ+EXTDBITW-1:0]data_in[INPUTCNT-1:0], data4nocs, data_out;
   packedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acui(
      .in   (array4nocs                      ),
      .out  (data4nocs[UNITBITW*ARRAYSIZ-1:0])
   );
   if (EXTDBITW > 0) assign data4nocs[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ] = extd4nocs;
   unpackedarray_packedunitarray_extd_combine2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(ARRAYSIZ),
      .ARRAYSIZ(INPUTCNT),
      .EXTDBITW(EXTDBITW)
   ) acuii(
      .in   (array_in),
      .ex   (extd_in ),
      .out  (data_in )
   );
   mux_bycs #(
      .UNITBITW   (UNITBITW*ARRAYSIZ+EXTDBITW),
      .INITNOCS   ({EINITNOCS, AINITNOCS}    ),
      .INPUTCNT   (INPUTCNT                  ),
      .DELAYTAPS  (DELAYTAPS                 ),
      .BALNCDLY   (BALNCDLY                  )
   ) muxi(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (data_in    ),
      .data4nocs  (data4nocs  ),
      .cs         (cs         ),
      .data_out   (data_out   )
   );
   unit_split2packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) usai(
      .in   (data_out[UNITBITW*ARRAYSIZ-1:0] ),
      .out  (array_out                       )
   );
   if (EXTDBITW > 0) assign extd_out = data_out[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ];
   else              assign extd_out = 1'b0;
   endgenerate
endmodule
module mux_bycs_unpackedarray_extd #(
   parameter int                             UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                             ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                             EXTDBITW  = 0,    ///< 额外数据位宽
   parameter bit[ARRAYSIZ-1:0][UNITBITW-1:0] AINITNOCS = {(ARRAYSIZ){{(UNITBITW){1'b0}}}},
   parameter bit[(EXTDBITW>0?EXTDBITW:1)-1:0]EINITNOCS = {(EXTDBITW>0?EXTDBITW:1){1'b0}},
   parameter int                             INPUTCNT  = 5,    ///< 待选通数据路数及选通信号阵列位宽
   parameter int                             DELAYTAPS = 0,    ///< 多路复用选择器延迟输出拍数
   parameter bit                             BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                               ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                               ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                clk,                                   ///< 驱动时钟
   input  wire                               aclr,                                  ///< 异步复位信号
   input  wire                               sclr,                                  ///< 同步复位信号
   input  wire                               clken,                                 ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[UNITBITW-1:0]                 array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],  ///< 待选通的数组阵列
   input  wire[UNITBITW-1:0]                 array4nocs[ARRAYSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_in[INPUTCNT-1:0],                 ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd4nocs,                             ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   input  wire[INPUTCNT-1:0]                 cs,                                    ///< 选通信号阵列。
                                                                                    ///< \attention 当例化参数 #CS2IDX_DELAYOUT 为 1'b1 时， #cs 信号应比 #data_in 、 #data4_nocs 信号提前一拍置位
   output wire[UNITBITW-1:0]                 array_out[ARRAYSIZ-1:0],               ///< 输出数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_out                               ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   wire[ARRAYSIZ-1:0][UNITBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   unpackedarrayunit_unpacked2packed #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(ARRAYSIZ),
      .ARRAYSIZ(INPUTCNT)
   ) aup2p(
      .in   (array_in   ),
      .out  (parray_in  )
   );
   array_unpacked2packed #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) nocsup2p(
      .in   (array4nocs ),
      .out  (parray4nocs)
   );
   mux_bycs_packedarray_extd #(
      .UNITBITW   (UNITBITW   ),
      .ARRAYSIZ   (ARRAYSIZ   ),
      .AINITNOCS  (AINITNOCS  ),
      .EINITNOCS  (EINITNOCS  ),
      .INPUTCNT   (INPUTCNT   ),
      .DELAYTAPS  (DELAYTAPS  ),
      .BALNCDLY   (BALNCDLY   )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .array_in   (parray_in  ),
      .array4nocs (parray4nocs),
      .extd_in    (extd_in    ),
      .extd4nocs  (extd4nocs  ),
      .cs         (cs         ),
      .array_out  (parray_out ),
      .extd_out   (extd_out   )
   );
   array_packed2unpacked #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) op2up(
      .in   (parray_out ),
      .out  (array_out  )
   );
endmodule

module mux_bycs_packedunit_packedarray_extd #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                                            EXTDBITW  = 0,    ///< 额外数据位宽
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据路数及选通信号阵列位宽
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  AINITNOCS = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter bit[(EXTDBITW>0?EXTDBITW:1)-1:0]               EINITNOCS = {(EXTDBITW>0?EXTDBITW:1){1'b0}},
   parameter int                                            DELAYTAPS = 0,    ///< 多路复用选择器延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                                              ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                              ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                            clk,                    ///< 驱动时钟
   input  wire                                           aclr,                   ///< 异步复位信号
   input  wire                                           sclr,                   ///< 同步复位信号
   input  wire                                           clken,                  ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array_in[INPUTCNT-1:0], ///< 待选通的数组阵列
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array4nocs,             ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]              extd_in[INPUTCNT-1:0],  ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]              extd4nocs,              ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   input  wire[INPUTCNT-1:0]                             cs,                     ///< 选通信号阵列。
                                                                                 ///< \attention 当例化参数 #CS2IDX_DELAYOUT 为 1'b1 时， #cs 信号应比 #data_in 、 #data4_nocs 信号提前一拍置位
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] array_out,              ///< 输出数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]              extd_out                ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   genvar i; generate
   wire[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:0]data_in[INPUTCNT-1:0], data4nocs, data_out;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) acui(
      .in   (array4nocs                               ),
      .out  (data4nocs[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   if (EXTDBITW > 0) assign data4nocs[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ] = extd4nocs;
   for (i = 0; i < INPUTCNT; i++) begin
      packedarray_packedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) acuii(
         .in   (array_in[i]                                 ),
         .out  (data_in[i][UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]  )
      );
      if (EXTDBITW > 0) assign data_in[i][UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ] = extd_in[i];
   end
   mux_bycs #(
      .UNITBITW   (UNITBITW*ARRAYSIZ+EXTDBITW),
      .INITNOCS   ({EINITNOCS, AINITNOCS}    ),
      .INPUTCNT   (INPUTCNT                  ),
      .DELAYTAPS  (DELAYTAPS                 ),
      .BALNCDLY   (BALNCDLY                  )
   ) muxi(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (data_in    ),
      .data4nocs  (data4nocs  ),
      .cs         (cs         ),
      .data_out   (data_out   )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) usai(
      .in   (data_out[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0] ),
      .out  (array_out                                )
   );
   if (EXTDBITW > 0) assign extd_out = data_out[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
   else              assign extd_out = 1'b0;
   endgenerate
endmodule
module mux_bycs_packedunit_unpackedarray_extd #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                                            EXTDBITW  = 0,    ///< 额外数据位宽
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据路数及选通信号阵列位宽
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  AINITNOCS = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter bit[(EXTDBITW>0?EXTDBITW:1)-1:0]               EINITNOCS = {(EXTDBITW>0?EXTDBITW:1){1'b0}},
   parameter int                                            DELAYTAPS = 0,    ///< 多路复用选择器延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                                              ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                              ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                clk,                                   ///< 驱动时钟
   input  wire                               aclr,                                  ///< 异步复位信号
   input  wire                               sclr,                                  ///< 同步复位信号
   input  wire                               clken,                                 ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]   array_in[INPUTCNT-1:0][ARRAYSIZ-1:0],  ///< 待选通的数组阵列
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]   array4nocs[ARRAYSIZ-1:0],              ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_in[INPUTCNT-1:0],                 ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd4nocs,                             ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   input  wire[INPUTCNT-1:0]                 cs,                                    ///< 选通信号阵列。
                                                                                    ///< \attention 当例化参数 #CS2IDX_DELAYOUT 为 1'b1 时， #cs 信号应比 #data_in 、 #data4_nocs 信号提前一拍置位
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]   array_out[ARRAYSIZ-1:0],               ///< 输出数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_out                               ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   genvar i; generate
   wire[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   for (i = 0; i < INPUTCNT; i++) begin
      unpackedarray_packedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) aup2p(
         .in   (array_in[i]                                 ),
         .out  (parray_in[i][ARRAYSIZ*AUNITSIZ*UNITBITW-1:0])
      );
      if (EXTDBITW > 0) assign parray_in[i][ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW] = extd_in[i];
   end
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ncsup2p(
      .in   (array4nocs                                  ),
      .out  (parray4nocs[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0] )
   );
   if (EXTDBITW > 0) assign parray4nocs[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW] = extd4nocs;
   mux_bycs #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .INPUTCNT   (INPUTCNT                           ),
      .INITNOCS   ({EINITNOCS, AINITNOCS}             ),
      .DELAYTAPS  (DELAYTAPS                          ),
      .BALNCDLY   (BALNCDLY                           )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (parray_in  ),
      .data4nocs  (parray4nocs),
      .cs         (cs         ),
      .data_out   (parray_out )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ap2up(
      .in   (parray_out[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]  ),
      .out  (array_out                                   )
   );
   if (EXTDBITW > 0) assign extd_out = parray_out[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW];
   else              assign extd_out = 1'b0;
   endgenerate
endmodule
module mux_bycs_unpackedunit_unpackedarray_extd #(
   parameter int                                            UNITBITW  = 8,    ///< 单位数据位宽
   parameter int                                            AUNITSIZ  = 1,    ///< 数组单位元素个数
   parameter int                                            ARRAYSIZ  = 2,    ///< 数组元素个数
   parameter int                                            EXTDBITW  = 0,    ///< 额外数据位宽
   parameter int                                            INPUTCNT  = 5,    ///< 待选通数据路数及选通信号阵列位宽
   parameter bit[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0]  AINITNOCS = {(ARRAYSIZ){{(AUNITSIZ){{(UNITBITW){1'b0}}}}}},
   parameter bit[(EXTDBITW>0?EXTDBITW:1)-1:0]               EINITNOCS = {(EXTDBITW>0?EXTDBITW:1){1'b0}},
   parameter int                                            DELAYTAPS = 0,    ///< 多路复用选择器延迟输出拍数
   parameter bit                                            BALNCDLY  = 1'b0  ///< 在各级复选器间平均分配延迟拍数标志：
                                                                              ///< 1'b0-在分级复选器中最多只分配根据 #mux_pkg::delaytaps4mux_recommend 计算的拍数，以节省资源；
                                                                              ///< 1'b1-将用户指定的延迟拍数平均分配到各级复选器中，以最大化优化时序性能
) (
   input  bit                                clk,                                               ///< 驱动时钟
   input  wire                               aclr,                                              ///< 异步复位信号
   input  wire                               sclr,                                              ///< 同步复位信号
   input  wire                               clken,                                             ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   input  wire[UNITBITW-1:0]                 array_in[INPUTCNT-1:0][ARRAYSIZ-1:0][AUNITSIZ-1:0],///< 待选通的数组阵列
   input  wire[UNITBITW-1:0]                 array4nocs[ARRAYSIZ-1:0][AUNITSIZ-1:0],            ///< 无待选通数据数组阵列被选通时选择输出的数据数组
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_in[INPUTCNT-1:0],                             ///< 输入待选通额外数据阵列
   input  wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd4nocs,                                         ///< 无待选通额外数据阵列被选通时选择输出的额外数据
   input  wire[INPUTCNT-1:0]                 cs,                                                ///< 选通信号阵列。
                                                                                                ///< \attention 当例化参数 #CS2IDX_DELAYOUT 为 1'b1 时， #cs 信号应比 #data_in 、 #data4_nocs 信号提前一拍置位
   output wire[UNITBITW-1:0]                 array_out[ARRAYSIZ-1:0][AUNITSIZ-1:0],             ///< 输出数据
   output wire[(EXTDBITW>0?EXTDBITW:1)-1:0]  extd_out                                           ///< 输出按索引位宽扩展后的待选通额外数据阵列
);
   wire[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:0] parray_in[INPUTCNT-1:0], parray4nocs, parray_out;
   genvar i; generate
   for (i = 0; i < INPUTCNT; i++) begin
      unpackedarray_unpackedunitarray_combineall2unit #(
         .UNITBITW(UNITBITW),
         .AUNITSIZ(AUNITSIZ),
         .ARRAYSIZ(ARRAYSIZ)
      ) aup2p(
         .in   (array_in[i]                                 ),
         .out  (parray_in[i][ARRAYSIZ*AUNITSIZ*UNITBITW-1:0])
      );
      if (EXTDBITW > 0) assign parray_in[i][ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW] = extd_in[i];
   end
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ncsup2p(
      .in   (array4nocs                                  ),
      .out  (parray4nocs[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0] )
   );
   if (EXTDBITW > 0) assign parray4nocs[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW] = extd4nocs;
   mux_bycs #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .INPUTCNT   (INPUTCNT                           ),
      .INITNOCS   ({EINITNOCS, AINITNOCS}             ),
      .DELAYTAPS  (DELAYTAPS                          ),
      .BALNCDLY   (BALNCDLY                           )
   ) muxipa(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .data_in    (parray_in  ),
      .data4nocs  (parray4nocs),
      .cs         (cs         ),
      .data_out   (parray_out )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) ap2up(
      .in   (parray_out[ARRAYSIZ*AUNITSIZ*UNITBITW-1:0]  ),
      .out  (array_out                                   )
   );
   if (EXTDBITW > 0) assign extd_out = parray_out[ARRAYSIZ*AUNITSIZ*UNITBITW+EXTDBITW-1:ARRAYSIZ*AUNITSIZ*UNITBITW];
   else              assign extd_out = 1'b0;
   endgenerate
endmodule
