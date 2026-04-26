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
 * \author johnyork@yeah.net
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

