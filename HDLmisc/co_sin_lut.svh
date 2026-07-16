/*!
 * \license SPDX-License-Identifier: MIT
 * \file co_sin_lut.svh
 * \brief 正弦、余弦函数查找表头文件
 */
`ifdef  __INC_FROM_CO_SIN_LUT__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_CO_SIN_LUT__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __CO_SIN_LUT_PKG__
 `define __CO_SIN_LUT_PKG__
package co_sin_lut_pkg;
   /*!
    * \brief 整型查找表输出时延
    * \param memmode 存储器资源使用模式
    */
   function automatic int delaytaps_i(int memmode);
      return 2 + (memmode > 0 ? 1 : 0);
   endfunction
endpackage
 `endif//__CO_SIN_LUT_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef __CO_SIN_LUT_ITF__
 `define __CO_SIN_LUT_ITF__

 `endif//__CO_SIN_LUT_ITF__

`else
 `undef  __ITF_BANNED__
`endif
