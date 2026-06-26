/*!
 * \license SPDX-License-Identifier: MIT
 * \file avalon.svh
 * \brief SystemVerilog实现的基于Altera公司的Avalon ST接口协议的Avalon协议链，头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`include "miscs.svh"
`include "mux.svh"

`ifdef  __INC_FROM_AVALON__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ //  该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_AVALON__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef  __AVALON_PKG__
 `define  __AVALON_PKG__
package avalon_pkg;
   /*!
    * \brief 计算数据序列长度的有效位宽
    * \param seqlen 数据序列长度
    * \return int型，表示数据序列长度的有效数据位宽
    */
   function automatic int bitwOfDataSeqLen(int seqlen);
      return miscs::minbitw_of_integer(seqlen ,31);
   endfunction
   /*!
    * \brief 计算数据序列索引的有效位宽
    * \param seqlen 数据序列长度
    * \return int型，表示数据序列索引的有效数据位宽
    */
   function automatic int bitwOfDataSeqIdx(int seqlen);
      return miscs::minbitw_of_integer(seqlen - 1, 31);
   endfunction
   /*!
    * \brief 计算时分复用处理拍数的有效位宽
    * \param tdmcnt 时分复用处理总拍数
    * \return int型，表示时分复用处理拍数的有效数据位宽
    */
   function automatic int bitwOfTdmCnt(int tdmcnt);
      return miscs::minbitw_of_integer(tdmcnt, 31);
   endfunction
   /*!
    * \brief 计算时分复用处理拍次索引的有效位宽
    * \param tdmcnt 时分复用处理总拍数
    * \return int型，表示时分复用处理拍次索引的有效数据位宽
    */
   function automatic int bitwOfTdmIdx(int tdmcnt);
      return miscs::minbitw_of_integer(tdmcnt - 1, 31);
   endfunction

   /*!
    * \brief Avalon接口配置参数
    */
   typedef struct packed {
      int        maxSink;  ///< Avalon接口节点输入数据拍数最大值
      int        maxSrc;   ///< Avalon接口节点输出数据拍数最大值
      int signed prclat;   ///< Avalon接口节点处理器延迟拍数，指从Avalon接口输入信号置位到Avalon接口输出信号需要经过的处理延迟时钟拍数
                           ///< \attention
                           ///< - 本参数不包含当 #bufSrc == 1'b1 时输出缓存的一拍延迟；
                           ///< - < 0 的值表示处理器时延不固定。
      bit        bufSrc;   ///< Avalon接口节点缓存输出信号标志，用于对输出信号作时序缓存，并在 #src_valid 置位时 #src_blk 信号置位后下一个时钟切换至缓存输出。
                           ///< 1'b1 - 对输出信号做时序缓存， 1'b0 - 不做时序缓存。
                           ///< \attention
                           ///< - 对输出信号做时序缓存的目的是以消耗额外的寄存器资源为代价，将Avalon接口 #src_blk 到 #sink_blk 的信号传递电路以时序逻辑代替组
                           ///< 合逻辑，避免Avalon接口链中反向传递信号路径上产生路径过长的组合逻辑电路，从而恶化时序性能。
                           ///< - 这么做的代价是正向传递的信号 #src_valid 、 #src_sop 、 #src_eop 以及其他与接口同步的信号都以组合逻辑电路输出，势必会影响本
                           ///< 级Avalon接口输出端与下级Avalon接口输入端之间的电路时序性能。当时序性能恶化至无法忍受时，可在下级Avalon接口中信号输入后额外增加
                           ///< 一级时序逻辑延迟以缓解之。
   } ifCfg;
   function automatic int maxSink_of_ifCfg(ifCfg ic);
      return ic.maxSink;
   endfunction
   function automatic int maxSrc_of_ifCfg(ifCfg ic);
      return ic.maxSrc;
   endfunction
   function automatic int signed prclat_of_ifCfg(ifCfg ic);
      return ic.prclat;
   endfunction
   function automatic bit bufSrc_of_ifCfg(ifCfg ic);
      return ic.bufSrc;
   endfunction
   /*! \brief Avalon接口节点总延时 */
   function automatic int totlat_of_ifCfg(ifCfg ic);
      return ic.prclat + int'(ic.bufSrc);
   endfunction
   /*!
    * \brief 生成Avalon接口配置参数
    * \param maxSink Avalon接口节点输入数据拍数最大值
    * \param maxSrc  Avalon接口节点输出数据拍数最大值
    * \param prclat  Avalon接口节点处理器延迟拍数，指从Avalon接口输入信号置位到Avalon接口输出信号需要经过的处理延迟时钟拍数，不包含 #bufSrc == 1'b1 时的输出缓存延迟；不确定或不固定时置0
    * \param bufSrc  Avalon接口节点缓存输出信号标志，用于对输出信号作时序缓存，并在 #src_valid 置位时 #src_blk 信号置位后下一个时钟切换至缓存输出。
    *                1'b1 - 对输出信号做时序缓存， 1'b0 - 不做时序缓存。
    *                \attention 
    *                - 对输出信号做时序缓存的目的是以消耗额外的寄存器资源为代价，将Avalon接口 #src_blk 到 #sink_blk 的信号传递电路以时序逻辑
    *                代替组合逻辑，避免Avalon接口链中反向传递信号路径上产生路径过长的组合逻辑电路，从而恶化时序性能。
    *                - 这么做的代价是正向传递的信号 #src_valid 、 #src_sop 、 #src_eop 以及其他与接口同步的信号都以组合逻辑电路输出，势必会影响本
    *                级Avalon接口输出端与下级Avalon接口输入端之间的电路时序性能。当时序性能恶化至无法忍受时，可在下级Avalon接口中信号输入后额外增加
    *                一级时序逻辑延迟以缓解之。
    * \return ifCfg型，生成的配置参数
    */
   function automatic ifCfg make_ifCfg(int maxSink, int maxSrc, int signed prclat, bit bufSrc);
      ifCfg ic;
      ic.maxSink = maxSink;
      ic.maxSrc  = maxSrc;
      ic.prclat  = prclat;
      ic.bufSrc  = bufSrc;
      return ic;
   endfunction
   localparam ifCfg deft_ifCfg = make_ifCfg(1, 1, 0, 0);
   /*! \brief 根据Avalon接口配置参数计算输入端数据长度位宽 */
   function automatic int bitwOfSinkCnt_of_ifCfg(ifCfg ic);
      return bitwOfDataSeqLen(maxSink_of_ifCfg(ic));
   endfunction
   /*! \brief 根据Avalon接口配置参数计算输入端数据索引位宽 */
   function automatic int bitwOfSinkIdx_of_ifCfg(ifCfg ic);
      return bitwOfDataSeqIdx(maxSink_of_ifCfg(ic));
   endfunction
   /*! \brief 根据Avalon接口配置参数计算输出端数据长度位宽 */
   function automatic int bitwOfSrcCnt_of_ifCfg(ifCfg ic);
      return bitwOfDataSeqLen(maxSrc_of_ifCfg(ic));
   endfunction
   /*! \brief 根据Avalon接口配置参数计算输出端数据索引位宽 */
   function automatic int bitwOfSrcIdx_of_ifCfg(ifCfg ic);
      return bitwOfDataSeqIdx(maxSrc_of_ifCfg(ic));
   endfunction
   /*! \brief 打印Avalon接口配置参数 */
   function automatic void print_ifCfg(ifCfg ic);
      $display("maxSink(%0d), maxSrc(%0d), prclat(%0d), bufSrc(%0d)", ic.maxSink, ic.maxSrc, ic.prclat, ic.bufSrc);
   endfunction

   /*!
    * \brief Avalon接口连接复用选择器配置参数
    */
   typedef struct packed {
      int        prevPortCnt;                      ///< 待选通的前级Avalon接口个数
      int signed prevPortMuxTaps;                  ///< 前级Avalon接口输出端信号列表选通延迟输出拍数
      int        sinkPortCnt;                      ///< 待选通的本级Avalon接口个数
      bit        sinkPortBufSig;                   ///< 本级Avalon接口输入端信号时序延迟输出标志：
                                                   ///< 1'b1-被选通的信号时序延迟输出以切断Avalon接口链表中过长的 #src_blk 、 #sink_blk 信号组合路径长度；
                                                   ///< 1'b0-被选通的信号以组合逻辑输出以节省资源。
                                                   ///< \attention 当Avalon接口连接复用选择器对本级Avalon接口输入端信号做时序延迟输出时，除反向传递信号以
                                                   ///< 时序电路延迟输出外，所有的正向传递信号均以组合逻辑电路输出，这势必会影响与下级Avalon接口输入端之间
                                                   ///< 的电路时序性能。当时序性能恶化至无法忍受时，可在下级Avalon接口中信号输入后额外增加一级时序逻辑延迟
                                                   ///< 以缓解之。
   } linkMuxCfg;
   function automatic int prevPortCnt_of_linkMuxCfg(linkMuxCfg lmc);
      return lmc.prevPortCnt;
   endfunction
   function automatic int signed prevPortMuxTaps_of_linkMuxCfg(linkMuxCfg lmc);
      return lmc.prevPortMuxTaps;
   endfunction
   function automatic int sinkPortCnt_of_linkMuxCfg(linkMuxCfg lmc);
      return lmc.sinkPortCnt;
   endfunction
   function automatic bit sinkPortBufSig_of_linkMuxCfg(linkMuxCfg lmc);
      return lmc.sinkPortBufSig;
   endfunction
   /*! \brief Avalon接口连接复用选择器延时 */
   function automatic int totlat_of_linkMuxCfg(linkMuxCfg lmc);
      return lmc.prevPortMuxTaps + int'(lmc.sinkPortBufSig);
   endfunction
   /*!
    * \brief 生成Avalon接口连接复用选择器配置参数
    * \param prevPortCnt 待选通的前级Avalon接口个数
    * \param prevPortMuxTaps  前级Avalon接口输出端信号列表选通延迟输出拍数
    * \param sinkPortCnt      待选通的本级Avalon接口个数
    * \param sinkPortBufSig   本级Avalon接口输入端信号时序延迟输出标志：
    *                         1'b1-被选通的信号时序延迟输出以切断Avalon接口链表中过长的 #src_blk 、 #sink_blk 信号组合路径长度；
    *                         1'b0-被选通的信号以组合逻辑输出以节省资源。
    *                         \attention 当Avalon接口连接复用选择器对本级Avalon接口输入端信号做时序延迟输出时，除反向传递信号以
    *                         时序电路延迟输出外，所有的正向传递信号均以组合逻辑电路输出，这势必会影响与下级Avalon接口输入端之间
    *                         的电路时序性能。当时序性能恶化至无法忍受时，可在下级Avalon接口中信号输入后额外增加一级时序逻辑延迟
    *                         以缓解之。
    * \return LinkMuxCfg型，生成的配置参数
    */
   function automatic linkMuxCfg make_linkMuxCfg(int prevPortCnt, int prevPortMuxTaps, int sinkPortCnt, bit sinkPortBufSig);
      linkMuxCfg lmc;
      lmc.prevPortCnt = prevPortCnt;
      lmc.prevPortMuxTaps = prevPortMuxTaps;
      lmc.sinkPortCnt = sinkPortCnt;
      lmc.sinkPortBufSig = sinkPortBufSig;
      return lmc;
   endfunction
   /*!
    * \brief Avalon接口镜像复用选择器配置参数
    */
   typedef struct packed {
      int        mirrorCnt;                        ///< 要连接的Avalon镜像接口个数
      int signed m2isinkMuxTaps;                   ///< 镜像Avalon接口输入端信号选通延迟输出拍数
      bit        ixmDelayOut;                      ///< Avalon接口镜像复用器输出端信号选通延迟一拍输出标志：
                                                   ///< 1'b1-选择的信号延迟一拍输出以获取更好的时序性能；
                                                   ///< 1'b0-选择的信号以组合逻辑输出以节省资源。
                                                   ///< \attention 当Avalon接口镜像复用器输出端信号选通延迟输出使能（本参数置位）时，被镜像接口输出的
                                                   ///< 信号将以组合逻辑电路输出，这势必会影响镜像接口的下一级Avalon接口输入端之间的电路时序性能。当时
                                                   ///< 序性能恶化至难以忍受时，可在下级Avalon接口中信号输入后额外增加一级时序逻辑延迟以缓解之。
   } mirrorMuxCfg;
   function automatic int mirrorCnt_of_mirrorMuxCfg(mirrorMuxCfg mmc);
      return mmc.mirrorCnt;
   endfunction
   function automatic int signed m2isinkMuxTaps_of_mirrorMuxCfg(mirrorMuxCfg mmc);
      return mmc.m2isinkMuxTaps;
   endfunction
   function automatic bit ixmDelayOut_of_mirrorMuxCfg(mirrorMuxCfg mmc);
      return mmc.ixmDelayOut;
   endfunction
   function automatic int sinklat_of_mirrorMuxCfg(mirrorMuxCfg mmc);
      return mmc.m2isinkMuxTaps + int'(mmc.ixmDelayOut);
   endfunction
   function automatic int srclat_of_mirrorMuxCfg(mirrorMuxCfg mmc);
      return int'(mmc.ixmDelayOut);
   endfunction
   /*!
    * \brief 生成Avalon接口镜像复用选择器配置参数
    * \param mirrorCnt       要连接的Avalon镜像接口个数
    * \param m2sinkMuxTaps   镜像Avalon接口输入端信号选通延迟输出拍数
    * \param ixmDelayOut     Avalon接口镜像复用器输出端信号选通延迟一拍输出标志：
    *                        1'b1-选择的信号延迟一拍输出以获取更好的时序性能；
    *                        1'b0-选择的信号以组合逻辑输出以节省资源。
    *                        \attention 当Avalon接口镜像复用器输出端信号选通延迟输出使能（本参数置位）时，被镜像接口输出的
    *                         信号将以组合逻辑电路输出，这势必会影响镜像接口的下一级Avalon接口输入端之间的电路时序性能。当时
    *                         序性能恶化至难以忍受时，可在下级Avalon接口中信号输入后额外增加一级时序逻辑延迟以缓解之。
    * \return mirrorMuxCfg型，生成的配置参数
    */
   function automatic mirrorMuxCfg make_mirrorMuxCfg(int mirrorCnt, int m2isinkMuxTaps, bit ixmDelayOut);
      mirrorMuxCfg mmc;
      mmc.mirrorCnt = mirrorCnt;
      mmc.m2isinkMuxTaps = m2isinkMuxTaps;
      mmc.ixmDelayOut = ixmDelayOut;
      return mmc;
   endfunction
