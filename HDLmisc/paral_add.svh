/*!
 * \license SPDX-License-Identifier: MIT
 * \file paral_add.svh
 * \brief 并行加法器头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`include "miscs.svh"

`ifdef  __INC_FROM_PARAL_ADD__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_PARAL_ADD__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __PARAL_ADD_PKG__
 `define __PARAL_ADD_PKG__
package paral_add_pkg;
   /*!
    * \brief 计算并行加法器的结果位宽
    * \param databitw 并行加法器输入数据单位位宽
    * \param paralcnt 并行加法器输入数据路数
    * \return int型，并行加法器结果位宽
    */
   function automatic int bitwof_fixedres(int databitw, int paralcnt);
      return miscs::minbitw_of_integer(.value(paralcnt), .maxbitw(32)) - 1 + databitw;
   endfunction
   /*!
    * \brief 计算并行加法器的推荐延迟拍数
    * \param paralcnt 并行加法器输入数据路数
    * \param fpebitw  浮点数指数位宽，0-表示针对无符号整数实现并行加法器，1-表示针对有符号整数实现并行加法器，>1-表示针对IEEE754型浮点数实现并行加法器
    * \return int型，并行加法器的推荐延迟拍数
    */
   function automatic int delaytaps_recommend(int paralcnt, int fpebitw);
      return miscs::minbitw_of_integer(paralcnt - 1, 32) + (fpebitw > 1 ? 0 : 0);
   endfunction
endpackage//paral_add_pkg
 `endif//__PARAL_ADD_PKG__

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

