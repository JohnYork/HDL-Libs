/*!
 * \license SPDX-License-Identifier: MIT
 * \file rams.svh
 * \brief RAM、RAM数组、RAM数组合并非数组元素位宽RAM头文件
 * \author johnyork@yeah.net
 */
`include "miscs.svh"

`ifdef  __INC_FROM_RAMS__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_RAMS__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __RAMS_PKG__
 `define __RAMS_PKG__

package rams_pkg;
   /*!
    * \brief 根据地址长度计算地址线位宽
    * \param addrLen 地址长度
    * \return int型，地址线位宽
    */
   function automatic int addrLen2AddrBitw(longint addrLen);
      return miscs::minbitw_of_longint(addrLen - 1, 64);
   endfunction
   /*! \brief 逻辑资源搭建RAM的RAM特征标识 */
   localparam ramstyle_logic = miscs::miscs_ramstyle_logic;
   /*! \brief 块RAM资源搭建RAM的RAM特征标识 */
   localparam ramstyle_ram = "ram";
   /*! \brief 自动分配资源搭建RAM的RAM特征标识 */
   localparam ramstyle_auto = "auto";
   /*!
    * \brief 计算推荐的RAM搭建资源类型、
    * \param addrlen  待实现的RAM地址长度
    * \param databitw 待实现的RAM数据位宽
    * \return int型，RAM搭建资源类型代码，0-以逻辑资源搭建RAM，2-以块RAM资源搭建RAM
    */
   function automatic int recommend_ramstyle(int addrlen, int databitw);
      int blkram_minaddrbitw, blkram_min_bits;
      blkram_minaddrbitw = 
      `ifdef   BLKRAM_MINBITW4NORSV
         `BLKRAM_MINBITW4NORSV;
      `elsif   COMPILER_VIVADO
         9
      `else
         10
      `endif
      ;
      blkram_min_bits =
      `ifdef   BLKRAM_MINBITS_RECOMMEND
         `BLKRAM_MINBITS_RECOMMEND;
      `elsif   COMPILER_VIVADO
         18*(2**7)   // 以K7的单位BlockRam为标准
      `else
         10*(2**8)
      `endif
      ;
      return (addrlen < blkram_minaddrbitw || addrlen*databitw < blkram_min_bits) ? 0 : 2;
   endfunction
endpackage

 `endif//__RAMS_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef __RAMS_ITF__
 `define __RAMS_ITF__
/*! \brief Simple Dual Port RAM interface */
interface sdpram_2clk_if #(
   parameter int DATABITW = 32,
   parameter int ADDRLEN  = 5
) (
   input  bit  clk_w,
   input  bit  clk_q,
   input  wire aclr,
   input  wire sclr_q
);
   logic                we;                        ///< RAM写信号，高电平(1)有效
   logic                clken_w;                   ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic [addrBitw-1:0] addr_w;                    ///< RAM写地址
   logic [DATABITW-1:0] data_w;                    ///< RAM待写数据
   logic                clken_q;                   ///< RAM读使能信号，高电平(1)有效
   logic [addrBitw-1:0] addr_q;                    ///< RAM读地址
   logic [DATABITW-1:0] data_q;                    ///< RAM读数据输出

   modport ramp(input clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, clk_q, clken_q, addr_q, output data_q);
   modport clip(input clk_w, aclr, sclr_q, clk_q, data_q, output we, clken_w, addr_w, data_w, clken_q, addr_q);
endinterface
interface sdpram_if #(
   parameter int DATABITW = 32,
   parameter int ADDRLEN  = 5
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                we;                        ///< RAM写信号，高电平(1)有效
   logic                clken_w;                   ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic [addrBitw-1:0] addr_w;                    ///< RAM写地址
   logic [DATABITW-1:0] data_w;                    ///< RAM待写数据
   logic                clken_q;                   ///< RAM读使能信号，高电平(1)有效
   logic [addrBitw-1:0] addr_q;                    ///< RAM读地址
   logic [DATABITW-1:0] data_q;                    ///< RAM读数据输出

   modport ramp(input clk, aclr, sclr, we, clken_w, addr_w, data_w, clken_q, addr_q, output data_q);
   modport clip(input clk, aclr, sclr, data_q, output we, clken_w, addr_w, data_w, clken_q, addr_q);
endinterface
/*! \brief Simple Dual Port RAM for packed-array interface */
interface sdpram_2clk_packedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk_w,
   input  bit  clk_q,
   input  wire aclr,
   input  wire sclr_q
);
   logic                            we;            ///< RAM写信号，高电平(1)有效
   logic                            clken_w;       ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addr_w;        ///< RAM写地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]data_w;        ///< RAM待写数据
   logic                            clken_q;       ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]              addr_q;        ///< RAM读地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]data_q;        ///< RAM读数据输出

   modport ramp(input clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, clk_q, clken_q, addr_q, output data_q);
   modport clip(input clk_w, aclr, sclr_q, clk_q, data_q, output we, clken_w, addr_w, data_w, clken_q, addr_q);
endinterface
interface sdpram_packedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                            we;            ///< RAM写信号，高电平(1)有效
   logic                            clken_w;       ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addr_w;        ///< RAM写地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]data_w;        ///< RAM待写数据
   logic                            clken_q;       ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]              addr_q;        ///< RAM读地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]data_q;        ///< RAM读数据输出

   modport ramp(input clk, aclr, sclr, we, clken_w, addr_w, data_w, clken_q, addr_q, output data_q);
   modport clip(input clk, aclr, sclr, data_q, output we, clken_w, addr_w, data_w, clken_q, addr_q);
endinterface
/*! \brief Simple Dual Port RAM for packed-array with extra data interface */
interface sdpram_2clk_packedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk_w,
   input  bit  clk_q,
   input  wire aclr,
   input  wire sclr_q
);
   logic                            we;            ///< RAM写信号，高电平(1)有效
   logic                            clken_w;       ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addr_w;        ///< RAM写地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]data_w;        ///< RAM待写数组数据
   logic[EXTDBITW-1:0]              extd_w;        ///< RAM待写扩展数据
   logic                            clken_q;       ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]              addr_q;        ///< RAM读地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]data_q;        ///< RAM读数组数据输出
   logic[EXTDBITW-1:0]              extd_q;        ///< RAM读扩展数据输出

   modport ramp(input clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, extd_w, clk_q, clken_q, addr_q, output data_q, extd_q);
   modport clip(input clk_w, aclr, sclr_q, clk_q, data_q, extd_q, output we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q);
endinterface
interface sdpram_packedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                            we;            ///< RAM写信号，高电平(1)有效
   logic                            clken_w;       ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addr_w;        ///< RAM写地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]data_w;        ///< RAM待写数组数据
   logic[EXTDBITW-1:0]              extd_w;        ///< RAM待写扩展数据
   logic                            clken_q;       ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]              addr_q;        ///< RAM读地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]data_q;        ///< RAM读数组数据输出
   logic[EXTDBITW-1:0]              extd_q;        ///< RAM读扩展数据输出

   modport ramp(input clk, aclr, sclr, we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q, output data_q, extd_q);
   modport clip(input clk, aclr, sclr, data_q, extd_q, output we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q);
endinterface
/*! \brief Simple Dual Port RAM for unpacked-array interface */
interface sdpram_2clk_unpackedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk_w,
   input  bit  clk_q,
   input  wire aclr,
   input  wire sclr_q
);
   logic                we;                  ///< RAM写信号，高电平(1)有效
   logic                clken_w;             ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic [addrBitw-1:0] addr_w;              ///< RAM写地址
   logic [DATABITW-1:0] data_w[ARRAYSIZ-1:0];///< RAM待写数据
   logic                clken_q;             ///< RAM读使能信号，高电平(1)有效
   logic [addrBitw-1:0] addr_q;              ///< RAM读地址
   logic [DATABITW-1:0] data_q[ARRAYSIZ-1:0];///< RAM读数据输出

   modport ramp(input clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, clk_q, clken_q, addr_q, output data_q);
   modport clip(input clk_w, aclr, sclr_q, clk_q, data_q, output we, clken_w, addr_w, data_w, clken_q, addr_q);
endinterface
interface sdpram_unpackedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                we;                  ///< RAM写信号，高电平(1)有效
   logic                clken_w;             ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic [addrBitw-1:0] addr_w;              ///< RAM写地址
   logic [DATABITW-1:0] data_w[ARRAYSIZ-1:0];///< RAM待写数据
   logic                clken_q;             ///< RAM读使能信号，高电平(1)有效
   logic [addrBitw-1:0] addr_q;              ///< RAM读地址
   logic [DATABITW-1:0] data_q[ARRAYSIZ-1:0];///< RAM读数据输出

   modport ramp(input clk, aclr, sclr, we, clken_w, addr_w, data_w, clken_q, addr_q, output data_q);
   modport clip(input clk, aclr, sclr, data_q, output we, clken_w, addr_w, data_w, clken_q, addr_q);
endinterface
/*! \brief Simple Dual Port RAM for unpacked-array with extra data interface */
interface sdpram_2clk_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk_w,
   input  bit  clk_q,
   input  wire aclr,
   input  wire sclr_q
);
   logic                we;                        ///< RAM写信号，高电平(1)有效
   logic                clken_w;                   ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic [addrBitw-1:0] addr_w;                    ///< RAM写地址
   logic [DATABITW-1:0] data_w[ARRAYSIZ-1:0];      ///< RAM待写数据
   logic [EXTDBITW-1:0] extd_w;                    ///< RAM待写扩展数据
   logic                clken_q;                   ///< RAM读使能信号，高电平(1)有效
   logic [addrBitw-1:0] addr_q;                    ///< RAM读地址
   logic [DATABITW-1:0] data_q[ARRAYSIZ-1:0];      ///< RAM读数据输出
   logic [EXTDBITW-1:0] extd_q;                    ///< RAM读扩展数据输出

   modport ramp(input clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, extd_w, clk_q, clken_q, addr_q, output data_q, extd_q);
   modport clip(input clk_w, aclr, sclr_q, clk_q, data_q, extd_q, output we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q);
endinterface
interface sdpram_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                we;                        ///< RAM写信号，高电平(1)有效
   logic                clken_w;                   ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic [addrBitw-1:0] addr_w;                    ///< RAM写地址
   logic [DATABITW-1:0] data_w[ARRAYSIZ-1:0];      ///< RAM待写数据
   logic [EXTDBITW-1:0] extd_w;                    ///< RAM待写扩展数据
   logic                clken_q;                   ///< RAM读使能信号，高电平(1)有效
   logic [addrBitw-1:0] addr_q;                    ///< RAM读地址
   logic [DATABITW-1:0] data_q[ARRAYSIZ-1:0];      ///< RAM读数据输出
   logic [EXTDBITW-1:0] extd_q;                    ///< RAM读扩展数据输出

   modport ramp(input clk, aclr, sclr, we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q, output data_q, extd_q);
   modport clip(input clk, aclr, sclr, data_q, extd_q, output we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q);
endinterface
/*! \brief Simple Dual Port RAM for packed-unit-packed-array interface */
interface sdpram_2clk_packedunit_packedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk_w,
   input  bit  clk_q,
   input  wire aclr,
   input  wire sclr_q
);
   logic                                           we;            ///< RAM写信号，高电平(1)有效
   logic                                           clken_w;       ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]                             addr_w;        ///< RAM写地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_w;        ///< RAM待写数据
   logic                                           clken_q;       ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]                             addr_q;        ///< RAM读地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_q;        ///< RAM读数据输出

   modport ramp(input clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, clk_q, clken_q, addr_q, output data_q);
   modport clip(input clk_w, aclr, sclr_q, clk_q, data_q, output we, clken_w, addr_w, data_w, clken_q, addr_q);
endinterface
interface sdpram_packedunit_packedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                                           we;            ///< RAM写信号，高电平(1)有效
   logic                                           clken_w;       ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]                             addr_w;        ///< RAM写地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_w;        ///< RAM待写数据
   logic                                           clken_q;       ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]                             addr_q;        ///< RAM读地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_q;        ///< RAM读数据输出

   modport ramp(input clk, aclr, sclr, we, clken_w, addr_w, data_w, clken_q, addr_q, output data_q);
   modport clip(input clk, aclr, sclr, data_q, output we, clken_w, addr_w, data_w, clken_q, addr_q);
endinterface
/*! \brief Simple Dual Port RAM for packed-unit-packed-array with extra data interface */
interface sdpram_2clk_packedunit_packedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk_w,
   input  bit  clk_q,
   input  wire aclr,
   input  wire sclr_q
);
   logic                                           we;            ///< RAM写信号，高电平(1)有效
   logic                                           clken_w;       ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]                             addr_w;        ///< RAM写地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_w;        ///< RAM待写数据
   logic[EXTDBITW-1:0]                             extd_w;        ///< RAM待写额外数据
   logic                                           clken_q;       ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]                             addr_q;        ///< RAM读地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_q;        ///< RAM读数据输出
   logic[EXTDBITW-1:0]                             extd_q;        ///< RAM读额外数据输出

   modport ramp(input clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, extd_w, clk_q, clken_q, addr_q, output data_q, extd_q);
   modport clip(input clk_w, aclr, sclr_q, clk_q, data_q, extd_q, output we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q);
endinterface
interface sdpram_packedunit_packedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                                           we;            ///< RAM写信号，高电平(1)有效
   logic                                           clken_w;       ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]                             addr_w;        ///< RAM写地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_w;        ///< RAM待写数据
   logic[EXTDBITW-1:0]                             extd_w;        ///< RAM待写额外数据
   logic                                           clken_q;       ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]                             addr_q;        ///< RAM读地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_q;        ///< RAM读数据输出
   logic[EXTDBITW-1:0]                             extd_q;        ///< RAM读额外数据输出

   modport ramp(input clk, aclr, sclr, we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q, output data_q, extd_q);
   modport clip(input clk, aclr, sclr, data_q, extd_q, output we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q);
endinterface
/*! \brief Simple Dual Port RAM for packed-unit-unpacked-array interface */
interface sdpram_2clk_packedunit_unpackedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk_w,
   input  bit  clk_q,
   input  wire aclr,
   input  wire sclr_q
);
   logic                            we;                  ///< RAM写信号，高电平(1)有效
   logic                            clken_w;             ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addr_w;              ///< RAM写地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]data_w[ARRAYSIZ-1:0];  ///< RAM待写数据
   logic                            clken_q;             ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]              addr_q;              ///< RAM读地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]data_q[ARRAYSIZ-1:0];///< RAM读数据输出

   modport ramp(input clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, clk_q, clken_q, addr_q, output data_q);
   modport clip(input clk_w, aclr, sclr_q, clk_q, data_q, output we, clken_w, addr_w, data_w, clken_q, addr_q);
endinterface
interface sdpram_packedunit_unpackedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                            we;                  ///< RAM写信号，高电平(1)有效
   logic                            clken_w;             ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addr_w;              ///< RAM写地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]data_w[ARRAYSIZ-1:0];///< RAM待写数据
   logic                            clken_q;             ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]              addr_q;              ///< RAM读地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]data_q[ARRAYSIZ-1:0];///< RAM读数据输出

   modport ramp(input clk, aclr, sclr, we, clken_w, addr_w, data_w, clken_q, addr_q, output data_q);
   modport clip(input clk, aclr, sclr, data_q, output we, clken_w, addr_w, data_w, clken_q, addr_q);
endinterface
/*! \brief Simple Dual Port RAM for packed-unit-unpacked-array with extra data interface */
interface sdpram_2clk_packedunit_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk_w,
   input  bit  clk_q,
   input  wire aclr,
   input  wire sclr_q
);
   logic                            we;                  ///< RAM写信号，高电平(1)有效
   logic                            clken_w;             ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addr_w;              ///< RAM写地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]data_w[ARRAYSIZ-1:0];///< RAM待写数据
   logic[EXTDBITW-1:0]              extd_w;              ///< RAM待写额外数据
   logic                            clken_q;             ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]              addr_q;              ///< RAM读地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]data_q[ARRAYSIZ-1:0];///< RAM读数据输出
   logic[EXTDBITW-1:0]              extd_q;              ///< RAM读额外数据输出

   modport ramp(input clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, extd_w, clk_q, clken_q, addr_q, output data_q, extd_q);
   modport clip(input clk_w, aclr, sclr_q, clk_q, data_q, extd_q, output we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q);
endinterface
interface sdpram_packedunit_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                            we;                  ///< RAM写信号，高电平(1)有效
   logic                            clken_w;             ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addr_w;              ///< RAM写地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]data_w[ARRAYSIZ-1:0];///< RAM待写数据
   logic[EXTDBITW-1:0]              extd_w;              ///< RAM待写额外数据
   logic                            clken_q;             ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]              addr_q;              ///< RAM读地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]data_q[ARRAYSIZ-1:0];///< RAM读数据输出
   logic[EXTDBITW-1:0]              extd_q;              ///< RAM读额外数据输出

   modport ramp(input clk, aclr, sclr, we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q, output data_q, extd_q);
   modport clip(input clk, aclr, sclr, data_q, extd_q, output we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q);
endinterface
/*! \brief Simple Dual Port RAM for unpacked-unit-unpacked-array with extra data interface */
interface sdpram_2clk_unpackedunit_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk_w,
   input  bit  clk_q,
   input  wire aclr,
   input  wire sclr_q
);
   logic                we;                                ///< RAM写信号，高电平(1)有效
   logic                clken_w;                           ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]  addr_w;                            ///< RAM写地址
   logic[DATABITW-1:0]  data_w[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< RAM待写数据
   logic[EXTDBITW-1:0]  extd_w;                            ///< RAM待写额外数据
   logic                clken_q;                           ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]  addr_q;                            ///< RAM读地址
   logic[DATABITW-1:0]  data_q[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< RAM读数据输出
   logic[EXTDBITW-1:0]  extd_q;                            ///< RAM读额外数据输出

   modport ramp(input clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, extd_w, clk_q, clken_q, addr_q, output data_q, extd_q);
   modport clip(input clk_w, aclr, sclr_q, clk_q, data_q, extd_q, output we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q);
endinterface
interface sdpram_unpackedunit_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                we;                                ///< RAM写信号，高电平(1)有效
   logic                clken_w;                           ///< RAM写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]  addr_w;                            ///< RAM写地址
   logic[DATABITW-1:0]  data_w[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< RAM待写数据
   logic[EXTDBITW-1:0]  extd_w;                            ///< RAM待写额外数据
   logic                clken_q;                           ///< RAM读使能信号，高电平(1)有效
   logic[addrBitw-1:0]  addr_q;                            ///< RAM读地址
   logic[DATABITW-1:0]  data_q[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< RAM读数据输出
   logic[EXTDBITW-1:0]  extd_q;                            ///< RAM读额外数据输出

   modport ramp(input clk, aclr, sclr, we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q, output data_q, extd_q);
   modport clip(input clk, aclr, sclr, data_q, extd_q, output we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q);
endinterface
/*! \brief True Dual Port RAM interface */
interface tdpram_2clk_if #(
   parameter int DATABITW = 32,
   parameter int ADDRLEN  = 5
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic                wea, web;                  ///< RAM端口写信号，高电平(1)有效
   logic                clkena, clkenb;            ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic [addrBitw-1:0] addra, addrb;              ///< RAM端口读写地址
   logic [DATABITW-1:0] da, db;                    ///< RAM端口输入信号
   logic [DATABITW-1:0] qa, qb;                    ///< RAM端口输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db);
endinterface
interface tdpram_if #(
   parameter int DATABITW = 32,
   parameter int ADDRLEN  = 5
) (
   input  bit clk,
   input  wire aclr,
   input  wire sclr
);
   logic                wea, web;                  ///< RAM端口写信号，高电平(1)有效
   logic                clkena, clkenb;            ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic [addrBitw-1:0] addra, addrb;              ///< RAM端口读写地址
   logic [DATABITW-1:0] da, db;                    ///< RAM端口输入信号
   logic [DATABITW-1:0] qa, qb;                    ///< RAM端口输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clk, aclr, sclr, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db);
endinterface
/*! \brief True Dual Port RAM for packed-array interface */
interface tdpram_2clk_packedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic                            wea, web;      ///< RAM端口写信号，高电平(1)有效
   logic                            clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addra, addrb;  ///< RAM端口读写地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]da, db;        ///< RAM端口输入信号
   logic[ARRAYSIZ-1:0][DATABITW-1:0]qa, qb;        ///< RAM端口输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db);
endinterface
interface tdpram_packedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                            wea, web;      ///< RAM端口写信号，高电平(1)有效
   logic                            clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addra, addrb;  ///< RAM端口读写地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]da, db;        ///< RAM端口输入信号
   logic[ARRAYSIZ-1:0][DATABITW-1:0]qa, qb;        ///< RAM端口输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clk, aclr, sclr, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db);
endinterface
/*! \brief True Dual Port RAM for packed-array with extra data interface */
interface tdpram_2clk_packedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic                            wea, web;      ///< RAM端口写信号，高电平(1)有效
   logic                            clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addra, addrb;  ///< RAM端口读写地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]da, db;        ///< RAM端口输入信号
   logic[ARRAYSIZ-1:0][DATABITW-1:0]qa, qb;        ///< RAM端口输出信号
   logic[EXTDBITW-1:0]              dea, deb;      ///< RAM端口扩展非数组数据输入信号
   logic[EXTDBITW-1:0]              qea, qeb;      ///< RAM端口扩展非数组数据输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb, output qa, qb, qea, qeb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, qea, qeb, output wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da, dea);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db, deb);
endinterface
interface tdpram_packedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                            wea, web;      ///< RAM端口写信号，高电平(1)有效
   logic                            clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addra, addrb;  ///< RAM端口读写地址
   logic[ARRAYSIZ-1:0][DATABITW-1:0]da, db;        ///< RAM端口输入信号
   logic[ARRAYSIZ-1:0][DATABITW-1:0]qa, qb;        ///< RAM端口输出信号
   logic[EXTDBITW-1:0]              dea, deb;      ///< RAM端口扩展非数组数据输入信号
   logic[EXTDBITW-1:0]              qea, qeb;      ///< RAM端口扩展非数组数据输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb, output qa, qb, qea, qeb);
   modport clip(input clk, aclr, sclr, qa, qb, qea, qeb, output wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da, dea);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db, deb);
endinterface
/*! \brief True Dual Port RAM for unpacked-array interface */
interface tdpram_2clk_unpackedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic                            wea, web;               ///< RAM端口写信号，高电平(1)有效
   logic                            clkena, clkenb;         ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic [addrBitw-1:0] addra, addrb;                       ///< RAM端口读写地址
   logic [DATABITW-1:0] da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   logic [DATABITW-1:0] qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db);
endinterface
interface tdpram_unpackedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                            wea, web;               ///< RAM端口写信号，高电平(1)有效
   logic                            clkena, clkenb;         ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic [addrBitw-1:0] addra, addrb;                       ///< RAM端口读写地址
   logic [DATABITW-1:0] da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   logic [DATABITW-1:0] qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clk, aclr, sclr, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db);
endinterface
/*! \brief True Dual Port RAM for unpacked-array with extra data interface */
interface tdpram_2clk_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic                wea, web;                           ///< RAM端口写信号，高电平(1)有效
   logic                clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]  addra, addrb;                       ///< RAM端口读写地址
   logic[DATABITW-1:0]  da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   logic[DATABITW-1:0]  qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号
   logic[EXTDBITW-1:0]  dea, deb;                           ///< RAM端口扩展非数组数据输入信号
   logic[EXTDBITW-1:0]  qea, qeb;                           ///< RAM端口扩展非数组数据输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb, output qa, qb, qea, qeb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, qea, qeb, output wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da, dea);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db, deb);
endinterface
interface tdpram_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                wea, web;                           ///< RAM端口写信号，高电平(1)有效
   logic                clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]  addra, addrb;                       ///< RAM端口读写地址
   logic[DATABITW-1:0]  da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   logic[DATABITW-1:0]  qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号
   logic[EXTDBITW-1:0]  dea, deb;                           ///< RAM端口扩展非数组数据输入信号
   logic[EXTDBITW-1:0]  qea, qeb;                           ///< RAM端口扩展非数组数据输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb, output qa, qb, qea, qeb);
   modport clip(input clk, aclr, sclr, qa, qb, qea, qeb, output wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da, dea);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db, deb);
endinterface
/*! \brief True Dual Port RAM for packed-unit-packed-array interface */
interface tdpram_2clk_packedunit_packedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic                                           wea, web;      ///< RAM端口写信号，高电平(1)有效
   logic                                           clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]                             addra, addrb;  ///< RAM端口读写地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] da, db;        ///< RAM端口输入信号
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] qa, qb;        ///< RAM端口输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db);
endinterface
interface tdpram_packedunit_packedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                                           wea, web;      ///< RAM端口写信号，高电平(1)有效
   logic                                           clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]                             addra, addrb;  ///< RAM端口读写地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] da, db;        ///< RAM端口输入信号
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] qa, qb;        ///< RAM端口输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clk, aclr, sclr, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db);
endinterface
/*! \brief True Dual Port RAM for packed-unit-packed-array with extra data interface */
interface tdpram_2clk_packedunit_packedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic                                           wea, web;      ///< RAM端口写信号，高电平(1)有效
   logic                                           clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]                             addra, addrb;  ///< RAM端口读写地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] da, db;        ///< RAM端口输入信号
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] qa, qb;        ///< RAM端口输出信号
   logic[EXTDBITW-1:0]                             dea, deb;      ///< RAM端口扩展非数组数据输入信号
   logic[EXTDBITW-1:0]                             qea, qeb;      ///< RAM端口扩展非数组数据输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb, output qa, qb, qea, qeb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, qea, qeb, output wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da, dea);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db, deb);
endinterface
interface tdpram_packedunit_packedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                                           wea, web;      ///< RAM端口写信号，高电平(1)有效
   logic                                           clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]                             addra, addrb;  ///< RAM端口读写地址
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] da, db;        ///< RAM端口输入信号
   logic[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] qa, qb;        ///< RAM端口输出信号
   logic[EXTDBITW-1:0]                             dea, deb;      ///< RAM端口扩展非数组数据输入信号
   logic[EXTDBITW-1:0]                             qea, qeb;      ///< RAM端口扩展非数组数据输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb, output qa, qb, qea, qeb);
   modport clip(input clk, aclr, sclr, qa, qb, qea, qeb, output wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da, dea);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db, deb);
endinterface
/*! \brief True Dual Port RAM for packed-unit-unpacked-array interface */
interface tdpram_2clk_packedunit_unpackedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic                            wea, web;                           ///< RAM端口写信号，高电平(1)有效
   logic                            clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addra, addrb;                       ///< RAM端口读写地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   logic[AUNITSIZ-1:0][DATABITW-1:0]qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db);
endinterface
interface tdpram_packedunit_unpackedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                            wea, web;                           ///< RAM端口写信号，高电平(1)有效
   logic                            clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addra, addrb;                       ///< RAM端口读写地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   logic[AUNITSIZ-1:0][DATABITW-1:0]qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clk, aclr, sclr, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db);
endinterface
/*! \brief True Dual Port RAM for packed-unit-unpacked-array with extra data interface */
interface tdpram_2clk_packedunit_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic                            wea, web;                           ///< RAM端口写信号，高电平(1)有效
   logic                            clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addra, addrb;                       ///< RAM端口读写地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   logic[AUNITSIZ-1:0][DATABITW-1:0]qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号
   logic[EXTDBITW-1:0]              dea, deb;                           ///< RAM端口扩展非数组数据输入信号
   logic[EXTDBITW-1:0]              qea, qeb;                           ///< RAM端口扩展非数组数据输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb, output qa, qb, qea, qeb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, qea, qeb, output wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da, dea);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db, deb);
endinterface
interface tdpram_packedunit_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic                            wea, web;                           ///< RAM端口写信号，高电平(1)有效
   logic                            clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]              addra, addrb;                       ///< RAM端口读写地址
   logic[AUNITSIZ-1:0][DATABITW-1:0]da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   logic[AUNITSIZ-1:0][DATABITW-1:0]qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号
   logic[EXTDBITW-1:0]              dea, deb;                           ///< RAM端口扩展非数组数据输入信号
   logic[EXTDBITW-1:0]              qea, qeb;                           ///< RAM端口扩展非数组数据输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb, output qa, qb, qea, qeb);
   modport clip(input clk, aclr, sclr, qa, qb, qea, qeb, output wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da, dea);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db, deb);
endinterface
/*! \brief True Dual Port RAM for unpacked-unit-unpacked-array interface */
interface tdpram_2clk_unpackedunit_unpackedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic              wea, web;                                                        ///< RAM端口写信号，高电平(1)有效
   logic              clkena, clkenb;                                                  ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]addra, addrb;                                                    ///< RAM端口读写地址
   logic[DATABITW-1:0]da[ARRAYSIZ-1:0][AUNITSIZ-1:0], db[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输入信号
   logic[DATABITW-1:0]qa[ARRAYSIZ-1:0][AUNITSIZ-1:0], qb[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db);
endinterface
interface tdpram_unpackedunit_unpackedarray_if #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic              wea, web;                                                        ///< RAM端口写信号，高电平(1)有效
   logic              clkena, clkenb;                                                  ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]addra, addrb;                                                    ///< RAM端口读写地址
   logic[DATABITW-1:0]da[ARRAYSIZ-1:0][AUNITSIZ-1:0], db[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输入信号
   logic[DATABITW-1:0]qa[ARRAYSIZ-1:0][AUNITSIZ-1:0], qb[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, output qa, qb);
   modport clip(input clk, aclr, sclr, qa, qb, output wea, web, clkena, clkenb, addra, addrb, da, db);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db);
endinterface
/*! \brief True Dual Port RAM for packed-unit-unpacked-array with extra data interface */
interface tdpram_2clk_unpackedunit_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clka, clkb,
   input  wire aclr,
   input  wire sclra, sclrb
);
   logic              wea, web;                                                        ///< RAM端口写信号，高电平(1)有效
   logic              clkena, clkenb;                                                  ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]addra, addrb;                                                    ///< RAM端口读写地址
   logic[DATABITW-1:0]da[ARRAYSIZ-1:0][AUNITSIZ-1:0], db[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输入信号
   logic[DATABITW-1:0]qa[ARRAYSIZ-1:0][AUNITSIZ-1:0], qb[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输出信号
   logic[EXTDBITW-1:0]dea, deb;                                                        ///< RAM端口扩展非数组数据输入信号
   logic[EXTDBITW-1:0]qea, qeb;                                                        ///< RAM端口扩展非数组数据输出信号

   modport ramp(input clka, clkb, aclr, sclra, sclrb, wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb, output qa, qb, qea, qeb);
   modport clip(input clka, clkb, aclr, sclra, sclrb, qa, qb, qea, qeb, output wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb);
   modport pap(input clka, aclr, sclra, qa, output wea, clkena, addra, da, dea);
   modport pbp(input clkb, aclr, sclrb, qb, output web, clkenb, addrb, db, deb);
endinterface
interface tdpram_unpackedunit_unpackedarray_extd_if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (
   input  bit  clk,
   input  wire aclr,
   input  wire sclr
);
   logic              wea, web;                                                        ///< RAM端口写信号，高电平(1)有效
   logic              clkena, clkenb;                                                  ///< RAM端口读写使能信号，高电平(1)有效
   localparam int addrBitw = miscs::minbitw_of_integer(ADDRLEN - 1, 32);
   logic[addrBitw-1:0]addra, addrb;                                                    ///< RAM端口读写地址
   logic[DATABITW-1:0]da[ARRAYSIZ-1:0][AUNITSIZ-1:0], db[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输入信号
   logic[DATABITW-1:0]qa[ARRAYSIZ-1:0][AUNITSIZ-1:0], qb[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输出信号
   logic[EXTDBITW-1:0]dea, deb;                                                        ///< RAM端口扩展非数组数据输入信号
   logic[EXTDBITW-1:0]qea, qeb;                                                        ///< RAM端口扩展非数组数据输出信号

   modport ramp(input clk, aclr, sclr, wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb, output qa, qb, qea, qeb);
   modport clip(input clk, aclr, sclr, qa, qb, qea, qeb, output wea, web, clkena, clkenb, addra, addrb, da, db, dea, deb);
   modport pap(input clk, aclr, sclr, qa, output wea, clkena, addra, da, dea);
   modport pbp(input clk, aclr, sclr, qb, output web, clkenb, addrb, db, deb);
endinterface
 `endif//__RAMS_ITF__

`else
 `undef  __ITF_BANNED__
`endif//__ITF_BANNED__

