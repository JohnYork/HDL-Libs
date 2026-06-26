/*!
 * \license SPDX-License-Identifier: MIT
 * \file multconst.svh
 * \brief 整型常数乘法器的头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`include "miscs.svh"

`ifdef  __INC_FROM_MULTCONST__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_MULTCONST__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef  __MULTCONST_PKG__
 `define  __MULTCONST_PKG__
package multconst_pkg;
   /*! \brief 推荐的 #umultconst 模块最小延迟拍数 */
   localparam int recommended_mindelaytaps_umultconst = 2;
   /*! \brief 推荐的 #imultconst 模块最小延迟拍数 */
   localparam int recommended_mindelaytaps_imultconst = 3;
   /*! \brief 推荐的 #ulmultconst 模块最小延迟拍数 */
   localparam int recommended_mindelaytaps_ulmultconst = 3;
   /*! \brief 推荐的 #ilmultconst 模块最小延迟拍数 */
   localparam int recommended_mindelaytaps_ilmultconst = 4;
   /*!
    * \brief 计算整型常数乘法器的有符号变量位宽
    * \param minOfVar 变量最小值
    * \param maxOfVar 变量最大值
    * \return int型，变量的位宽
    */
   function automatic int bitwOfSignedVar(longint signed minOfVar, longint signed maxOfVar);
      int bitwOfMin, bitwOfMax;
      bitwOfMin = miscs::minbitw_of_signed_longint(minOfVar, $bits(minOfVar));
      bitwOfMax = miscs::minbitw_of_signed_longint(maxOfVar, $bits(maxOfVar));
      return bitwOfMin > bitwOfMax ? bitwOfMin : bitwOfMax;
   endfunction
   /*!
    * \brief 计算整型常数乘法器的无符号变量位宽
    * \param minOfVar 变量最小值
    * \param maxOfVar 变量最大值
    * \return int型，变量的位宽
    */
   function automatic int bitwOfUnsignedVar(longint minOfVar, longint maxOfVar);
      int bitwOfMin, bitwOfMax;
      bitwOfMin = miscs::minbitw_of_longint(minOfVar, $bits(minOfVar));
      bitwOfMax = miscs::minbitw_of_longint(maxOfVar, $bits(maxOfVar));
      return bitwOfMin > bitwOfMax ? bitwOfMin : bitwOfMax;
   endfunction
   /*!
    * \brief 计算常数为有符号型的有符号整型常数乘法器的结果位宽
    * \param minOfVar  变量最小值
    * \param maxOfVar  变量最大值
    * \param signedVar 有符号变量标志
    * \param constArg  常数数值
    * \return int型，结果位宽
    */
   function automatic int bitwOfSignedMultRes_constSigned(longint signed minOfVar, longint signed maxOfVar, bit signedVar, longint signed constArg);
      int constbitw, varMinBitw, varMaxBitw, bitwOfMin, bitwOfMax, ttrshft, rshftc, rshftv;
      longint signed constArgRsh, minOfVarRsh, maxOfVarRsh;
      constbitw = miscs::bits_of_signed_longint(constArg, 64);
      if (signedVar) begin
         varMinBitw = miscs::bits_of_signed_longint(minOfVar, 64);
         varMaxBitw = miscs::bits_of_signed_longint(maxOfVar, 64);
         $display("minOfVar = %0d(%0h) varMinBitw = %0d, maxOfVar = %0d(%0h) varMaxBitw = %0d, constbitw = %0d", minOfVar, minOfVar, varMinBitw, maxOfVar, maxOfVar, varMaxBitw, constbitw);
         if (constbitw + varMinBitw > 64) begin
            ttrshft = constbitw + varMinBitw - 64;
            rshftc = ttrshft/2;
            rshftv = ttrshft - rshftc;
         end else begin
            ttrshft = 0;
            rshftc = 0;
            rshftv = 0;
         end
         if (constArg < 0) constArgRsh = -((-constArg)>>>rshftc);
         else              constArgRsh = (constArg>>>rshftc);
         if (minOfVar < 0) minOfVarRsh = -((-minOfVar)>>>rshftv);
         else              minOfVarRsh = (minOfVar>>>rshftv);
         bitwOfMin = miscs::minbitw_of_signed_longint(minOfVarRsh*constArgRsh, 64) + ttrshft;
         $display("minOfVar = %0d(%0h), constArg = %0h, rshftv = %0d, rshftc = %0d, minOfVarRsh(%0d)*constArgRsh(%0d) = %0d(%0h), ttrshft = %0d, bitwOfMin = %0d", minOfVar, minOfVar, constArg, rshftv, rshftc, minOfVarRsh, constArgRsh, minOfVarRsh*constArgRsh, minOfVarRsh*constArgRsh, ttrshft, bitwOfMin);
         if (constbitw + varMaxBitw > 64) begin
            ttrshft = constbitw + varMaxBitw - 64;
            rshftc = ttrshft/2;
            rshftv = ttrshft - rshftc;
         end else begin
            ttrshft = 0;
            rshftc = 0;
            rshftv = 0;
         end
         if (constArg < 0) constArgRsh = -((-constArg)>>>rshftc);
         else              constArgRsh = (constArg>>>rshftc);
         if (maxOfVar < 0) maxOfVarRsh = -((-maxOfVar)>>>rshftv);
         else              maxOfVarRsh = (maxOfVar>>>rshftv);
         bitwOfMax = miscs::minbitw_of_signed_longint(maxOfVarRsh*constArgRsh, 64) + ttrshft;
         $display("maxOfVar = %0d(%0h), constArg = %0h, rshftv = %0d, rshftc = %0d, maxOfVarRsh(%0d)*constArgRsh(%0d) = %0d(%0h), ttrshft = %0d, bitwOfMax = %0d", maxOfVar, maxOfVar, constArg, rshftv, rshftc, maxOfVarRsh, constArgRsh, maxOfVarRsh*constArgRsh, maxOfVarRsh*constArgRsh, ttrshft, bitwOfMax);
      end else begin
         varMinBitw = miscs::bits_of_longint(minOfVar, 64);
         varMaxBitw = miscs::bits_of_longint(maxOfVar, 64);
         $display("minOfVar = %0d(%0h) varMinBitw = %0d, maxOfVar = %0d(%0h) varMaxBitw = %0d, constbitw = %0d", minOfVar, minOfVar, varMinBitw, maxOfVar, maxOfVar, varMaxBitw, constbitw);
         if (constbitw + varMinBitw > 64) begin
            ttrshft = constbitw + varMinBitw - 64;
            rshftc = ttrshft/2;
            rshftv = ttrshft - rshftc;
         end else begin
            ttrshft = 0;
            rshftc = 0;
            rshftv = 0;
         end
         if (constArg < 0) constArgRsh = -((-constArg)>>>rshftc);
         else              constArgRsh = (constArg>>>rshftc);
         minOfVarRsh = (minOfVar>>>rshftv);
         bitwOfMin = miscs::minbitw_of_signed_longint(minOfVarRsh*constArgRsh, 64) + ttrshft;
         $display("minOfVar = %0d(%0h), constArg = %0h, rshftv = %0d, rshftc = %0d, minOfVarRsh(%0d)*constArgRsh(%0d) = %0d(%0h), ttrshft = %0d, bitwOfMin = %0d", minOfVar, minOfVar, constArg, rshftv, rshftc, minOfVarRsh, constArgRsh, minOfVarRsh*constArgRsh, minOfVarRsh*constArgRsh, ttrshft, bitwOfMin);
         if (constbitw + varMaxBitw > 64) begin
            ttrshft = constbitw + varMaxBitw - 64;
            rshftc = ttrshft/2;
            rshftv = ttrshft - rshftc;
         end else begin
            ttrshft = 0;
            rshftc = 0;
            rshftv = 0;
         end
         if (constArg < 0) constArgRsh = -((-constArg)>>>rshftc);
         else              constArgRsh = (constArg>>>rshftc);
         maxOfVarRsh = (maxOfVar>>>rshftv);
         bitwOfMax = miscs::minbitw_of_signed_longint(maxOfVarRsh*constArgRsh, 64) + ttrshft;
         $display("maxOfVar = %0d(%0h), constArg = %0h, rshftv = %0d, rshftc = %0d, maxOfVarRsh(%0d)*constArgRsh(%0d) = %0d(%0h), ttrshft = %0d, bitwOfMax = %0d", maxOfVar, maxOfVar, constArg, rshftv, rshftc, maxOfVarRsh, constArgRsh, maxOfVarRsh*constArgRsh, maxOfVarRsh*constArgRsh, ttrshft, bitwOfMax);
      end
   // $display("constArg = %0d, constbitw = %0d, varMinBitw = %0d, varMaxBitw = %0d, bitwOfMin = %0d, bitwOfMax = %0d", constArg, constbitw, varMinBitw, varMaxBitw, bitwOfMin, bitwOfMax);
      return bitwOfMin > bitwOfMax ? bitwOfMin : bitwOfMax;
   endfunction
   /*!
    * \brief 计算常数为无符号型的有符号整型常数乘法器的结果位宽
    * \param minOfVar  变量最小值
    * \param maxOfVar  变量最大值
    * \param signedVar 有符号变量标志
    * \param constArg  常数数值
    * \return int型，结果位宽
    */
   function automatic int bitwOfSignedMultRes_constUnsigned(longint signed minOfVar, longint signed maxOfVar, bit signedVar, longint constArg);
      int constbitw, varMinBitw, varMaxBitw, bitwOfMin, bitwOfMax, ttrshft, rshftc, rshftv;
      int signed constArgRsh, minOfVarRsh, maxOfVarRsh;
      constbitw = miscs::bits_of_longint(constArg, 64);
      if (signedVar) begin
         varMinBitw = miscs::bits_of_signed_longint(minOfVar, 64);
         varMaxBitw = miscs::bits_of_signed_longint(maxOfVar, 64);
         if (constbitw + varMinBitw > 64) begin
            ttrshft = constbitw + varMinBitw - 64;
            rshftc = ttrshft/2;
            rshftv = ttrshft - rshftc;
         end else begin
            ttrshft = 0;
            rshftc = 0;
            rshftv = 0;
         end
         constArgRsh = (constArg>>>rshftc);
         if (minOfVar < 0) minOfVarRsh = -((-minOfVar)>>>rshftv);
         else              minOfVarRsh = (minOfVar>>>rshftv);
         bitwOfMin = miscs::minbitw_of_signed_longint(minOfVarRsh*constArgRsh, 64) + ttrshft;
         if (constbitw + varMaxBitw > 64) begin
            ttrshft = constbitw + varMaxBitw - 64;
            rshftc = ttrshft/2;
            rshftv = ttrshft - rshftc;
         end else begin
            ttrshft = 0;
            rshftc = 0;
            rshftv = 0;
         end
         constArgRsh = (constArg>>>rshftc);
         if (maxOfVar < 0) maxOfVarRsh = -((-maxOfVar)>>>rshftv);
         else              maxOfVarRsh = (maxOfVar>>>rshftv);
         bitwOfMax = miscs::minbitw_of_signed_longint((signed'(maxOfVar>>>rshftv))*(signed'(constArg>>rshftc)), 64) + ttrshft;
      end else begin
         varMinBitw = miscs::bits_of_longint(minOfVar, 64);
         varMaxBitw = miscs::bits_of_longint(maxOfVar, 64);
         if (constbitw + varMinBitw > 64) begin
            ttrshft = constbitw + varMinBitw - 64;
            rshftc = ttrshft/2;
            rshftv = ttrshft - rshftc;
         end else begin
            ttrshft = 0;
            rshftc = 0;
            rshftv = 0;
         end
         constArgRsh = (constArg>>>rshftc);
         minOfVarRsh = (minOfVar>>>rshftv);
         bitwOfMin = miscs::minbitw_of_signed_longint(minOfVarRsh*constArgRsh, 64) + ttrshft;
         if (constbitw + varMaxBitw > 64) begin
            ttrshft = constbitw + varMaxBitw - 64;
            rshftc = ttrshft/2;
            rshftv = ttrshft - rshftc;
         end else begin
            ttrshft = 0;
            rshftc = 0;
            rshftv = 0;
         end
         constArgRsh = (constArg>>>rshftc);
         maxOfVarRsh = (maxOfVar>>>rshftv);
         bitwOfMax = miscs::minbitw_of_signed_longint(maxOfVarRsh*constArgRsh, 64) + ttrshft;
      end
      return bitwOfMin > bitwOfMax ? bitwOfMin : bitwOfMax;
   endfunction
   /*!
    * \brief 根据常数位宽计算有符号整型常数乘法器的结果位宽
    * \param minOfVar    变量最小值
    * \param maxOfVar    变量最大值
    * \param signedVar   有符号变量标志
    * \param constBitw   常数位宽
    * \param constArg    常数数值
    * \param signedConst 有符号常数标志
    * \return int型，结果位宽
    */
   function automatic int bitwOfSignedMultRes_constBitw(longint signed minOfVar, longint signed maxOfVar, bit signedVar, int constBitw, longint signed constArg, bit signedConst);
      longint signed maxConst, minConst;
      int bitwOfConstMulMinOfVar, bitwOfConstMulMaxOfVar;
      maxConst = ~((-longint'(1))<<<(constBitw-(int'(signedConst))));
      if (signedConst) begin
         minConst = - maxConst;
         if (constArg == minConst - 1) minConst = minConst - 1;
      end
      else begin
         minConst = 0;
      end
      // $display("DBG: maxConst = 'h%h, minConst = 'h%h", maxConst, minConst);
      if (signedVar) begin
         bitwOfConstMulMinOfVar = bitwOfSignedMultRes_constSigned(
            .minOfVar(minConst),
            .maxOfVar(maxConst),
            .signedVar(signedConst),
            .constArg(minOfVar)
         );
         bitwOfConstMulMaxOfVar = bitwOfSignedMultRes_constSigned(
            .minOfVar(minConst),
            .maxOfVar(maxConst),
            .signedVar(signedConst),
            .constArg(maxOfVar)
         );
      end
      else begin
         bitwOfConstMulMinOfVar = bitwOfSignedMultRes_constUnsigned(
            .minOfVar(minConst),
            .maxOfVar(maxConst),
            .signedVar(signedConst),
            .constArg(minOfVar)
         );
         bitwOfConstMulMaxOfVar = bitwOfSignedMultRes_constUnsigned(
            .minOfVar(minConst),
            .maxOfVar(maxConst),
            .signedVar(signedConst),
            .constArg(maxOfVar)
         );
      end
      // $display("DBG: bitwOfConstMulMinOfVar = 'h%h, bitwOfConstMulMaxOfVar = 'h%h", bitwOfConstMulMinOfVar, bitwOfConstMulMaxOfVar);
      return (bitwOfConstMulMinOfVar > bitwOfConstMulMaxOfVar) ? bitwOfConstMulMinOfVar : bitwOfConstMulMaxOfVar;
   endfunction
   /*!
    * \brief 计算常数为无符号型的无符号整型常数乘法器的结果位宽
    * \param minOfVar  变量最小值
    * \param maxOfVar  变量最大值
    * \param constArg  常数数值
    * \return int型，结果位宽
    */
   function automatic int bitwOfUnsignedMultRes_constUnsigned(longint unsigned minOfVar, longint unsigned maxOfVar, longint constArg);
      int constbitw, varMinBitw, varMaxBitw, bitwOfMin, bitwOfMax, ttrshft, rshftc, rshftv;
      constbitw = miscs::bits_of_longint(constArg, 64);
      varMinBitw = miscs::bits_of_longint(minOfVar, 64);
      varMaxBitw = miscs::bits_of_longint(maxOfVar, 64);
      if (constbitw + varMinBitw > 64) begin
         ttrshft = constbitw + varMinBitw - 64;
         rshftc = ttrshft/2;
         rshftv = ttrshft - rshftc;
      end else begin
         ttrshft = 0;
         rshftc = 0;
         rshftv = 0;
      end
      bitwOfMin = miscs::minbitw_of_longint((minOfVar>>rshftv)*(constArg>>rshftc), 64) + ttrshft;
      if (constbitw + varMaxBitw > 64) begin
         ttrshft = constbitw + varMaxBitw - 64;
         rshftc = ttrshft/2;
         rshftv = ttrshft - rshftc;
      end else begin
         ttrshft = 0;
         rshftc = 0;
         rshftv = 0;
      end
      bitwOfMax = miscs::minbitw_of_longint((maxOfVar>>rshftv)*(constArg>>rshftc), 64) + ttrshft;
      return bitwOfMin > bitwOfMax ? bitwOfMin : bitwOfMax;
   endfunction
   /*!
    * \brief 根据常数位宽计算无符号整型常数乘法器的结果位宽
    * \param minOfVar    变量最小值
    * \param maxOfVar    变量最大值
    * \param constBitw   常数位宽
    * \return int型，结果位宽
    */
   function automatic int bitwOfUnsignedMultRes_constBitw(longint minOfVar, longint maxOfVar, int constBitw);
      longint signed maxConst, minConst;
      int bitwOfConstMulMinOfVar, bitwOfConstMulMaxOfVar;
      maxConst = ~((-longint'(1))<<<constBitw);
      minConst = 0;
      bitwOfConstMulMinOfVar = bitwOfUnsignedMultRes_constUnsigned(
         .minOfVar(minConst),
         .maxOfVar(maxConst),
         .constArg(minOfVar)
      );
      bitwOfConstMulMaxOfVar = bitwOfUnsignedMultRes_constUnsigned(
         .minOfVar(minConst),
         .maxOfVar(maxConst),
         .constArg(maxOfVar)
      );
      return (bitwOfConstMulMinOfVar > bitwOfConstMulMaxOfVar) ? bitwOfConstMulMinOfVar : bitwOfConstMulMaxOfVar;
   endfunction
endpackage
 `endif// __MULTCONST_PKG__

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

