/*!
 * \license SPDX-License-Identifier: MIT
 * \file array_partadapter.svh
 * \brief 数组元素分块合路适配器的头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`ifdef  __INC_FROM_ARRAY_PARTADAPTER__
`ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_ARRAY_PARTADAPTER__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __ARRAY_PARTADAPTER_PKG__
 `define __ARRAY_PARTADAPTER_PKG__
package array_partadapter_pkg;
   /*! \brief 处理时延 */
   function automatic int delaytaps(
      int adaptcnt,  ///< 数组元素适配分块数
      int outmode    ///< 输出模式：
                     ///< 0-无延迟输出，不保持输出结果，消耗最少逻辑和寄存器资源，时序性能较好；
                     ///< 1-无延迟输出但保持输出结果，消耗额外的逻辑和寄存器资源，时序性能较为紧张；
                     ///< 2-延迟输出且保持输出结果，消耗额外的寄存器资源，时序性能较好。
   );
      if (adaptcnt <= 1) return 0;
      else               return (outmode == 2)
                                ? 1
                                : 0;
   endfunction
endpackage
 `endif//__ARRAY_PARTADAPTER_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef __ARRAY_PARTADAPTER_ITF__
 `define __ARRAY_PARTADAPTER_ITF__

 `endif//__ARRAY_PARTADAPTER_ITF__

`else
 `undef  __ITF_BANNED__
`endif