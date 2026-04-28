/*!
 * \license SPDX-License-Identifier: MIT
 * \file shifttaps.svh
 * \brief 自动选择资源类型的移阶寄存器
 * \author JohnYork <johnyork@yeah.net>
 */
 `ifdef  __INC_FROM_SHIFTTAPS__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_SHIFTTAPS__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __SHIFTTAPS_PKG__
 `define __SHIFTTAPS_PKG__
package shifttaps_pkg;
   /*! \brief 模块 #shiftvartaps 从 #outtap 信号置位到对应延迟拍数的数据输出建立之间的延迟拍数 */
   localparam int delaytaps_onouttap_of_shiftvartaps = 3;
endpackage
 `endif//__SHIFTTAPS_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef __SHIFTTAPS_ITF__
 `define __SHIFTTAPS_ITF__

 `endif//__SHIFTTAPS_ITF__

`else
 `undef  __ITF_BANNED__
`endif