endpackage
 `endif// __AVALON_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef  __AVALON_ITF__
 `define  __AVALON_ITF__
/*! \brief Avalon接口 */
interface avalon_if #(
   parameter avalon_pkg::ifCfg IC = avalon_pkg::deft_ifCfg  ///< Avalon接口配置参数
) (
   input bit  clk,                                 ///< 驱动时钟
   input wire aclr,                                ///< 异步复位信号，高电平(1)有效
   input wire sclr,                                ///< 同步复位信号，高电平(1)有效
   input wire clken                                ///< 接口使能标志，高电平(1)有效
);
   localparam int bitsof_sink_maxcnt = avalon_pkg::bitwOfDataSeqLen(avalon_pkg::maxSink_of_ifCfg(IC));
   localparam int bitsof_sink_idx    = avalon_pkg::bitwOfDataSeqIdx(avalon_pkg::maxSink_of_ifCfg(IC));
   logic[bitsof_sink_idx   -1:0] sink_idx;         ///< 本节点接口当前输入数据在序列中的索引
   logic[bitsof_sink_idx   -1:0] sink_nxtidx;      ///< 本节点接口下一输入数据在序列中的索引
   logic[bitsof_sink_maxcnt-1:0] sink_cnt;         ///< 本节点接口上一已输入完毕的序列的长度，可由 #avalon_makesink 产生，也可由用户通过 #sinkp 端口列表赋值
                                                   ///< \attention #sink_cnt 在 #sink_eop 时刻采样， #sink_eop 下一时钟生效， #sink_sop 下一时钟清零
   logic sink_sop;                                 ///< 本节点接口输入数据序列起始标志，高电平(1)有效
   logic sink_eop;                                 ///< 本节点接口输入数据序列结束标志，高电平(1)有效
   logic sink_valid;                               ///< 本节点接口输入数据序列有效标志，高电平(1)有效
                                                   ///< \attention 当该信号有效时，本模块假定每一个时钟周期均输入一个数据，因此当序列中一个数据的持续时间超过1个时钟
                                                   ///< 周期时，用户须将数据有效标志压窄为一个时钟周期宽度后再连接至本信号端口上。
   logic sink_blk;                                 ///< 本节点接口处理器给出的本节点输入数据序列阻塞请求，高电平(1)有效
                                                   ///< \attention 必须谨慎处理 #sink_blk 信号的赋值问题，以尽可能避免陷入阻塞赋值死循环，一般的赋值原则是：
                                                   ///< - 当本级节点的输出数据时序相对输入数据没有改变时，本级节点向上级节点请求的 #sink_blk 信号可以考虑使用阻塞赋值；
                                                   ///< - 当本级节点的输出数据时序相对输入数据有改变时，应考虑采用预报的方式对 #sink_blk 信号使用非阻塞赋值。
   logic prcsr_blk;                                ///< 本节点接口处理器给出的本节点处理器阻塞状态，高电平(1)有效。本信号表示除了因时分复用运算之外的其他因素（本处理器或后级处理器的阻塞请求）造成的阻塞状态。
                                                   ///< \attention
                                                   ///< - 当 #clken 为低电平(0)时，处理器阻塞状态也应被置位
                                                   ///< - 当本节点处理器以时分复用模式处理前级节点输入的数据时，输入数据序列阻塞请求将被置位，而处理器阻塞请求则不会置位
                                                   ///< - 当本节点处理器不以时分复用模式处理前级节点输入的数据时，处理器阻塞状态应与输入数据序列阻塞状态一致
   logic usr_blk;                                  ////< 用户为本节点接口处理器指定的处理器阻塞状态
   localparam int bitsof_src_maxcnt = avalon_pkg::bitwOfDataSeqLen(avalon_pkg::maxSrc_of_ifCfg(IC));
   localparam int bitsof_src_idx    = avalon_pkg::bitwOfDataSeqIdx(avalon_pkg::maxSrc_of_ifCfg(IC));
   logic[bitsof_src_idx   -1:0] src_idx;           ///< 本节点接口当前输出数据在序列中的索引
   logic[bitsof_src_idx   -1:0] src_nxtidx;        ///< 本节点接口下一输出数据在序列中的索引
   logic[bitsof_src_maxcnt-1:0] src_cnt;           ///< 本结点接口当前输出数据序列的长度，必须由用户通过 #procp 端口列表赋值
                                                   ///< \attention #src_cnt 最迟必须在 #src_eop 时刻生效
   logic src_sop;                                  ///< 本节点接口输出数据序列起始标志，高电平(1)有效
   logic src_eop;                                  ///< 本节点接口输出数据序列结束标志，高电平(1)有效
   logic src_valid;                                ///< 本节点接口输出数据序列有效标志，高电平(1)有效
                                                   ///< \attention 当该信号有效时，本模块假定每一个时钟周期均输出一个数据，因此当序列中一个数据的持续时间超过1个时钟
                                                   ///< 周期时，用户须将数据有效标志压窄为一个时钟周期宽度后再连接至本信号端口上。
   logic src_blk;                                  ///< 下一节点接口处理器给出的本节点输出数据序列阻塞请求，高电平(1)有效
   logic src_bufsel;                               ///< 本节点接口数据输出缓存选择信号，高电平(1)时选择处理器输出数据的延迟一拍保持的缓存数据输出，低电平(0)时选择处理器输出数据直接输出
                                                   ///< \attention 本信号用于 #src_blk 信号置位时，保持
   /*! \brief 本节点接口的时钟及复位信号端口信号列表 */
   modport crp(input clk, aclr, sclr, clken);
   /*!
    * \brief 本节点接口的输入端服务器访问端口列表
    * \details 本端口列表可使用 #avalon_makesink_witheop 或 #avalon_makesink_withcnt 模块产生Avalon接口输入端信号，也可使用 #avalon_link 模块将本节点接口的输入端信号连接至前一节点接口的输出端信号。
    */
   modport sinkp(input prcsr_blk, usr_blk, sink_blk, output sink_idx, sink_nxtidx, sink_cnt, sink_sop, sink_eop, sink_valid);
   /*!
    * \brief 本节点接口的数据处理用交互信号端口列表
    * \attention
    * - #src_sop 信号由用户定义的处理器产生有助于避免Avalon接口的输出端索引陷入无法恢复的不同步状态。
    * \p 因为当输出端的输出计数仅由 #src_valid 控制时，Avalon接口无法获知 #src_valid 有效时的什么时刻才是序列的起始时刻，只能凭借内
    * 部的输出计数器来估计，若输出计数器因为某种原因与实际的输出数据失去同步，则在仅有 #src_valid 信号的情况下Avalon接口无法探测并修复
    * 计数器的不同步状态。
    * - 必须谨慎处理 #sink_blk 信号的赋值问题，以尽可能避免陷入阻塞赋值死循环，一般的赋值原则是：
    *   - 当本级节点的输出数据时序相对输入数据没有改变时，本级节点向上级节点请求的 #sink_blk 信号可以考虑使用阻塞赋值；
    *   - 当本级节点的输出数据时序相对输入数据有改变时，应考虑采用预报的方式对 #sink_blk 信号使用非阻塞赋值。
    * - 数据阻塞原则：#sink_blk 信号由低变高应仅由数据输出触发。
    *   - 对输出端， #src_blk 信号是下级节点通知本级节点暂时停止依序更换输出端数据的标志：
    *      -# 当 #src_blk 为高电平时，应停止更新输出端数据（即下一拍输出端数据状态与当前数据保持一致）；
    *      -# 当 #src_blk 为低电平时，则开始更新输出端数据（即下一拍输出端给出下一组数据）。
    *   - 对输入端， #sink_blk 信号是本级节点通知上级节点暂停依序更换输出端数据的标志：
    *      -# #sink_blk 信号的置位必须仅由本级节点输入数据产生，即：当本级节点仅能输入一拍数据时，下一时钟置位 #sink_blk 信号；
    *      -# #sink_blk 信号的清零时序：当下一时钟本级节点可以开始输入至少一拍数据时， #sink_blk 信号清零。
    */
   modport procp(input sink_idx, sink_nxtidx, sink_cnt, sink_sop, sink_eop, sink_valid, src_idx, src_nxtidx, src_blk, src_eop, output prcsr_blk, usr_blk, sink_blk, src_cnt, src_sop, src_valid, src_bufsel);
   /*! \brief 本节点接口的辅助信号传递用交互信号端口列表 */
   modport auxp(input sink_idx, sink_nxtidx, sink_cnt, sink_sop, sink_eop, sink_valid, prcsr_blk, usr_blk, src_idx, src_nxtidx, src_blk, src_eop, sink_blk, src_cnt, src_sop, src_valid, src_bufsel);
   /*!
    * \brief 本节点接口的输出端服务器访问端口列表
    * \attention #src_sop 信号由用户定义的处理器产生有助于避免Avalon接口的输出端索引陷入无法恢复的不同步状态。
    * 因为当输出端的输出计数仅由 #src_valid 控制时，Avalon接口无法获知 #src_valid 有效时的什么时刻才是序列的起始时刻，只能凭借内部
    * 的输出计数器来估计，若输出计数器因为某种原因与实际的输出数据失去同步，则在仅有 #src_valid 信号的情况下Avalon接口无法探测并修复
    * 计数器的不同步状态。
    */
   modport srcp(input src_cnt, src_valid, src_blk, src_sop, output src_idx, src_nxtidx, src_eop);
   /*!
    * \brief 下一节点使用的本节点与在Avalon流水接口链中的下一节点的交互信号端口列表
    * \attention 由下级节点直连反馈过来的本级节点 #src_blk 信号必须遵守的约定：
    * - 仅当前一时钟时刻 #src_valid 信号为高(1)时，本时钟时刻的信号 #src_blk 才可以由低(0)翻转为高(1)，即 #src_blk 信号的置位必须仅由
    * 下级节点的数据输入造成；
    * - #src_blk 信号由高(1)翻转为低(0)则不受 #src_valid 信号状态的限制。
    */
   modport nextp(input src_idx, src_nxtidx, src_cnt, src_sop, src_eop, src_valid, src_bufsel, output src_blk);
   /*!
    * \brief 本节点作为子链表的上层节点，传递子链表表头节点输入信号到本节点输入端的交互信号端口列表
    * \details 本端口列表与待封装子链表的头结点的 #sink2topp 对接来实现上层节点输入端信号对子链表头结点的输入端信号的连接。
    */
   modport topsinkfrmnodp(input sink_valid, sink_eop, output sink_idx, sink_nxtidx, sink_cnt, sink_sop, sink_blk, prcsr_blk, usr_blk);
   /*!
    * \brief 本节点作为子链表的上层节点时，传递输入信号到子链表的表头节点输入端的交互信号端口列表
    * \details 本端口列表与待封装子链表的头结点的 #sinkp 对接来实现上层节点输入端信号对子链表头结点输入端信号的连接。
    * \attention 当使用本端口列表从上层节点连接子链表表头节点时，因上层节点的输入端信号与子链表表头节点的输入端直接连接，
    * 上层节点应调用 #avalon_makesink_witheop 或 #avalon_makesink_withcnt 来为其做输入端服务处理，子链表头结点则不可使用 #avalon_makesink 来为其做输入端。
    * \todo 对于不从子链表输入端取得 #sink_blk 信号的情况，可从连接模块的入口信号引入，由用户选择是否引用子链表头节点的 #sink_blk 信号还是自己生成的 #sink_blk 信号。
    */
   modport topsink2nodp(input sink_idx, sink_nxtidx, sink_cnt, sink_sop, sink_eop, sink_valid, output prcsr_blk, usr_blk, sink_blk);
   /*!
    * \brief 本节点作为子链表的上层节点时，传递子链表的表尾节点输出信号到本节点输出端的交互信号端口列表
    * \details 本端口列表与待封装子链表的尾节点的 #nextp 对接来实现上层节点输出端信号对子链表尾节点输出信号的连接。
    * \attention 当使用本端口列表从上层节点连接子链表表尾节点时，因上层节点的输出端信号与子链表表尾节点的输出端直接连接，
    * 上层节点不可调用 #avalon_prcsrmake 或者 #avalon_makesrc 来为其做输出端服务处理。
    */
   modport topsrcfrmnodp(input src_blk, output src_idx, src_nxtidx, src_cnt, src_sop, src_eop, src_valid, src_bufsel);
   /*!
    * \brief 本节点作为子链表的上层节点时，连接子链表表头和表尾的交互信号端口列表
    * \details 本端口列表与待封装子链表的头节点的 #nodsinkp 、 尾节点的 #nextp 一起使用来实现上层节点对子链表的封装
    * \attention
    * - 因本端口列表需要从子链表的表头拷贝 #sink_blk 信号对本节点的 #sink_blk 变量赋值，所以本节点的端口列表 #procp 将不再被允许使用，否则将引起
    * 对本节点的 #sink_blk 变量重复赋值的冲突；
    * \p 从另一方面来讲，子链表上的处理器模块链已经实现了父节点的处理器功能，使用 #procp 来重复创建处理器也是不合法的。
    * - 当使用本端口列表从上层节点连接子链表表头节点时：
    *   - 因后者的输入端信号与上层节点的输入端信号直接连接，后者不可再调用 #avalon_makesink_witheop 或 #avalon_makesink_withcnt 来为其做输入端服务处理，后者的输出端服务处理不变；
    *   - 而前者的输出端信号与子链表表尾节点的输出端直接连接，前者不可再调用 #avalon_makesrc 来为其做输出端服务处理，前者的输入端服务处理不变。
    */
   modport topnodp(input sink_idx, sink_nxtidx, sink_cnt, sink_sop, sink_eop, sink_valid, src_blk, output prcsr_blk, usr_blk, sink_blk, src_idx, src_nxtidx, src_cnt, src_sop, src_eop, src_valid, src_bufsel);
   /*!
    * \brief 本结点作为子链表的上层节点，且本节点处于父链表的头结点时，连接子链表表头和表尾的交互信号端口列表
    * \details 本端口列表与待封装子链表的头结点的 #nodsinkp 、 尾节点的 #nextp 一起使用 #avalonchain_chain2node 来实现上层节点对子链表的封装
    * \attention
    * - 因本端口列表需要从子链表的表头拷贝 #sink_blk 信号对本节点的 #sink_blk 变量赋值，所以本节点的端口列表 #procp 将不再被允许使用，否则将引起
    * 对本节点的 #sink_blk 变量重复赋值的冲突；
    * \p 从另一方面来讲，子链表上的处理器模块链已经实现了父节点的处理器功能，使用 #procp 来重复创建处理器也是不合法的。
    * - 当使用本端口列表从上层节点连接子链表表头节点时：
    *   - 因后者的某些输入端信号与上层节点的输入端信号直接连接，后者不可再调用 #avalon_makesink_witheop 或 #avalon_makesink_withcnt 来为其做输入端服务处理，后者的输出端服务处理不变；
    *   - 而前者的输出端信号与子链表表尾节点的输出端直接连接，前者不可再调用 #avalon_makesrc 来为其做输出端服务处理，前者的输入端服务处理不变。
    */
   modport topheadp(input sink_valid, sink_eop, src_blk, output prcsr_blk, usr_blk, sink_idx, sink_nxtidx, sink_cnt, sink_sop, sink_blk, src_idx, src_nxtidx, src_cnt, src_sop, src_eop, src_valid, src_bufsel);
   /*!
    * \brief 本节点作为链表的头结点时，与上层链表头节点之间的交互信号端口列表
    * \details 本端口列表与链表尾节点的 #nextp 、父链表头结点的 #topheadp 一起使用 #avalonchain_chain2head 来实现上层链表头结点对子链表的封装
    * \attention 因头结点需要用户输入 #clk 、 #aclr 、 #clken 、 #sink_valid 、 #sink_eop 信号，并向用户输出 #sink_sop 、 #sink_idx 、 
    * #duration 、 #sink_blk 信号，这使得封装成的上层链表的节点只能作为头结点使用。因此当子链表存在头节点时，其只能封装为父链表的头结点使用。
    */
   modport sink2topp(input prcsr_blk, usr_blk, sink_blk, sink_idx, sink_nxtidx, sink_cnt, sink_sop, output sink_eop, sink_valid);
