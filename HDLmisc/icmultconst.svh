/*!
 * \license SPDX-License-Identifier: MIT
 * \file icmultconst.svh
 * \brief 整型常数复数乘法器的头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`include "miscs.svh"
`include "multconst.svh"

`ifdef  __INC_FROM_ICMULTCONST__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_ICMULTCONST__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __ICMULTCONST_PKG__
 `define __ICMULTCONST_PKG__
package icmultconst_pkg;
   /*!
    * \brief 计算整型常数复数乘法器的结果位宽
    * \param real_minVar 变量实部最小值
    * \param real_maxVar 变量实部最大值
    * \param const_real  常量实部值
    * \param imag_minVar 变量虚部最小值
    * \param imag_maxVar 变量虚部最大值
    * \param const_imag  常量虚部值
    * \return int型，结果复数各分部的位宽最大值
    */
   function automatic int bitwOfCplxResPart(int real_minVar, int real_maxVar, int const_real, int imag_minVar, int imag_maxVar, int const_imag);
      longint signed real_minOfRes_rmr, real_maxOfRes_rmr, real_minOfRes_imi, real_maxOfRes_imi, real_minOfRes, real_maxOfRes, minOfRes;
      longint signed imag_minOfRes_rmi, imag_maxOfRes_rmi, imag_minOfRes_imr, imag_maxOfRes_imr, imag_minOfRes, imag_maxOfRes, maxOfRes;
      real_minOfRes_rmr = (longint'(signed'(real_minVar)))*(longint'(signed'(const_real)));
      real_maxOfRes_rmr = (longint'(signed'(real_maxVar)))*(longint'(signed'(const_real)));
      real_minOfRes_imi = (longint'(signed'(imag_minVar)))*(longint'(signed'(const_imag)));
      real_maxOfRes_imi = (longint'(signed'(imag_maxVar)))*(longint'(signed'(const_imag)));
      if (real_minOfRes_rmr > real_maxOfRes_rmr) begin
         real_minOfRes_rmr = real_minOfRes_rmr ^ real_maxOfRes_rmr;
         real_maxOfRes_rmr = real_minOfRes_rmr ^ real_maxOfRes_rmr;
         real_minOfRes_rmr = real_minOfRes_rmr ^ real_maxOfRes_rmr;
      end
      if (real_minOfRes_imi > real_maxOfRes_imi) begin
         real_minOfRes_imi = real_minOfRes_imi ^ real_maxOfRes_imi;
         real_maxOfRes_imi = real_minOfRes_imi ^ real_maxOfRes_imi;
         real_minOfRes_imi = real_minOfRes_imi ^ real_maxOfRes_imi;
      end
      real_minOfRes = real_minOfRes_rmr - real_maxOfRes_imi;
      real_maxOfRes = real_maxOfRes_rmr - real_minOfRes_imi;
      imag_minOfRes_rmi = (longint'(signed'(real_minVar)))*(longint'(signed'(const_imag)));
      imag_maxOfRes_rmi = (longint'(signed'(real_maxVar)))*(longint'(signed'(const_imag)));
      imag_minOfRes_imr = (longint'(signed'(imag_minVar)))*(longint'(signed'(const_real)));
      imag_maxOfRes_imr = (longint'(signed'(imag_maxVar)))*(longint'(signed'(const_real)));
      if (imag_minOfRes_rmi > imag_maxOfRes_rmi) begin
         imag_minOfRes_rmi = imag_minOfRes_rmi ^ imag_maxOfRes_rmi;
         imag_maxOfRes_rmi = imag_minOfRes_rmi ^ imag_maxOfRes_rmi;
         imag_minOfRes_rmi = imag_minOfRes_rmi ^ imag_maxOfRes_rmi;
      end
      if (imag_minOfRes_imr > imag_maxOfRes_imr) begin
         imag_minOfRes_imr = imag_minOfRes_imr ^ imag_maxOfRes_imr;
         imag_maxOfRes_imr = imag_minOfRes_imr ^ imag_maxOfRes_imr;
         imag_minOfRes_imr = imag_minOfRes_imr ^ imag_maxOfRes_imr;
      end
      imag_minOfRes = imag_minOfRes_rmi + imag_minOfRes_imr;
      imag_maxOfRes = imag_maxOfRes_rmi + imag_maxOfRes_imr;
      if (real_minOfRes < imag_minOfRes) minOfRes = real_minOfRes;
      else                               minOfRes = imag_minOfRes;
      if (real_maxOfRes > imag_maxOfRes) maxOfRes = real_maxOfRes;
      else                               maxOfRes = imag_maxOfRes;
      return multconst_pkg::bitwOfSignedVar( .minOfVar(minOfRes), .maxOfVar(maxOfRes));
   endfunction
   /*!
    * \brief 计算延迟建议值
    * \param min_area    最小面积标志
    * \param usehardcore 使用硬件乘法器核标志
    */
   function automatic int delaytapsrecommend(bit use3multp, bit usehardcore);
      return 1 + int'(use3multp) + (usehardcore ? 1 : 3) + 1;
   endfunction
endpackage
 `endif//__ICMULTCONST_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef __ICMULTCONST_ITF__
 `define __ICMULTCONST_ITF__

 `endif//__ICMULTCONST_ITF__

`else
 `undef  __ITF_BANNED__
`endif

