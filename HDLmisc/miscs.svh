/*!
 * \license SPDX-License-Identifier: MIT
 * \file miscs.svh
 * \brief 部分通用工具类函数的头文件
 * \attention 编译需预定义的宏有：
 * -
 * -# COMPILER_xxx ，编译/综合器的版本号，可选用的有：
 *    - #COMPILER_VIVADO ，定义 Vivado 的版本号，eg. 2016 , 2017 , 2020 ...
 *    - #COMPILER_QUARTUS ，定义，Quartus 的版本号，eg. 16 , 17 , 18 ...
 * -# BLKRAM_xxx ，块RAM资源配置参数，可配置的有：
 *    - #BLKRAM_RAMBITS ，定义可引用的单位块RAM资源的存储位数，根据器件上块RAM资源的可配置最大位宽设置，若未定义该宏，则默认引用 Xilinx K7 系列芯片的资源配置(18*1024)。
 *    - #BLKRAM_MAXBITS4SDP ，定义可用于简单双口RAM的块RAM最大位宽，根据器件上块RAM资源的可配置最大位宽设置，若未定义该宏，则默认引用 Xilinx K7 系列芯片的资源配置(72)。
 *    - #BLKRAM_MAXBITS4TDP ，定义可用于真双口RAM的块RAM最大位宽，根据器件上块RAM资源的可配置最大位宽设置，若未定义该宏，则默认引用 Xilinx K7 系列芯片的资源配置(36)。
 *    - #BLKRAM_MINBITW4NORSV ，定义可不产生闲置比特的块RAM最小位宽（例如，当配置RAM位宽为 1bit 时，最小位宽为9的块RAM将有 8bits 位宽被闲置），根据器件上块RAM资源参数配置
 *    - #BLKRAM_MINBITS_RECOMMEND ，定义建议使用块RAM资源例化RAM的最小比特数门限，当需要例化的RAM总比特数高于该门限时， #rams_pkg::recommend_ramstyle() 将返回建议使用
 * 块RAM资源的代码，否则返回建议使用逻辑资源的代码。未定义该宏时 #rams_pkg::recommend_ramstyle() 使用默认参数  18*(2**9) 。
 * -# #SHIFTTAPS_TAPS2RAM ，定义使用RAM资源例化移阶寄存器的移阶拍数门限，与宏 #ALLBITS2RAM_GATE 一起使用，当移阶拍数高于该门限，且满足移阶寄存器需要使用的全
 * 部比特数高于宏 #ALLBITS2RAM_GATE 定义的值时，程序将使用RAM资源（块RAM或者逻辑资源RAM）例化移阶寄存器，未定义该宏时则默认使用门限 4 。
 * -# #ALLBITS2RAM_GATE ，定义使用RAM资源例化移阶寄存器的比特位数门限，与宏 #SHIFTTAPS_TAPS2RAM 一起使用，当移阶寄存器需要使用的全部比特数高于该门限，且满足
 * 移阶拍数高于宏 #SHIFTTAPS_TAPS2RAM 定义的值时，程序将使用RAM资源（块RAM或者逻辑资源RAM）例化移阶寄存器，未定义该宏时则默认使用参数 40 。
 * -# MUX_xxx ，多路复选器配置参数，可配置的有：
 *    - #MAXINPUTS_OFBASICMUX 定义每个基本多路复选器支持的最多输入路数，当输入的路数超过该门限时，将例化更多的多路复选器来执行复选，未定义该宏时默认使用参数 4 。
 *    - #MUX_MAXOUTBITS 定义每个基本多路复选器最多复选输出的位宽数，当需要复选输出的位宽数超过该门限时，将例化更多的多路复选器来执行复选，未定义该宏时默认使用参数 4096 。
 * -# FFT_xxx ，FFT核配置参数，可配置的有：
 *    - #FFT_AUTOGEN_TWROM_LOG2PTS_LIMIT ，定义FFT核旋转因子自动生成的点数限制，该门限大于0且旋转因子乘法对应的点数超过该门限时，程序将从文件中读取旋转因子参数表，否则
 * 自动生成参数表，未定义该宏时默认使用参数 0 。
 * \author JohnYork <johnyork@yeah.net>
 */
/* -- SystemVerilog头文件宏模板

`ifdef  __INC_FROM_xxx__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_xxx__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __xxx_PKG__
 `define __xxx_PKG__

 `endif//__xxx_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef __xxx_ITF__
 `define __xxx_ITF__

 `endif//__xxx_ITF__

`else
 `undef  __ITF_BANNED__
`endif

 */
`ifdef  __INC_FROM_MISCS__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_MISCS__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef  __MISCS_PKG__
 `define  __MISCS_PKG__
