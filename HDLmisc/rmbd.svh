/*!
 * \license SPDX-License-Identifier: MIT
 * \file rmbd.svh
 * \brief 从低位向高位搜索给定值的比特位，并返回搜索到的比特位的位置索引－LSB为0。
 * \author JohnYork <johnyork@yeah.net>
 */
`include "miscs.svh"
`include "mux.svh"

`ifdef  __INC_FROM_RMBD__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`endif//__INC_FROM_RMBD__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __RMBD_PKG__
 `define __RMBD_PKG__
package rmbd_pkg;
   /*! \brief 计算比特搜索器的处理级数 */
   function automatic int stageCountOfDataBitw(int unsigned databitw);
      return miscs::minbitw_of_integer(
                     .value   (databitw-1 ),
                     .maxbitw ($bits(int) )) + 1;
   endfunction
   /*! \brief 推荐的处理延迟拍数 */
   function automatic int delaytaps_recommend(int unsigned databitw);
      return (stageCountOfDataBitw(databitw)+mux_pkg::mux_maxstage_pertap*2-1)/(mux_pkg::mux_maxstage_pertap*2);
   endfunction
   /*! \brief 推荐的比特搜索器位置索引位宽 */
   function automatic int iposbw_recommend(int unsigned databitw);
      return miscs::minbitw_of_integer(
                     .value   (databitw   ),
                     .maxbitw ($bits(int) ));
   endfunction
endpackage: rmbd_pkg
 `endif//__RMBD_PKG__

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

