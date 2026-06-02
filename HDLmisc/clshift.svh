/*!
 * \license SPDX-License-Identifier: MIT
 * \file clshift.svh
 * \brief 逻辑、算术移位器的头文件
 * \author JohnYork <johnyork@yeah.net>
 */

`ifdef  __INC_FROM_CLSHIFT__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_CLSHIFT__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __CLSHIFT_PKG__
 `define __CLSHIFT_PKG__
`include "miscs.svh"
`include "mux.svh"
package clshift_pkg;
   /*! \brief 计算移位器处理级数 */
   function automatic int stageCountOfDataBitw(int unsigned databitw);
      return miscs::minbitw_of_integer(databitw, 31);
   endfunction
   /*! \brief 推荐的处理延迟拍数 */
   function automatic int delaytaps_recommend(int unsigned databitw);
      return mux_pkg::delaytaps4mux_recommend(.inputcnt(databitw));
   endfunction
   /*! \brief 计算移位器移位位数位宽 */
   function automatic int distanceBitwOfDataBitw(int unsigned databitw);
      return miscs::minbitw_of_integer(databitw, 31);
   endfunction
endpackage: clshift_pkg
 `endif//__CLSHIFT_PKG__

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

