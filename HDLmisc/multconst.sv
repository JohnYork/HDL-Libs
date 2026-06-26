/*!
 * \license SPDX-License-Identifier: MIT
 * \file multconst.sv
 * \brief 整型常数乘法器
 * \details umultconst 实现无符号整型数乘以无符号型常数的乘法。imultconst 实现有符号/无符号整型数乘以有符号型常数的乘法
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, paral_add, pipedelay, roundint
 */
`include "miscs.svh"
`include "paral_add.svh"
`define __INC_FROM_MULTCONST__
`include "multconst.svh"
`timescale 1ps/1ps
module __umultconst_intnl_shift #(
   parameter int SHIFT_BITS,
   parameter int SHIFTRES_IDXARRAY[0:SHIFT_BITS],
   parameter int SHIFTRES_ARRAY_CNT,
   parameter int unsigned CONSTARG,
   parameter bit MASK_ZERO,
   parameter int VAR_BITW,
   parameter int CONSTBITW_USE,
   parameter int RESBITW_E,
   parameter int MULTCHK_PARTCNT
) (
   input  wire[VAR_BITW-1:0]  var_arg,
   output wire[RESBITW_E-1:0] shiftres[0:SHIFTRES_ARRAY_CNT-1]
);
   localparam int shiftres_shift_cnt = SHIFTRES_IDXARRAY[0];
   genvar ishift, ioffset; generate
      for (ishift = 0; ishift < shiftres_shift_cnt; ishift++) begin: SHIFT
         localparam int ibit2shft = SHIFTRES_IDXARRAY[ishift+1];
         initial if (ibit2shft < 0) $error("umultconst: got unexpect ibit2shft(%0d) at array index %0d", ibit2shft, ishift);
         wire [RESBITW_E-1:0] mask_res;
         if (ibit2shft > 0) assign mask_res[ibit2shft-1:0] = '0;
         for (ioffset = 0; ioffset < MULTCHK_PARTCNT; ioffset++) begin: DUPLIC
            localparam int ioffset2fill = ioffset*VAR_BITW + ibit2shft;
            initial if (ioffset2fill < 0) $error("umultconst: bad ioffset2fill(%0d)", ioffset2fill);
            if (ioffset2fill+VAR_BITW > 0) begin
               localparam int maskres_ilsb2fill = ioffset2fill > 0 ? ioffset2fill : 0;
               if (ioffset2fill < CONSTBITW_USE && ioffset2fill + VAR_BITW <= RESBITW_E)
                  assign mask_res[ioffset2fill+VAR_BITW-1:ioffset2fill] = (CONSTARG[ioffset2fill]^MASK_ZERO) ? var_arg[VAR_BITW-1:0] : '0;
               else assign mask_res[RESBITW_E-1:ioffset2fill] = '0;
            end
         end
         localparam int msbits2zero = RESBITW_E - ibit2shft - MULTCHK_PARTCNT*VAR_BITW;
         if (msbits2zero > 0) assign mask_res[RESBITW_E-1:RESBITW_E-msbits2zero] = '0;
         assign shiftres[ishift] = mask_res;
      end
      if (MASK_ZERO) assign shiftres[SHIFTRES_ARRAY_CNT - 1] = var_arg[VAR_BITW-1:0];
   endgenerate
endmodule
/*! \brief 整型常数乘法器运算用函数 */
package multconst_localpkg;
   /*!
    * \brief 乘法运算结果中需要为输入结果位宽而保留的数据位宽
    * \param resbitw_e 根据例化参数 MINOF_VAR, MAXOF_VAR 和 constbitw_use 预测的结果位宽
    * \param resbitw_i 根据例化参数 varbitwbyinput(VARBITW) 和 constbitw_use 预测的结果位宽
    * \param RESBITW   用户指定的例化参数 RESBITW 的值
    *             resbitw_e <= [MINOF_VAR, MAXOF_VAR, constbitw_use]
    *             |----------------------------------------------------------|
    *         resbitw_i <= [varbitwbyinput(VARBITW), constbitw_use]                            VARBITW >= var_bitw[MINOF_VAR, MAXOF_VAR]
    *         |--------------------------------------------------------------|
    *         
    *         |----------------------(RESBITW = 0)---------------------------|
    *             |-iMsbOfPipeRes                                            |-iLsbOfPipeRes
    *               iMsbOfPipeRes_inVarConstRes = resbitw_e - 1,               iLsbOfPipeRes_inVarConstRes = 0
    *               iMsbOfPipeRes_inInputRes    = resbitw_e - 1,               iLsbOfPipeRes_inInputRes    = 0
    *
    *         |-------------------(RESBITW > 0)----------------------|-------|------|
    *             |-iMsbOfPipeRes                                                   |-iLsbOfPipeRes
    *               iMsbOfPipeRes_inVarConstRes = res_bitw_e - 1                      iLsbOfPipeRes_inVarConstRes = resbitw_i - RESBITW (resbitw_i >= RESBITW)
    *                                            + ((resbitw_i < RESBITW)                                        或 0                   (resbitw_i  < RESBITW)
    *                                               ? (RESBITW - resbitw_i)
    *                                               : 0;
    *               iMsbOfPipeRes_inInputRes    =  \                                  iLsbOfPipeRes_inInputRes    = 0                     (resbitw_i >= RESBITW)
    *                                               |                                                            或 RESBITW - resbitw_i   (resbitw_i <  RESBITW)
    *                                           RESBITW  < resbitw_i : resbitw_e - 1 - (resbitw_i - RESBITW)
    *                                           RESBITW >= resbitw_i : resbitw_e - 1 + (RESBITW - resbitw_i)
    *
    * |-------|--------|-------------------(RESBITW < 0)---------------------|
    * |-iMsbOfPipeRes                                                        |-iLsbOfPipeRes
    *   iMsbOfPipeRes_inVarConstRes = (resbitw_e >= (-RESBITW))                iLsbOfPipeRes_inVarConstRes = 0
    *                                 ? ((-RESBITW) - 1)
    *                                 : resbitw_e - 1
    *   iMsbofPipeRes_inInputRes    = (resbitw_e >= (-RESBITW))                iLsbOfPipeRes_inInputRes    = 0
    *                                 ? ((-RESBITW) - 1)
    *                                 : resbitw_e - 1
    */
   function automatic int iMsbOfPipeRes_inVarConstRes(
      int resbitw_e,
      int resbitw_i,
      int RESBITW
   );
      int ret;
      if (RESBITW >= 0) begin
         ret = resbitw_e - 1;
         if (resbitw_i < RESBITW)
            ret = ret + (RESBITW - resbitw_i);
      end else begin
         if (resbitw_e >= (-RESBITW))
            ret = (-RESBITW) - 1;
         else
            ret = resbitw_e - 1;
      end
      return ret;
   endfunction
   function automatic int iLsbOfPipeRes_inVarConstRes(
      int resbitw_e,
      int resbitw_i,
      int RESBITW
   );
      if (RESBITW <= 0)
         return 0;
      else
      if (resbitw_i >= RESBITW)
         return resbitw_i - RESBITW;
      else
         return 0;
   endfunction
   function automatic int iLsbOfPipeRes_inInputRes(
      int resbitw_e,
      int resbitw_i,
      int RESBITW
   );
      if (RESBITW > 0 && resbitw_i < RESBITW)
         return RESBITW - resbitw_i;
      return 0;
   endfunction
   function automatic int iMsbOfPipeRes_inInputRes(
      int resbitw_e,
      int resbitw_i,
      int RESBITW
   );
      int ret;
      ret = resbitw_e - 1;
      if      (RESBITW == 0) return ret;
      else if (RESBITW  > 0) begin
         if (RESBITW < resbitw_i) return ret - (resbitw_i - RESBITW);
         else                     return ret + (RESBITW - resbitw_i);
      end else begin
         if (resbitw_e >= (-RESBITW))
            return -RESBITW - 1;
         else
            return resbitw_e - 1;
      end
   endfunction
   /*! 长整型常数乘法器运算用函数 */
   function automatic int lowerpartbitw_ofbitw(int totalbitw);
      return totalbitw > 32 ? totalbitw/2 : totalbitw;
   endfunction
   function automatic int higherpartbitw_ofbitw(int totalbitw);
      return totalbitw - lowerpartbitw_ofbitw(totalbitw);
   endfunction
   typedef struct {
      int ilsbofpart_ineres[3:0];
      int bitwofpart_ineres[3:0];
      int bitwof_eres;
   } eresbi_t;
   function automatic eresbi_t calc_eresbitinf(int constbitwl, int varbitwl, int bitwof_part[3:0]);
      eresbi_t erbi;
      erbi.ilsbofpart_ineres[3] = constbitwl + varbitwl;
      erbi.ilsbofpart_ineres[2] = constbitwl;
      erbi.ilsbofpart_ineres[1] = varbitwl;
      erbi.ilsbofpart_ineres[0] = 0;
      erbi.bitwofpart_ineres[3] = bitwof_part[3] + erbi.ilsbofpart_ineres[3];
      erbi.bitwofpart_ineres[2] = bitwof_part[2] + erbi.ilsbofpart_ineres[2];
      erbi.bitwofpart_ineres[1] = bitwof_part[1] + erbi.ilsbofpart_ineres[1];
      erbi.bitwofpart_ineres[0] = bitwof_part[0] + erbi.ilsbofpart_ineres[0];
      if      (bitwof_part[3]>0)                                                       erbi.bitwof_eres = erbi.bitwofpart_ineres[3];
      else if (bitwof_part[2]>0 && erbi.bitwofpart_ineres[2]>erbi.bitwofpart_ineres[1])erbi.bitwof_eres = erbi.bitwofpart_ineres[2];
      else if (bitwof_part[1]>0)                                                       erbi.bitwof_eres = erbi.bitwofpart_ineres[1];
      else                                                                             erbi.bitwof_eres = erbi.bitwofpart_ineres[0];
      return erbi;
   endfunction
   function automatic bit[3:0] res_w_partselflag(int resbitw_o, bit res_msbalign, int constbitwl, int varbitwl, int bitwof_part[3:0]);
      bit[3:0] eres_partselflag;
      eresbi_t erbi;
      erbi = calc_eresbitinf(constbitwl, varbitwl, bitwof_part);
      if (res_msbalign) begin
         int signed ilsb_ofres_ineres;
         ilsb_ofres_ineres = signed'(erbi.bitwof_eres) - signed'(resbitw_o);
         eres_partselflag[3] = (bitwof_part[3] > 0 && ilsb_ofres_ineres <= signed'(erbi.bitwofpart_ineres[3])) ? 1'b1 : 1'b0;
         eres_partselflag[2] = (bitwof_part[2] > 0 && ilsb_ofres_ineres <= signed'(erbi.bitwofpart_ineres[2])) ? 1'b1 : 1'b0;
         eres_partselflag[1] = (bitwof_part[1] > 0 && ilsb_ofres_ineres <= signed'(erbi.bitwofpart_ineres[1])) ? 1'b1 : 1'b0;
         eres_partselflag[0] = (bitwof_part[0] > 0 && ilsb_ofres_ineres <= signed'(erbi.bitwofpart_ineres[0])) ? 1'b1 : 1'b0;
      end else begin
         eres_partselflag[3] = (bitwof_part[3] > 0 && resbitw_o >= erbi.ilsbofpart_ineres[3]) ? 1'b1 : 1'b0;
         eres_partselflag[2] = (bitwof_part[2] > 0 && resbitw_o >= erbi.ilsbofpart_ineres[2]) ? 1'b1 : 1'b0;
         eres_partselflag[1] = (bitwof_part[1] > 0 && resbitw_o >= erbi.ilsbofpart_ineres[1]) ? 1'b1 : 1'b0;
         eres_partselflag[0] = (bitwof_part[0] > 0 && resbitw_o >= erbi.ilsbofpart_ineres[0]) ? 1'b1 : 1'b0;
      end
      return eres_partselflag;
   endfunction
   typedef struct packed {
      bit[31:0] msbc_ofres_w;
      bit[31:0] ilsb_ofres_w;
      bit[31:0] bitwof_res_w;
   } res_w_inf_t;
   function automatic int msbc_ofres_w_in_res_w_inf(res_w_inf_t rwi);
      return rwi.msbc_ofres_w;
   endfunction
   function automatic int ilsb_ofres_w_in_res_w_inf(res_w_inf_t rwi);
      return rwi.ilsb_ofres_w;
   endfunction
   function automatic int bitwof_res_w_in_res_w_inf(res_w_inf_t rwi);
      return rwi.bitwof_res_w;
   endfunction
   function automatic res_w_inf_t res_w_bitw(bit[3:0] res_w_psf, int constbitwl, int varbitwl, int bitwof_part[3:0]);
      res_w_inf_t rwi;
      int ilsb_ofres_w_ineres, msbc_ofres_w_ineres;
      eresbi_t erbi;
      erbi = calc_eresbitinf(constbitwl, varbitwl, bitwof_part);
      if      (res_w_psf[0]) ilsb_ofres_w_ineres = erbi.ilsbofpart_ineres[0];
      else if (res_w_psf[1] != 1'b0 && erbi.ilsbofpart_ineres[1] < erbi.ilsbofpart_ineres[2]) ilsb_ofres_w_ineres = erbi.ilsbofpart_ineres[1];
      else if (res_w_psf[2]) ilsb_ofres_w_ineres = erbi.ilsbofpart_ineres[2];
      else                   ilsb_ofres_w_ineres = erbi.ilsbofpart_ineres[3];
      if      (res_w_psf[3]) msbc_ofres_w_ineres = erbi.bitwofpart_ineres[3];
      else if (res_w_psf[2] != 1'b0 && erbi.bitwofpart_ineres[2] > erbi.bitwofpart_ineres[1]) msbc_ofres_w_ineres = erbi.bitwofpart_ineres[2];
      else if (res_w_psf[1]) msbc_ofres_w_ineres = erbi.bitwofpart_ineres[1];
      else                   msbc_ofres_w_ineres = erbi.bitwofpart_ineres[0];
      rwi.msbc_ofres_w = msbc_ofres_w_ineres;
      rwi.ilsb_ofres_w = ilsb_ofres_w_ineres;
      rwi.bitwof_res_w = msbc_ofres_w_ineres - ilsb_ofres_w_ineres;
      return rwi;
   endfunction
   typedef int signed res_w_ilsb_ofpart_t[3:0];
   function automatic res_w_ilsb_ofpart_t res_w_ilsb_ofpart(int resbitw_o, int constbitwl, int varbitwl, int bitwof_part[3:0]);
      res_w_ilsb_ofpart_t ilsbop;
      eresbi_t erbi;
      erbi = calc_eresbitinf(constbitwl, varbitwl, bitwof_part);
      // 各累加部分最低位在待截位结果中的最低位位置，注意：下面的代码需要更改
      ilsbop[3] = erbi.ilsbofpart_ineres[3];
      ilsbop[2] = erbi.ilsbofpart_ineres[2];
      ilsbop[1] = erbi.ilsbofpart_ineres[1];
      ilsbop[0] = erbi.ilsbofpart_ineres[0];
      return ilsbop;
   endfunction
endpackage

/*! \brief 无符号整型常数乘法器 */
module umultconst #(
   parameter int unsigned MINOF_VAR = 6'h01,       ///< 无符号变量的定义域范围中的最小值
   parameter int unsigned MAXOF_VAR = 6'h30,       ///< 无符号变量的定义域范围中的最大值
   parameter int unsigned CONSTARG  = 3,           ///< 常量参数，必须是大于等于0的值
   parameter int unsigned VARBITW   = 0,           ///< 指定的变量位宽， = 0 表示根据变量的最大值、最小值自动计算位宽
   parameter int unsigned CONSTBITW = 0,           ///< 指定的常量位宽， = 0 表示根据常量的值自动计算位宽
   parameter int signed   RESBITW   = 0,           ///< 指定结果位宽， = 0 时表示自动计算最佳位宽， > 0 表示计算结果按高位对齐，< 0 表示计算结果按低位对齐
   parameter bit          USEHRDCOR = 1'b0,        ///< 使用硬件核例化常数乘法器标志，1'b0-使用逻辑元件例化常数乘法器，1'b1-使用硬件乘法器核例化常数乘法器
   parameter bit          RNDRESLSB = 1'b1,        ///< 结果最低位做四舍五入处理标志，1'b1-对结果最低位四舍五入，1'b0-不对结果最低位四舍五入
   parameter int          DELAYTAPS = 0            ///< 延迟输出拍数，可选值：0,1,2
) (clk, aclr, sclr, clken, var_arg, var_valid, res, res_valid);
   input  bit                       clk;           ///< 驱动时钟
   input  wire                      aclr;          ///< 异步复位信号，高电平(1)有效
   input  wire                      sclr;          ///< 同步复位信号，高电平(1)有效
   input  wire                      clken;         ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   initial if (MAXOF_VAR < 0) $error("umultconst : MAXOF_VAR(%0d) should not be negative value!", MAXOF_VAR);
   initial if (MINOF_VAR < 0) $error("umultconst : MINOF_VAR(%0d) should not be negative value!", MINOF_VAR);
   localparam int var_bitw = multconst_pkg::bitwOfUnsignedVar(MINOF_VAR, MAXOF_VAR);
   initial if (VARBITW > 0 && var_bitw > VARBITW) $error("umultconst : specified VARBITW(%0d) could not hold all bits of variable between MINOF_VAR(%0d) and MAXOF_VAR(%0d)", VARBITW, MINOF_VAR, MAXOF_VAR);
   localparam int varbitwbyinput = VARBITW > 0 ? VARBITW : var_bitw;
   input  wire[var_bitw-1:0]        var_arg;       ///< 输入的变量被乘数
   input  wire                      var_valid;     ///< 输入变量有效标志，本标志除了可用作同步外，还被用于在仿真时模块内部对 #var_arg 做值域检查的使能控制
   initial if (CONSTARG < 0)  $error("umultconst : CONSTARG(%0d) should not be negative value!", CONSTARG);
   localparam int constbitw = miscs::minbitw_of_integer(CONSTARG, $bits(CONSTARG));
   initial if (CONSTBITW > 0 && constbitw > CONSTBITW)
      $error("umultconst: the bitwidth(%0d) of CONSTARG(%0d) exceeds the parameter CONSTBITW(%0d)", constbitw, CONSTARG, CONSTBITW);
   localparam int constbitw_use = CONSTBITW > 0 ? CONSTBITW : constbitw;
   localparam int resbitw2e = (CONSTBITW == 0)
                              ? multconst_pkg::bitwOfUnsignedMultRes_constUnsigned(
                                                .minOfVar(MINOF_VAR  ),
                                                .maxOfVar(MAXOF_VAR  ),
                                                .constArg(CONSTARG   ))
                              : multconst_pkg::bitwOfUnsignedMultRes_constBitw(
                                                .minOfVar   (MINOF_VAR  ),
                                                .maxOfVar   (MAXOF_VAR  ),
                                                .constBitw  (CONSTBITW  ));
   localparam int resbitw_e = (resbitw2e < constbitw_use)
                              ? constbitw_use
                              : resbitw2e;
   localparam int resbitw_i = (CONSTARG == 0 && CONSTBITW == 0)
                              ? 1
                              : miscs::minresbitw_of_unsignedint_multiply(
                                          .bitwofA(varbitwbyinput ),
                                          .bitwofB(constbitw_use  ));
   localparam int res_bitw  = (RESBITW != 0)
                              ? ((RESBITW < 0)
                                 ? (-RESBITW)
                                 : RESBITW)
                              : resbitw_i;
   output logic[res_bitw-1:0]       res;           ///< 乘法结果
   output wire                      res_valid;     ///< 输出结果有效标志

   initial forever begin
      # 2
      if (~aclr & ~sclr & var_valid) begin
         if (var_arg < MINOF_VAR || var_arg > MAXOF_VAR)
            $error("umultconst : specified var_arg(%0d) out of range[%0d, %0d]!", var_arg, MINOF_VAR, MAXOF_VAR);
      end
   end
   localparam int iMsbOfPipeRes_inVarConstRes = multconst_localpkg::iMsbOfPipeRes_inVarConstRes(
                                                                     .resbitw_e  (resbitw_e  ),
                                                                     .resbitw_i  (resbitw_i  ),
                                                                     .RESBITW    (RESBITW    ));
   localparam int iLsbOfPipeRes_inVarConstRes = multconst_localpkg::iLsbOfPipeRes_inVarConstRes(
                                                                     .resbitw_e  (resbitw_e  ),
                                                                     .resbitw_i  (resbitw_i  ),
                                                                     .RESBITW    (RESBITW    ));
   localparam int iLsbOfPipeRes_inInputRes    = multconst_localpkg::iLsbOfPipeRes_inInputRes(
                                                                     .resbitw_e  (resbitw_e  ),
                                                                     .resbitw_i  (resbitw_i  ),
                                                                     .RESBITW    (RESBITW    ));
   localparam int iMsbOfPipeRes_inInputRes    = multconst_localpkg::iMsbOfPipeRes_inInputRes(
                                                                     .resbitw_e  (resbitw_e  ),
                                                                     .resbitw_i  (resbitw_i  ),
                                                                     .RESBITW    (RESBITW    ));
   localparam int pipe_resbitw = iMsbOfPipeRes_inInputRes - iLsbOfPipeRes_inInputRes + 1;
   wire [pipe_resbitw-1:0] res2o;
   logic[resbitw_e-1:0] res_s;
   /*
    * \details 常数乘法原理
    * 标准的乘法运算：  xxxx * 1010 :
    *             xxxx*0
    *            xxxx*1
    *           xxxx*0
    *          xxxx*1
    * ---------------------------------
    *            xxxx0
    *          xxxx000
    * ---------------------------------
    * 即 res = xxxx000 + xxxx0
    * 可见：
    * 1.乘法运算可由一系列的与、移位、加运算完成；
    * 2.上面例子中，右边的 1010 是常数，其中值为0的比特位对应的移位值可以不参与加法运算，这给常数乘法运算降低资源提供了可能。
    * 在被乘数和乘数有效比特位宽不一致的情况下，可选取二者中有效比特位宽较小的作为移位位数；另外当常数的有效比特位宽超过变量
    * 有效位宽一倍时，可向高位重复掩码至常数的有效比特位宽，以进一步降低资源。
    */
   localparam int multchk_partcnt = (constbitw_use + var_bitw - 1)/var_bitw;           // 每次同时检测的比特区间数
// initial $display("DBG0: multchk_partcnt = %0d", multchk_partcnt );
   localparam int shift_bits = (constbitw_use > var_bitw) ? var_bitw : constbitw_use;  // 总共需要移位检测的位数
   // 根据输入常数和 #shift_bits 产生常数移位检测掩码
   typedef int unsigned constarg_mskarray_t[0:shift_bits-1];
   function automatic constarg_mskarray_t constarg_mskarray_gen(int shbits, int conbitw, int varbitw, int mcpc);
      constarg_mskarray_t a;
      int unsigned constmsk, mp_one;
      int i;
      for (i = 0; i < $bits(int) && i <= mcpc*varbitw; i += varbitw) begin
         mp_one[i] = 1'b1;
      end
      constmsk = ~((-1)<<conbitw);
      for (i = 0; i < shbits; i++) begin
         a[i] = ((mp_one<<i)&constmsk);
//       $display("DBG1: a[%0d] = %0h", i, a[i]);
      end
      return a;
   endfunction
   localparam constarg_mskarray_t constarg_mskarray = constarg_mskarray_gen(shift_bits, constbitw_use, var_bitw, multchk_partcnt);
// initial constarg_mskarray_gen(shift_bits, constbitw_use, var_bitw, multchk_partcnt);
   typedef int shiftres_idxarray_t[0:shift_bits];  // 列表第0个元素存储表中有效元素个数，有效元素从索引1开始
   function automatic shiftres_idxarray_t shiftres_idx_gen(int signed constarg, int conbitw, int shbits, bit bit2chk, constarg_mskarray_t cama);
      shiftres_idxarray_t a;
      int i, sr_cnt, bitmsks;
      sr_cnt = 0;
      bitmsks = ((-1)<<conbitw);
      if (bit2chk)bitmsks = ~bitmsks;
      for (i = 0; i < shbits; i++) begin
         if ((|((~(constarg^bitmsks))&cama[i]))) begin
            sr_cnt = sr_cnt + 1;
            a[sr_cnt] = i;
//          $display("DBG2: a[%0d] = %0h, i = %0d, bit2chk = %0d", sr_cnt, a[sr_cnt], i, bit2chk);
         end
      end
      a[0] = sr_cnt;
//    $display("DBG2: a[%0d] = %0h", 0, a[0]);
      for (i = sr_cnt+1; i <= shbits; i++) begin
         a[i] = -1;
//       $display("DBG2: a[%0d] = %0h", i, a[i]);
      end
      return a;
   endfunction
/*   initial begin
      automatic int absconst = (CONSTARG < 0) ? -CONSTARG : CONSTARG;
      automatic int resbitw = var_bitw + miscs::minbitw_of_integer(absconst - 1, 31) + ((CONSTARG < 0) ? 1 : 0);
      automatic int resbitwOfFunc = imultconst_pkg::resBitwOfArgs(MAXOF_VAR, CONSTARG);
      $display(" resbitw = %0d, resbitwOfFunc = %0d", resbitw, resbitwOfFunc);
      automatic int dbg_bitmask = 32'h0;
      automatic int unsigned constarg = CONSTARG;
      automatic bit bit2chk = 1'b1;
      automatic int i, j;
      automatic int bitw_const = minbitw_of_integer(CONSTARG, 32);
      for (j = 0; j < bitw_const; j += shift_bits) begin
         for (i = 0; i < shift_bits; i++) begin
            automatic int ibit2chk = j + i;
            if (ibit2chk >= bitw_const) break;
            dbg_bitmask[i] |= (constarg[ibit2chk] == bit2chk) ? 1'b1 :1'b0;
            $display("ibit2chk = %0d, constarg[ibit2chk] = %0b, dbg_bitmask[i] = %0b, dbg_bitmask = %0h", ibit2chk, constarg[ibit2chk], dbg_bitmask[i], dbg_bitmask);
         end
      end
      $display("%h", dbg_bitmask);
   end*/
   /*
    * \details 当移位检测掩码中比特1的数量少于等于比特0时，按比特1的掩码来检测将获得最多 (shift_bits + 1)/2 个待求和项，而当
    * 比特1的数量多余比特0时，按比特1的掩码来检测将产生超过 (shift_bits + 1)/2 个待求和项，极端情况下将产生 shift_bits 个，
    * 达不到降低资源的要求。
    * 此时可以考虑按数量较少的比特0来检测，这样最多将产生 (shift_bits + 1)/2 个待求和项。
    * 令 T = 2^constbitw_use ， T = B + C ，则 B = (T - C) ，则求和项较多的 A*B 问题可转换为求和项较少的A*C的问题：
    *   A*B = A*(T - C) = A*T - A*C 
    * 又因为 C = T - B ＝ {(constbitw_use){1'b1}}^B + 1 ， 则有：
    *   A*B = A*T - A*{(constbitw_use){1'b1}}^B - A
    * 令 M = A*{(constbitw_use){1'b1}}^B + A ， 则：
    *   A*B = A*T - M
    * 综合上述算法，令 mask_zero = 1'b1 表示移位检测掩码中比特1的数量多于比特0的情况：
    *    sumof_shiftres = mask_zero ? A*{(constbitw_use){1'b1}}^B + A : A*B
    *    res = mask_zero ? A*2^constbitw_use - sumof_shiftres : sumof_shiftres;
    */
   // 对比特0做掩码的条件：比特1的位数比比特0的位数多至少2
   // bit1cnt + bit0cnt = shift_bits, 
   // bit1cnt - bit0cnt > 1 可得 bit1cnt > bit0cnt + 1
   // 即 bit1cnt*2 > bit1cnt + bit0cnt + 1 = shift_bits + 1
   // 也即 2*bit1cnt - shift_bits > 1
   localparam shiftres_idxarray_t shiftres_idxarray_msk1 = shiftres_idx_gen(CONSTARG, constbitw_use, shift_bits, 1'b1, constarg_mskarray);
// initial shiftres_idx_gen(CONSTARG, constbitw_use, shift_bits, 1'b1, constarg_mskarray);
   localparam shiftres_idxarray_t shiftres_idxarray_msk0 = shiftres_idx_gen(CONSTARG, constbitw_use, shift_bits, 1'b0, constarg_mskarray);
// initial shiftres_idx_gen(CONSTARG, constbitw_use, shift_bits, 1'b0, constarg_mskarray);
   localparam int shiftres_cnt_msk1 = shiftres_idxarray_msk1[0];
   localparam bit mask_zero = (2*shiftres_cnt_msk1 - shift_bits) > 1 ? 1'b1 : 1'b0;
   localparam int shiftres_cnt_msk0 = shiftres_idxarray_msk0[0];
   localparam int shiftres_array_cnt = mask_zero ? (shiftres_cnt_msk0 + 1) : shiftres_cnt_msk1;
   localparam int shiftres_shift_cnt = mask_zero ? shiftres_cnt_msk0 : shiftres_cnt_msk1;
   localparam shiftres_idxarray_t shiftres_idxarray = mask_zero ? shiftres_idxarray_msk0 : shiftres_idxarray_msk1;
   // 根据常数移位检测掩码，产生移位结果数组与移位位数索引的映射数组
   wire [resbitw_e-1:0] shiftres[0:shiftres_array_cnt-1], shiftres_piped[0:shiftres_array_cnt-1];
   genvar ioffset, ishift; generate
   if (CONSTARG == 0) assign res = '0;
   else begin
      localparam int paral_add_delaytaps_recommended = paral_add_pkg::delaytaps_recommend(
         .paralcnt(shiftres_array_cnt  ),
         .fpebitw (0                   )
      );
      localparam int shiftres_delaytaps_nohrdcor = (DELAYTAPS > paral_add_delaytaps_recommended + 1) ? 1 : 0;
      localparam int paral_add_delaytaps_used_nohrdcor = (DELAYTAPS >= paral_add_delaytaps_recommended + 1) ? paral_add_delaytaps_recommended : ((DELAYTAPS > 1) ? (DELAYTAPS - 1) : 0);
      if (USEHRDCOR) assign res_s = var_arg[var_bitw-1:0] * (constbitw_use)'(CONSTARG);
      else begin
         __umultconst_intnl_shift #(
            .SHIFT_BITS          (shift_bits          ),
            .SHIFTRES_IDXARRAY   (shiftres_idxarray   ),
            .SHIFTRES_ARRAY_CNT  (shiftres_array_cnt  ),
            .CONSTARG            (CONSTARG            ),
            .MASK_ZERO           (mask_zero           ),
            .VAR_BITW            (var_bitw            ),
            .CONSTBITW_USE       (constbitw_use       ),
            .RESBITW_E           (resbitw_e           ),
            .MULTCHK_PARTCNT     (multchk_partcnt     )
         ) varshift_byconst_i(
            .var_arg (var_arg ),
            .shiftres(shiftres)
         );
         pipedelay_taps_unpackedarray #(
            .DATABITW   (resbitw_e                    ),
            .ARRAYSIZ   (shiftres_array_cnt           ),
            .DELAYTAPS  (shiftres_delaytaps_nohrdcor  )
         ) pipe_shiftres(
            .clk     (clk           ),
            .aclr    (aclr          ),
            .sclr    (sclr          ),
            .clken   (clken         ),
            .x       (shiftres      ),
            .pipe_x  (shiftres_piped)
         );
         // 求和
         logic[resbitw_e-1:0] osumres, res_ns;
         paral_add_unpackedarray #(
            .DATABITW   (resbitw_e                          ),
            .FPEBITW    (0                                  ),
            .PARALCNT   (shiftres_array_cnt                 ),
            .RESBITW    (-resbitw_e                         ),
            .DELAYTAPS  (paral_add_delaytaps_used_nohrdcor  )
         ) sumres_padd(
            .clk  (clk           ),
            .aclr (aclr          ),
            .sclr (sclr          ),
            .clken(clken         ),
            .x    (shiftres_piped),
            .r    (osumres       )
         );
         if (~mask_zero)assign res_ns = osumres;
         else begin
            logic [var_bitw-1:0] var_arg_pipe;
            pipedelay_taps #(
               .DATABITW   (var_bitw                                                      ),
               .DELAYTAPS  (shiftres_delaytaps_nohrdcor+paral_add_delaytaps_used_nohrdcor )
            ) var_arg_piper(
               .clk     (clk                    ),
               .aclr    (aclr                   ),
               .sclr    (sclr                   ),
               .clken   (clken                  ),
               .x       (var_arg[var_bitw-1:0]  ),
               .pipe_x  (var_arg_pipe           )
            );
            assign res_ns = (resbitw_e)'(unsigned'({var_arg_pipe, {(constbitw_use){1'b0}}} - (var_bitw + constbitw_use)'(osumres)));
         end
         /* \attention 下面的代码用于匹配 #CONSTARG 为负值的情况。
          * 为处理 #CONSTARG 为负值的情况，必须额外执行一次异或运算和一次加法运算，而且本模块算法并不能很好的兼容变量 #var_arg 为有符号数的情况，
          * 这意味着为处理 #var_arg 为负的情况，调用者必须额外执行一次异或运算和加法运算，再加上输入 #var_arg 时执行的取绝对值运算（包括一次异或
          * 和加法），调用者总共需要额外执行4次运算，这无疑会在一定程度上加重电路的时序负担。
          * 而如果限制模块仅处理无符号整数乘法，下面代码的异或、加法总共两次运算可以被节省，而对有符号运算，由调用者计算结果符号和 #var_arg 取绝对
          * 值的运算可以近似在同一步完成，对结果做符号修正又需要额外执行一次异或运算和加法运算。即调用者的额外运算次数不变，而模块内部节省了两次运算
          * ，意味着总的运算次数减少了两次，有利于减轻电路的时序负担。
          */
      // assign res_s = (res_ns^{(resbitw_e){neg_constarg}}) + (resbitw_e)'(neg_constarg);
         assign res_s = res_ns;
      end
      initial if (iMsbOfPipeRes_inInputRes >= res_bitw) $error("found bad msb idx!");
      if(RNDRESLSB == 1'b1 && iLsbOfPipeRes_inVarConstRes > 0) assign res2o = res_s[iMsbOfPipeRes_inVarConstRes:iLsbOfPipeRes_inVarConstRes] + (pipe_resbitw)'(res_s[iLsbOfPipeRes_inVarConstRes-1]);
      else                                                     assign res2o = res_s[iMsbOfPipeRes_inVarConstRes:iLsbOfPipeRes_inVarConstRes];
      localparam int res_delaytaps = USEHRDCOR ? DELAYTAPS : (DELAYTAPS - shiftres_delaytaps_nohrdcor - paral_add_delaytaps_used_nohrdcor);
      pipedelay_taps #(
         .DATABITW   (pipe_resbitw  ),
         .DELAYTAPS  (res_delaytaps )
      ) pipe_res(
         .clk     (clk                                                     ),
         .aclr    (aclr                                                    ),
         .sclr    (sclr                                                    ),
         .clken   (clken                                                   ),
         .x       (res2o                                                   ),
         .pipe_x  (res[iMsbOfPipeRes_inInputRes:iLsbOfPipeRes_inInputRes]  )
      );
      if(res_bitw > iMsbOfPipeRes_inInputRes+1) assign res[res_bitw                -1:iMsbOfPipeRes_inInputRes+1] = {(res_bitw-iMsbOfPipeRes_inInputRes-1){1'b0}};
      if(iLsbOfPipeRes_inInputRes > 0)          assign res[iLsbOfPipeRes_inInputRes-1:                         0] = {(iLsbOfPipeRes_inInputRes){1'b0}};
   end
   endgenerate
   pipedelay_taps #(
      .DATABITW   (1          ),
      .DELAYTAPS  (DELAYTAPS  )
   ) pipe_validflag(
      .clk     (clk        ),
      .aclr    (aclr       ),
      .sclr    (sclr       ),
      .clken   (clken      ),
      .x       (var_valid  ),
      .pipe_x  (res_valid  )
   );
endmodule
/*! \brief 兼容有符号数输入的整型常数乘法器 */
module imultconst_negcmb #(
   parameter bit           dbg_flag = 1'b0,
   parameter int signed    MINOF_VAR  = 6'h01,     ///< 有符号变量的定义域范围中的最小值
   parameter int signed    MAXOF_VAR  = 6'h30,     ///< 有符号变量的定义域范围中的最大值
   parameter bit           SIGNED_VAR = 1'b0,      ///< 输入变量是有符号数标志，1'b1-有符号数，以补码形式表示，1'b0-无符号数
   parameter int signed    CONSTARG   = 3,         ///< 常量参数
   parameter int unsigned  VARBITW    = 0,         ///< 指定的变量位宽， = 0 表示根据变量的最大值、最小值自动计算位宽
   parameter int unsigned  CONSTBITW  = 0,         ///< 指定的常量位宽， = 0 表示根据常量的值自动计算位宽
                                                   ///< \attention 
                                                   ///< -# 有符号数常量的位宽：常量的有效位宽加符号位位宽
                                                   ///< -# 有符号数常量有效位宽：即是常量绝对值的位宽。
   parameter int signed    RESBITW    = 0,         ///< 指定结果位宽， = 0 时表示自动计算最佳位宽， > 0 表示计算结果按高位对齐，< 0 表示计算结果按低位对齐
   parameter bit           USEHRDCOR  = 1'b0,      ///< 使用硬件核例化常数乘法器标志，1'b0-使用逻辑元件例化常数乘法器，1'b1-使用硬件乘法器核例化常数乘法器
   parameter bit           RNDRESLSB  = 1'b1,      ///< 结果最低位做四舍五入处理标志，1'b1-对结果最低位四舍五入，1'b0-不对结果最低位四舍五入
   parameter int           DELAYTAPS  = 0          ///< 延迟输出拍数，可选值：0,1,2,3
) (clk, aclr, sclr, clken, var_arg, var_valid, negc, res, res_valid);
   input  bit                       clk;           ///< 驱动时钟
   input  wire                      aclr;          ///< 异步复位信号，高电平(1)有效
   input  wire                      sclr;          ///< 同步复位信号，高电平(1)有效
   input  wire                      clken;         ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   initial if (SIGNED_VAR == 1'b0 && (MINOF_VAR < 0 || MAXOF_VAR < 0)) $error("imultconst - MINOF_VAR(%0d) and MAXOF_VAR(%0d) should not be negative for unsigned integer(SIGNED_VAR = %0b)", MINOF_VAR, MAXOF_VAR, SIGNED_VAR);
   localparam int var_bitw = SIGNED_VAR
                             ? multconst_pkg::bitwOfSignedVar(MINOF_VAR, MAXOF_VAR)
                             : multconst_pkg::bitwOfUnsignedVar(MINOF_VAR, MAXOF_VAR);
   localparam int varbitwbyinput = VARBITW != 0 ? VARBITW : var_bitw;
   input  wire[varbitwbyinput-1:0]  var_arg;       ///< 输入的变量被乘数
   input  wire                      var_valid;     ///< 输入变量有效标志，本标志除了可用作同步外，还被用于在仿真时模块内部对 #var_arg 做值域检查的使能控制
   input  wire                      negc;          ///< 运算时常数符号取反标志
   localparam bit neg_constarg = (CONSTARG < 0)
                                 ? 1'b1
                                 : 1'b0;
   localparam int abs_constarg = neg_constarg
                                 ? (-CONSTARG)
                                 : CONSTARG;
   localparam int constbitw = miscs::minbitw_of_signed_integer(CONSTARG, $bits(CONSTARG));
   initial if (CONSTBITW > 0 && constbitw > CONSTBITW)
      $error("imultconst: the bitwidth(%0d) of CONSTARG(%0d) exceeds the parameter CONSTBITW(%0d)", constbitw, CONSTARG, CONSTBITW);
   localparam int constbitw_use = (CONSTBITW > 0)
                                  ? CONSTBITW
                                  : constbitw;
   localparam int resbitw2e = (CONSTBITW == 0)
                              ? multconst_pkg::bitwOfSignedMultRes_constSigned(
                                                .minOfVar   (MINOF_VAR  ),
                                                .maxOfVar   (MAXOF_VAR  ),
                                                .signedVar  (SIGNED_VAR ),
                                                .constArg   (CONSTARG   ))
                              : multconst_pkg::bitwOfSignedMultRes_constBitw(
                                                   .minOfVar   (MINOF_VAR  ),
                                                   .maxOfVar   (MAXOF_VAR  ),
                                                   .signedVar  (SIGNED_VAR ),
                                                   .constBitw  (CONSTBITW  ),
                                                   .constArg   (CONSTARG   ),
                                                   .signedConst(1'b1       ));
   localparam int resbitw_e = (resbitw2e < constbitw_use)
                              ? constbitw_use
                              : resbitw2e;
   localparam int resbitw_i = (CONSTARG == 0 && CONSTBITW == 0)
                              ? 1
                              : miscs::minresbitw_of_signedint_multiply(
                                          .bitwofA(varbitwbyinput+
                                                   (SIGNED_VAR
                                                    ? 0
                                                    : 1)/*变量是无符号数时补齐为有符号数的位宽再计算结果位宽*/),
                                          .bitwofB(constbitw_use  ));
   localparam int res_bitw  = (RESBITW != 0)
                              ? ((RESBITW < 0)
                                 ? (-RESBITW)
                                 : RESBITW)
                              : resbitw_i;
   output logic[res_bitw-1:0]       res;           ///< 乘法结果
   output wire                      res_valid;     ///< 输出结果有效标志
   
   initial if (VARBITW > $bits(int) || CONSTBITW > $bits(int))
      $error("imultconst: the value that greator than %0d specified for VARBITW(%0d) and CONSTBITW(%0d) is not supported ,try to use ilmultconst", $bits(int), VARBITW, CONSTBITW);
   initial forever begin
      # 2
      if (~aclr & ~sclr & var_valid) begin
         if (SIGNED_VAR == 1'b1) begin
            if (int'(signed'(var_arg)) < MINOF_VAR || int'(signed'(var_arg)) > MAXOF_VAR)
               $error("imultconst : specified var_arg(%0d) out of range[%0d, %0d]!", longint'(signed'(var_arg)), MINOF_VAR, MAXOF_VAR);
         end else if (var_arg < MINOF_VAR || var_arg > MAXOF_VAR)
            $error("imultconst : specified var_arg(%0d) out of range[%0d, %0d]!", var_arg, MINOF_VAR, MAXOF_VAR);
      end
   end
   generate if (abs_constarg == 0) begin: MULT_0
      assign res = '0;
      pipedelay_taps #(
         .DATABITW   (1          ),
         .DELAYTAPS  (DELAYTAPS  )
      ) pipe_valid(
         .clk     (clk        ),
         .aclr    (aclr       ),
         .sclr    (sclr       ),
         .clken   (clken      ),
         .x       (var_valid  ),
         .pipe_x  (res_valid  )
      );
   end else begin
      localparam int varbitwbyinput4u = varbitwbyinput - (int'(SIGNED_VAR));
      localparam int var_bitw4u       = var_bitw - (int'(SIGNED_VAR));
      localparam int constbitw_use4u  = constbitw_use - 1;
      localparam int resbitw_e4u = resbitw_e - 1;
      localparam int resbitw_i4u = resbitw_i - 1;
      localparam int signed RESBITW4u = (RESBITW == 0)
                                        ? 0
                                        : ((RESBITW > 0)
                                           ? (RESBITW - 1)
                                           : (RESBITW + 1));
      localparam int iMsbOfPipeRes_inVarConstRes = multconst_localpkg::iMsbOfPipeRes_inVarConstRes(
                                                                        .resbitw_e  (resbitw_e4u),
                                                                        .resbitw_i  (resbitw_i4u),
                                                                        .RESBITW    (RESBITW4u  ));
      localparam int iLsbOfPipeRes_inVarConstRes = multconst_localpkg::iLsbOfPipeRes_inVarConstRes(
                                                                        .resbitw_e  (resbitw_e4u),
                                                                        .resbitw_i  (resbitw_i4u),
                                                                        .RESBITW    (RESBITW4u  ));
      localparam int iLsbOfPipeRes_inInputRes    = multconst_localpkg::iLsbOfPipeRes_inInputRes(
                                                                        .resbitw_e  (resbitw_e4u),
                                                                        .resbitw_i  (resbitw_i4u),
                                                                        .RESBITW    (RESBITW4u  ));
      localparam int iMsbOfPipeRes_inInputRes    = multconst_localpkg::iMsbOfPipeRes_inInputRes(
                                                                        .resbitw_e  (resbitw_e4u),
                                                                        .resbitw_i  (resbitw_i4u),
                                                                        .RESBITW    (RESBITW4u  ));
      localparam int pipe_resbitw = iMsbOfPipeRes_inInputRes - iLsbOfPipeRes_inInputRes + 1;
      wire [pipe_resbitw-1:0] res2o;
      wire                    res_sign;
      if (abs_constarg == 1) begin: MULT_1
         wire[var_bitw-1:0]var_multconst, neg_vmc;
         assign neg_vmc = -(signed'(var_arg[var_bitw-1:0]));
         if (neg_constarg) assign var_multconst = negc
                                                  ? var_arg[var_bitw-1:0]
                                                  : neg_vmc;
         else              assign var_multconst = negc
                                                  ? neg_vmc
                                                  : var_arg[var_bitw-1:0];
         /* 
          * pipe_resbitw 与 resbitw_e 低位对齐，因为都是根据 var_bitw 和 constbitw 计算的
          */
         assign res2o    = var_multconst[iMsbOfPipeRes_inVarConstRes:iLsbOfPipeRes_inVarConstRes],
                res_sign = var_multconst[iMsbOfPipeRes_inVarConstRes];
         pipedelay_taps #(
            .DATABITW   (pipe_resbitw+1),
            .DELAYTAPS  (DELAYTAPS     )
         ) pipe_res(
            .clk     (clk                                                                 ),
            .aclr    (aclr                                                                ),
            .sclr    (sclr                                                                ),
            .clken   (clken                                                               ),
            .x       ({var_valid,res2o}                                                   ),
            .pipe_x  ({res_valid,res[iMsbOfPipeRes_inInputRes:iLsbOfPipeRes_inInputRes]}  )
         );
         if (res_bitw > iMsbOfPipeRes_inInputRes+1) assign res[res_bitw                -1:iMsbOfPipeRes_inInputRes+1] = {(res_bitw-1-iMsbOfPipeRes_inInputRes){res[iMsbOfPipeRes_inInputRes]}};
         if (iLsbOfPipeRes_inInputRes > 0)          assign res[iLsbOfPipeRes_inInputRes-1:                         0] = {(iLsbOfPipeRes_inInputRes){1'b0}};
      end else begin: MULT_X
         localparam int umc_delaytaps = (DELAYTAPS > 1)
                                        ? (DELAYTAPS - 1)
                                        : 0;
         wire valid2pipe;
         if (USEHRDCOR) begin
            logic[1:0][resbitw_e                 -1:0]res2tr;
            logic[1:0][var_bitw+((~SIGNED_VAR)&1)-1:0]var_arg_2c;
            if (SIGNED_VAR)assign var_arg_2c[0] = (var_arg[var_bitw-1:0]^{(var_bitw){negc}}) + (var_bitw)'(negc);
            else           assign var_arg_2c[0] = ({1'b0, var_arg[var_bitw-1:0]}^{(var_bitw+1){negc}}) + (var_bitw+1)'(negc);
            if (umc_delaytaps - 1 > 0) begin
               always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
                  if      (aclr) var_arg_2c[1] <= {(var_bitw+(~SIGNED_VAR)){1'b0}};
                  else if (sclr) var_arg_2c[1] <= {(var_bitw+(~SIGNED_VAR)){1'b0}};
                  else           var_arg_2c[1] <= clken ? var_arg_2c[0] : var_arg_2c[1];
               end
            end
            else assign var_arg_2c[1] = var_arg_2c[0];
            if (SIGNED_VAR)assign res2tr[0] = signed'(var_arg_2c[1]) * signed'((constbitw_use)'(CONSTARG));
            else           assign res2tr[0] = signed'(var_arg_2c[1]) * signed'((constbitw_use)'(CONSTARG));
            if (umc_delaytaps - 2 > 0) begin
               always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
                  if      (aclr) res2tr[1] <= {(resbitw_e){1'b0}};
                  else if (sclr) res2tr[1] <= {(resbitw_e){1'b0}};
                  else           res2tr[1] <= clken ? res2tr[0] : res2tr[1];
               end
            end
            else assign res2tr[1] = res2tr[0];
            if (RESBITW >= 0) begin
               roundint #(
                  .ARGBITW    (resbitw_e     ),
                  .SIGNEDARG  (1'b1          ),
                  .RESBITW    (pipe_resbitw+1),
                  .DELAYTAPS  ((umc_delaytaps > 2)
                               ? (umc_delaytaps - 2)
                               : ((umc_delaytaps > 1)
                                  ? (umc_delaytaps - 1)
                                  : umc_delaytaps))
               ) resrnd(
                  .clk  (clk              ),
                  .aclr (aclr             ),
                  .sclr (sclr             ),
                  .clken(clken            ),
                  .a    (res2tr[1]        ),
                  .r    ({res_sign, res2o})
               );
               pipedelay_taps #(
                  .DATABITW   (1             ),
                  .DELAYTAPS  (umc_delaytaps )
               ) pipe_valid(
                  .clk     (clk        ),
                  .aclr    (aclr       ),
                  .sclr    (sclr       ),
                  .clken   (clken      ),
                  .x       (var_valid  ),
                  .pipe_x  (valid2pipe )
               );
            end
            else begin
               pipedelay_taps #(
                  .DATABITW   (pipe_resbitw+2),
                  .DELAYTAPS  (umc_delaytaps )
               ) pipe_valid(
                  .clk     (clk                                ),
                  .aclr    (aclr                               ),
                  .sclr    (sclr                               ),
                  .clken   (clken                              ),
                  .x       ({var_valid, res2tr[pipe_resbitw:0]}),
                  .pipe_x  ({valid2pipe, res_sign, res2o}      )
               );
            end
         end else begin
            wire[var_bitw-1:0]var_in;
            if (SIGNED_VAR == 1'b0) assign var_in = var_arg[var_bitw-1:0];
            else begin
               wire sign_var = var_arg[var_bitw-1];
               // 输入变量取绝对值。
               /* \attention 通过符号位选择和通过异或联合加法的取绝对值运算其运算次数是近似的。原因：
                * 1.符号位选择时仍然需要生成输入变量的负值，这需要一次取反和一次加法运算，再加上根据符号位选择输出，总共需要三次运算，
                * 而经过电路优化后，应该可以降低至两次左右；
                * 2.而异或联合加法的运算需要对输入变量执行取反和加法两次运算；
                */
               assign var_in = (var_arg[var_bitw-1:0]^{(var_bitw){sign_var}}) + (var_bitw)'(sign_var);
            end
            localparam int abs_maxof_var = (SIGNED_VAR == 1'b1 && MAXOF_VAR < 0)
                                           ? (-MAXOF_VAR)
                                           : MAXOF_VAR;
            localparam int abs_minof_var = (SIGNED_VAR == 1'b1 && MINOF_VAR < 0)
                                           ? (-MINOF_VAR)
                                           : MINOF_VAR;
            localparam int maxof_absvar = (abs_maxof_var > abs_minof_var)
                                          ? abs_maxof_var
                                          : abs_minof_var;
            localparam int minof_absvar = (MAXOF_VAR[$bits(MAXOF_VAR)-1]^MINOF_VAR[$bits(MINOF_VAR)-1])
                                          ? 0
                                          : ((abs_maxof_var < abs_minof_var)
                                             ? abs_maxof_var
                                             : abs_minof_var);
            localparam int var2in_bitw  = multconst_pkg::bitwOfUnsignedVar(minof_absvar, maxof_absvar);
            localparam int absconstbitw = constbitw_use4u;
            localparam int absresbitw_e = multconst_pkg::bitwOfUnsignedMultRes_constUnsigned(maxof_absvar, minof_absvar, abs_constarg);
            localparam int signed absres_bitw  = ((RESBITW != 0)
                                                  ? (RESBITW4u + ((RESBITW > 0)
                                                                   ? 1
                                                                   : 0))
                                                  : absresbitw_e);
            localparam int ures_bitw = miscs::absi(.x(absres_bitw));
            wire[ures_bitw-1:0] ures;
            umultconst #(
               .MINOF_VAR  (minof_absvar  ),
               .MAXOF_VAR  (maxof_absvar  ),
               .CONSTARG   (abs_constarg  ),
               .VARBITW    (var2in_bitw   ),
               .CONSTBITW  (absconstbitw  ),
               .RESBITW    (absres_bitw   ),
               .USEHRDCOR  (USEHRDCOR     ),
               .RNDRESLSB  (RNDRESLSB     ),
               .DELAYTAPS  (umc_delaytaps )
            ) umci(
               .clk        (clk                    ),
               .aclr       (aclr                   ),
               .sclr       (sclr                   ),
               .clken      (clken                  ),
               .var_arg    (var_in[var2in_bitw-1:0]),
               .var_valid  (var_valid              ),
               .res        (ures[ures_bitw-1:0]    ),
               .res_valid  (valid2pipe             )
            );
            wire sign2fixres;
            pipedelay_taps #(
               .DATABITW   (1             ),
               .DELAYTAPS  (umc_delaytaps )
            ) signres_pipe(
               .clk     (clk                                                              ),
               .aclr    (aclr                                                             ),
               .sclr    (sclr                                                             ),
               .clken   (clken                                                            ),
               .x       (((neg_constarg^negc)^(SIGNED_VAR&var_arg[var_bitw-1]))&(|var_arg)),
               .pipe_x  (sign2fixres                                                      )
            );
            if (RESBITW == 0) begin: RE0
               assign res_sign = sign2fixres&(|ures); // 无符号乘法结果为0时保证符号位为0，避免得到错误的最大负值结果
               if (SIGNED_VAR)assign res2o = (((pipe_resbitw)'(ures))^{(pipe_resbitw){sign2fixres}}) + (pipe_resbitw)'(sign2fixres);
               else           assign res2o = (((pipe_resbitw)'(ures))^{(pipe_resbitw){sign2fixres}});
            end else begin
               wire[ures_bitw:0] res2trunc;
               if (absresbitw_e < ures_bitw - 1) assign res2trunc = ({1'b0, ures}^{(ures_bitw+1){sign2fixres}}) + (ures_bitw+1)'({sign2fixres, {(ures_bitw - absresbitw_e - 1){1'b0}}});
               else                              assign res2trunc = ({1'b0, ures}^{(ures_bitw+1){sign2fixres}}) + (ures_bitw+1)'({sign2fixres});
               if (RESBITW >= 0 || ures_bitw < pipe_resbitw) assign res_sign = sign2fixres&(|ures); // 无符号乘法结果为0时保证符号位为0，避免得到错误的最大负值结果
               else                                          assign res_sign = res2trunc[pipe_resbitw];
               if (pipe_resbitw < ures_bitw && RESBITW > 0) begin: R0
                  if (pipe_resbitw-1 <= ures_bitw) begin: RR0
                     assign res2o = res2trunc[pipe_resbitw-1:0];  // 经仿真验证：前面的无符号乘法做了四舍五入后这里不用再做，做了反而造成结果比真实值小1
                  end else begin: RR1
                     assign res2o[ures_bitw+1:0] = {res2trunc[ures_bitw], res2trunc[ures_bitw:0]};  // 经仿真验证：前面的无符号乘法做了四舍五入后这里不用再做，做了反而造成结果比真实值小1
                     if (pipe_resbitw-1 > ures_bitw+1)
                        assign res2o[pipe_resbitw-1:ures_bitw+2] = {(pipe_resbitw-1-(ures_bitw+1)){res2o[ures_bitw+1]}};
                  end
               end else begin: R1
                  if (pipe_resbitw-1 <= ures_bitw) begin: RR2
                     assign res2o = res2trunc[pipe_resbitw-1:0];
                  end else begin: RR3
                     assign res2o = {{(pipe_resbitw-1-ures_bitw){res2trunc[ures_bitw]}}, res2trunc[ures_bitw:0]};
                  end
               end
            end
         end
         pipedelay_taps #(
            .DATABITW   (pipe_resbitw + 2 ),
            .DELAYTAPS  ((DELAYTAPS >= 1)
                         ? 1
                         : 0              )
         ) pipe_res(
            .clk     (clk                                                                                               ),
            .aclr    (aclr                                                                                              ),
            .sclr    (sclr                                                                                              ),
            .clken   (clken                                                                                             ),
            .x       ({valid2pipe,res_sign,res2o}                                                                       ),
            .pipe_x  ({res_valid,res[iMsbOfPipeRes_inInputRes+1],res[iMsbOfPipeRes_inInputRes:iLsbOfPipeRes_inInputRes]})
         );
         if(res_bitw > iMsbOfPipeRes_inInputRes + 2) assign res[res_bitw                -1:iMsbOfPipeRes_inInputRes+2] = {(res_bitw-iMsbOfPipeRes_inInputRes-2){res[iMsbOfPipeRes_inInputRes+1]}};
         if(iLsbOfPipeRes_inInputRes > 0)            assign res[iLsbOfPipeRes_inInputRes-1:                         0] = {(iLsbOfPipeRes_inInputRes){1'b0}};
      end
   end endgenerate
endmodule
module imultconst #(
   parameter int signed    MINOF_VAR  = 6'h01,     ///< 有符号变量的定义域范围中的最小值
   parameter int signed    MAXOF_VAR  = 6'h30,     ///< 有符号变量的定义域范围中的最大值
   parameter bit           SIGNED_VAR = 1'b0,      ///< 输入变量是有符号数标志，1'b1-有符号数，以补码形式表示，1'b0-无符号数
   parameter int signed    CONSTARG   = 3,         ///< 常量参数
   parameter int unsigned  VARBITW    = 0,         ///< 指定的变量位宽， = 0 表示根据变量的最大值、最小值自动计算位宽
   parameter int unsigned  CONSTBITW  = 0,         ///< 指定的常量位宽， = 0 表示根据常量的值自动计算位宽
                                                   ///< \attention 
                                                   ///< -# 有符号数常量的位宽：常量的有效位宽加符号位位宽
                                                   ///< -# 有符号数常量有效位宽：即是常量绝对值的位宽。
   parameter int signed    RESBITW    = 0,         ///< 指定结果位宽， = 0 时表示自动计算最佳位宽， > 0 表示计算结果按高位对齐，< 0 表示计算结果按低位对齐
   parameter bit           USEHRDCOR  = 1'b0,      ///< 使用硬件核例化常数乘法器标志，1'b0-使用逻辑元件例化常数乘法器，1'b1-使用硬件乘法器核例化常数乘法器
   parameter bit           RNDRESLSB  = 1'b1,      ///< 结果最低位做四舍五入处理标志，1'b1-对结果最低位四舍五入，1'b0-不对结果最低位四舍五入
   parameter int           DELAYTAPS  = 0          ///< 延迟输出拍数，可选值：0,1,2,3
) (clk, aclr, sclr, clken, var_arg, var_valid, res, res_valid);
   input  bit                       clk;           ///< 驱动时钟
   input  wire                      aclr;          ///< 异步复位信号，高电平(1)有效
   input  wire                      sclr;          ///< 同步复位信号，高电平(1)有效
   input  wire                      clken;         ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   initial if (SIGNED_VAR == 1'b0 && (MINOF_VAR < 0 || MAXOF_VAR < 0)) $error("imultconst - MINOF_VAR(%0d) and MAXOF_VAR(%0d) should not be negative for unsigned integer(SIGNED_VAR = %0b)", MINOF_VAR, MAXOF_VAR, SIGNED_VAR);
   localparam int var_bitw = SIGNED_VAR
                             ? multconst_pkg::bitwOfSignedVar(MINOF_VAR, MAXOF_VAR)
                             : multconst_pkg::bitwOfUnsignedVar(MINOF_VAR, MAXOF_VAR);
   localparam int varbitwbyinput = (VARBITW != 0)
                                   ? VARBITW
                                   : var_bitw;
   input  wire[varbitwbyinput-1:0]  var_arg;       ///< 输入的变量被乘数
   input  wire                      var_valid;     ///< 输入变量有效标志，本标志除了可用作同步外，还被用于在仿真时模块内部对 #var_arg 做值域检查的使能控制
   localparam int constbitw = miscs::minbitw_of_signed_integer(CONSTARG, $bits(CONSTARG));
   initial if (CONSTBITW > 0 && constbitw > CONSTBITW)
      $error("imultconst: the bitwidth(%0d) of CONSTARG(%0d) exceeds the parameter CONSTBITW(%0d)", constbitw, CONSTARG, CONSTBITW);
   localparam int constbitw_use = (CONSTBITW > 0)
                                  ? CONSTBITW
                                  : constbitw;
   localparam int resbitw_i = (CONSTARG == 0 && CONSTBITW == 0)
                              ? 1
                              : miscs::minresbitw_of_signedint_multiply(
                                          .bitwofA(varbitwbyinput+
                                                   (SIGNED_VAR
                                                    ? 0
                                                    : 1)/*变量是无符号数时补齐为有符号数的位宽再计算结果位宽*/),
                                          .bitwofB(constbitw_use  ));
   localparam int res_bitw  = (RESBITW != 0)
                              ? ((RESBITW < 0)
                                 ? (-RESBITW)
                                 : RESBITW)
                              : resbitw_i;
   output logic[res_bitw-1:0]       res;           ///< 乘法结果
   output wire                      res_valid;     ///< 输出结果有效标志

   imultconst_negcmb #(
      .MINOF_VAR  (MINOF_VAR  ),
      .MAXOF_VAR  (MAXOF_VAR  ),
      .SIGNED_VAR (SIGNED_VAR ),
      .CONSTARG   (CONSTARG   ),
      .VARBITW    (VARBITW    ),
      .CONSTBITW  (CONSTBITW  ),
      .RESBITW    (RESBITW    ),
      .USEHRDCOR  (USEHRDCOR  ),
      .RNDRESLSB  (RNDRESLSB  ),
      .DELAYTAPS  (DELAYTAPS  )
   ) imci(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .var_arg    (var_arg    ),
      .var_valid  (var_valid  ),
      .negc       (1'b0       ),
      .res        (res        ),
      .res_valid  (res_valid  )
   );
endmodule
/*! \brief 无符号长整型常数乘法器 */
module ulmultconst #(
   parameter longint unsigned MINOF_VAR = 6'h01,   ///< 无符号变量的定义域范围中的最小值
   parameter longint unsigned MAXOF_VAR = 6'h30,   ///< 无符号变量的定义域范围中的最大值
   parameter longint unsigned CONSTARG  = 3,       ///< 常量参数
   parameter int     unsigned VARBITW   = 0,       ///< 指定的变量位宽， = 0 表示根据变量的最大值、最小值自动计算位宽
   parameter int     unsigned CONSTBITW = 0,       ///< 指定的常量位宽， = 0 表示根据常量的值自动计算位宽
   parameter int     signed   RESBITW   = 0,       ///< 指定结果位宽， = 0 时表示自动计算最佳位宽， > 0 表示计算结果按高位对齐，< 0 表示计算结果按低位对齐;
   parameter bit              USEHRDCOR = 1'b0,    ///< 使用硬件核例化常数乘法器标志，1'b0-使用逻辑元件例化常数乘法器，1'b1-使用硬件乘法器核例化常数乘法器
   parameter bit              RNDRESLSB = 1'b1,    ///< 结果最低位做四舍五入处理标志，1'b1-对结果最低位四舍五入，1'b0-不对结果最低位四舍五入
   parameter int              DELAYTAPS = 0        ///< 延迟输出拍数，可选值：0,1,2,3
) (clk, aclr, sclr, clken, var_arg, var_valid, res, res_valid);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr;                ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 同步复位信号，高电平(1)有效
   input  wire                clken;               ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   initial if (MAXOF_VAR < 0) $error("ulmultconst : MAXOF_VAR(%0d) should not be negative value!", MAXOF_VAR);
   initial if (MINOF_VAR < 0) $error("ulmultconst : MINOF_VAR(%0d) should not be negative value!", MINOF_VAR);
   localparam int var_bitw = multconst_pkg::bitwOfUnsignedVar(MINOF_VAR, MAXOF_VAR);
   initial if (VARBITW > 0 && var_bitw > VARBITW) $error("ulmultconst : specified VARBITW(%0d) could not hold all bits of variable between MINOF_VAR(%0d) and MAXOF_VAR(%0d)", VARBITW, MINOF_VAR, MAXOF_VAR);
   localparam int varbitwbyinput = VARBITW > 0 ? VARBITW : var_bitw;
   input  wire[var_bitw-1:0]  var_arg;             ///< 输入的变量被乘数
   input  wire                var_valid;           ///< 输入变量有效标志，本标志除了可用作同步外，还被用于在仿真时模块内部对 #var_arg 做值域检查的使能控制
   initial if (CONSTARG < 0)  $error("ulmultconst : CONSTARG(%0d) should not be negative value!", CONSTARG);
   localparam int constbitw = miscs::minbitw_of_longint(CONSTARG, $bits(CONSTARG));
   initial if (CONSTBITW > 0 && constbitw > CONSTBITW)
      $error("ulmultconst: the bitwidth(%0d) of CONSTARG(%0d) exceeds the parameter CONSTBITW(%0d)", constbitw, CONSTARG, CONSTBITW);
   localparam int constbitw_use = CONSTBITW > 0 ? CONSTBITW : constbitw;
   localparam int resbitw2e = (CONSTBITW == 0)
                              ? multconst_pkg::bitwOfUnsignedMultRes_constUnsigned(
                                                .minOfVar(MINOF_VAR  ),
                                                .maxOfVar(MAXOF_VAR  ),
                                                .constArg(CONSTARG   ))
                              : multconst_pkg::bitwOfUnsignedMultRes_constBitw(
                                                .minOfVar   (MINOF_VAR  ),
                                                .maxOfVar   (MAXOF_VAR  ),
                                                .constBitw  (CONSTBITW  ));
   localparam int resbitw_e = (resbitw2e < constbitw_use)
                              ? constbitw_use
                              : resbitw2e;
   localparam int resbitw_i = (CONSTARG == 0 && CONSTBITW == 0)
                              ? 1
                              : miscs::minresbitw_of_unsignedint_multiply(
                                          .bitwofA(varbitwbyinput ),
                                          .bitwofB(constbitw_use  ));
   localparam int res_bitw  = (RESBITW != 0)
                              ? ((RESBITW < 0)
                                 ? (-RESBITW)
                                 : RESBITW)
                              : resbitw_i;
   output logic[res_bitw-1:0] res;                 ///< 乘法结果
   output wire                res_valid;           ///< 输出结果有效标志

   initial forever begin
      # 2
      if (~aclr & ~sclr & var_valid) begin
         if (var_arg < MINOF_VAR || var_arg > MAXOF_VAR)
            $error("ulmultconst : specified var_arg(%0d) out of range[%0d, %0d]!", var_arg, MINOF_VAR, MAXOF_VAR);
      end
   end
   localparam int constbitwl = multconst_localpkg::lowerpartbitw_ofbitw(constbitw_use);
   localparam int constbitwh = multconst_localpkg::higherpartbitw_ofbitw(constbitw_use);
   localparam int varbitwl = multconst_localpkg::lowerpartbitw_ofbitw(var_bitw);
   localparam int varbitwh = multconst_localpkg::higherpartbitw_ofbitw(var_bitw);
   localparam int constargh = int'(CONSTARG >> constbitwl);
   localparam int constargl = int'(CONSTARG[constbitwl-1:0]);
   localparam int constargl4bitw = constargh > 0 ? (2**constbitwl-1) : constargl;
   localparam int minof_varh = int'(MINOF_VAR>>varbitwl);
   localparam int minof_varl = varbitwh > 0 ? 0 : int'(MINOF_VAR);
   localparam int maxof_varh = int'(MAXOF_VAR>>varbitwl);
   localparam int maxof_varl = varbitwh > 0 ? (2**varbitwl-1) : int'(MAXOF_VAR);
   localparam int bitwof_chmvh = (constbitwh > 0 && varbitwh > 0) ? multconst_pkg::bitwOfUnsignedMultRes_constUnsigned(minof_varh, maxof_varh, constargh) : 0;
   localparam int bitwof_chmvl = (constbitwh > 0) ? multconst_pkg::bitwOfUnsignedMultRes_constUnsigned(minof_varl, maxof_varl, constargh) : 0;
   localparam int bitwof_clmvh = (varbitwh   > 0) ? multconst_pkg::bitwOfUnsignedMultRes_constUnsigned(minof_varh, maxof_varh, constargl4bitw) : 0;
   localparam int bitwof_clmvl = multconst_pkg::bitwOfUnsignedMultRes_constUnsigned(minof_varl, maxof_varl, constargl4bitw);
   /*
    * 1.ch > 0, vh > 0  :  ch * vh , ch * vl, cl * vh
    * 2.ch > 0, vh = 0  :  ch * vl , cl * vl
    * 3.ch = 0, vh > 0  :  cl * vh , cl * vl
    * 4.ch = 0, vh = 0  :  cl * vl
    *
    * sch = constbitwl - 乘法结果中 ch 的左移位数
    * scl = 0          - 乘法结果中 cl 的左移位数
    * svh = varbitwl   - 乘法结果中 vh 的左移位数
    * svl = 0          - 乘法结果中 vl 的左移位数
    * 乘法结果 RES：
    * RES = ch*(2^sch)*vh*(2^svh) + ch*(2^sch)*vl*(2^svl) + cl*(2^scl)*vh*(2^svh) + cl*(2^scl)*vl*(2^svl)
    *     = ch*vh*2^(sch+svh) + ch*vl*2^(sch+svl) + cl*vh*2^(scl+svh) + cl*vl*2^(scl+svl)
    *     = (ch*vh*2^(sch+svh-scl-svl) + ch*vl*2^(sch+svl-scl-svl) + cl*vh*2^(scl+svh-scl-svl) + cl*vl)*2^(scl+svl)
    *     = (ch*vh*2^(sch+svh-scl-svl) + ch*vl*2^(sch-scl) + cl*vh*2^(svh-svl) + cl*vl)*2^(scl+svl)
    *     = (ch*vh*2^(constbitwl + varbitwl) + ch*vl*2^(constbitwl) + cl*vh*2^(varbitwl) + cl*vl)
    */
   localparam int bitwof_parts[3:0] = '{bitwof_chmvh, bitwof_chmvl, bitwof_clmvh, bitwof_clmvl};
   localparam bit[3:0]            partself_res_w = multconst_localpkg::res_w_partselflag(res_bitw, RESBITW > 0 ? 1'b1 : 1'b0, constbitwl, varbitwl, bitwof_parts);
   localparam multconst_localpkg::res_w_inf_t res_w_inf = multconst_localpkg::res_w_bitw(partself_res_w, constbitwl, varbitwl, bitwof_parts);
   localparam int                 bitwof_res_w   = multconst_localpkg::bitwof_res_w_in_res_w_inf(res_w_inf);
   localparam int                 msbc_ofres_w   = multconst_localpkg::msbc_ofres_w_in_res_w_inf(res_w_inf);
   localparam int                 ilsb_ofres_w   = multconst_localpkg::ilsb_ofres_w_in_res_w_inf(res_w_inf);
   localparam multconst_localpkg::res_w_ilsb_ofpart_t ilsbop_res_w = multconst_localpkg::res_w_ilsb_ofpart(res_bitw, constbitwl, varbitwl, bitwof_parts);
   wire [bitwof_res_w-1:0] g_res_w;
   wire                    g_valid;
   wire[varbitwl-1:0]varargl = var_arg[varbitwl-1:0];
   generate if ((partself_res_w & 4'b1010) != 0) begin: VH
      wire[varbitwh-1:0]varargh = var_arg[var_bitw-1:var_bitw-varbitwh];
   end
   if (partself_res_w[3] != 1'b0) begin: CH_M_VH
      wire [bitwof_chmvh-1:0] ires;
      wire                    ivalid;
      umultconst #(
         .MINOF_VAR  (minof_varh                         ),
         .MAXOF_VAR  (maxof_varh                         ),
         .CONSTARG   (constargh                          ),
         .VARBITW    (0                                  ),
         .CONSTBITW  (0                                  ),
         .RESBITW    (-bitwof_chmvh                      ),
         .USEHRDCOR  (USEHRDCOR                          ),
         .RNDRESLSB  (RNDRESLSB                          ),
         .DELAYTAPS  (DELAYTAPS > 0 ? DELAYTAPS - 1 : 0  )
      ) mult_chmvh(
         .clk        (clk        ),
         .aclr       (aclr       ),
         .sclr       (sclr       ),
         .clken      (clken      ),
         .var_arg    (VH.varargh ),
         .var_valid  (var_valid  ),
         .res        (ires       ),
         .res_valid  (ivalid     )
      );
      wire [bitwof_res_w-1:0] res_w;
      initial if (bitwof_chmvh + ilsbop_res_w[3] > msbc_ofres_w)
         $error("ulmultconst : bitwof_chmvh(%0d) + ilsbop_res_w[3](%0d) > msbc_ofres_w(%0d)", bitwof_chmvh, ilsbop_res_w[3], msbc_ofres_w);
      else if (ilsbop_res_w[3] < 0) $error("ulmultconst : illegal negative ilsbop_res_w[3](%0d)", ilsbop_res_w[3]);
      if (ilsbop_res_w[3] > 0)assign res_w = (bitwof_res_w)'({ires, {(ilsbop_res_w[3]){1'b0}}});
      else                    assign res_w = (bitwof_res_w)'(ires);
   end
   if (partself_res_w[2] != 1'b0) begin: CH_M_VL
      wire [bitwof_chmvl-1:0] ires;
      wire                    ivalid;
      umultconst #(
         .MINOF_VAR  (minof_varl                         ),
         .MAXOF_VAR  (maxof_varl                         ),
         .CONSTARG   (constargh                          ),
         .VARBITW    (0                                  ),
         .CONSTBITW  (0                                  ),
         .RESBITW    (-bitwof_chmvl                      ),
         .USEHRDCOR  (USEHRDCOR                          ),
         .RNDRESLSB  (RNDRESLSB                          ),
         .DELAYTAPS  (DELAYTAPS > 0 ? DELAYTAPS - 1 : 0  )
      ) mult_chmvl(
         .clk        (clk        ),
         .aclr       (aclr       ),
         .sclr       (sclr       ),
         .clken      (clken      ),
         .var_arg    (varargl    ),
         .var_valid  (var_valid  ),
         .res        (ires       ),
         .res_valid  (ivalid     )
      );
      wire [bitwof_res_w-1:0] res_w;
      initial if (bitwof_chmvl + ilsbop_res_w[2] > msbc_ofres_w)
         $error("ulmultconst : bitwof_chmvl(%0d) + ilsbop_res_w[2](%0d) > msbc_ofres_w(%0d)", bitwof_chmvl, ilsbop_res_w[2], msbc_ofres_w);
      else if (ilsbop_res_w[2] < 0) $error("ulmultconst : illegal negative ilsbop_res_w[2](%0d)", ilsbop_res_w[2]);
      if (ilsbop_res_w[2] > 0)assign res_w = (bitwof_res_w)'({ires, {(ilsbop_res_w[2]){1'b0}}});
      else                    assign res_w = (bitwof_res_w)'(ires);
   end
   if (partself_res_w[1] != 1'b0) begin: CL_M_VH
      wire [bitwof_clmvh-1:0] ires;
      wire                    ivalid;
      umultconst #(
         .MINOF_VAR  (minof_varh                         ),
         .MAXOF_VAR  (maxof_varh                         ),
         .CONSTARG   (constargl                          ),
         .VARBITW    (0                                  ),
         .CONSTBITW  (0                                  ),
         .RESBITW    (-bitwof_clmvh                      ),
         .USEHRDCOR  (USEHRDCOR                          ),
         .RNDRESLSB  (RNDRESLSB                          ),
         .DELAYTAPS  (DELAYTAPS > 0 ? DELAYTAPS - 1 : 0  )
      ) mult_clmvh(
         .clk        (clk        ),
         .aclr       (aclr       ),
         .sclr       (sclr       ),
         .clken      (clken      ),
         .var_arg    (VH.varargh ),
         .var_valid  (var_valid  ),
         .res        (ires       ),
         .res_valid  (ivalid     )
      );
      wire [bitwof_res_w-1:0] res_w;
      initial if (bitwof_clmvh + ilsbop_res_w[1] > msbc_ofres_w)
         $error("ulmultconst : bitwof_clmvh(%0d) + ilsbop_res_w[1](%0d) > msbc_ofres_w(%0d)", bitwof_clmvh, ilsbop_res_w[1], msbc_ofres_w);
      else if (ilsbop_res_w[1] < 0) $error("ulmultconst : illegal negative ilsbop_res_w[1](%0d)", ilsbop_res_w[1]);
      if (ilsbop_res_w[1] > 0)assign res_w = (bitwof_res_w)'({ires, {(ilsbop_res_w[1]){1'b0}}});
      else                    assign res_w = (bitwof_res_w)'(ires);
   end
   if (partself_res_w[0] != 1'b0) begin: CL_M_VL
      wire [bitwof_clmvl-1:0] ires;
      wire                    ivalid;
      umultconst #(
         .MINOF_VAR  (minof_varl                         ),
         .MAXOF_VAR  (maxof_varl                         ),
         .CONSTARG   (constargl                          ),
         .VARBITW    (0                                  ),
         .CONSTBITW  (0                                  ),
         .RESBITW    (-bitwof_clmvl                      ),
         .USEHRDCOR  (USEHRDCOR                          ),
         .RNDRESLSB  (RNDRESLSB                          ),
         .DELAYTAPS  (DELAYTAPS > 0 ? DELAYTAPS - 1 : 0  )
      ) mult_clmvl(
         .clk        (clk        ),
         .aclr       (aclr       ),
         .sclr       (sclr       ),
         .clken      (clken      ),
         .var_arg    (varargl    ),
         .var_valid  (var_valid  ),
         .res        (ires       ),
         .res_valid  (ivalid     )
      );
      wire [bitwof_res_w-1:0] res_w;
      initial if (bitwof_clmvl + ilsbop_res_w[0] > msbc_ofres_w)
         $error("ulmultconst : bitwof_clmvl(%0d) + ilsbop_res_w[0](%0d) > msbc_ofres_w(%0d)", bitwof_clmvl, ilsbop_res_w[0], msbc_ofres_w);
      else if (ilsbop_res_w[0] < 0) $error("ulmultconst : illegal negative ilsbop_res_w[0](%0d)", ilsbop_res_w[0]);
      if (ilsbop_res_w[0] > 0)assign res_w = (bitwof_res_w)'({ires, {(ilsbop_res_w[0]){1'b0}}});
      else                    assign res_w = (bitwof_res_w)'(ires);
   end
   if      (partself_res_w == 4'b0001) assign g_res_w = CL_M_VL.res_w,                                                 g_valid = CL_M_VL.ivalid;
   else if (partself_res_w == 4'b0010) assign g_res_w = CL_M_VH.res_w,                                                 g_valid = CL_M_VH.ivalid;
   else if (partself_res_w == 4'b0011) assign g_res_w = CL_M_VL.res_w + CL_M_VH.res_w,                                 g_valid = CL_M_VH.ivalid;
   else if (partself_res_w == 4'b0100) assign g_res_w = CH_M_VL.res_w,                                                 g_valid = CH_M_VL.ivalid;
   else if (partself_res_w == 4'b0101) assign g_res_w = CH_M_VL.res_w + CL_M_VL.res_w,                                 g_valid = CH_M_VL.ivalid;
   else if (partself_res_w == 4'b0110) assign g_res_w = CH_M_VL.res_w + CL_M_VH.res_w,                                 g_valid = CH_M_VL.ivalid;
   else if (partself_res_w == 4'b0111) assign g_res_w = CH_M_VL.res_w + CL_M_VH.res_w + CL_M_VL.res_w,                 g_valid = CH_M_VL.ivalid;
   else if (partself_res_w == 4'b1000) assign g_res_w = CH_M_VH.res_w,                                                 g_valid = CH_M_VH.ivalid;
   else if (partself_res_w == 4'b1001) assign g_res_w = CH_M_VH.res_w + CL_M_VL.res_w,                                 g_valid = CH_M_VH.ivalid;
   else if (partself_res_w == 4'b1010) assign g_res_w = CH_M_VH.res_w + CL_M_VH.res_w,                                 g_valid = CH_M_VH.ivalid;
   else if (partself_res_w == 4'b1011) assign g_res_w = CH_M_VH.res_w + CL_M_VH.res_w + CL_M_VL.res_w,                 g_valid = CH_M_VL.ivalid;
   else if (partself_res_w == 4'b1100) assign g_res_w = CH_M_VH.res_w + CH_M_VL.res_w,                                 g_valid = CH_M_VH.ivalid;
   else if (partself_res_w == 4'b1101) assign g_res_w = CH_M_VH.res_w + CH_M_VL.res_w + CL_M_VL.res_w,                 g_valid = CH_M_VL.ivalid;
   else if (partself_res_w == 4'b1110) assign g_res_w = CH_M_VH.res_w + CH_M_VL.res_w + CL_M_VH.res_w,                 g_valid = CH_M_VL.ivalid;
   else if (partself_res_w == 4'b1111) assign g_res_w = CH_M_VH.res_w + CH_M_VL.res_w + CL_M_VH.res_w + CL_M_VL.res_w, g_valid = CH_M_VL.ivalid;
   localparam int iMsbOfPipeRes_inVarConstRes = multconst_localpkg::iMsbOfPipeRes_inVarConstRes(
                                                                     .resbitw_e  (resbitw_e  ),
                                                                     .resbitw_i  (resbitw_i  ),
                                                                     .RESBITW    (RESBITW    ));
   localparam int iLsbOfPipeRes_inVarConstRes = multconst_localpkg::iLsbOfPipeRes_inVarConstRes(
                                                                     .resbitw_e  (resbitw_e  ),
                                                                     .resbitw_i  (resbitw_i  ),
                                                                     .RESBITW    (RESBITW    ));
   localparam int iLsbOfPipeRes_inInputRes    = multconst_localpkg::iLsbOfPipeRes_inInputRes(
                                                                     .resbitw_e  (resbitw_e  ),
                                                                     .resbitw_i  (resbitw_i  ),
                                                                     .RESBITW    (RESBITW    ));
   localparam int iMsbOfPipeRes_inInputRes    = multconst_localpkg::iMsbOfPipeRes_inInputRes(
                                                                     .resbitw_e  (resbitw_e  ),
                                                                     .resbitw_i  (resbitw_i  ),
                                                                     .RESBITW    (RESBITW    ));
   localparam int pipe_resbitw = iMsbOfPipeRes_inInputRes - iLsbOfPipeRes_inInputRes + 1;
   wire [pipe_resbitw-1:0] res2o;
   if      (pipe_resbitw == bitwof_res_w) assign res2o = g_res_w;
   else if (RESBITW > 0) begin
      /*
       * |------pipe_resbitw-----|
       *    |-------bitwof_res_w------|
       */
      localparam int iMsbOfResW2Pick = iMsbOfPipeRes_inVarConstRes > (bitwof_res_w-1) ? (bitwof_res_w-1) : iMsbOfPipeRes_inVarConstRes;
      if (RNDRESLSB == 1'b1 && iLsbOfPipeRes_inVarConstRes > 0)
           assign res2o[iMsbOfResW2Pick-iLsbOfPipeRes_inVarConstRes:0] = g_res_w[bitwof_res_w-1:iLsbOfPipeRes_inVarConstRes] + (res_bitw)'(g_res_w[iLsbOfPipeRes_inVarConstRes-1]);
      else assign res2o[iMsbOfResW2Pick-iLsbOfPipeRes_inVarConstRes:0] = g_res_w[bitwof_res_w-1:iLsbOfPipeRes_inVarConstRes];
      if (iMsbOfResW2Pick < iMsbOfPipeRes_inVarConstRes) assign res2o[pipe_resbitw-1:pipe_resbitw-(iMsbOfPipeRes_inVarConstRes-iMsbOfResW2Pick)] = {(iMsbOfPipeRes_inVarConstRes-iMsbOfResW2Pick){1'b0}};
   end else                               assign res2o = (pipe_resbitw)'(g_res_w);
   pipedelay_taps #(
      .DATABITW   (pipe_resbitw + 1       ),
      .DELAYTAPS  (DELAYTAPS > 0 ? 1 : 0  )
   ) pipe_res(
      .clk     (clk                                                                 ),
      .aclr    (aclr                                                                ),
      .sclr    (sclr                                                                ),
      .clken   (clken                                                               ),
      .x       ({g_valid,   res2o}                                                  ),
      .pipe_x  ({res_valid, res[iMsbOfPipeRes_inInputRes:iLsbOfPipeRes_inInputRes]} )
   );
   if(res_bitw > iMsbOfPipeRes_inInputRes + 1) assign res[res_bitw                -1:iMsbOfPipeRes_inInputRes+1] = {(res_bitw-1-iMsbOfPipeRes_inInputRes){1'b0}};
   if(iLsbOfPipeRes_inInputRes > 0)            assign res[iLsbOfPipeRes_inInputRes-1:                         0] = {(iLsbOfPipeRes_inInputRes){1'b0}};
   endgenerate
endmodule
/*! \brief 兼容有符号数输入的长整型常数乘法器 */
module ilmultconst_negcmb #(
   parameter longint signed MINOF_VAR  = 6'h01,    ///< 有符号变量的定义域范围中的最小值
   parameter longint signed MAXOF_VAR  = 6'h30,    ///< 有符号变量的定义域范围中的最大值
   parameter bit            SIGNED_VAR = 1'b0,     ///< 输入变量是有符号数标志，1'b1-有符号数，以补码形式表示，1'b0-无符号数
   parameter longint signed CONSTARG   = 3,        ///< 常量参数，必须是不等于0的值
   parameter int unsigned   VARBITW    = 0,        ///< 指定的变量位宽， = 0 表示根据变量的最大值、最小值自动计算位宽
   parameter int unsigned   CONSTBITW  = 0,        ///< 指定的常量位宽， = 0 表示根据常量的值自动计算位宽。
                                                   ///< \attention 常量有效位宽：即是常量绝对值的位宽。
   parameter int signed     RESBITW    = 0,        ///< 指定结果位宽， = 0 时表示自动计算最佳位宽， > 0 表示计算结果按高位对齐，< 0 表示计算结果按低位对齐
   parameter bit            USEHRDCOR  = 1'b0,     ///< 使用硬件核例化常数乘法器标志，1'b0-使用逻辑元件例化常数乘法器，1'b1-使用硬件乘法器核例化常数乘法器
   parameter bit            RNDRESLSB  = 1'b1,     ///< 结果最低位做四舍五入处理标志，1'b1-对结果最低位四舍五入，1'b0-不对结果最低位四舍五入
   parameter int            DELAYTAPS  = 0         ///< 延迟输出拍数，可选值：0,1,2,3,4
) (clk, aclr, sclr, clken, var_arg, var_valid, negc, res, res_valid);
   input  bit                       clk;           ///< 驱动时钟
   input  wire                      aclr;          ///< 异步复位信号，高电平(1)有效
   input  wire                      sclr;          ///< 同步复位信号，高电平(1)有效
   input  wire                      clken;         ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   initial if (SIGNED_VAR == 1'b0 && (MINOF_VAR < 0 || MAXOF_VAR < 0)) $error("ilmultconst - MINOF_VAR(%0d) and MAXOF_VAR(%0d) should not be negative for unsigned integer(SIGNED_VAR = %0b)", MINOF_VAR, MAXOF_VAR, SIGNED_VAR);
   localparam int var_bitw = SIGNED_VAR
                             ? multconst_pkg::bitwOfSignedVar(MINOF_VAR, MAXOF_VAR)
                             : multconst_pkg::bitwOfUnsignedVar(MINOF_VAR, MAXOF_VAR);
   localparam int varbitwbyinput = (VARBITW != 0)
                                   ? VARBITW
                                   : var_bitw;
   input  wire[varbitwbyinput-1:0]  var_arg;             ///< 输入的变量被乘数
   input  wire                      var_valid;     ///< 输入变量有效标志，本标志除了可用作同步外，还被用于在仿真时模块内部对 #var_arg 做值域检查的使能控制
   input  wire                      negc;          ///< 运算时常数符号取反标志
   localparam bit neg_constarg = (CONSTARG < 0)
                                 ? 1'b1
                                 : 1'b0;
   localparam longint abs_constarg = neg_constarg
                                    ? (-CONSTARG)
                                    : CONSTARG;
   localparam int constbitw = miscs::minbitw_of_signed_longint(CONSTARG, $bits(CONSTARG));
   initial if (CONSTBITW > 0 && constbitw > CONSTBITW)
      $error("ilmultconst: the bitwidth(%0d) of CONSTARG(%0d) exceeds the parameter CONSTBITW(%0d)", constbitw, CONSTARG, CONSTBITW);
   localparam int constbitw_use = (CONSTBITW > 0)
                                  ? CONSTBITW
                                  : constbitw;
   localparam int resbitw2e = (CONSTBITW == 0)
                              ? multconst_pkg::bitwOfSignedMultRes_constSigned(
                                                .minOfVar   (MINOF_VAR  ),
                                                .maxOfVar   (MAXOF_VAR  ),
                                                .signedVar  (SIGNED_VAR ),
                                                .constArg   (CONSTARG   ))
                              : multconst_pkg::bitwOfSignedMultRes_constBitw(
                                                .minOfVar   (MINOF_VAR  ),
                                                .maxOfVar   (MAXOF_VAR  ),
                                                .signedVar  (SIGNED_VAR ),
                                                .constBitw  (CONSTBITW  ),
                                                .constArg   (CONSTARG   ),
                                                .signedConst(1'b1       ));
   localparam int resbitw_e = (resbitw2e < constbitw_use)
                              ? constbitw_use
                              : resbitw2e;
   localparam int resbitw_i = (CONSTARG == 0 && CONSTBITW == 0)
                              ? 1
                              : miscs::minresbitw_of_signedint_multiply(
                                          .bitwofA(varbitwbyinput+
                                                   (SIGNED_VAR
                                                    ? 0
                                                    : 1)/*变量是无符号数时补齐为有符号数的位宽再计算结果位宽*/),
                                          .bitwofB(constbitw_use  ));
   localparam int res_bitw  = (RESBITW != 0)
                              ? ((RESBITW < 0)
                                 ? (-RESBITW)
                                 : RESBITW)
                              : resbitw_i;
   output logic[res_bitw-1:0]       res;           ///< 乘法结果
   output wire                      res_valid;     ///< 输出结果有效标志

   initial forever begin
      # 2
      if (~aclr & ~sclr & var_valid) begin
         if (SIGNED_VAR == 1'b1) begin
            if ((signed'(var_arg)) < MINOF_VAR || (signed'(var_arg)) > MAXOF_VAR)
               $error("ilmultconst : specified var_arg(%0d) out of range[%0d, %0d]!", longint'(signed'(var_arg)), MINOF_VAR, MAXOF_VAR);
         end else if (var_arg < MINOF_VAR || var_arg > MAXOF_VAR)
            $error("ilmultconst : specified var_arg(%0d) out of range[%0d, %0d]!", var_arg, MINOF_VAR, MAXOF_VAR);
      end
   end
   generate if (abs_constarg == longint'(0)) begin: MULT_0
      assign res = '0;
      pipedelay_taps #(
         .DATABITW   (1          ),
         .DELAYTAPS  (DELAYTAPS  )
      ) pipe_valid(
         .clk     (clk        ),
         .aclr    (aclr       ),
         .sclr    (sclr       ),
         .clken   (clken      ),
         .x       (var_valid  ),
         .pipe_x  (res_valid  )
      );
   end else begin
      localparam int varbitwbyinput4u = varbitwbyinput - (int'(SIGNED_VAR));
      localparam int constbitw_use4u  = constbitw_use - 1;
      localparam int resbitw_e4u = resbitw_e - 1;
      localparam int resbitw_i4u = resbitw_i - 1;
      localparam int signed RESBITW4u = (RESBITW == 0)
                                        ? 0
                                        : ((RESBITW > 0)
                                           ? (RESBITW - 1)
                                           : (RESBITW + 1));
      localparam int iMsbOfPipeRes_inVarConstRes = multconst_localpkg::iMsbOfPipeRes_inVarConstRes(
                                                                        .resbitw_e  (resbitw_e4u),
                                                                        .resbitw_i  (resbitw_i4u),
                                                                        .RESBITW    (RESBITW4u  ));
      localparam int iLsbOfPipeRes_inVarConstRes = multconst_localpkg::iLsbOfPipeRes_inVarConstRes(
                                                                        .resbitw_e  (resbitw_e4u),
                                                                        .resbitw_i  (resbitw_i4u),
                                                                        .RESBITW    (RESBITW4u  ));
      localparam int iLsbOfPipeRes_inInputRes    = multconst_localpkg::iLsbOfPipeRes_inInputRes(
                                                                        .resbitw_e  (resbitw_e4u),
                                                                        .resbitw_i  (resbitw_i4u),
                                                                        .RESBITW    (RESBITW4u  ));
      localparam int iMsbOfPipeRes_inInputRes    = multconst_localpkg::iMsbOfPipeRes_inInputRes(
                                                                        .resbitw_e  (resbitw_e4u),
                                                                        .resbitw_i  (resbitw_i4u),
                                                                        .RESBITW    (RESBITW4u  ));
      localparam int pipe_resbitw = iMsbOfPipeRes_inInputRes - iLsbOfPipeRes_inInputRes + 1;
      wire [pipe_resbitw-1:0] res2o;
      wire                    res_sign;
      if (abs_constarg == longint'(1)) begin: MULT_1
         initial assert(resbitw_e == var_bitw + (SIGNED_VAR == 1'b1 && MINOF_VAR < 0 && miscs::bits_of_signed_longint(.valuei(MINOF_VAR), .maxbits($bits(longint))) == 1+miscs::bits_of_signed_longint(.valuei(MINOF_VAR+1), .maxbits($bits(longint)))) ? 1 : 0);
         wire[var_bitw-1:0]var_multconst, neg_vmc;
         assign neg_vmc = -(signed'(var_arg[var_bitw-1:0]));
         if (neg_constarg) assign var_multconst = negc
                                                  ? var_arg[var_bitw-1:0]
                                                  : neg_vmc;
         else              assign var_multconst = negc
                                                  ? neg_vmc
                                                  : var_arg[var_bitw-1:0];
         /* 
          * pipe_resbitw 与 resbitw_e 低位对齐，因为都是根据 var_bitw 和 constbitw 计算的
          */
         assign res2o    = var_multconst[iMsbOfPipeRes_inVarConstRes:iLsbOfPipeRes_inVarConstRes],
                res_sign = var_multconst[iMsbOfPipeRes_inVarConstRes];
         pipedelay_taps #(
            .DATABITW   (pipe_resbitw+1),
            .DELAYTAPS  (DELAYTAPS     )
         ) pipe_res(
            .clk     (clk                                                                 ),
            .aclr    (aclr                                                                ),
            .sclr    (sclr                                                                ),
            .clken   (clken                                                               ),
            .x       ({var_valid,res2o}                                                   ),
            .pipe_x  ({res_valid,res[iMsbOfPipeRes_inInputRes:iLsbOfPipeRes_inInputRes]}  )
         );
         if (res_bitw > iMsbOfPipeRes_inInputRes+1) assign res[res_bitw                -1:iMsbOfPipeRes_inInputRes+1] = {(res_bitw-1-iMsbOfPipeRes_inInputRes){res[iMsbOfPipeRes_inInputRes]}};
         if (iLsbOfPipeRes_inInputRes > 0)          assign res[iLsbOfPipeRes_inInputRes-1:                         0] = {(iLsbOfPipeRes_inInputRes){1'b0}};
      end else begin: MULT_X
         localparam int umc_delaytaps = (DELAYTAPS > 1)
                                        ? (DELAYTAPS - 1)
                                        : 0;
         wire valid2pipe;
         if (USEHRDCOR) begin
            logic[1:0][resbitw_e                 -1:0]res2tr;
            logic[1:0][var_bitw+((~SIGNED_VAR)&1)-1:0]var_arg_2c;
            if (SIGNED_VAR)assign var_arg_2c[0] = (var_arg[var_bitw-1:0]^{(var_bitw){negc}}) + (var_bitw)'(negc);
            else           assign var_arg_2c[0] = ({1'b0, var_arg[var_bitw-1:0]}^{(var_bitw+1){negc}}) + (var_bitw+1)'(negc);
            if (umc_delaytaps - 1 > 0) begin
               always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
                  if      (aclr) var_arg_2c[1] <= {(var_bitw+(~SIGNED_VAR)){1'b0}};
                  else if (sclr) var_arg_2c[1] <= {(var_bitw+(~SIGNED_VAR)){1'b0}};
                  else           var_arg_2c[1] <= clken ? var_arg_2c[0] : var_arg_2c[1];
               end
            end
            else assign var_arg_2c[1] = var_arg_2c[0];
            localparam bit[constbitw_use-1:0]const2m = (constbitw_use)'(CONSTARG);
            if (SIGNED_VAR)assign res2tr[0] = (signed'(var_arg_2c[1]) * signed'(const2m));//signed'((constbitw_use)'(CONSTARG));
            else           assign res2tr[0] = (signed'(var_arg_2c[1]) * signed'(const2m));//signed'((constbitw_use)'(CONSTARG));
            if (umc_delaytaps - 2 > 0) begin
               always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
                  if      (aclr) res2tr[1] <= {(resbitw_e){1'b0}};
                  else if (sclr) res2tr[1] <= {(resbitw_e){1'b0}};
                  else           res2tr[1] <= clken ? res2tr[0] : res2tr[1];
               end
            end
            else assign res2tr[1] = res2tr[0];
            if (RESBITW >= 0) begin
               roundint #(
                  .ARGBITW    (resbitw_e     ),
                  .SIGNEDARG  (1'b1          ),
                  .RESBITW    (pipe_resbitw+1),
                  .DELAYTAPS  ((umc_delaytaps > 2)
                               ? (umc_delaytaps - 2)
                               : ((umc_delaytaps > 1)
                                  ? (umc_delaytaps - 1)
                                  : umc_delaytaps))
               ) resrnd(
                  .clk  (clk              ),
                  .aclr (aclr             ),
                  .sclr (sclr             ),
                  .clken(clken            ),
                  .a    (res2tr[1]        ),
                  .r    ({res_sign, res2o})
               );
               pipedelay_taps #(
                  .DATABITW   (1             ),
                  .DELAYTAPS  (umc_delaytaps )
               ) pipe_valid(
                  .clk     (clk        ),
                  .aclr    (aclr       ),
                  .sclr    (sclr       ),
                  .clken   (clken      ),
                  .x       (var_valid  ),
                  .pipe_x  (valid2pipe )
               );
            end
            else begin
               pipedelay_taps #(
                  .DATABITW   (pipe_resbitw+2),
                  .DELAYTAPS  (umc_delaytaps )
               ) pipe_valid(
                  .clk     (clk                                ),
                  .aclr    (aclr                               ),
                  .sclr    (sclr                               ),
                  .clken   (clken                              ),
                  .x       ({var_valid, res2tr[pipe_resbitw:0]}),
                  .pipe_x  ({valid2pipe, res_sign, res2o}      )
               );
            end
         end else begin
            wire[var_bitw-1:0]var_in;
            if (SIGNED_VAR == 1'b0) assign var_in = var_arg[var_bitw-1:0];
            else begin
               wire sign_var = var_arg[var_bitw-1];
               // 输入变量取绝对值。
               /* \attention 通过符号位选择和通过异或联合加法的取绝对值运算其运算次数是近似的。原因：
                * 1.符号位选择时仍然需要生成输入变量的负值，这需要一次取反和一次加法运算，再加上根据符号位选择输出，总共需要三次运算，
                * 而经过电路优化后，应该可以降低至两次左右；
                * 2.而异或联合加法的运算需要对输入变量执行取反和加法两次运算；
                */
               assign var_in = (var_arg[var_bitw-1:0]^{(var_bitw){sign_var}}) + (var_bitw)'(sign_var);
            end
            localparam longint abs_maxof_var = (SIGNED_VAR == 1'b1 && MAXOF_VAR < 0)
                                               ? (-MAXOF_VAR)
                                               : MAXOF_VAR;
            localparam longint abs_minof_var = (SIGNED_VAR == 1'b1 && MINOF_VAR < 0)
                                               ? (-MINOF_VAR)
                                               : MINOF_VAR;
            localparam longint maxof_absvar = (abs_maxof_var > abs_minof_var)
                                              ? abs_maxof_var
                                              : abs_minof_var;
            localparam longint minof_absvar = (MAXOF_VAR[$bits(MAXOF_VAR)-1]^MINOF_VAR[$bits(MINOF_VAR)-1])
                                              ? 0
                                              : ((abs_maxof_var < abs_minof_var)
                                                 ? abs_maxof_var
                                                 : abs_minof_var);
            localparam int     var2in_bitw  = multconst_pkg::bitwOfUnsignedVar(minof_absvar, maxof_absvar);
            localparam int     absconstbitw = constbitw_use4u;
            localparam int     absresbitw_e = multconst_pkg::bitwOfUnsignedMultRes_constUnsigned(maxof_absvar, minof_absvar, abs_constarg);
            localparam int signed absres_bitw  = ((RESBITW != 0)
                                                  ? (RESBITW4u + ((RESBITW > 0)
                                                                   ? 1
                                                                   : 0))
                                                  : absresbitw_e);
            localparam int        ures_bitw = miscs::absi(.x(absres_bitw));
            wire[ures_bitw-1:0] ures;
            ulmultconst #(
               .MINOF_VAR  (minof_absvar  ),
               .MAXOF_VAR  (maxof_absvar  ),
               .CONSTARG   (abs_constarg  ),
               .VARBITW    (var2in_bitw   ),
               .CONSTBITW  (absconstbitw  ),
               .RESBITW    (absres_bitw   ),
               .USEHRDCOR  (USEHRDCOR     ),
               .RNDRESLSB  (RNDRESLSB     ),
               .DELAYTAPS  (umc_delaytaps )
            ) umci(
               .clk        (clk                    ),
               .aclr       (aclr                   ),
               .sclr       (sclr                   ),
               .clken      (clken                  ),
               .var_arg    (var_in[var2in_bitw-1:0]),
               .var_valid  (var_valid              ),
               .res        (ures[ures_bitw-1:0]    ),
               .res_valid  (valid2pipe             )
            );
            wire sign2fixres;
            pipedelay_taps #(
               .DATABITW   (1             ),
               .DELAYTAPS  (umc_delaytaps )
            ) signres_pipe(
               .clk     (clk                                                              ),
               .aclr    (aclr                                                             ),
               .sclr    (sclr                                                             ),
               .clken   (clken                                                            ),
               .x       (((neg_constarg^negc)^(SIGNED_VAR&var_arg[var_bitw-1]))&(|var_arg)),
               .pipe_x  (sign2fixres                                                      )
            );
            if (RESBITW == 0) begin
               assign res_sign = sign2fixres&(|ures); // 无符号乘法结果为0时保证符号位为0，避免得到错误的最大负值结果
               if (SIGNED_VAR)assign res2o = (((pipe_resbitw)'(ures))^{(pipe_resbitw){sign2fixres}}) + (pipe_resbitw)'(sign2fixres);
               else           assign res2o = (((pipe_resbitw)'(ures))^{(pipe_resbitw){sign2fixres}});
            end else begin
               wire[ures_bitw:0] res2trunc;
               if (absresbitw_e < ures_bitw - 1) assign res2trunc = ({1'b0, ures}^{(ures_bitw+1){sign2fixres}}) + (ures_bitw+1)'({sign2fixres, {(ures_bitw - absresbitw_e - 1){1'b0}}});
               else                              assign res2trunc = ({1'b0, ures}^{(ures_bitw+1){sign2fixres}}) + (ures_bitw+1)'({sign2fixres});
               if (RESBITW >= 0 || ures_bitw < pipe_resbitw) assign res_sign = sign2fixres&(|ures); // 无符号乘法结果为0时保证符号位为0，避免得到错误的最大负值结果
               else                                          assign res_sign = res2trunc[pipe_resbitw];
               if (pipe_resbitw < ures_bitw && RESBITW > 0) begin
                  if (pipe_resbitw-1 <= ures_bitw)
                     assign res2o = res2trunc[pipe_resbitw-1:0];  // 经仿真验证：前面的无符号乘法做了四舍五入后这里不用再做，做了反而造成结果比真实值小1
                  else begin
                     assign res2o[ures_bitw+1:0] = {res2trunc[ures_bitw], res2trunc[ures_bitw:0]};  // 经仿真验证：前面的无符号乘法做了四舍五入后这里不用再做，做了反而造成结果比真实值小1
                     if (pipe_resbitw-1 > ures_bitw+1)
                        assign res2o[pipe_resbitw-1:ures_bitw+2] = {(pipe_resbitw-1-(ures_bitw+1)){res2o[ures_bitw+1]}};
                  end
               end else begin
                  if (pipe_resbitw-1 <= ures_bitw)
                     assign res2o = res2trunc[pipe_resbitw-1:0];
                  else begin
                     assign res2o = {{(pipe_resbitw-1-ures_bitw){res2trunc[ures_bitw]}}, res2trunc[ures_bitw:0]};
                  end
               end
            end
         end
         pipedelay_taps #(
            .DATABITW   (pipe_resbitw + 2 ),
            .DELAYTAPS  ((DELAYTAPS >= 1)
                         ? 1
                         : 0              )
         ) pipe_res(
            .clk     (clk                                                                                                  ),
            .aclr    (aclr                                                                                                 ),
            .sclr    (sclr                                                                                                 ),
            .clken   (clken                                                                                                ),
            .x       ({valid2pipe, res_sign, res2o}                                                                        ),
            .pipe_x  ({res_valid, res[iMsbOfPipeRes_inInputRes+1], res[iMsbOfPipeRes_inInputRes:iLsbOfPipeRes_inInputRes]} )
         );
         if(res_bitw > iMsbOfPipeRes_inInputRes + 2) assign res[res_bitw                -1:iMsbOfPipeRes_inInputRes+2] = {(res_bitw-iMsbOfPipeRes_inInputRes-2){res[iMsbOfPipeRes_inInputRes+1]}};
         if(iLsbOfPipeRes_inInputRes > 0)            assign res[iLsbOfPipeRes_inInputRes-1:                         0] = {(iLsbOfPipeRes_inInputRes){1'b0}};
      end
   end endgenerate
endmodule
module ilmultconst #(
   parameter longint signed MINOF_VAR  = 6'h01,    ///< 有符号变量的定义域范围中的最小值
   parameter longint signed MAXOF_VAR  = 6'h30,    ///< 有符号变量的定义域范围中的最大值
   parameter bit            SIGNED_VAR = 1'b0,     ///< 输入变量是有符号数标志，1'b1-有符号数，以补码形式表示，1'b0-无符号数
   parameter longint signed CONSTARG   = 3,        ///< 常量参数，必须是不等于0的值
   parameter int unsigned   VARBITW    = 0,        ///< 指定的变量位宽， = 0 表示根据变量的最大值、最小值自动计算位宽
   parameter int unsigned   CONSTBITW  = 0,        ///< 指定的常量位宽， = 0 表示根据常量的值自动计算位宽。
                                                   ///< \attention 常量有效位宽：即是常量绝对值的位宽。
   parameter int signed     RESBITW    = 0,        ///< 指定结果位宽， = 0 时表示自动计算最佳位宽， > 0 表示计算结果按高位对齐，< 0 表示计算结果按低位对齐
   parameter bit            USEHRDCOR  = 1'b0,     ///< 使用硬件核例化常数乘法器标志，1'b0-使用逻辑元件例化常数乘法器，1'b1-使用硬件乘法器核例化常数乘法器
   parameter bit            RNDRESLSB  = 1'b1,     ///< 结果最低位做四舍五入处理标志，1'b1-对结果最低位四舍五入，1'b0-不对结果最低位四舍五入
   parameter int            DELAYTAPS  = 0         ///< 延迟输出拍数，可选值：0,1,2,3,4
) (clk, aclr, sclr, clken, var_arg, var_valid, res, res_valid);
   input  bit                       clk;           ///< 驱动时钟
   input  wire                      aclr;          ///< 异步复位信号，高电平(1)有效
   input  wire                      sclr;          ///< 同步复位信号，高电平(1)有效
   input  wire                      clken;         ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   initial if (SIGNED_VAR == 1'b0 && (MINOF_VAR < 0 || MAXOF_VAR < 0)) $error("ilmultconst - MINOF_VAR(%0d) and MAXOF_VAR(%0d) should not be negative for unsigned integer(SIGNED_VAR = %0b)", MINOF_VAR, MAXOF_VAR, SIGNED_VAR);
   localparam int var_bitw = SIGNED_VAR
                             ? multconst_pkg::bitwOfSignedVar(MINOF_VAR, MAXOF_VAR)
                             : multconst_pkg::bitwOfUnsignedVar(MINOF_VAR, MAXOF_VAR);
   localparam int varbitwbyinput = (VARBITW != 0)
                                   ? VARBITW
                                   : var_bitw;
   input  wire[varbitwbyinput-1:0]  var_arg;             ///< 输入的变量被乘数
   input  wire                      var_valid;     ///< 输入变量有效标志，本标志除了可用作同步外，还被用于在仿真时模块内部对 #var_arg 做值域检查的使能控制
   localparam int constbitw = miscs::minbitw_of_signed_longint(CONSTARG, $bits(CONSTARG));
   initial if (CONSTBITW > 0 && constbitw > CONSTBITW)
      $error("ilmultconst: the bitwidth(%0d) of CONSTARG(%0d) exceeds the parameter CONSTBITW(%0d)", constbitw, CONSTARG, CONSTBITW);
   localparam int constbitw_use = (CONSTBITW > 0)
                                  ? CONSTBITW
                                  : constbitw;
   localparam int resbitw_i = (CONSTARG == 0 && CONSTBITW == 0)
                              ? 1
                              : miscs::minresbitw_of_signedint_multiply(
                                          .bitwofA(varbitwbyinput+
                                                   (SIGNED_VAR
                                                    ? 0
                                                    : 1)/*变量是无符号数时补齐为有符号数的位宽再计算结果位宽*/),
                                          .bitwofB(constbitw_use  ));
   localparam int res_bitw  = (RESBITW != 0)
                              ? ((RESBITW < 0)
                                 ? (-RESBITW)
                                 : RESBITW)
                              : resbitw_i;
   output logic[res_bitw-1:0]       res;           ///< 乘法结果
   output wire                      res_valid;     ///< 输出结果有效标志

   ilmultconst_negcmb #(
      .MINOF_VAR  (MINOF_VAR  ),
      .MAXOF_VAR  (MAXOF_VAR  ),
      .SIGNED_VAR (SIGNED_VAR ),
      .CONSTARG   (CONSTARG   ),
      .VARBITW    (VARBITW    ),
      .CONSTBITW  (CONSTBITW  ),
      .RESBITW    (RESBITW    ),
      .USEHRDCOR  (USEHRDCOR  ),
      .RNDRESLSB  (RNDRESLSB  ),
      .DELAYTAPS  (DELAYTAPS  )
   ) ilmci(
      .clk        (clk        ),
      .aclr       (aclr       ),
      .sclr       (sclr       ),
      .clken      (clken      ),
      .var_arg    (var_arg    ),
      .var_valid  (var_valid  ),
      .negc       (1'b0       ),
      .res        (res        ),
      .res_valid  (res_valid  )
   );
endmodule
