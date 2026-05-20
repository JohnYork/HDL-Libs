/*!
 * \license SPDX-License-Identifier: MIT
 * \file array_partmux.svh
 * \brief 数组元素分块多路复用器，头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`include "mux.svh"

`ifdef  __INC_FROM_ARRAY_PARTMUX__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_ARRAY_PARTMUX__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __ARRAY_PARTMUX_PKG__
 `define __ARRAY_PARTMUX_PKG__
package array_partmux_pkg;
   /*!
    * \brief 计算数组分块多路复用时的分块数
    * \param array_siz    数组元素个数
    * \param cnt_per_part 每个数组分块包含的元素个数
    * \return int型，数组的分块数
    */
   function automatic int partCnt_ofArray(int array_siz, int cnt_per_part);
      return (array_siz + cnt_per_part - 1)/cnt_per_part;
   endfunction
   /*!
    * \brief 计算数组分块多路复用时平均每块的元素个数
    * \param array_siz 数组元素个数
    * \param parts     数组分块数
    * \return int型，每块最多元素个数
    */
   function automatic int cntPerPart_ofArrayParts(int array_siz, int parts);
      cntPerPart_ofArrayParts = array_siz / parts;
      if (cntPerPart_ofArrayParts*parts < array_siz) cntPerPart_ofArrayParts = cntPerPart_ofArrayParts + 1;
      return cntPerPart_ofArrayParts;
   endfunction

   /*! \brief 计算数组分块多路复用选择器选通需要的最少延迟拍数 */
   function automatic int delaytaps4arraypartmux_minimum(int parts);
      return mux_pkg::delaytaps4mux_minimum(parts);
   endfunction
   /*! \brief 计算数组分块多路复用选择器选通推荐使用的延迟拍数 */
   function automatic int delaytaps4arraypartmux_recommend(int parts);
      return mux_pkg::delaytaps4mux_recommend(parts);
   endfunction
endpackage: array_partmux_pkg
 `endif//__ARRAY_PARTMUX_PKG__

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

