/*!
 * \license SPDX-License-Identifier: MIT
 * \file norm.sv
 * \brief 统计有符号数中冗余符号位位数模块的头文件
 * \author JohnYork <johnyork@yeah.net>
 */

`ifdef  __INC_FROM_NORM__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_NORM__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef  __NORM_PKG__
 `define  __NORM_PKG__
`include "miscs.svh"
`include "mux.svh"
package norm_pkg;
   /*! \brief 数据位宽对应的运算处理分级数 */
   function automatic int stageCountOfDataBitw(int unsigned databitw);
      return miscs::minbitw_of_integer(databitw - 1, 31);
   endfunction
   /*! \brief 冗余符号位数值的最小位宽 */
   function automatic int minBitwOfReduBits(int unsigned databitw);
      return miscs::minbitw_of_integer(databitw - 1, 31);
   endfunction
   /*! \brief 推荐的延迟拍数 */
   function automatic int delaytaps_recommend(int unsigned databitw);
      return mux_pkg::delaytaps4mux_recommend(.inputcnt(databitw));
   endfunction
endpackage: norm_pkg
 `endif// __NORM_PKG__

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

