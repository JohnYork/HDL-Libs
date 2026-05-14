/*!
 * \license SPDX-License-Identifier: MIT
 * \file partmux.svh
 * \brief 数据分块多路复用选择器，头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`ifdef  __INC_FROM_PARTMUX__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_PARTMUX__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __PARTMUX_PKG__
 `define __PARTMUX_PKG__
`include "mux.svh"
package partmux_pkg;
   /*!
    * \brief 计算数据分块多路复用选择器的分块数
    * \param dataBitw 待分块的数据位宽
    * \param partBitw 分块位宽
    * \return int型，数据分块多路复用器输出的分块数
    */
   function automatic int partCntOfDataBitw(int dataBitw, int partBitw);
      if (dataBitw <= 0) return 1;
      partCntOfDataBitw = dataBitw / partBitw;
      if (partCntOfDataBitw*partBitw < dataBitw) partCntOfDataBitw = partCntOfDataBitw + 1;
      return partCntOfDataBitw;
   endfunction
   /*!
    * \brief 计算分块多路复用选择器选通需要的最少延迟拍数
    * \param dataBitw 待分块的数据位宽
    * \param partBitw 分块位宽
    * \return int型，需要的最少延迟拍数
    */
   function automatic int delaytaps4partmux_minimum(int dataBitw, int partBitw);
      return mux_pkg::delaytaps4mux_minimum(partCntOfDataBitw(dataBitw, partBitw));
   endfunction
   /*!
    * \brief 计算分块多路复用选择器选通推荐使用的延迟拍数
    * \param dataBitw 待分块的数据位宽
    * \param partBitw 分块位宽
    * \return int型，需要的最少延迟拍数
    */
   function automatic int delaytaps4partmux_recommend(int dataBitw, int partBitw);
      return mux_pkg::delaytaps4mux_recommend(partCntOfDataBitw(dataBitw, partBitw));
   endfunction
endpackage: partmux_pkg
 `endif//__PARTMUX_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__
`else
 `undef  __ITF_BANNED__
`endif

