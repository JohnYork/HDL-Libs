/*!
 * \license SPDX-License-Identifier: MIT
 * \file lmbd.svh
 * \brief 从高位向低位搜索给定值比特位模块的头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`include "miscs.svh"
`include "mux.svh"

`ifdef  __INC_FROM_LMBD__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_LMBD__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef  __LMBD_PKG__
 `define  __LMBD_PKG__
package lmbd_pkg;
   /*! \brief 计算比特搜索器的处理级数 */
   function automatic int stageCountOfDataBitw(int unsigned databitw);
      return miscs::minbitw_of_integer(
                     .value   (databitw-1 ),
                     .maxbitw ($bits(int) )) + 1;
   endfunction
   /*! \brief 推荐的处理延迟拍数 */
   function automatic int delaytaps_recommend(int unsigned databitw);
      return (stageCountOfDataBitw(.databitw(databitw))+mux_pkg::mux_maxstage_pertap*2-1)/(mux_pkg::mux_maxstage_pertap*2);
   endfunction
   /*! \brief 推荐的比特搜索器位置索引位宽 */
   function automatic int iposbw_recommend(int unsigned databitw);
      return miscs::minbitw_of_integer(
                     .value   (databitw   ),
                     .maxbitw ($bits(int) ));
   endfunction
endpackage: lmbd_pkg
 `endif// __LMBD_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__INC_INTERFACE__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__
`else
 `undef  __ITF_BANNED__
`endif