endinterface: avalon_if
/*!
 * \brief Avalon接口辅助信号传递接口
 * \details
 * -# 本接口用于管理和传递与Avalon接口信号同步的非标准接口信号；
 * -# 本接口可使用 #avalon_auxsigifi_sync 或者 #avalon_auxsigifi_syncwith_avalonif 驱动；
 * -# 本接口也可使用 #avalon_auxsig_sync 或者 avalon_auxsig_syncwith_avalonif 单独驱动接口的 #sink_sig 和 #src_sig 信号。
 * -# 本接口数组可使用 #avalon_auxsig
 */
interface avalon_auxsigif #(
   parameter int AUXSIG_BITW = 1
);
   logic[AUXSIG_BITW-1:0] sink_sig;
   logic[AUXSIG_BITW-1:0] src_sig;
endinterface: avalon_auxsigif
/*!
 * \brief Avalon接口辅助信号合并数组传递接口
 * \details
 * -# 本接口用于管理和传递与Avalon接口信号同步的非标准接口合并数组信号；
 * -# 本接口可使用 #avalon_packedarray_auxsigifi_sync 或者 #avalon_packedarray_auxsigifi_syncwith_avalonif 驱动；
 * -# 本接口也可使用 #avalon_packedarray_auxsig_sync 或者 #avalon_packedarray_auxsig_syncwith_avalonif 单独驱动接口的 #sink_sigs 和 #src_sigs 信号。
 */
