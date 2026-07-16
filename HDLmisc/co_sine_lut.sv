/*!
 * \license SPDX-License-Identifier: MIT
 * \file co_sine_lut.sv
 * \brief 余弦、正弦函数查找表
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, rams, pipedelay
 */
`include "miscs.svh"
`include "rams.svh"
`define __INC_FROM_CO_SIN_LUT__
`include "co_sin_lut.svh"
/*! \brief 整型余弦/正弦函数查找表ROM */
module co_sine_rom #(
   parameter int DATABITW = 8,                     ///< ROM数据位宽
   parameter int EXPBITW  = 1,                     ///< ROM数据指数位宽，>1表示输入数据为浮点数，且 #EXPBITW 是浮点数指数位宽，1-有符号整数，0-无符号整数
                                                   ///< \attention 无符号整数形式的查找表数据是在有符号整数数据的基础上加上 2**(DATABITW-1) 实现。
   parameter int ADDRLEN  = 2**8,                  ///< 地址长度
   parameter int MEM_MODE = 1                      ///< <= 0 -使用较多存储器资源（4倍于最少存储器消耗）以节省组合逻辑资源，响应速度较快；
                                                   ///< == 1 -使用标准的存储器资源（2倍于最少存储器消耗）以换取较快的响应速度；
                                                   ///< >= 2 -使用最少的存储器资源，但输出有组合逻辑电路，响应较慢。
) (clk, clken, addr1, addr2, we, wdata, data1, data2);
   input  bit                         clk;         ///< 驱动时钟
   input  wire                        clken;       ///< 时序逻辑翻转使能信号，高电平(1)使能
   localparam int bitwof_addr = miscs::minbitw_of_longint(ADDRLEN-1, 64);
   input  wire      [bitwof_addr-1:0] addr1;       ///< 端口1读地址
   input  wire      [bitwof_addr-1:0] addr2;       ///< 端口2读地址
   input  wire                        we;          ///< 写使能信号，应保持0.保留该端口是为了去除Altera FPGA平台下的编译警告
   input  wire      [DATABITW-1:0]    wdata;       ///< 写端口数据，应保持全0，保留该端口是为了去除Altera FPGA平台下的编译警告
   output reg signed[DATABITW-1:0]    data1;       ///< 端口1读数据输出，在端口1读地址有效后下一个时钟输出
   output reg signed[DATABITW-1:0]    data2;       ///< 端口2读数据输出，在端口2读地址有效后下一个时钟输出

   initial begin
      if (EXPBITW <= 1) begin
         if (DATABITW > 61)
            $warning("co_sine_rom: DATABITW(%0d) greator than 61 can not be supported on fix data(EXPBITW(%0d) is not greator than 1)! tail bits will be filled with 0!", DATABITW, EXPBITW);
         if (ADDRLEN > 64'd2**61)
            $error("co_sine_rom: ADDRLEN(%0d) greator than 2305843009213693952(2^61) can not be supported on fix data(EXPBITW(%0d) is not greator than 1)!", ADDRLEN, EXPBITW);
      end else begin
         if (EXPBITW < 8)
            $error("co_sine_rom: EXPBITW(%0d) should not be less than 8 for IEEE754 float point data", EXPBITW);
         if (DATABITW < 43 && EXPBITW > 10)
            $error("co_sine_rom: EXPBITW(%0d) should not be greator than 10 while DATABITW(%0d) is less than 43 for IEEE754 float point data", EXPBITW, DATABITW);
         if (DATABITW >= 43 && EXPBITW < 11)
            $error("co_sine_rom: EXPBITW(%0d) should not be less than 1 while DATABITW(%0d) is not less than 43 for IEEE754 float point data", EXPBITW, DATABITW);
         if (DATABITW >= 43 && DATABITW - EXPBITW - 1 < 31)
            $error("co_sine_rom: MANBITW(DATABITW(%0d) - EXPBITW(%0d) - 1 = %0d) should not be less than 31 for IEEE754 float point data", DATABITW, EXPBITW, DATABITW - EXPBITW - 1);
      end
      if (MEM_MODE == 1 && (ADDRLEN % 2) != 0)
         $error("co_sine_rom: MEM_MODE(%0d) that not zero is not allowed while ADDRLEN(%0d) is not the time of 2", MEM_MODE, ADDRLEN);
      if (MEM_MODE >= 2 && (ADDRLEN % 4) != 0)
         $error("co_sine_rom: MEM_MODE(%0d) that greator than 1 is not allowed while ADDRLEN(%0d) is not the time of 4", MEM_MODE, ADDRLEN);
   end
   initial assert(MEM_MODE <= 0 || (MEM_MODE == 1 && (ADDRLEN % 2) == 0) || (MEM_MODE >= 2 && (ADDRLEN % 4) == 0));
   localparam bit signed[DATABITW-1:0] cosine_0 = (EXPBITW > 1)
                                                  ? `IEEE_754_FPCONST_ONE(DATABITW, EXPBITW)
                                                  : (DATABITW)'(((64'd2**61-1)>>(61-(DATABITW-1))) + ((EXPBITW < 1)
                                                                                                      ? (64'd2**(DATABITW-1))
                                                                                                      : 0));
   localparam bit signed[DATABITW-1:0] cosine_pi_2 = (EXPBITW > 1)
                                                     ? `IEEE_754_FPCONST_ZERO(DATABITW, EXPBITW)
                                                     : (DATABITW)'(0 + ((EXPBITW < 1)
                                                                        ? (64'd2**(DATABITW-1))
                                                                        : 0));
   localparam bit signed[DATABITW-1:0] ieeefp_negmsk = {1'b1, {(DATABITW-1){1'b0}}};
   localparam int unfulladdr = (2**rams_pkg::addrLen2AddrBitw(.addrLen(ADDRLEN)) > ADDRLEN)
                               ? 1
                               : 0;
   localparam int addr_of_pi_2 = (ADDRLEN+3)/4;
   localparam int addr_of_pi   = (ADDRLEN+1)/2;
   localparam int addr_of_2pi  = ADDRLEN;
   localparam int addrlen = (MEM_MODE <= 0)
                            ? (addr_of_2pi + unfulladdr)
                            : ((MEM_MODE <= 1)
                               ? (addr_of_pi + unfulladdr)
                               : (addr_of_pi_2 + 1/*加1是为了可以直接从ROM中输出pi/2相位对应的三角函数值*/));
   function automatic bit[addrlen-1:0][DATABITW-1:0] prepare_lut();
      bit[addrlen-1:0][DATABITW-1:0] ret;
      if (EXPBITW <= 1) begin// 定点数实现
         miscs::divres_t dr;
         longint signed iphs, iphsend, idx, idxend, it2end, divdr, it2add;
         dr = miscs::fixdiv(.divd(miscs::q61_pi),.divs(ADDRLEN));
         it2add = miscs::divres2qfix(.dr(dr),.fracbits(1)); // 0...2pi的枚举范围的累加量
         // 枚举计算 0 ... pi/2 的三角函数值
         ret[0] = cosine_0;
         if (ADDRLEN % 4 == 0) it2end = miscs::q61_pi/2;
         else                  it2end = miscs::q61_pi;
         for (iphs = it2add, idx = 1; iphs < it2end; iphs += it2add, idx++) begin
            longint signed res = miscs::q61cos(iphs);
            longint signed val = (res>>>(61-(DATABITW-1)));
            if(EXPBITW < 1)ret[idx] = val + (64'd2**(DATABITW-1));
            else           ret[idx] = val[DATABITW-1] ? val - ((DATABITW)'(1)) : val;
         end
         // 拷贝或者枚举计算 pi/2 ... pi 的三角函数
         idxend = idx;
         iphsend = iphs;
         if ((ADDRLEN % 4) != 0) begin
            /* 本模块的调用者限制 #MEM_MODE >= 2 时 #ADDRLEN 必须保证可被 4 整除，
             * 因此这里可以不考虑 #MEM_MODE >= 2 且 #ADDRLEN 不能被 4 整除的情况。
             */
            for (iphs = iphsend, idx = idxend; idx < addr_of_pi; idx++, iphs += it2add) begin
               longint signed res = miscs::q61cos(iphs);
               longint signed val = (res>>>(61-(DATABITW-1)));
               if(EXPBITW < 1) ret[idx] = val + (64'd2**(DATABITW-1));
               else            ret[idx] = val[DATABITW-1] ? val - ((DATABITW)'(1)) : val;
            end
            // if (MEM_MODE == 1 && (addr_of_pi % 2) != 0) ret[addr_of_pi] = -cosine_0;
         end else begin
            // MEM_MODE < 2 && ADDRLEN % 4 == 0
            // 复制 0 - pi/2 的余弦函数值到 pi/2 - pi
            // pi/2
            ret[addr_of_pi_2] = cosine_pi_2;
            // (pi/2, pi)
            if (MEM_MODE < 2) begin
               for (idx = addr_of_pi_2 + 1; idx < addr_of_pi; idx ++) begin
                  ret[idx] = -ret[addr_of_pi - idx];
               end
            end
         end
         // 拷贝或者枚举计算 pi ... 2pi 的三角函数
         idxend = idx;
         if ((ADDRLEN % 2) != 0) begin
            for (idx = idxend; idx < ADDRLEN; idx++) begin
               longint signed q61coef_of_pi, res;
               longint signed val;
               q61coef_of_pi = miscs::q61coef_of_pi_for_triangular_on_div(
                                       .divdent (idx*2   ), // 三角函数相位范围是0...2pi，这里 idx*2 是为了计算 2pi 周期的相位值
                                       .divisor (ADDRLEN ));
               res = miscs::q61cos(miscs::q61mult(.q61xi(miscs::q61_pi),.q61yi(q61coef_of_pi)));
               val = (res>>>(61-(DATABITW-1)));
               if(EXPBITW < 1)ret[idx] = val + (64'd2**(DATABITW-1));
               else           ret[idx] = val[DATABITW-1] ? val - ((DATABITW)'(1)) : val;
            end
         end else begin
            // ADDRLEN % 2 == 0
            // 复制 0 - pi 的余弦值到 pi - 2pi
            // pi
            ret[addr_of_pi] = -cosine_0;
            for (idx = addr_of_pi + 1; idx < addr_of_2pi; idx++) begin
               ret[idx] = ret[addr_of_2pi - idx];
            end
         end
         if (unfulladdr == 1) begin
            if      (MEM_MODE <= 0) ret[addr_of_2pi] = ret[0];
            else if (MEM_MODE == 1) ret[addr_of_pi] = -cosine_0;
         end
      end else begin// IEEE754浮点数实现
         miscs::sfpt iphs, iphsend, it2end, divdr, it2add;
         longint signed idx, idxend;
         it2add = miscs::sfp_div(.divd(miscs::sfp_2pi),.divs(miscs::sfp_makesfp_byqp(.qp(ADDRLEN),.qwidth(0)))); // 0...2pi的枚举范围的累加量
         // 枚举计算 0 ... pi/2 的三角函数值
         ret[0] = cosine_0;
         if (ADDRLEN % 4 == 0) it2end = miscs::sfp_hf_pi;
         else                  it2end = miscs::sfp_pi;
         for (iphs = it2add, idx = 1; miscs::sfp_cmp(.p1(iphs),.p2(it2end)) < 0; iphs = miscs::sfp_add(.sfp1i(iphs),.sfp2i(it2add)), idx++) begin
            miscs::sfpt res = miscs::sfp_cos(.phsi(iphs));
            // $display("DBG-1: idx = %0d, res = ", idx); miscs::sfp_printg(res, 6);
            ret[idx][DATABITW-1] = miscs::ieeefp_sign_of_sfp(.sfp(res));
            ret[idx][DATABITW-2:DATABITW-1-EXPBITW] = miscs::ieeefp_exp_of_sfp(.sfp(res),.expbitw(EXPBITW));
            ret[idx][DATABITW-2-EXPBITW:0] = miscs::ieeefp_man_of_sfp(.sfp(res),.manbitw(DATABITW-1-EXPBITW));
         end
         // 拷贝或者枚举计算 pi/2 ... pi 的三角函数
         idxend = idx;
         iphsend = iphs;
         if ((ADDRLEN % 4) != 0) begin
            /* 本模块的调用者限制 #MEM_MODE >= 2 时 #ADDRLEN 必须保证可被 4 整除，
            * 因此这里可以不考虑 #MEM_MODE >= 2 且 #ADDRLEN 不能被 4 整除的情况。
            */
            for (iphs = iphsend, idx = idxend; idx < addr_of_pi; idx++, iphs += it2add) begin
               miscs::sfpt res = miscs::sfp_cos(.phsi(iphs));
               ret[idx][DATABITW-1] = miscs::ieeefp_sign_of_sfp(.sfp(res));
               ret[idx][DATABITW-2:DATABITW-1-EXPBITW] = miscs::ieeefp_exp_of_sfp(.sfp(res),.expbitw(EXPBITW));
               ret[idx][DATABITW-2-EXPBITW:0] = miscs::ieeefp_man_of_sfp(.sfp(res),.manbitw(DATABITW-1-EXPBITW));
            end
            // if (MEM_MODE == 1 && (addr_of_pi % 2) != 0) ret[addr_of_pi] = -cosine_0;
         end else begin
            // MEM_MODE < 2 && ADDRLEN % 4 == 0
            // 复制 0 - pi/2 的余弦函数值到 pi/2 - pi
            // pi/2
            ret[addr_of_pi_2] = cosine_pi_2;
            // (pi/2, pi)
            if (MEM_MODE < 2) begin
               for (idx = addr_of_pi_2 + 1; idx < addr_of_pi; idx ++) begin
                  ret[idx] = (ret[addr_of_pi - idx]^ieeefp_negmsk);
               end
            end
         end
         // 拷贝或者枚举计算 pi ... 2pi 的三角函数
         idxend = idx;
         if ((ADDRLEN % 2) != 0) begin
            for (idx = idxend; idx < ADDRLEN; idx++) begin
               miscs::sfpt res;
               iphs = miscs::sfp_div(
                              .divd(miscs::sfp_mul(miscs::sfp_2pi, miscs::sfp_makesfp_byqp(.qp(idx),.qwidth(0)))),
                              .divs(miscs::sfp_makesfp_byqp(.qp(ADDRLEN),.qwidth(0))));
               res = miscs::sfp_cos(.phsi(iphs));
               ret[idx][DATABITW-1] = miscs::ieeefp_sign_of_sfp(.sfp(res));
               ret[idx][DATABITW-2:DATABITW-1-EXPBITW] = miscs::ieeefp_exp_of_sfp(.sfp(res),.expbitw(EXPBITW));
               ret[idx][DATABITW-2-EXPBITW:0] = miscs::ieeefp_man_of_sfp(.sfp(res),.manbitw(DATABITW-1-EXPBITW));
            end
         end else begin
            // ADDRLEN % 2 == 0
            // 复制 0 - pi 的余弦值到 pi - 2pi
            // pi
            ret[addr_of_pi] = (cosine_0^ieeefp_negmsk);
            for (idx = addr_of_pi + 1; idx < addr_of_2pi; idx++) begin
               ret[idx] = ret[addr_of_2pi - idx];
            end
         end
         if (unfulladdr == 1) begin
            if      (MEM_MODE <= 0) ret[addr_of_2pi] = ret[0];
            else if (MEM_MODE == 1) ret[addr_of_pi] = (cosine_0^ieeefp_negmsk);
         end
      end
      return ret;
   endfunction
   localparam bit[addrlen-1:0][DATABITW-1:0] initrom = prepare_lut();
   // localparam bit[addrlen-1:0][DATABITW-1:0] initrom = '0;//prepare_lut();
   localparam int bitwofaddr2use = rams_pkg::addrLen2AddrBitw(.addrLen(addrlen));
   (* ram_style = (rams_pkg::recommend_ramstyle(addrlen, DATABITW) == 0) ? rams_pkg::ramstyle_logic : rams_pkg::ramstyle_ram *)
   reg signed[DATABITW-1:0]rom[addrlen-1:0];
   initial begin
      automatic longint i;
      // prepare_lut();
      for (i = 0; i < addrlen; i++)
         rom[i] = initrom[i];
   end
`ifdef COMPILER_QUARTUS
   always @(posedge clk) begin
      if (clken&we) begin
`ifndef  __MODELSIM__
         rom[addr1] <= wdata;
`endif
         data1      <= wdata;
         data2      <= wdata;
      end
      else begin
         data1 <= clken ? rom[addr1[bitwofaddr2use-1:0]] : data1;
         data2 <= clken ? rom[addr2[bitwofaddr2use-1:0]] : data2;
      end
   end
`else
   always @(posedge clk) begin
      data1 <= clken ? rom[addr1[bitwofaddr2use-1:0]] : data1;
      data2 <= clken ? rom[addr2[bitwofaddr2use-1:0]] : data2;
   end
`endif
endmodule
/*!
 * \brief 整型余弦、正弦函数查找表
 */
module co_sine_table #(
   parameter int MAGBITW        = 8,               ///< 函数输出幅度值位宽
   parameter int EXPBITW        = 1,               ///< 幅值数据指数位宽，>1表示输入数据为浮点数，且 #EXPBITW 是浮点数指数位宽，1-有符号整数，0-无符号整数
                                                   ///< \attention 无符号整数形式的查找表数据是在有符号整数数据的基础上加上 2**(DATABITW-1) 实现。
   parameter int PHSLEN         = 8,               ///< 表示一周的相位的量化数，对应于以弧度为单位的角度 [0, 2pi)，或者以度为单位的角度[0,360)
   parameter bit LEADING_ORTHOG = 1'b1,            ///< 超前正交支路模式，1-正交支路输出的相位超前于同相支路90°，其他值-正交支路输出的相位滞后于同相支路90°
   parameter int MEM_MODE       = 1,               ///< 存储器资源使用模式，查找表输出延迟拍数与该参数有关，可用 co_sine_lut_pkg::delaytaps_i 获取：
                                                   ///< <= 0 -使用较多存储器资源（4倍于最少存储器消耗）以节省逻辑资源，响应速度较快；
                                                   ///< == 1 -使用标准的存储器资源（2倍于最少存储器消耗）以及一定的逻辑资源，响应速度较慢
                                                   ///< >= 2 -使用最少的存储器资源以及最多的逻辑资源，响应速度较慢
   parameter bit NONEGPHS       = 1'b0             ///< 相位无负值输入标志，1'b0-相位输入取值范围为-pi - +pi ； 1'b1-相位输入取值范围为 0 - +2pi 。
                                                   ///< \attention
                                                   ///< - 对 #PHSLEN 是 2 的幂次的情况，相位输入取值范围设置为 -pi - +pi 与 0 - +2pi 消耗的资源情况相同
                                                   ///< - 对 #PHSLEN 不是 2 的幂次的情况，将相位输入取值范围设置为 0 - +2pi 则可比设置为 -pi - +pi 的情况节省转换电路和资源。
) (clk, clken, idxInPhs, magInPhs, magOrthog);
   input  bit                          clk;        ///< 驱动时钟
   input  wire                         clken;      ///< 时序逻辑翻转使能信号，高电平(1)使能
   localparam int bitwOfPhs = miscs::minbitw_of_longint(PHSLEN-1,64);
   input  wire        [bitwOfPhs-1:0]  idxInPhs;   ///< 取值范围： #NONEGPHS == 1'b1 时 [0, PHSLEN] ， #NONEGPHS == 1'b0 时 [-PHSLEN/2, PHSLEN/2]
                                                   ///< \attention 当给出的相位值超出有效取值范围时，模块将无法返回正确的函数值
   output logic signed[MAGBITW-1:0]    magInPhs;   ///< 同相（余弦）函数值
   output logic signed[MAGBITW-1:0]    magOrthog;  ///< 正交（正弦）函数值

   initial begin
      if (MEM_MODE >= 2 && (PHSLEN % 4) != 0)
         $error("co_sine_table: PHSLEN(%0d) should be divisable by 4 while MEM_MODE(%0d) is set to greator than or equal to 2", PHSLEN, MEM_MODE);
      if (MEM_MODE == 1 && (PHSLEN % 2) != 0)
         $error("co_sine_table: PHSLEN(%0d) should be divisable by 2 while MEM_MODE(%0d) is set to 1", PHSLEN, MEM_MODE);
   end
   localparam bit [bitwOfPhs:0]addr_of_pi_2 = (bitwOfPhs+1)'((PHSLEN+3)/4);
   localparam bit [bitwOfPhs:0]addr_of_pi   = (bitwOfPhs+1)'((PHSLEN+1)/2);
   localparam bit [bitwOfPhs:0]addr_of_3pi_2 = (bitwOfPhs+1)'(PHSLEN - PHSLEN/4);
   localparam bit [bitwOfPhs:0]addr_of_2pi   = (bitwOfPhs+1)'(PHSLEN);
   wire [bitwOfPhs-1:0] idxOrth_RA, idxInPhs_RA;
   wire                 negOrth, negInPhs;
   generate
   if (PHSLEN == 2**bitwOfPhs) begin: FULLADDR
      wire[1:0]inPhsMSB = idxInPhs[bitwOfPhs-1:bitwOfPhs-2];
      wire[1:0]orthMSBs = LEADING_ORTHOG == 1'b1 ? inPhsMSB + 2'd1 : inPhsMSB - 2'd1;
      if (MEM_MODE <= 0) begin
         assign idxInPhs_RA = idxInPhs, idxOrth_RA = {orthMSBs, idxInPhs[bitwOfPhs-3:0]};
         assign negInPhs = 1'b0, negOrth = 1'b0;
      end
      else if (MEM_MODE == 1) begin
         /* ROM 地址范围：0 - pi */
         /* idxInPhs    idxInPhs_RA       NEG(MAG)
            < pi/2      idxInPhs             N
            < pi        idxInPhs             N
            < 3pi/2     idxInPhs             Y
            < 2pi       idxInPhs             Y
            idxOrth 的判断真值表与 idxInPhs 一致
          */
         assign idxInPhs_RA = idxInPhs, negInPhs = idxInPhs[bitwOfPhs-1];
         assign idxOrth_RA  = {orthMSBs, idxInPhs[bitwOfPhs-3:0]}, negOrth = orthMSBs[1];
      end else if (MEM_MODE == 2) begin
         /* ROM 地址范围：0 - pi/2 */
         /* idxInPhs    idxInPhs_RA       NEG(MAG)
            < pi/2      idxInPhs          N
            < pi        pi - idxInPhs     Y
            < 3pi/2     idxInPhs - pi     Y
            < 2pi       2pi - idxInPhs    N
          */
         assign idxInPhs_RA[bitwOfPhs-1] = 1'b0,
                idxInPhs_RA[bitwOfPhs-2] = (inPhsMSB[0]&(~(|idxInPhs[bitwOfPhs-3:0]))),
                idxInPhs_RA[bitwOfPhs-3:0] = inPhsMSB[0] ? -idxInPhs[bitwOfPhs-3:0] : idxInPhs[bitwOfPhs-3:0];
         assign negInPhs    = ^inPhsMSB;
         wire[bitwOfPhs-1:0]idxOrth_e  = {orthMSBs, idxInPhs[bitwOfPhs-3:0]};
         assign idxOrth_RA[bitwOfPhs-1] = 1'b0,
                idxOrth_RA[bitwOfPhs-2] = (orthMSBs[0]&(~(|idxInPhs[bitwOfPhs-3:0]))),
                idxOrth_RA[bitwOfPhs-3:0] = orthMSBs[0] ? -idxInPhs[bitwOfPhs-3:0] : idxInPhs[bitwOfPhs-3:0];
         assign negOrth    = ^orthMSBs;
      end
   end else begin: UNFULLADDR
      // 当 #NONEGPHS == 1'b0 时， #idxInPhs < 0 则 #idxInPhs + 2pi
      wire[bitwOfPhs:0] idxOrth_m2Pi, idxInPhs_m2Pi, idxInPhs_e;
      if (NONEGPHS == 1'b0)assign idxInPhs_e = idxInPhs[bitwOfPhs-1] ? {idxInPhs[bitwOfPhs-1], idxInPhs} + addr_of_2pi + 1 : {1'b0, idxInPhs[bitwOfPhs-1:0]};
      else                 assign idxInPhs_e = {1'b0, idxInPhs};
      // 输入相位模至 0 - 2pi 之间的角度：因为当地址长度非2的幂次时，在ROM中设计 -pi 到 pi 之间的地址需要消耗额外的存储器空间，并不划算
      assign idxInPhs_m2Pi = (idxInPhs_e >= addr_of_2pi) ? idxInPhs_e - addr_of_2pi : idxInPhs_e;
      if (LEADING_ORTHOG == 1'b1) begin: LEADORTH
         /* orthogPhs:
               inPhs             inPhs + pi/2           y            inPhs + pi/2 + y        y_of_inPhs
           截止于 4pi
           >= 7pi/2                 >= 4pi            -4pi                 >= 0                 -3pi/2 - 2pi
           >= 3pi                   >= 7pi/2          -2pi                 >= 3pi/2             -3pi/2
           >= 5pi/2                 >= 3pi            -2pi                 >= pi                -3pi/2
           >= 2pi                   >= 5pi/2          -2pi                 >= pi/2              -3pi/2
           >= 3pi/2                 >= 2pi            -2pi                 >= 0                 -3pi/2
           >= pi                    >= 3pi/2            0                  >= 3pi/2              +pi/2
           >= pi/2                  >= 1pi              0                  >= pi                 +pi/2
           >= 0                     >= pi/2             0                  >= pi/2               +pi/2
           >= -pi/2                 >= 0                0                  >= 0                  +pi/2
           >= -pi                   >= -pi/2          +2pi                 >= 3pi/2              -pi/2 + 2pi
          */
         assign idxOrth_m2Pi = (idxInPhs_e < addr_of_3pi_2) ? (idxInPhs_e + addr_of_pi_2)
                                                            : ((idxInPhs_e < (addr_of_3pi_2 + addr_of_2pi)) ? (idxInPhs_e - addr_of_3pi_2)
                                                                                                            : (idxInPhs_e - addr_of_2pi - addr_of_3pi_2));
      end else begin: FOLWORTH
         /* orthogPhs:
               inPhs             inPhs - pi/2           y           inPhs - pi/2 + y        y_of_inPhs
           截止于 4pi
           >= 7pi/2                 >= 3pi            -2pi                 >= pi            -pi/2 - 2pi
           >= 3pi                   >= 5pi/2          -2pi                 >= pi/2          -pi/2 - 2pi
           >= 5pi/2                 >= 2pi            -2pi                 >= 0             -pi/2 - 2pi
           >= 2pi                   >= 3pi/2            0                  >= 3pi/2         -pi/2
           >= 3pi/2                 >= pi               0                  >= pi            -pi/2
           >= pi                    >= pi/2             0                  >= pi/2          -pi/2
           >= pi/2                  >= 0                0                  >= 0             -pi/2
           >= 0                     >= -pi/2          +2pi                 >= 3pi/2         3pi/2
          */
         assign idxOrth_m2Pi = (idxInPhs_e < addr_of_pi_2) ? (idxInPhs_e + addr_of_3pi_2)
                                                           : ((idxInPhs_e < (addr_of_pi_2 + addr_of_2pi)) ? (idxInPhs_e - addr_of_pi_2)
                                                                                                          : (idxInPhs_e - addr_of_pi_2 - addr_of_2pi));
      end
      if (MEM_MODE <= 0) begin: MM0
         /* ROM 地址范围：0~2pi */
         assign idxInPhs_RA = idxInPhs_m2Pi[bitwOfPhs-1:0], idxOrth_RA = idxOrth_m2Pi[bitwOfPhs-1:0];
         assign negOrth = 1'b0, negInPhs = 1'b0;
      end else if (MEM_MODE == 1) begin: MM1
         /* ROM 地址范围：0-pi */
         wire[bitwOfPhs:0] idxInPhs_RA_e = (idxInPhs_m2Pi >= addr_of_pi) ? (addr_of_2pi - idxInPhs_m2Pi) : idxInPhs_m2Pi;
         wire[bitwOfPhs:0] idxOrth_RA_e = (idxOrth_m2Pi >= addr_of_pi) ? (addr_of_2pi - idxOrth_m2Pi) : idxOrth_m2Pi;
         assign idxInPhs_RA = idxInPhs_RA_e[bitwOfPhs-1:0];
         assign idxOrth_RA  = idxOrth_RA_e[bitwOfPhs-1:0];
         assign negInPhs = 1'b0;//(idxInPhs_m2Pi >= addr_of_pi) ? 1'b1 : 1'b0;
         assign negOrth = 1'b0;//(signed'(idxOrth_m2Pi) >= signed'({addr_of_pi)) ? 1'b1 : 1'b0;
      end else begin: MM2
         /* ROM 地址范围：0-pi/2 */
         /* idxInPhs_m2Pi     idxInPhs_RA          neg(idxInPhs_RA)
            0 - pi/2          idxInPhs_m2Pi              N
            pi/2 - pi         pi - idxInPhs_m2Pi         Y
            pi - 3pi/2        idxInPhs_m2Pi - pi         Y
            3pi/2 - 2pi       2pi - idxInPhs_m2Pi        N
          */
         wire[bitwOfPhs:0] idxInPhs_RA_e = (idxInPhs_m2Pi >= addr_of_3pi_2) ? (addr_of_2pi - idxInPhs_m2Pi)
                                                                            : ((idxInPhs_m2Pi >= addr_of_pi) ? (idxInPhs_m2Pi - addr_of_pi)
                                                                                                             : ((idxInPhs_m2Pi >= addr_of_pi_2) ? (addr_of_pi - idxInPhs_m2Pi)
                                                                                                                                                : idxInPhs_m2Pi));
         /* idxOrth_m2Pi:与 idxInPhs_m2Pi 的判断类似
          */
         wire[bitwOfPhs:0] idxOrth_RA_e = (idxOrth_m2Pi >= addr_of_3pi_2) ? (addr_of_2pi - idxOrth_m2Pi)
                                                                          : ((idxOrth_m2Pi >= addr_of_pi) ? (idxOrth_m2Pi - addr_of_pi)
                                                                                                          : ((idxOrth_m2Pi >= addr_of_pi_2) ? (addr_of_pi - idxOrth_m2Pi)
                                                                                                                                            : idxOrth_m2Pi));
         assign idxInPhs_RA = idxInPhs_RA_e[bitwOfPhs-1:0];
         assign idxOrth_RA  = idxOrth_RA_e[bitwOfPhs-1:0];
         assign negInPhs = (idxInPhs_m2Pi >= addr_of_pi_2 && idxInPhs_m2Pi < addr_of_3pi_2) ? 1'b1 : 1'b0;
         assign negOrth  = (idxOrth_m2Pi  >= addr_of_pi_2 && idxOrth_m2Pi  < addr_of_3pi_2) ? 1'b1 : 1'b0;
      end
   end
   logic [1:0][bitwOfPhs-1:0] idxRA;
   always_ff @(posedge clk) begin
      idxRA <= clken ? {idxOrth_RA, idxInPhs_RA} : idxRA;
   end
   wire [1:0][MAGBITW-1:0] mag2o;
   co_sine_rom #(
      .DATABITW(MAGBITW),  .EXPBITW(EXPBITW),.ADDRLEN(PHSLEN), .MEM_MODE(MEM_MODE)
   ) phs2mag_rom(
      .clk(clk),        .clken(clken),
      .addr1(idxRA[0]), .addr2(idxRA[1]),
      .we(1'b0),        .wdata('0),
      .data1(mag2o[0]), .data2(mag2o[1])
   );
   if (MEM_MODE > 0) begin
      wire  [1:0]                negRes;
      pipedelay_taps #(
         .DATABITW(2),  .DELAYTAPS(2)
      ) negres_flag_pipe(
         .clk(clk),  .aclr(1'b0),.sclr(1'b0),.clken(clken),.x({negOrth,negInPhs}), .pipe_x(negRes)
      );
      always_ff @(posedge clk) begin
         magInPhs  <= clken ? (negRes[0] ? -mag2o[0] : mag2o[0]) : magInPhs;
         magOrthog <= clken ? (negRes[1] ? -mag2o[1] : mag2o[1]) : magOrthog;
      end
   end else begin
      assign magInPhs = mag2o[0], magOrthog = mag2o[1];
   end endgenerate
endmodule