package miscs;
   /*! \brief 预定义宏参数转换 */
   ///< 逻辑/分布式RAM资源标识关键字
   localparam miscs_ramstyle_logic = 
   `ifdef   COMPILER_VIVADO
      "distributed";
   `elsif   COMPILER_QUARTUS
      "logic";
   `else
      "";
   `endif
   // 单位块RAM资源的位数
   `ifndef  BLKRAM_RAMBITS
   localparam int blkram_rambits = 1024*18;
   `else
   localparam int blkram_rambits = `BLKRAM_RAMBITS;
   `endif// BLKRAM_RAMBITS
   // 可用于简单双口RAM的块RAM最大位宽
   `ifndef  BLKRAM_MAXBITW4SDP
   localparam int blkram_maxbitw4sdp = 72;
   `else
   localparam int blkram_maxbitw4sdp = `BLKRAM_MAXBITW4SDP;
   `endif// BLKRAM_MAXBITW4SDP
   // 可用于真双口RAM的块RAM最大位宽
   `ifndef  BLKRAM_MAXBITW4TDP
   localparam int blkram_maxbitw4tdp = 36;
   `else
   localparam int blkram_maxbitw4tdp = `BLKRAM_MAXBITW4TDP;
   `endif
   `ifdef  BLKRAM_MINBITS_RECOMMEND
   localparam int blkram_minbits_recommend = `BLKRAM_MINBITS_RECOMMEND;
   `elsif COMPILER_QUARTUS
   localparam int blkram_minbits_recommend = 10*(2**10);
   `elsif COMPILER_VIVADO
   localparam int blkram_minbits_recommend = 10*(2**9);  // 以K7的单位BlockRam为标准
   `else
   localparam int blkram_minbits_recommend = 10*(2**9);  // 以K7的单位BlockRam为标准
   `endif
   // 可不产生闲置比特的块RAM最小位宽
   `ifdef  BLKRAM_MINBITW4NORSV
   localparam int blkram_minbitw4norsv = `BLKRAM_MINBITW4NORSV;
   `elsif   COMPILER_QUARTUS
   localparam int blkram_minbitw4norsv = 10;
   `elsif   COMPILER_VIVADO
   localparam int blkram_minbitw4norsv = 9;
   `else
   localparam int blkram_minbitw4norsv = 9;
   `endif
   ///< 使用RAM例化移阶寄存器的移阶时钟拍数门限
   `ifndef  SHIFTTAPS_TAPS2RAM
   localparam int taps2ram = 4;
   `else
   localparam int taps2ram = `SHIFTTAPS_TAPS2RAM;
   `endif
   ///< 例化RAM的最小比特位数门限
   `ifndef  ALLBITS2RAM_GATE
   localparam int allbits2ram = 64;
   `else
   localparam int allbits2ram = `ALLBITS2RAM_GATE;
   `endif
   ///< SFFT用CORDIC计算旋转因子乘法的最小序列长度LOG2值
   `ifndef SFFT_MIN_LOG2PTS_CORDIC_TW
   localparam int sfft_minlog2pts_cordic_tw = 0;   // 默认禁止用CORDIC计算旋转因子乘法，因其消耗逻辑资源过大
   `else
   localparam int sfft_minlog2pts_cordic_tw = `SFFT_MIN_LOG2PTS_CORDIC_TW;
   `endif
   /*! \brief 字符类型定义 */
   typedef bit[7:0] bytechar_t;
   /*!
    * \brief 计算无符号数值的有效比特位数
    * \param value   待计算有效比特位数的无符号数值
    * \param maxbits 最大比特位数
    * \return 输入数值的有效比特位数
    */
   function automatic int bits_of_integer(int unsigned value, int maxbits);
      for (int i = 1; i < maxbits; i++) begin
         if (value < 2**i) return i;
      end
      return maxbits;
   endfunction
   function automatic int bits_of_longint(longint unsigned value, int maxbits);
      if ((value>>32) != 0)return (maxbits >= 32) ? bits_of_integer((value>>32), maxbits-32) + 32 : maxbits;
      else                 return bits_of_integer(value, (maxbits > 32) ? 32 : maxbits);
   endfunction
   /*!
    * \brief 计算有符号数值的有效比特位数
    * \param value   待计算有效比特位数的有符号数值
    * \param maxbits 最大比特位数
    * \return int型，输入数值的有效比特位数
    */
   function automatic int bits_of_signed_integer(int signed valuei, int maxbits);
      int signed value;
      value = valuei;
      if      (value == 0) return 1;
      else if (value <  0) value = -value;
      return bits_of_integer(value, maxbits - 1) + 1;
   endfunction
   function automatic int bits_of_signed_longint(longint signed valuei, int maxbits);
      longint signed value;
      value = valuei;
      if      (value == 0) return 1;
      else if (value <  0) value = -value;
      return bits_of_longint(value, maxbits - 1) + 1;
   endfunction
   /*!
    * \brief 计算无符号数值的最小比特位宽
    * \param value   待计算最小比特位宽的无符号数值
    * \param maxbitw 最大比特位宽
    * \return 输入数值的有效比特位数
    */
   function automatic int minbitw_of_integer(int unsigned value, int maxbitw);
      return bits_of_integer(value, maxbitw);
   endfunction
   function automatic int minbitw_of_longint(longint unsigned value, int maxbitw);
      return bits_of_longint(value, maxbitw);
   endfunction
   /*!
    * \brief 计算有符号数值的最小比特位宽
    * \param value   待计算最小比特位宽的有符号数值
    * \param maxbits 最大比特位宽
    * \return int型，输入数值的最小比特位宽
    */
   function automatic int minbitw_of_signed_integer(int signed value, int maxbitw);
      /* 正整数的位宽 = 有效比特位数 + 1位符号位
       * 负整数的位宽 =    -1 ： 1 位
       *               < - 1 : 取反后有效比特位数 + 1位符号位
       */
      if      (  value  >= 0) return bits_of_integer(value, maxbitw-1) + 1;
      else if ((~value) == 0) return 1;
      else                    return bits_of_integer((~value), maxbitw-1) + 1;
   endfunction
   function automatic int minbitw_of_signed_longint(longint signed value, int maxbitw);
      if      (  value  >= 0) return bits_of_longint(value, maxbitw-1) + 1;
      else if ((~value) == 0) return 1;
      else                    return bits_of_longint((~value), maxbitw-1) + 1;
   endfunction
   /*!
    * \brief 无符号整数乘法结果最小位宽
    * \param bitwofA 乘法输入参数A位宽
    * \param bitwofB 乘法输入参数B位宽
    * \return int型，无符号整数乘法结果最小位宽
    */
   function automatic int minresbitw_of_unsignedint_multiply(int bitwofA, int bitwofB);
      int resbitw;
      resbitw = bitwofA + bitwofB;
      if (bitwofA == 1 || bitwofB == 1) resbitw = resbitw - 1; // 其中有一个乘数位宽仅为1时，该乘数的值域范围为{0，1}，最大值仅为1，乘法结果最大位宽不会超过另一个乘数的位宽
      return resbitw;
   endfunction
   /*!
    * \brief 根据无符号整数乘法结果最小位宽计算输入参数位宽
    * \param resbitw  无符号整数乘法结果最小位宽
    * \param arg2bitw 第二输入参数位宽
    * \return 第一输入参数位宽
    */
   function automatic int argbitw_of_unsignedint_multiply_minresbitw(int resbitw, int arg2bitw);
      if (arg2bitw == 1) return resbitw;
      else               return resbitw - arg2bitw;
   endfunction
   /*!
    * \brief 有符号整数乘法结果最小位宽
    * \param bitwofA 乘法输入参数A位宽（包括符号位）
    * \param bitwofB 乘法输入参数B位宽（包括符号位）
    * \return int型，有符号整数乘法结果最小位宽
    */
   function automatic int minresbitw_of_signedint_multiply(int bitwofA, int bitwofB);
      /* \attention 与无符号整数不同，有符号整数当除去符号位的有效位数为1时，该整数所能表示的数的范围为{-2,-1,0,+1}，取-2时乘法结果仍然涉及到扩位。
       因此有效位数为1时不能参考无符号整数乘法的结果最小位宽计算方法 */
      return 1/*结果符号位*/ + (bitwofA - 1)/*A的数据位宽*/ + (bitwofB - 1)/*B的数据位宽*/;
   endfunction
   /*!
    * \brief 根据有符号整数乘法结果最小位宽计算输入参数位宽
    * \param resbitw  有符号整数乘法结果最小位宽
    * \param arg2bitw 第二输入参数位宽
    * \return 第一输入参数位宽
    */
   function automatic int argbitw_of_signedint_multiply_minresbitw(int resbitw, int arg2bitw);
      return resbitw - 1/*结果位宽*/ - (arg2bitw - 1)/*第二输入参数有效位宽*/ + 1/*第一输入参数符合位*/;
   endfunction
   /*!
    * \brief 统计输入整数中给定比特值的位数
    * \param value   待统计比特值的整数
    * \param maxbits 输入整数的二进制位数
    * \param bit2s   待统计的比特值
    * \return int型，给定比特值的位数
    */
   function automatic int bitcnt_of_integer(int unsigned value, int maxbits, bit bit2s);
      int count, i;
      count = 0;
      for (i = 0; i < 32 && i < maxbits; i++) begin
         if (value[i] == bit2s) count++;
      end
      return count;
   endfunction
   function automatic int bitcnt_of_longint(longint unsigned value, int maxbits, bit bit2s);
      int count, i;
      count = 0;
      for (i = 0; i < 64 && i < maxbits; i++) begin
         if (value[i] == bit2s) count++;
      end
      return count;
   endfunction
   /*!
    * \brief 根据分层处理的层数和计划延迟拍数计算分层处理时各层之间的延迟拍数
    * \param stagecnt  分层处理的层数
    * \param ibgnstage 分层处理的起始层索引， 0, 1, ..., (stagecnt-1)
    * \param iendstage 分层处理的结束层索引， 0, 1, ..., (stagecnt-1)
    * \param totaltaps 总的计划延迟拍数
    * \param top_first 是否顶层优先延迟，1'b0 - 底层优先产生延迟， 1'b1 - 顶层优先产生延迟。
    */
   function automatic int delaytaps4stagerange(int stagecnt, int ibgnstage, int iendstage, int totaltaps, bit top_first);
      int judge_0, judge_1;
      if (top_first) begin
         judge_1 = (ibgnstage + 0)*totaltaps/stagecnt;
         judge_0 = (iendstage + 1)*totaltaps/stagecnt;
      end else begin
         judge_1 = (stagecnt - (iendstage + 1))*totaltaps/stagecnt;
         judge_0 = (stagecnt - (ibgnstage + 0))*totaltaps/stagecnt;
      end
      return judge_0 - judge_1;
   endfunction
   /*!
    * \brief 根据分层处理的层数和计划延迟拍数计算分层处理时给定层的延迟拍数
    * \param stagecnt  分层处理的层数
    * \param ibgnstage 分层处理的起始层索引， 0, 1, ..., (stagecnt-1)
    * \param iendstage 分层处理的结束曾索引， 0, 1, ..., (stagecnt-1)
    * \param totaltaps 总的计划延迟拍数
    * \param top_first 是否顶层优先延迟，1'b0 - 底层优先产生延迟， 1'b1 - 顶层优先产生延迟。
    */
   function automatic int delaytaps4stage(int stagecnt, int istage, int totaltaps, bit top_first);
      return delaytaps4stagerange(stagecnt, istage, istage, totaltaps, top_first);
   endfunction
   /*! \brief 求绝对值 */
   function automatic int signed absi(int signed x);
      return (x >= 0) ? x : -x;
   endfunction
   function automatic longint signed absil(longint signed x);
      return (x >= 0) ? x : -x;
   endfunction
   /*! \brief 选取最大值 */
   function automatic int unsigned maxu(int unsigned x, int unsigned y);
      return x > y ? x : y;
   endfunction
   function automatic int signed maxi(int signed x, int signed y);
      return x > y ? x : y;
   endfunction
   function automatic longint unsigned maxul(longint unsigned x, longint unsigned y);
      return x > y ? x : y;
   endfunction
   function automatic longint signed maxil(longint signed x, longint signed y);
      return x > y ? x : y;
   endfunction
   /*! \brief 选取最小值 */
   function automatic int unsigned minu(int unsigned x, int unsigned y);
      return x < y ? x : y;
   endfunction
   function automatic int signed mini(int signed x, int signed y);
      return x < y ? x : y;
   endfunction
   function automatic longint unsigned minul(longint unsigned x, longint unsigned y);
      return x < y ? x : y;
   endfunction
   function automatic longint signed minil(longint signed x, longint signed y);
      return x < y ? x : y;
   endfunction
   /*!
    * \brief Euclid法(辗转相除法)求两个正整数的最大公约数
    * \param x, y 待求公约数的两个正整数
    * \return longint unsigned型，x和y的最大公约数
    */
   function automatic longint unsigned gcd(longint unsigned xi, longint unsigned yi);
      longint unsigned r, x, y;
      x = xi;
      y = yi;
      if (x < y) begin
         r = x;   x = y;   y = r;
      end
      r = x % y;
      while(r > 0) begin
         x = y;
         y = r;
         r = x % y;
      end
      return y;
   endfunction
   /*!
    * \brief 求两个正整数的最小公倍数
    * \param x, y 待求公倍数的两个正整数
    * \return longint unsigned型，x和y的最小公倍数
    */
   function automatic longint unsigned lcm(longint unsigned x, longint unsigned y);
      longint unsigned g;
      g = gcd(x, y);
      return (x/g)*y;
   endfunction
   /*!
    * \brief 整型数求平方根
    * \param val 待求平方根的整型数
    * \return int型，输入整型数的平方根
    */
   function automatic int unsigned isqrt(longint unsigned val);
      longint unsigned res, res_cmp;
      int cntr;
      res = (val>>1);
      res_cmp = 0;
      cntr = 0;
      while((res*res - val != 0 || res != res_cmp) && cntr < 1000) begin
         res_cmp = res;
         res = (res>>1) + ((val/res)>>1);
         cntr = cntr + 1;
      end
      return unsigned'(int'(res));
   endfunction
   /*!
    * \typedef divres_t
    * \brief 定点除法结果结构体
    */
   typedef struct packed {
      bit               neg;                       // 商为负数标志，1'b1-商是负数，1'b0-商是非负数
      longint unsigned  intp;                      // 商的整数部分，最多64位
      longint unsigned  frac;                      // 商的小数部分，最多64位
   } divres_t;
   /*!
    * \brief 64位定点除法运算
    * \param divd 被除数，最多64位（包含符号位）
    * \param divs 除数，最多64位（包含符号位）
    * \return divres_t型，除法结果
    */
   function automatic divres_t fixdiv(longint signed divd, longint signed divs);
      divres_t res;
      longint unsigned udd, udv, tmp;
      int i, ibc;
      res.neg = 1'b0;
      res.intp = 0;
      res.frac = 0;
      udd = 0;
      udv = 0;
      if (divs == 0) begin
         $error("fixdiv : zero divisor is not allowed!");
         return res;
      end
      if (divs < 0) begin
         udv = unsigned'(-divs);
         res.neg ^= 1'b1;
      end else udv = unsigned'(divs);
      if (divd == 0) return res;
      if (divd < 0) begin
         udd = unsigned'(-divd);
         res.neg ^= 1'b1;
      end else udd = unsigned'(divd);
      // 统计结果的整数部分位数，同时对齐除数与被除数的最高位
      for (ibc = 0, tmp = udv; tmp < udd; ibc++) begin
         udv = tmp;
         tmp <<= 1;
      end
      // 商的整数部分
      if (ibc <= 0) udd <<= 1;
      else begin
         while (ibc > 0) begin
            res.intp <<= 1;
            if (udd >= udv) begin
               res.intp |= 1;
               udd -= udv;
            end
            udd <<= 1;
            ibc--;
         end
      end
      // 商的小数部分
      for (i = 0; i <= 63; i++) begin
         res.frac <<= 1;
         if (udd >= udv) begin
            res.frac |= 1;
            udd -= udv;
         end
         udd <<= 1;
      end
      return res;
   endfunction
   /*!
    * \brief 定点除法结果转换定点数
    * \param divres   定点除法结果
    * \param fracbits 定点数小数位数，<= 63
    * \return longint signed型定点数
    */
   function automatic longint signed divres2qfix(divres_t dr, int unsigned fracbits);
      longint signed res;
      int signed intbits;
      if (fracbits > 63) begin
         $warning("divres2qfix : fracbits(%0d) which is greator than 63 will be forced to 63 defaultly!", fracbits);
         fracbits = 63;
      end
      intbits = 63 - fracbits;
      if (bits_of_longint(dr.intp, 64) > intbits) begin
         $error("divres2qfix : OVERFLOW on integer part! integer part bitwidth(%0d) of specified fixpoint format(fracbits = %0d) can not hold all the integer part of result, it requires fracbits to be %0d bits or less.", intbits, fracbits, 63 - bits_of_longint(dr.intp, 64));
         return 0;
      end
      if (intbits > 0) res = (dr.intp<<fracbits);
      res |= (dr.frac>>(64 - fracbits));
      res += ((dr.frac>>(64 - fracbits - 1))&1);
      if (dr.neg) res = -res;
      return res;
   endfunction
   /*!
    * \brief Q.61型数乘法
    * \param q61x Q.61型被乘数
    * \param q61y Q.61型乘数
    * \return Q.61型乘法运算结果
    */
   function automatic longint signed q61mult(longint signed q61xi, longint signed q61yi);
      longint signed q61x, q61y, res, tmp, xh, xl, yh, yl;
      bit sign;
      sign = 1'b0;
      if (q61xi < 64'sd0) begin
         sign = ~sign;
         q61x = -q61xi;
      end
      else q61x = q61xi;
      if (q61yi < 64'sd0) begin
         sign = ~sign;
         q61y = -q61yi;
      end
      else q61y = q61yi;
      xh = q61x>>>31; xl = q61x&(~((longint'(signed'(-1)))<<31)); // x.h30, x.l31
      yh = q61y>>>30; yl = q61y&(~((longint'(signed'(-1)))<<30)); // y.h31, y.l30
      res = xh * yh;    // (x.h30 * y.h31) ... (x.l31 ... y.l30), 结果位数：61(msbs)，总位数：122，去掉低61位，保留高61位，右移位数：0
      tmp = xh * yl;    // (x.h30 * y.l30) ...                  , 结果位数：60(msbs)，总位数：91， 去掉低61位，保留高30位，右移位数：30
      res = res + (tmp>>>30);
      tmp = xl * yh;    // (x.l31 * y.h31) ...                  , 结果位数：62(msbs)，总位数：92， 去掉低61位，保留高31位，右移位数：31
      res = res + (tmp>>>31);
      if (sign) res = -res;
      return res;
   endfunction
   /*!
   /*!
    * \brief 计算两个Q.61型数的平方和或平方差的平方根
    * \param q61x               Q.61型数x
    * \param q61y               Q.61型数y
    * \param sqrt_of_diff_sqrxy 计算 sqrt(x^2 - y^2) 标志，1'b0-计算 sqrt(x^2 + y^2) 1'b1-计算 sqrt(x^2 - y^2) 
    * \return Q.61型数平方和或者平方差的平方根运算结果
    */
   function automatic longint unsigned q61sqrt2(longint signed q61x, longint signed q61y, bit sqrt_of_diff_sqrxy);
      longint signed divres, sqres, multscal, itsres, sres;
      if (q61x < 0) q61x = -q61x;
      if (q61y < 0) q61y = -q61y;
      if (q61x == q61y) begin
         multscal = q61x;
         if (sqrt_of_diff_sqrxy) itsres = 0;
         else                    itsres   = longint'(1.4142135623730950488016887242097*((longint'(2))**61));
      end else begin
         longint signed ittmp, tmp2it;
         int signed itcntr;
         if (q61x < q61y) begin
            multscal = q61y;
            divres = q61div(q61x, q61y);
         end else begin
            multscal = q61x;
            divres = q61div(q61y, q61x);
         end
         sqres = q61mult(divres, divres);
         if (sqrt_of_diff_sqrxy) sqres = -sqres;
         itsres = ((longint'(2))**61);
         ittmp = sqres/2;
         itsres += ittmp;
         itcntr = 4;//2*n
         do begin
            divres = q61div(itcntr - 3, itcntr);
            tmp2it = -q61mult(sqres, divres);
            ittmp  = q61mult(ittmp, tmp2it);
            itsres += ittmp;
            itcntr += 2;
         end while(ittmp != 0 && itcntr < 1000);
      end
      sres = q61mult(itsres, multscal);
      return unsigned'(sres);
   endfunction
   /*!
    * \brief 计算两个Q.61型数的平方和或平方差的倒数平方根
    * \param q61x                Q.61型数x
    * \param q61y                Q.61型数y
    * \param rsqrt_of_diff_sqrxy 计算 rsqrt(x^2 - y^2) 标志，1'b0-计算 rsqrt(x^2 + y^2) 1'b1-计算 rsqrt(x^2 - y^2) 
    * \return Q.61型数平方和或平方差的倒数平方根运算结果
    */
   function automatic longint unsigned q61rsqrt2(longint signed q61x, longint signed q61y, bit rsqrt_of_diff_sqrxy);
      longint signed divres, sqres, divscal, itsres, sres;
      if (q61x < 0) q61x = -q61x;
      if (q61y < 0) q61y = -q61y;
      if (q61x == q61y) begin
         divscal = q61x;
         if (rsqrt_of_diff_sqrxy)itsres = 64'hFFFFFFFFFFFFFFFF;// 除零溢出
         else                    itsres   = longint'(1.4142135623730950488016887242097*((longint'(2))**60));
      end else begin
         longint signed ittmp, tmp2it;
         int signed itcntr;
         if (q61x < q61y) begin
            divscal = q61y;
            divres = q61div(q61x, q61y);
         end else begin
            divscal = q61x;
            divres = q61div(q61y, q61x);
         end
         sqres = q61mult(divres, divres);
         if (~rsqrt_of_diff_sqrxy)sqres = -sqres;
         itsres = ((longint'(2))**61);
         ittmp = sqres/2;
         itsres += ittmp;
         $display("sqres = %h(%0d), ittmp = %h(%0d), itsres = %h(%0d)", sqres, sqres, ittmp, ittmp, itsres, itsres);
         itcntr = 4; // 2*n
         do begin
            divres = q61div(itcntr - 1, itcntr);
            tmp2it = q61mult(sqres, divres);
            ittmp  = q61mult(ittmp, tmp2it);
            itsres += ittmp;
            $display("itcntr = %0d, tmp2it = %h(%0d), ittmp = %0d, itsres = %0d", itcntr, tmp2it, tmp2it, ittmp, itsres);
            itcntr += 2;
         end while(ittmp != 0 && itcntr < 1000);
      end
      sres = q61div(itsres, divscal);
      return unsigned'(sres);
   endfunction
   /*!
    * \brief Q.61型数表示的sqrt(2)
    */
   localparam longint signed q61_sqrt2 = real2q61(1.4142135623730950488016887242097);//longint'(1.4142135623730950488016887242097*((longint'(2))**61));
   /*!
    * \brief Q.61型数表示的pi
    */
   localparam longint signed q61_pi = real2q61(3.1415926535897932384626433832795);//longint'(3.1415926535897932384626433832795*((longint'(2))**61));
   /*!
    * \brief 实数度转换为Q.61型弧度值
    */
   function automatic longint signed fdeg2q61rad(real fdeg);
      real fpi, frad;
      fpi  = real'(q61_pi);
      frad = fpi*fdeg/180;
      return signed'(longint'(frad));
   endfunction
   /*!
    * \brief Q.5型数表示的度转换为Q.61型弧度值
    */
   function automatic longint signed q5deg2q61rad(int signed q5deg);
      longint signed q61pi_hipart, q61pi_lopart, res_hipart, res_lopart;
      q61pi_hipart = (q61_pi >> 30);
      q61pi_lopart = (q61_pi & (~((-1)<<30)));
      res_hipart = q61pi_hipart * q5deg * ((1 << 30)/(180*(2**5)));
      res_lopart = q61pi_lopart * q5deg / (180*(2**5));
      return res_hipart + res_lopart;
   endfunction
   /*!
    * \brief Q.61数的sin/sinh函数实现核
    * \param q61phs          输入的Q.61相位值，单位：弧度，输入值域范围：-7244019458077122842(-pi) ～ +7244019458077122842(pi)
    * \param hyperbolic_mode 双曲坐标计算模式：0-圆坐标计算模式（计算sin函数）；1-计算双曲正弦函数；2-计算双曲余弦函数
    * \return Q.61型sin/sinh函数值
    * \attention 参考Q.61型数的'1'的整型值为：(1<<61)
    */
   function automatic longint signed q61_sin_sinh_core(
      longint signed q61phs,
      int            hyperbolic_mode
   );
      longint signed divdr, divdr_factbegin, tmp, itcntr, phs2it, res;
      bit[1:0] calcfn;
      bit neg, calcsign;
      res = 0;
      neg = 0;
      calcsign = 0;
      if (hyperbolic_mode == 0) begin
         calcfn = 2'b00;
         // calcfn:计算方式
         // 00 : sin(phs)
         // 01 : cos(pi/2 - phs)
         // 10 : cos(phs - pi/2)
         // 11 : sin(pi  -  phs)
         if (q61phs < 0) begin
            q61phs = -q61phs;
            neg = neg ^ 1'b1;
         end
         if (q61phs >= q61_pi) begin
            q61phs = q61phs - q61_pi;
            neg = neg ^ 1'b1;
         end
         phs2it = q61phs;
         if (q61phs >= q61_pi/4) begin
            phs2it = q61_pi/2 - q61phs;
            calcfn = 2'b01;
            if (q61phs >= q61_pi/2) begin
               phs2it = q61phs - q61_pi/2;
               calcfn = 2'b10;
               if (q61phs >= q61_pi/2 + q61_pi/4) begin
                  phs2it = q61_pi - q61phs;
                  calcfn = 2'b11;
               end
            end
         end
      end
      else if (hyperbolic_mode == 1) begin
         calcfn = 2'b00;
         if (q61phs < 0) begin
            q61phs = -q61phs;
            neg = neg ^ 1'b1;
         end
         phs2it = q61phs;
      end
      else if (hyperbolic_mode == 2) begin
         calcfn = 2'b01;
         if (q61phs < 0) begin
            q61phs = -q61phs;
         end
         phs2it = q61phs;
      end
      if (^calcfn) begin
         /*
            cos(x) = 1 - x^2/2 + x^4/4! - x^6/6! + ...
          */
         divdr_factbegin = 0;
         tmp = 1<<61;
      end
      else begin
         /*
            sin(x) = x - x^3/3! + x^5/5! - x^7/7! + ...
          */
         divdr_factbegin = 1;
         tmp = phs2it;
      end
      res = 0;
      itcntr = 0;
      divdr = divdr_factbegin;
      while (tmp != 0) begin
         if (itcntr > 10000) begin
            $warning("q61sin: iteration times(%0d) are too much to complete!", itcntr);
            break;
         end
         if (hyperbolic_mode > 0) res += tmp;
         else begin
            if (calcsign) res -= tmp;
            else          res += tmp;
            calcsign ^= 1;
         end
         divdr = divdr + 1;
         tmp = q61mult(tmp, phs2it/divdr);
         divdr = divdr + 1;
         tmp = q61mult(tmp, phs2it/divdr);
         itcntr = itcntr + 1;
      end
      if (neg) res = -res;
      return res;
   endfunction
   /*!
    * \brief Q.61数的sin函数实现
    * \param q61phs 输入的Q.61相位值，单位：弧度，输入值域范围：-7244019458077122842(-pi) ～ +7244019458077122842(pi)
    * \return Q.61型sin函数值
    * \attention 参考Q.61型数的'1'的整型值为：(1<<61)
    */
   function automatic longint signed q61sin(
      longint signed q61phs
   );
      return q61_sin_sinh_core(.q61phs(q61phs), .hyperbolic_mode(0));
   endfunction
   /*!
    * \brief Q.61数的cos函数实现
    * \param q61phs 输入的Q.61相位值，单位：弧度，输入值域范围：-7244019458077122842(-pi) ～ +7244019458077122842(pi)
    * \return Q.61型cos函数值
    * \attention 参考Q.61型数的'1'的整型值为：(1<<61)
    */
   function automatic longint signed q61cos(
      longint signed q61phs
   );
      longint signed calcphs, halfpi;
      halfpi = q61_pi/2;
      if (q61phs < -halfpi)calcphs = (q61phs + q61_pi) - halfpi;
      else                 calcphs = (halfpi - q61phs);
      return q61_sin_sinh_core(.q61phs(calcphs),.hyperbolic_mode(0));
   endfunction
   /*!
    * \brief 为三角函数计算 miscs::q61_pi 的分数系数，按周期性将角度换到 -pi 至 pi 之间
    * \param divdent 分数系数的被除数
    * \param divisor 分数系数的除数
    * \return Q.61型数表示的将角度切换到 -pi 至 pi 之间的系数，值域范围为 -1.0 至 1.0 之间
    */
   function automatic longint signed q61coef_of_pi_for_triangular_on_div(
      longint signed divdent, longint signed divisor
   );
      if     (divdent >= divisor)return q61div(((divdent + divisor)%(2*divisor)) - divisor, divisor);
      else if(divdent < -divisor)return q61div(((divdent - divisor)%(2*divisor)) + divisor, divisor);
      else                       return q61div(divdent, divisor);
   endfunction
   /*!
    * \brief 为三角函数计算 miscs::q61_pi 的倍数系数，按周期性将角度换到 -pi 至 pi 之间
    * \param mulint 倍数系数的整数倍数
    * \param mulqfp 倍数系数的Q.61型小数倍数
    * \return Q.61型数表示的将角度切换到 -pi 至 pi 之间的系数，值域范围为 -1.0 至 1.0 之间
    */
   function automatic longint signed q61coef_of_pi_for_triangular_on_mul(
      longint signed mulint, longint signed mulqfp
   );
      longint signed q61_normed_mulint, q61_normed_mulqfp, q61_normed_res;
      int bitsofmulint, mulqfp_shbits, res_intbits;
      bit neg_res;
      bitsofmulint = bits_of_signed_longint(mulint, 64);
      if (bitsofmulint <= 61) q61_normed_mulint = mulint <<< (61 - bitsofmulint);
      else                    q61_normed_mulint = mulint >>> (bitsofmulint - 61);
      mulqfp_shbits = bits_of_signed_longint(mulqfp, 64) - 61;
      if (mulqfp_shbits >= 0) q61_normed_mulqfp = mulqfp >>> mulqfp_shbits;
      else                    q61_normed_mulqfp = mulqfp <<< (-mulqfp_shbits);
      res_intbits = bitsofmulint + mulqfp_shbits;
      q61_normed_res = q61mult(q61_normed_mulint, q61_normed_mulqfp);
      if (q61_normed_res < 0) begin
         neg_res = 1'b1;
         q61_normed_res = - q61_normed_res;
      end else begin
         neg_res = 1'b0;
      end
      if (res_intbits > 0) begin
         q61_normed_res = q61_normed_res << res_intbits;
         q61_normed_res = q61_normed_res + (longint'(2))**61;
         q61_normed_res = q61_normed_res&(~((longint'(-1))<<<62));
         q61_normed_res = q61_normed_res - (longint'(2))**61;
         if (neg_res) q61_normed_res = -q61_normed_res;
         if (q61_normed_res >= (longint'(2))**61) q61_normed_res = q61_normed_res - ((longint'(2))**62);
      end
      else q61_normed_res = q61_normed_res >>> (-res_intbits); // 已经在 -1.0 至 1.0 之间，不再切换象限
      return q61_normed_res;
   endfunction
   /*!
    * \brief Q.61数的sinh函数实现
    * \param q61phs 输入的Q.61相位值，单位：弧度，输入值域范围：-q61_sinh_maxphs ～ +q61_sinh_maxphs
    * \return Q.61型sinh函数值
    * \attention 参考Q.61型数的'1'的整型值为：(1<<61)
    */
   localparam longint signed q61_sinh_maxphs = real2q61(2.094712547261101);//longint'(2.094712547261101*((longint'(2))**61)); // asinh((2^61-1)*4/2^61)
   function automatic longint signed q61sinh(
      longint signed q61phs
   );
      return q61_sin_sinh_core(.q61phs(q61phs), .hyperbolic_mode(1));
   endfunction
   /*!
    * \brief Q.61数的cosh函数实现
    * \param q61phs 输入的Q.61相位值，输入值域范围：-q61_cosh_maxphs ～ +q61_cosh_maxphs
    * \return Q.61型cosh函数值
    * \attention 参考Q.61型数的'1'的整型值为：(1<<61)
    */
   localparam longint signed q61_cosh_maxphs = real2q61(2.063437068895561);//longint'(2.063437068895561*((longint'(2))**61))-1537/*-1537用于确保最大相位对应计算结果不溢出*/;// acosh((2^61-1)*4/2^61)
   function automatic longint signed q61cosh(
      longint signed q61phs
   );
      return q61_sin_sinh_core(.q61phs(q61phs), .hyperbolic_mode(2));
   endfunction
   /*!
    * \brief Q.61数的反正切运算核
    * \param y          矢量纵坐标分量y，要求 abs(y) < 2**61
    * \param x          矢量横坐标分量x，要求 abs(x) < 2**61
    * \param hyperbolic 按双曲线坐标计算标志：1'b0-按圆坐标计算；1'b1-按双曲线坐标计算
    * \return Q.61型的弧度值，0 <= res <= q61_pi/2
    * \attention 当 #hyperbolic == 1'b1 时，要求 #y/#x < 0.999329299739067 (tanh((2^61-1)*4/2^61))
    */
   localparam longint signed q61_atanh_maxscale = real2q61(0.999329299739067);//longint'(0.999329299739067*((longint'(2))**61)); // (tanh((2^61-1)*4/2^61))
   function automatic longint signed q61atan_core(
      longint signed y,
      longint signed x,
      bit            hyperbolic
   );
      longint signed ty, tx, r, t, trignorm_atan_scal, t2, t3, t4, divdr, res;
      bit acc_sub;
      trignorm_atan_scal = (64'd2)**61;
      if (y == 0 && x == 0) return 0;
      ty = y; if (ty < 0) ty = -ty;
      tx = x; if (tx < 0) tx = -tx;
      if (hyperbolic == 1'b1) begin
         if (ty > q61mult(tx, q61_atanh_maxscale)) return 64'h7FFFFFFFFFFFFFFF;// 上溢出
         r = 0;
         t = 1;
      end else if (ty <= tx / 2) begin // + res; // 0 <= res <= 1/8
         r = 0;
         t = 1;
      end else if (tx <= ty / 2) begin // - res; // 3/8 < res <= 1/2
         r = ty;
         ty = tx;
         tx = r;
         r = q61_pi/2 + (q61_pi&1);
         t = -(signed'(64'd1));
      end else begin                   // + res; // 1/8 < res <= 3/8
         r = ty - tx;
         tx = ty + tx;
         ty = r;
         r = q61_pi/4 + ((q61_pi/2)&1);
         t = 1;
      end
      res = q61div(ty, tx);
      if (t < 0) t = longint'(-res);
      else       t = longint'(res);

      t3 = trignorm_atan_scal;
      t2 = q61mult(t, t);
      t4 = t2;
      acc_sub = 1'b1;
      divdr = 3;
      while ((t4/divdr) > 0) begin
         if (hyperbolic) t3 = t3 + (t4/divdr);
         else begin
            if (acc_sub) t3 = t3 - (t4/divdr);
            else         t3 = t3 + (t4/divdr);
            acc_sub = ~acc_sub;
         end
         t4 = q61mult(t4, t2);
         divdr = divdr + 2;
      end
      return r + q61mult(t, t3);
   endfunction
   /*!
    * \brief 计算Q.61数的二象限反正切值
    * \param y 矢量纵坐标分量y，要求 abs(y) < 2**61
    * \param x 矢量横坐标分量x，要求 abs(x) < 2**61
    * \return Q.61型的弧度值，-q61_pi/2 <= res <= q61_pi/2
    */
   function automatic longint signed q61atan2i2q(
      longint signed y, longint signed x
   );
      longint signed r;
      r = q61atan_core(y, x, 1'b0);
      if (y[63]^x[63]) r = -r;
      return r;
   endfunction
   /*!
    * \brief 计算Q.61数的四象限反正切值
    * \param y 矢量纵坐标分量y，要求 abs(y) < 2**61
    * \param x 矢量横坐标分量x，要求 abs(x) < 2**61
    * \return Q.61型的弧度值，-q61_pi/2 <= res <= q61_pi/2
    */
   function automatic longint signed q61atan2i4q(
      longint signed y, longint signed x
   );
      longint signed r;
      r = q61atan_core(y, x, 1'b0);
      if (x < 0) r = q61_pi - r;
      if (y < 0) r = -r;
      return r;
   endfunction
   /*!
    * \brief 计算Q.61数的二象限反双曲正切值
    * \param y 矢量纵坐标分量y，要求 abs(y) < 2**61
    * \param x 矢量横坐标分量x，要求 abs(x) < 2**61
    * \return Q.61型，-64'sd1**61 <= res <= 64'sd1**61
    */
   function automatic longint signed q61atanh2i2q(
      longint signed y, longint signed x
   );
      longint signed r;
      r = q61atan_core(y, x, 1'b1);
      if (y[63]^x[63]) r = -r;
      return r;
   endfunction
   /*!
    * \brief 计算Q.61数的四象限反双曲正切值
    * \param y 矢量纵坐标分量y，要求 abs(y) < 2**61
    * \param x 矢量横坐标分量x，要求 abs(x) < 2**61
    * \return Q.61型，-64'sd2**61 <= res <= 64'sd2**61
    */
   function automatic longint signed q61atanh2i4q(
      longint signed y, longint signed x
   );
      longint signed r;
      r = q61atan_core(y, x, 1'b1);
      if (x < 0) r = (64'd2**61)*2 - r;
      if (y < 0) r = -r;
      return r;
   endfunction
   /*! \brief 对数运算用到的部分常量 */
   localparam int signed  q30_root2_2            = ((1.4142135623730950488016887242097 +0.0000000004656612873077392578125)*2**30);
   localparam int signed  q30_root4_2            = ((1.1892071150027210667174999705605 +0.0000000004656612873077392578125)*2**30);
   localparam int signed  q30_root4root2_2       = ((1.6817928305074290860622509524664 +0.0000000004656612873077392578125)*2**30);
   localparam int signed  q30_recip_root4_2      = ((0.84089641525371454303112547623321+0.0000000004656612873077392578125)*2**30);
   localparam int signed  q30_recip_root2_2      = ((0.70710678118654752440084436210485+0.0000000004656612873077392578125)*2**30);
   localparam int signed  q30_recip_root4root2_2 = ((0.59460355750136053335874998528024+0.0000000004656612873077392578125)*2**30);
   localparam int signed  q15_loge2              = ((0.69314718055994530941723212145818+0.0000152587890625)*2**15);
   localparam int signed  q15_loge2_div2         = ((0.34657359027997265470861606072909+0.0000152587890625)*2**15);
   localparam int signed  q15_loge2_div4         = ((0.17328679513998632735430803036454+0.0000152587890625)*2**15);
   localparam int signed  q15_loge2_div4_mul3    = ((0.51986038541995898206292409109363+0.0000152587890625)*2**15);
   localparam int signed  q15_recip_loge2        = ((1.4426950408889634073599246810019 +0.0000152587890625)*2**15);
   localparam int signed  q15_recip_loge10       = ((0.43429448190325182765112891891661+0.0000152587890625)*2**15);
   localparam int signed  q15_log10_2            = ((0.30102999566398119521373889472449+0.0000152587890625)*2**15);
   localparam int signed  q15_log2_10            = ((3.3219280948873623478703194294894 +0.00010137720016136)*2**15);
   /*!
    * \brief 计算自然对数值
    * \param y 待求取自然对数值的Q.30数
    * \return 按Q.15数表示的自然对数结果，误差最大6.1e-5
    */
   function automatic int signed q15ilogofq30(
      longint signed y
   );
      /*! 
       * \remarks 原理： 
       * 1.任意正底的对数均可转换为自然对数之间的乘、除运算，如(1)所示： 
       * log_a(x) = ln(x)/ln(a)，a > 0，x > 0                                            (1)
       * 2.自然对数的幂级数展开式如(2)所示。 
       * ln[(1+x)/(1-x)] = 2[x + x^3/3 + x^5/5 + ... + x^(2n+1)/(2n+1) + ...]， |x| < 1  (2) 
       *     对式(2)，令y = (1+x)/(1-x)，则有：
       * x = (y-1)/(y+1)                                                                 (3)
       *     经仿真实验验证，无论y > 1还是0 < y <= 1，当y越趋近于1时，式(2)给出的级数收敛速度越快，反之
       * 若y越趋近于0或+inf时，式(2)的收敛速度越慢，而函数ln(y)在0 < y <= 1的数据区间内比y > 1的区间内 
       * 有更陡峭的收敛曲线，因此可将输入数归化至1/2 < y <= 1之间来使用式(2)求解对数，以得到快速的收敛 
       * 速度：
       *     令
       * y = yy*2^n，1/2 < yy <= 1，n为任意整数                                          (4) 
       *     根据数学知识，可知以n为未知数的方程(4)必然有解，因此有：
       * ln(y) = ln(yy) + n*ln(2)                                                        (5) 
       * 式(5)中，ln(2)为预先可求得的常数，于是求ln(y)的问题便转换为如何求取ln(yy)的问题了。
       *     对ln(yy)，1/2 < yy <= 1，经仿真实验验证，其收敛速度在趋近于1/2时仍然较慢，因此我们希望将
       * yy归化至收敛速度更快的趋近于1的区间。为此，取分区分界点1/(2^(1/2))，将(1/2,1]区间分为两个区间： 
       *     a. (1/2,1/(2^(1/2))]； 
       *     b. (1/(2^(1/2)),1]； 
       * 当1/2 < yy <= 1/(2^(1/2))时，可令z = yy*2^(1/2)，则有： 
       * 1/(2^(1/2)) < z <= 1， 
       * ln(yy) = ln(z) - ln(2)/2 
       * 因此最初的问题便转换为求取ln(z)的问题了。 
       *     对z∈(1/(2^(1/2),1]，经仿真实验发现，对按Q.30型数输入按Q.15型数输出的情形，式(2)在z趋近于
       * 1/(2^(1/2))时仍然需要至少3次的迭代才能保证收敛，且计算误差可能达到4*2^(-15)，为进一步提高精度 
       * 和收敛速度，需对(1/2,1]区间做进一步分区。为此，取三个分区分界点1/(2^(3/4))、1/(2^(1/2))、 
       * 1/(2^(1/4))，将区间(1/2,1]分为四个分区： 
       *     a. (1/2,1/(2^(3/4))] 
       *     b. (1/(2^(3/4)),1/(2^(1/2))] 
       *     c. (1/(2^(1/2)),1/(2^(1/4))] 
       *     d. (1/(2^(1/4)),1]
       *     对分区d.，经仿真发现，对按Q.30型数输入按Q.15型数输出的情形，可取得最多迭代2次，最少迭代0次
       * 的收敛速度，且计算误差最多±2*2^(-15)，已足够满足精度要求，再向下分区将因为判决代码增多导致运 
       * 算速度降低。
       */
      int signed n, yy, x, r, i, yyh, yyl, cch, ccl, cc;
      if (y < 0) return -64'h7FFFFFFFFFFFFFFF;  // 输入数据异常
      // y 归一化到0.5~1之间的Q.30数
      n = bits_of_longint(y, 64) - 1 - 30;
      if (n > 0) yy = (y >> n);
      else       yy = (y << (-n));
      // 1/2 ～ 1之间分为四段区间：
      // (a)   1/(2)       ～ 1/(2^(3/4))
      // (b)   1/(2^(3/4)) ～ 1/(2^(1/2))
      // (c)   1/(2^(1/2)) ～ 1/(2^(1/4))
      // (d)   1/(2^(1/4)) ～ 1
      // 在区间(d)的数据具有最快的收敛速度，因此需要将yy归化至区间(d)后进行计算
      if (yy >= q30_recip_root4_2) r = 0;             // 1/(2^(1/4)) <= yy < 1，不乘以系数
      else begin
         if (yy >= q30_recip_root2_2) begin           // 1/(2^(1/2)) <= yy < 1/(2^(1/4))，乘上系数2^(1/4)
            cch = (q30_root4_2>>15);ccl = (q30_root4_2&32'h7FFF);
            r = -(q15_loge2_div4);
         end
         else if (yy >= q30_recip_root4root2_2) begin // 1/(2^(3/4)) <= yy < 1/(2^(1/2))，乘上系数2^(1/2)
            cch = (q30_root2_2>>15);ccl = (q30_root2_2&32'h7FFF);
            r = -(q15_loge2_div2);
         end
         else begin                                   //          yy <  1/(2^(3/4))，乘上系数2^(3/4)
            cch = (q30_root4root2_2>>15); ccl = (q30_root4root2_2&32'h7FFF);
            r = -(q15_loge2_div4_mul3);
         end
         yyh = (yy>>15); yyl = (yy&32'h7FFF);
         yy = yyh*cch + ((yyh*ccl)>>15) + ((yyl*cch)>>15);
      end
      // x = (y - 1)/(y + 1)
      x = (yy*2 - (1<<31))/((yy + (1<<30))>>15);// 2*x = 2*(yy - 1)/(yy + 1) : Q.15数
      // 因为yy在0.5～1之间，可确定x <= 0
      r = r + x;                                // r = 2*x
      yy = x;                                   // yy <= 0
      x = ((x*(x/2))>>15);                      // x = x^2     x:Q.16, x^2 > 0
      for (i = 1; i <= 2; i++) begin
         yy = yy*x;                             // yy = yy*x, yy:Q.31
         if (yy > -(2**15)*2*(i*2+1)) break;    // yy <= 0, x^2 >= 0, 则 yy*x^2 <= 0
         if (i == 1) cc = (2**15)/(2*(1*2 + 1));
         else        cc = (2**15)/(2*(2*2 + 1));
         r = r + (((yy>>15)*cc)>>16);
         yy = (yy >> 16);
      end
      r = r + n*q15_loge2;
      return r;
   endfunction
   /*!
    * \brief Q.15数乘法
    * \param x 输入Q.15数x
    * \param y 输入Q.15数y
    * \return Q.15数乘法结果
    */
   function automatic int signed q15mul(
      int signed x,
      int signed y
   );
      int signed xh, xl, yh, yl, r;
      xh = (x>>>7); xl = (x&32'h7F);
      yh = (y>>>7); yl = (y&32'h7F);
      r = xh*yh + ((xh*yl)>>>7) + ((yh*xl)>>>7);
      r = (r>>>1) + (r&1);
      return r;
   endfunction
   /*!
    * \brief 计算底2对数值
    * \param y 待求取自然对数值的Q.30数
    * \return 按Q.15数表示的底2对数结果，误差最大6.1e-5
    */
   function automatic int signed q15ilog2ofq30(
      longint signed y
   );
      return q15mul(q15ilogofq30(y), q15_recip_loge2);
   endfunction
   /*!
    * \brief 计算底10对数值
    * \param y 待求取自然对数值的Q.30数
    * \return 按Q.15数表示的底10对数结果，误差最大6.1e-5
    */
   function automatic int signed q15ilog10ofq30(
      longint signed y
   );
      return q15mul(q15ilogofq30(y), q15_recip_loge10);
   endfunction
endpackage
 `endif//__MISCS_PKG__
`else
 `undef  __PKG_BANNED__
`endif// __PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__
`else
 `undef  __ITF_BANNED__
`endif

`ifndef  __MISCS_M__
`define  __MISCS_M__
/*! \brief 时序电路同步信号表 */
`ifdef   ENABLE_ASYNC_CLR
 `define CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)  posedge clk, aclr
 `define CLKTABLE_NEGEDGE_ASYNC_CLR(clk, aclr)  negedge clk, aclr
 `define CLKTABLE_BOTHEDGE_ASYNC_CLR(clk, aclr) posedge clk, negedge clk, aclr
`else
 `define CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)  posedge clk
 `define CLKTABLE_NEGEDGE_ASYNC_CLR(clk, aclr)  negedge clk
 `define CLKTABLE_BOTHEDGE_ASYNC_CLR(clk, aclr) posedge clk , negedge clk
`endif

`endif//__MISCS_M__