interface avalon_packedarray_auxsigif #(
   parameter int AUXSIG_BITW = 1,
   parameter int ARRAYSIZ    = 1
);
   logic[ARRAYSIZ-1:0][AUXSIG_BITW-1:0]sink_sigs;
   logic[ARRAYSIZ-1:0][AUXSIG_BITW-1:0]src_sigs;
endinterface
/*!
 * \brief Avalon接口辅助信号非合并数组传递接口
 * \details
 * -# 本接口用于管理和传递与Avalon接口信号同步的非标准接口非合并数组信号；
 * -# 本接口可使用 #avalon_unpackedarray_auxsigifi_sync 或者 #avalon_unpackedarray_auxsigifi_syncwith_avalonif 驱动；
 * -# 本接口也可使用 #avalon_unpackedarray_auxsig_sync 或者 avalon_unpackedarray_auxsig_syncwith_avalonif 单独驱动接口的 #sink_sigs 和 #src_sigs 信号。
 */
interface avalon_unpackedarray_auxsigif #(
   parameter int AUXSIG_BITW = 1,
   parameter int ARRAYSIZ    = 1
);
   logic [AUXSIG_BITW-1:0] sink_sigs[ARRAYSIZ-1:0];
   logic [AUXSIG_BITW-1:0] src_sigs[ARRAYSIZ-1:0];
