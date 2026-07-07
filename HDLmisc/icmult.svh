/*!
 * \license SPDX-License-Identifier: MIT
 * \file icmult.svh
 * \brief 整型复数乘法器的头文件
 * \author JohnYork <johnyork@yeah.net>
 */

`ifdef  __INC_FROM_ICMULT__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_ICMULT__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __ICMULT_PKG__
 `define __ICMULT_PKG__

package icmult_pkg;
   /*!
    * \brief 计算复数乘法器结果的最小不截位位宽
    * \param aPartBitw 输入复数a的实部、虚部位宽
    * \param bPartBitw 输入复数b的实部、虚部位宽
    * \return int型，结果复数的实部、虚部不产生截位的最小位宽
    */
   function automatic int resPartBitw(int aPartBitw, int bPartBitw);
      return (aPartBitw - 1/*有符号整数去掉符号位才是用于计算的有效位*/) + (bPartBitw - 1/*有符号整数去掉符号位才是用于计算的有效位*/)
             + 1/*A与B的实部虚部互相乘积后再相加*/ + 1/*结果加上符号位*/;
   endfunction
   /*!
    * \brief 根据复数乘法器结果的最小不截位位宽计算输入参数的实部、虚部位宽
    * \param resPartBitw 结果的最小不截位位宽
    * \param in2PartBitw 第二输入参数的实部、虚部位宽
    * \return 第一输入参数的实部、虚部位宽。
    */
   function automatic int inPartBitw(int resPartBitw, int in2PartBitw);
      return resPartBitw - 1/*结果加上符号位*/ - 1/*A与B的实部虚部互相乘积后再相加*/ - (in2PartBitw - 1/*有符号整数去掉符号位才是用于计算的有效位*/) + 1/*有符号整数去掉符号位才是用于计算的有效位*/;
   endfunction
   /*!
    * \brief 计算整型复数乘法器的推荐延迟拍数
    * \param use3multp 使用三乘法器版本标志，1'b0-使用标准的4乘法器算法实现复数乘法器，1'b1-使用3乘法器算法实现复数乘法器
    * \return int型，整型复数乘法器的推荐延迟拍数
    */
   function automatic int delaytapsrecommend(bit use3multp);
      return int'(use3multp)/*pre-add*/ + 1/*multiply*/ + 1/*post-add*/;
   endfunction
endpackage

 `endif//__ICMULT_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef __ICMULT_ITF__
 `define __ICMULT_ITF__

 `endif//__ICMULT_ITF__

`else
 `undef  __ITF_BANNED__
`endif
