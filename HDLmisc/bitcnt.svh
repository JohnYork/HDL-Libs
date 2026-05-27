/*!
 * \license SPDX-License-Identifier: MIT
 * \file bitcnt.svh
 * \brief 比特位统计器头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`ifdef  __INC_FROM_BITCNT__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_BITCNT__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __BITCNT_PKG__
 `define __BITCNT_PKG__
`include "miscs.svh"
package bitcnt_pkg;
   /*!
    * \brief 计算比特位统计器推荐的处理延迟
    * \param bitw 比特位统计器的输入数据位宽
    * \return int型，推荐的比特位统计器处理延迟
    */
   function automatic int delaytaps_recommend(int bitw);
      return miscs::minbitw_of_integer(bitw, 32);
   endfunction
endpackage
 `endif//__BITCNT_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef __BITCNT_ITF__
 `define __BITCNT_ITF__

 `endif//__BITCNT_ITF__

`else
 `undef  __ITF_BANNED__
`endif