endinterface
/*!
 * \brief Avalon接口辅助信号合并数组及额外数据传递接口
 * \details
 * -# 本接口用于管理和传递与Avalon接口信号同步的非标准接口合并数组信号；
 * -# 本接口可使用 #avalon_packedarray_auxsigifi_sync 或者 #avalon_packedarray_auxsigifi_syncwith_avalonif 驱动；
 * -# 本接口也可使用 #avalon_packedarray_auxsig_sync 或者 #avalon_packedarray_auxsig_syncwith_avalonif 单独驱动接口的 #sink_sigs 和 #src_sigs 信号。
 */
interface avalon_packedarray_extd_auxsigif #(
   parameter int AUXSIG_BITW = 1,
   parameter int ARRAYSIZ    = 1,
   parameter int EXTDBITW    = 1
);
   logic[ARRAYSIZ-1:0][AUXSIG_BITW-1:0]sink_sigs;
   logic[ARRAYSIZ-1:0][AUXSIG_BITW-1:0]src_sigs;
   logic[EXTDBITW-1:0]                 sink_extd;
   logic[EXTDBITW-1:0]                 src_extd;
endinterface
/*!
 * \brief Avalon接口辅助信号非合并数组及额外数据传递接口
 * \details
 * -# 本接口用于管理和传递与Avalon接口信号同步的非标准接口非合并数组信号；
 * -# 本接口可使用 #avalon_unpackedarray_auxsigifi_sync 或者 #avalon_unpackedarray_auxsigifi_syncwith_avalonif 驱动；
 * -# 本接口也可使用 #avalon_unpackedarray_auxsig_sync 或者 avalon_unpackedarray_auxsig_syncwith_avalonif 单独驱动接口的 #sink_sigs 和 #src_sigs 信号。
 */
interface avalon_unpackedarray_extd_auxsigif #(
   parameter int AUXSIG_BITW = 1,
   parameter int ARRAYSIZ    = 1,
   parameter int EXTDBITW    = 1
);
   logic [AUXSIG_BITW-1:0] sink_sigs[ARRAYSIZ-1:0];
   logic [AUXSIG_BITW-1:0] src_sigs[ARRAYSIZ-1:0];
   logic [EXTDBITW-1:0]    sink_extd;
   logic [EXTDBITW-1:0]    src_extd;
endinterface
/*! \brief Avalon接口多路复用器控制信号接口 */
interface avalon_linkmux_if #(
   parameter avalon_pkg::linkMuxCfg LMC = avalon_pkg::make_linkMuxCfg(2, 0, 2, 0)///< Avalon接口多路复用器配置参数
);
   localparam int prevPortCnt = avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC);
   localparam int sinkPortCnt = avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC);
   logic[prevPortCnt-1:0] prevp_cs;       ///< 前级Avalon接口输出端信号列表在输出时刻的选通信号
                                          ///< \attention
                                          ///< 当有多个输出端信号列表被选通时，仅比特位索引最低的选通信号对应的信号列表被选通
   logic[sinkPortCnt-1:0] sinkp_cs;       ///< 本级Avalon接口输入端信号列表在输入时刻的选通信号
                                          ///< \attention 
                                          ///< - 当有多个输入端信号列表被选通时，仅比特位索引最低的选通信号对应的信号列表被选通
                                          ///< - 当 LMC.sinkPortBufSig == 1'b1时，本信号同步于Avalon接口多路复用器输出端信号的前一拍，否则本信号同步于输出端信号同步
   bit  [sinkPortCnt-1:0] sink_clk;       ///< 本级Avalon接口驱动时钟信号
   logic[sinkPortCnt-1:0] sink_aclr;      ///< 本级Avalon接口异步复位信号，高电平(1)有效
   logic[sinkPortCnt-1:0] sink_clken;     ///< 本级Avalon接口时钟使能信号，高电平(1)有效
   logic[sinkPortCnt-1:0] sink_sclr;      ///< 本级Avalon接口同步复位信号，高电平(1)有效
   logic[sinkPortCnt-1:0] sink_bufsel;    ///< 本级Avalon接口输入端信号缓冲区选择信号，1-选择缓冲区信号输出，0-选择直连信号输出
   logic[sinkPortCnt-1:0] blkbysinkp;     ///< 本级Avalon接口输入端反馈的阻塞请求信号，高电平(1)有效
   logic[sinkPortCnt-1:0] blkbynocs;      ///< 因为本级Avalon接口输入端没有被选中而产生的阻塞请求信号，高电平(1)有效
   logic[sinkPortCnt-1:0] sink_muxblk;    ///< 本级Avalon接口输入端信号缓冲区保持信号，1-信号缓冲区状态保持，0-信号缓冲区按时序更新
   logic[sinkPortCnt-1:0] prevpmuxclken;  ///< 前级Avalon接口输出端复选本级Avalon接口输入端的复选使能信号，高电平(1)有效
   /*! \brief 多路复用器控制信号输出端口 */
   modport ifmuxp(output prevp_cs, sinkp_cs, sink_clk, sink_aclr, sink_clken, sink_sclr, sink_bufsel, blkbysinkp, blkbynocs, sink_muxblk, prevpmuxclken);
   /*! \brief 辅助信号同步用控制信号输入端口 */
   modport auxmuxp(input prevp_cs, sinkp_cs, sink_clk, sink_aclr, sink_clken, sink_sclr, sink_bufsel, blkbysinkp, blkbynocs, sink_muxblk, prevpmuxclken);
endinterface: avalon_linkmux_if
/*! \brief Avalon接口镜像连接器控制信号接口 */
interface avalon_mirrormux_if #(
   parameter avalon_pkg::mirrorMuxCfg MMC = avalon_pkg::make_mirrorMuxCfg(2, 0, 0)  ///< Avalon接口镜像连接器配置参数
);
   localparam int mirrorCnt = avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC);
   localparam int idxBitwOfSinkPort = mux_pkg::idxbitw_ofmux(mirrorCnt);
   /*!
    * \attention #msinkidx 、 midx4mux2srci 、 msrci_idx 的时序同步位置示意图
    *                   |->td_m2i = avalon_pkg::m2isinkMuxTaps_of_mirrorMuxCfg(MMC)
    *                 |<>|
    *                 |->T0m
    *  clk_sink:   ^__^__^^__^^__^^__^^ ...
    *  ifim_sink:  ^^^|________________ ...
    *  ifi_sink :  ^^^^^^|_____________ ...
    *                    |->T0i
    *                                           
    *                                            |->T1i
    *  clk_src :                          ... ^__^__^^__^^__^^__^^
    *  ifi_src :                          ... ^^^|___
    *  ifim_src:                          ... ^^^^^^|_____
    *                                               |->T1m
    *                                            |<>|
    *                                              |->td_i2m = 2*avalon_pkg::ixmDelayOut_of_mirrorMuxCfg(MMC)
    */
   bit                  clk;        ///< 被镜像连接的驱动时钟信号
   logic                aclr;       ///< 被镜像连接的Avalon接口异步复位信号，高电平(1)有效
   logic                sclr;       ///< 被镜像连接的Avalon接口同步复位信号，高电平(1)有效
   logic                clken;      ///< 被镜像连接的Avalon接口时钟使能信号，高电平(1)有效
   logic[mirrorCnt-1:0] msink_cs;   ///< 镜像Avalon接口实例输入端信号在“信号从被选通的镜像Avalon接口输出的时刻”（T0m）的选通信号数组
   logic[mirrorCnt-1:0] isink_cs;   ///< 镜像Avalon接口实例输入端信号在“信号从被镜像的Avalon接口输入的时刻”（T0I）的选通信号数组
   logic                isinkblk;   ///< 被镜像Avalon接口实力输入端阻塞请求信号，高电平(1)有效
   logic                sink_bufsel;///< 被镜像Avalon接口实例输入端信号缓冲区选择信号，1'b1-选择缓冲区信号输出，1'b0-选择直连信号输出
   logic                sinkmuxidle;///< 被镜像Avalon接口实例输入端信号缓冲区保持信号，1'b1-信号缓冲区状态保持，1'b0-信号缓冲区按时序更新
   bit  [mirrorCnt-1:0] mclk;       ///< 镜像Avalon接口实例数组的驱动时钟信号数组
   logic[mirrorCnt-1:0] maclr;      ///< 镜像Avalon接口实例数组的异步复位信号数组，高电平(1)有效
   logic[mirrorCnt-1:0] msclr;      ///< 镜像Avalon接口实例数组输出端同步复位信号，高电平(1)有效
   logic[mirrorCnt-1:0] mclken;     ///< 镜像Avalon接口时钟使能信号，高电平(1)有效
   logic[mirrorCnt-1:0] msrci_cs;   ///< 镜像Avalon接口实例数组输出端信号在信号输入时刻（T1i）的选通信号
   logic[mirrorCnt-1:0] msrcm_cs;   ///< 镜像Avalon接口实例数组输出端信号在信号输出时刻（T1m）的选通信号
   logic[mirrorCnt-1:0] msrcblk;    ///< 镜像Avalon接口实力的输出端阻塞请求信号，高电平(1)有效
   logic[mirrorCnt-1:0] msrc_bufsel;///< 镜像Avalon接口实例数组输出端信号缓冲区选择信号，1'b1-选择缓冲区信号输出，1'b0-选择直连信号输出
   logic[mirrorCnt-1:0] msrcmuxidle;///< 镜像Avalon接口实例数组输出端信号缓冲区保持信号，1'b1-信号缓冲区状态保持，1'b0-信号缓冲区按时序更新
   /*! \brief 镜像连接器控制信号输出端口 */
   modport ifmuxp(output clk, aclr, sclr, clken, msink_cs, isink_cs, isinkblk, sink_bufsel, sinkmuxidle, mclk, maclr, msclr, mclken, msrci_cs, msrcm_cs, msrcblk, msrc_bufsel, msrcmuxidle);
   /*! \brief 辅助信号同步用控制信号输入端口 */
   modport auxmuxp(input clk, aclr, sclr, clken, msink_cs, isink_cs, isinkblk, sink_bufsel, sinkmuxidle, mclk, maclr, msclr, mclken, msrci_cs, msrcm_cs, msrcblk, msrc_bufsel, msrcmuxidle);
endinterface: avalon_mirrormux_if
 `endif// __AVALON_ITF__

`else
 `undef  __ITF_BANNED__
`endif

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

