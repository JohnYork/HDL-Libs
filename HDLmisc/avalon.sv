/*!
 * \license SPDX-License-Identifier: MIT
 * \file avalon.sv
 * \brief SystemVerilog实现的基于Altera公司的Avalon ST接口协议的Avalon协议链
 * \details 本模块实现基于Altera公司的Avalon接口协议的Avalon协议链，设计目的是：
 * -# 为了简化运算中各级节点模块间的Avalon接口协议连接；
 * -# 额外提供输入、输出数据的索引计数和总数计数；
 * -# 提供下级节点向上级节点请求阻塞的功能
 * -# Avalon接口链表中的信号传递方向：
 *    -# 正向传递信号包括：sink_idx 、 sink_nxtidx 、 sink_cnt 、 sink_sop 、 sink_eop 、 sink_valid 、 src_idx 、 src_nxtidx 、 src_cnt 、 src_sop 、 src_eop 、 src_valid
 *    -# 反向传递信号包括：sink_blk 、 prcsr_blk 、 #src_blk
 * \usage
 * -# Avalon接口单节点应用：
 *    -# 例化 #avalon_if 类型的接口实例；
 *    -# 例化 #avalon_makesink 类型的模块实例来产生接口实例的Avalon接口输入端信号；
 *    -# 例化 #avalon_tdmif 类型的时分复用处理接口实例，并设置最大时分复用拍数例化参数，连接输入时分复用拍数参数；
 *    -# 设计和例化Avalon接口实例的数据处理器模块，要求：
 *       - 入口信号至少包括 #avalon_if.procp 和 #avalon_if.srcp 类型的接口实例处理器端口信号列表；
 *       - 处理器须设置 #avalon_if.procp 类型的处理器端口信号列表中的 #src_cnt 、 #src_sop 、 #src_valid 、 #prcsr_blk 、 #sink_blk 信号；
 *       - 处理器须设置 #avalon_if.srcp 类型的处理器端口信号列表中的 #src_idx 、 #src_nxtidx 、 #src_eop 信号；
 *       - 可例化 #avalon_prcsrmake 类型的模块实例来按默认设置输出信号（不需要单独例化 #avalon_makesrc 模块来设置 #avalon_if.srcp 的信号），该模块要求处理器：
 *          -# 在 #src_blk 为低时对输出数据做延迟一拍缓存，在 #src_blk 为高时，以及由高变低后的第一拍数据输出，选择延迟缓存数据输出，否则选择处理器输出端口数据直接输出，可
 *          例化模块 #avalon_srcsig_bybufsel 或者 #avalon_srcsig_bybufsel_auxp 来实现该功能；
 *          -# 对存在时分复用延迟处理，且处理结果不需要归集输出的处理器，可直接按上述方法处理输出数据；
 *          -# 对存在时分复用延迟处理，单处理结果需要归集输出的处理器，若归集器有缓存功能（例如： #array_partadapter_byidx ），可不必额外例化缓存器，直接将 #src_blk 与
 *          归集器的写使能信号相与后送给归集器即可。
 *       － 对有时分复用处理的处理器，可例化 #avalon_tdmmake 来产生以Avalon接口传递的时分复用同步信号；
 *    -# 对需要与Avalon接口保持同步的信号，可以例化 #avalon_auxsig_sync 、 #avalon_auxsigifi_sync 模块结合 #avalon_srcsig_bybufsel 来实现同步，另外，
 *       还可以例化 #avalon_auxsig_syncwith_avalonif 、 #avalon_auxsigifi_syncwith_avalonif 来实现同步（不需要额外例化 #avalon_srcsig_bybufsel ，模块内部已有例化实例）。
 * -# Avalon接口链表的应用：
 *    -# 按“Avalon接口单节点应用”的说明声明和例化链表上每个Avalon接口节点的各种接口和模块实例，其中：
 *       - 对链表的首节点接口，需要例化“Avalon接口单节点应用”中提到的全部接口和模块实例；
 *       - 对链表的非首节点接口，不用例化“Avalon接口单节点应用”中提到的 #avalon_makesink 模块实例。
 *    -# 例化 #avalon_link 类型的模块实例来对链表上的各Avalon接口节点进行首尾链接。
 *    -# 链表节点的处理器设计：
 *       - 对需要执行数据处理的节点，需要按“Avalon接口单节点应用”的说明设计接口处理器，并例化 #avalon_makesrc 模块实例；
 *       - 对仅做桥接、用于选择器输入的节点，可以例化 #avalon_directsrc 模块来实现接口信号的直通，不需要单独设计接口处理器及例化 #avalon_makesrc 模块实例。
 * -# Avalon接口链表的多路复用选择实现：
 *    -# 为多路复用的输入Avalon接口节点和输出Avalon接口节点分别例化一个 #avalon_if 数组，并使用 #avalon_mirror_make 来将各输入节点和输出节点分别镜像至输入
 *       #avalon_if 数组和输出 #avalon_if 数组；
 *    -# 例化 #avalon_linkmux_prevpbyidx 或 #avalon_linkmux_prevpbycs 来实现输入节点和输出节点的多路复用选择。
 * -# Avalon接口链表节点的多路复用选择实现（适用于模块实例的分时复用设计）：
 *    -# 例化 #avalon_if 数组用于连接分时复用节点客户端Avalon接口链表；
 *    -# 例化 #avalon_mirror_muxer 实现Avalon接口节点的多路复用选择。
 * -# Avalon接口链表归并为单个Avalon接口节点的应用：
 *    -# 按“Avalon接口处理链表的应用”声明和例化Avalon接口链表；
 *    -# 例化归并用的上层Avalon接口节点；
 *    -# 例化Avalon接口处理链表归并模块：
 *       - 若归并成的上层节点作为单个节点使用，或者作为链表的表头节点使用，则例化 #avalon_chain2head 模块来实现归并；
 *       - 若归并成的上层节点作为链表的非表头节点使用，则例化 #avalon_chain2node 模块来实现归并。
 * -# Avalon接口处理链表应用于Avalon处理器内部实现的应用：
 *    - 按“Avalon接口单节点应用”声明和例化链表上每个Avalon接口节点的各种接口和模块实例；
 *    - 按“Avalon接口链表归并为单个Avalon接口节点的应用”将处理器内部的Avalon接口处理链表例化 #avalon_chain2head 或 #avalon_chain2node 归并连接至处理器的Avalon接口；
 *      作为该实现方案的一个可选替代方案，使用者还可以按如下方法连接链表的首节点和尾节点：
 *       - 对链表的首节点接口，使用 #avalon_prcsr_attachfrmsink 将输入端信号连接至上层处理器的 #avalon_if.topsinkfrmnodp 类型的端口信号列表；
 *         或者使用 #avalon_prcsr_attach2sink 将输入端信号连接至上层处理器的 #avalon_if.topsinkp 类型的端口信号列表
 *       - 对链表的尾节点，可从下面两种设计方案中选用一种：
 *         - 使用 #avalon_prcsr_attachsrc 将输出端信号连接至上层处理器的 #avalon_if.procp 、 #avalon_if.srcp 类型的端口信号列表的输出端信号；
           - 使用 #avalon_prcsrmake 产生上层处理器的输出信号。
 *       - 对相对首节点存在时分复用处理的尾节点，可例化 #avalon_prcsrmake 类型的模块实例并设置例化参数 #TDMOP_MODE 为-1来去掉时分复用同步信息后输出信号。
 * -# Avalon接口处理链表的阻塞信号前向传递设计：
 *    - 直接的阻塞信号前向传递在Avalon接口处理链表节点较多时会造成阻塞信号的组合逻辑电路路径过长，影响设计的时序性能；
 *    - Avalon接口节点可选择对输出信号做缓存（设置avalon接口各模块的例化参数 #BUF_SRCSIG 为1），并在下级节点的阻塞信号置位时选择输出经缓存的输出信号的方式，使得下级节点的阻塞信号
 * 可延迟一拍后再赋值于本级节点，从而截断阻塞信号传递的组合逻辑电路；
 *    - 此种解决方案是以加长节点输出信号的组合逻辑路径长度、牺牲节点输出信号的时序性能来换取阻塞信号前向传递路径的截断，为缓解本级节点和下级节点间的时序冲突，需要在下级节点对本级节
 * 点输出至下级节点的信号延迟一拍后再做处理。
 *    - Avalon接口处理链表的最后一级节点不应对输出信号做缓存，以提高输出信号的时序性能。
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, mux, pipedelay, shifttaps, selsig2idx, packconv, multconst, fifos, dff_latch, edge_detectr, seqs_errchk
 */
`include "miscs.svh"
`include "mux.svh"
`define __INC_FROM_AVALON__
`include "avalon.svh"
/*!
 * \brief 为Avalon接口准备输入端信号
 * \attention 当使用本模块来产生Avalon接口的输入端信号时，用户处理器应避免直接对 #avalon_if 接口中所有输入端信号进行写操作，
 * 而必须通过本模块来实现对这些信号的写，以避免重复赋值错误的出现
 */
module avalon_makesink_witheop #(
   parameter avalon_pkg::ifCfg IC = avalon_pkg::deft_ifCfg
) (
   avalon_if.crp     crp,                          ///< Avalon接口时钟及复位信号端口列表
   avalon_if.sinkp   sinkp,                        ///< Avalon接口输入端口信号列表
   input  wire       sink_valid,                   ///< 数据输入有效标志，高电平(1)有效
                                                   ///< \attention 当该信号有效时，本模块假定每一个时钟周期均输入一个数据，因此当序列中一个数据的持续时间超过1个时钟
                                                   ///< 周期时，用户须将数据有效标志压窄为一个时钟周期宽度后再连接至本信号端口上。
   input  wire       sink_sop,                     ///< 用户给出的输入数据序列起始标志，高电平(1)有效，在 #sink_blk 未置位时持续一个 #clk 宽度
   input  wire       sink_eop,                     ///< 用户给出的输入数据序列结束标志，高电平(1)有效，在 #sink_blk 未置位时持续一个 #clk 宽度。
                                                   ///< \attention
                                                   ///< - 当用户不给出输入数据序列结束标志 #sink_eop 时，本模块将计数至 #IC.maxSink 时自动置位 #src_eop
                                                   ///< - 当用户给出输入数据序列结束标志 #sink_eop 时，本模块在用户给出 #sink_eop 标志的同时置位 #src_eop
   output logic      sink_blk                      ///< 输入数据序列阻塞请求标志，高电平(1)有效。
                                                   ///< \attention 
                                                   ///< - 当 #sink_blk 置位时，本模块的输入数据计数器将暂停更新，此时用户应保持当前数据输入接口上的数据状态不更新，直
                                                   ///< 到 #sink_blk 清零为止。否则本模块的输入数据计数器将与实际输入数据失去同步，可能造成数据丢失。
                                                   ///< - 本结点的处理器在输出 #sink_blk 请求时还应综合考虑本模块输出的 #sink_blk 请求信号，用户甚至可以考虑直接将
                                                   ///< 节点接口的 #sink_blk 变量连接至本信号端口上
);
   localparam int maxSink = avalon_pkg::maxSink_of_ifCfg(IC);
   // 接口 #sink_blk 信号输出
   assign sink_blk = sinkp.sink_blk;
   // 输入数据序列计数器
   localparam int bitsof_sinkcntr = avalon_pkg::bitwOfDataSeqIdx(maxSink);
   initial if (maxSink <= 0) $error("avalon_makesink_witheop : IC.maxSink(%0d) must be greator than zero!", maxSink);
   localparam int bitsof_sinkcnt = avalon_pkg::bitwOfDataSeqLen(maxSink);
   initial if (bitsof_sinkcnt > $bits(sinkp.sink_cnt)) $error("avalon_makesink_witheop : bitwidth of sinkp.sink_cnt(%0d) is not enough to hold all the value of actual count, it must at least be %0d", $bits(sinkp.sink_cnt), bitsof_sinkcntr);
   logic[bitsof_sinkcntr-1:0] sinkcntr;
   logic[bitsof_sinkcnt-1:0]  sink_cnt;
   wire[bitsof_sinkcnt-1:0]sinkcntr_inc = (bitsof_sinkcnt)'(sinkcntr) + (bitsof_sinkcnt)'(1);
   logic[bitsof_sinkcntr-1:0] sinkcntr2upd;
   always_comb begin
      if      (crp.aclr)sinkcntr2upd = '0;
      else if (crp.sclr)sinkcntr2upd = '0;
      else if (sink_valid) begin
         if (crp.clken) begin
            if      (sinkp.sink_blk)sinkcntr2upd = sinkcntr;
            else if (sinkp.sink_eop) begin
               /* 异常 EOP 检测及状态更新
                *           |- cnt = 0 : OK, upd = 0
                *           |            |- sop = 1 :  OK, upd = 0 
                * eop = 1 -< - cnt = 1 -< - sop = 0 : BAD, upd = 0
                *           |- cnt > 1 -< - sop = 1 : BAD, 认为 sop 正确， upd = 1
                *                        |- sop = 0 :  OK, upd = 0
                */
               if (sink_cnt > (bitsof_sinkcntr)'(1) && sink_sop == 1'b1)
                  sinkcntr2upd = (bitsof_sinkcntr)'(1);
               else
                  sinkcntr2upd = '0;
            end
            else if (sink_sop)  sinkcntr2upd = (bitsof_sinkcntr)'(1);
            else if (|sinkcntr) sinkcntr2upd = sinkcntr_inc[bitsof_sinkcntr-1:0];
            else                sinkcntr2upd = sinkcntr;
         end
         else                       sinkcntr2upd = sinkcntr;
      end
      else              sinkcntr2upd = sinkcntr;
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
      if (crp.aclr) sinkcntr <= '0;
      else          sinkcntr <= sinkcntr2upd;
   end
   // 输入数据序列状态
   assign sinkp.sink_valid = sink_valid;
   assign sinkp.sink_sop = sink_valid & (sink_sop | (~(|sinkcntr)));
   assign sinkp.sink_eop = (sinkcntr == (bitsof_sinkcntr)'(maxSink-1) || sink_eop == 1'b1) ? sink_valid : 1'b0;
   assign sinkp.sink_idx = (sink_sop&sink_valid) ? '0 : sinkcntr;
   assign sinkp.sink_nxtidx = sinkcntr2upd;
   // 输入数据序列长度采样值
   wire[bitsof_sinkcnt-1:0]sinkcnt2upd = (sink_valid) ? sinkcntr_inc : sink_cnt;
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
      if      (crp.aclr)                  sink_cnt <= '0;
      else if (crp.sclr)                  sink_cnt <= '0;
      else if (~crp.clken|sinkp.sink_blk) sink_cnt <= sink_cnt;
      else if (sinkp.sink_eop)            sink_cnt <= sinkcnt2upd;
      else if (sinkp.sink_sop)            sink_cnt <= '0;
      else                                sink_cnt <= sink_cnt;
   end
   assign sinkp.sink_cnt = sinkp.sink_eop ? sinkcnt2upd : sink_cnt;
   // \attention 上面的组合逻辑是必要的：为了避免 #sink_cnt 在紧接着 #sink_eop 的下一段数据的 #sink_sop 时刻生效
endmodule
module avalon_makesink_withcnt #(
   parameter avalon_pkg::ifCfg IC = avalon_pkg::deft_ifCfg
) (
   avalon_if.crp                                            crp,        ///< Avalon接口时钟及复位信号端口列表
   avalon_if.sinkp                                          sinkp,      ///< Avalon接口输入端口信号列表
   input  wire                                              sink_valid, ///< 数据输入有效标志，高电平(1)有效
                                                                        ///< \attention 当该信号有效时，本模块假定每一个时钟周期均输入一个数据，因此当序列中一个数据的持续时间超过1个时钟
                                                                        ///< 周期时，用户须将数据有效标志压窄为一个时钟周期宽度后再连接至本信号端口上。
   input  wire                                              sink_sop,   ///< 用户给出的输入数据序列起始标志，高电平(1)有效，在 #sink_blk 未置位时持续一个 #clk 宽度
   input  wire [avalon_pkg::bitwOfSinkCnt_of_ifCfg(IC)-1:0] sink_cnt,   ///< 用户给出的输入数据序列长度
   input  wire                                              sinkcnt_rdy,///< 用户给出的输入数据序列长度有效标志，高电平(1)有效。
   output logic                                             sink_blk    ///< 输入数据序列阻塞请求标志，高电平(1)有效。
                                                                        ///< \attention 
                                                                        ///< - 当 #sink_blk 置位时，本模块的输入数据计数器将暂停更新，此时用户应保持当前数据输入接口上的数据状态不更新，直
                                                                        ///< 到 #sink_blk 清零为止。否则本模块的输入数据计数器将与实际输入数据失去同步，可能造成数据丢失。
                                                                        ///< - 本结点的处理器在输出 #sink_blk 请求时还应综合考虑本模块输出的 #sink_blk 请求信号，用户甚至可以考虑直接将
                                                                        ///< 节点接口的 #sink_blk 变量连接至本信号端口上
);
   localparam int maxSink = avalon_pkg::maxSink_of_ifCfg(IC);
   // 接口 #sink_blk 信号输出
   assign sink_blk = sinkp.sink_blk;
   // 输入数据序列计数器
   localparam int bitsof_sinkcntr = avalon_pkg::bitwOfDataSeqIdx(maxSink);
   initial if (maxSink <= 0) $error("avalon_makesink_withcnt : IC.maxSink(%0d) must be greator than zero!", maxSink);
   initial if (bitsof_sinkcntr > $bits(sinkp.sink_cnt)) $error("avalon_makesink_withcnt : bitwidth of p.sink_cnt(%0d) is not enough to hold all the value of actual count, it must at least be %0d", $bits(sinkp.sink_cnt), bitsof_sinkcntr);
   logic[bitsof_sinkcntr-1:0] sinkcntr;
   wire [bitsof_sinkcntr-1:0] sinkcntr_inc = sinkcntr + (bitsof_sinkcntr)'(1);
   logic[bitsof_sinkcntr-1:0] sinkcntr2upd;
   always_comb begin
      if      (crp.aclr)sinkcntr2upd = '0;
      else if (crp.sclr)sinkcntr2upd = '0;
      else if (sink_valid) begin
         if (crp.clken) begin
            if      (sinkp.sink_blk)sinkcntr2upd = sinkcntr;
            else if (sinkp.sink_eop) begin
               /* 异常 EOP 检测及状态更新
                *           |- cnt = 0 : OK, upd = 0
                *           |            |- sop = 1 :  OK, upd = 0 
                * eop = 1 -< - cnt = 1 -< - sop = 0 : BAD, upd = 0
                *           |- cnt > 1 -< - sop = 1 : BAD, 认为 sop 正确， upd = 1
                *                        |- sop = 0 :  OK, upd = 0
                */

               if (sinkcnt_rdy == 1'b1 && sinkp.sink_cnt > (bitsof_sinkcntr)'(1) && sink_sop == 1'b1)
                  sinkcntr2upd = (bitsof_sinkcntr)'(1);
               else
                  sinkcntr2upd = '0;
            end
            else if (sink_sop)  sinkcntr2upd = (bitsof_sinkcntr)'(1);
            else if (|sinkcntr) sinkcntr2upd = sinkcntr_inc;
            else                sinkcntr2upd = sinkcntr;
         end
         else                       sinkcntr2upd = sinkcntr;
      end
      else              sinkcntr2upd = sinkcntr;
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
      if (crp.aclr) sinkcntr <= '0;
      else          sinkcntr <= sinkcntr2upd;
   end
   // 输入数据序列状态
   assign sinkp.sink_valid = sink_valid;
   assign sinkp.sink_sop = sink_valid & (sink_sop | (~(|sinkcntr)));
   localparam int bitsof_sinkcnt = avalon_pkg::bitwOfDataSeqLen(maxSink);
   wire[bitsof_sinkcntr-1:0] lastidx_ofsink = (bitsof_sinkcntr)'(sinkp.sink_cnt - (bitsof_sinkcnt)'(1));
   assign sinkp.sink_eop = ((sinkcntr == lastidx_ofsink) || sinkcntr == (bitsof_sinkcntr)'(maxSink-1)) ? sink_valid : 1'b0;
   assign sinkp.sink_idx = (sink_sop&sink_valid) ? '0 : sinkcntr;
   assign sinkp.sink_nxtidx = sinkcntr2upd;
   // 输入数据序列长度
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
      if      (crp.aclr)sinkp.sink_cnt <= '0;
      else if (crp.sclr)sinkp.sink_cnt <= '0;
      else              sinkp.sink_cnt <= (crp.clken&(~sinkp.sink_blk)&sinkcnt_rdy) ? sink_cnt : sinkp.sink_cnt;
   end
endmodule
module avalon_makesink_maxsink #(
   parameter avalon_pkg::ifCfg IC = avalon_pkg::deft_ifCfg
) (
   avalon_if                                                ifi,        ///< Avalon接口实例
   input  wire                                              sink_valid, ///< 数据输入有效标志，高电平(1)有效
                                                                        ///< \attention 当该信号有效时，本模块假定每一个时钟周期均输入一个数据，因此当序列中一个数据的持续时间超过1个时钟
                                                                        ///< 周期时，用户须将数据有效标志压窄为一个时钟周期宽度后再连接至本信号端口上。
   input  wire                                              sink_sop,   ///< 用户给出的输入数据序列起始标志，高电平(1)有效，在 #sink_blk 未置位时持续一个 #clk 宽度
   output logic                                             sink_blk    ///< 输入数据序列阻塞请求标志，高电平(1)有效。
                                                                        ///< \attention 
                                                                        ///< - 当 #sink_blk 置位时，本模块的输入数据计数器将暂停更新，此时用户应保持当前数据输入接口上的数据状态不更新，直
                                                                        ///< 到 #sink_blk 清零为止。否则本模块的输入数据计数器将与实际输入数据失去同步，可能造成数据丢失。
                                                                        ///< - 本结点的处理器在输出 #sink_blk 请求时还应综合考虑本模块输出的 #sink_blk 请求信号，用户甚至可以考虑直接将
                                                                        ///< 节点接口的 #sink_blk 变量连接至本信号端口上
);
   localparam int bitwof_sinkcnt = avalon_pkg::bitwOfSinkCnt_of_ifCfg(IC);
   localparam bit[bitwof_sinkcnt-1:0] sinkcnt = (bitwof_sinkcnt)'(avalon_pkg::maxSink_of_ifCfg(IC));
   avalon_makesink_withcnt #(
      .IC(IC)
   ) makesinki(
      .crp        (ifi.crp    ),
      .sinkp      (ifi.sinkp  ),
      .sink_valid (sink_valid ),
      .sink_sop   (sink_sop   ),
      .sink_cnt   (sinkcnt    ),
      .sinkcnt_rdy(1'b1       ),
      .sink_blk   (sink_blk   )
   );

endmodule
module avalon_makesink_forhead #(
   parameter avalon_pkg::ifCfg IC = avalon_pkg::deft_ifCfg
) (
   avalon_if                                                ifi,        ///< Avalon接口实例
   input  wire [avalon_pkg::bitwOfSinkCnt_of_ifCfg(IC)-1:0] sink_cnt,   ///< 用户给出的输入数据序列长度
   input  wire                                              sinkcnt_rdy,///< 用户给出的输入数据序列长度有效标志，高电平(1)有效。
   output logic                                             sink_blk    ///< 输入数据序列阻塞请求标志，高电平(1)有效。
                                                                        ///< \attention 
                                                                        ///< - 当 #sink_blk 置位时，本模块的输入数据计数器将暂停更新，此时用户应保持当前数据输入接口上的数据状态不更新，直
                                                                        ///< 到 #sink_blk 清零为止。否则本模块的输入数据计数器将与实际输入数据失去同步，可能造成数据丢失。
                                                                        ///< - 本结点的处理器在输出 #sink_blk 请求时还应综合考虑本模块输出的 #sink_blk 请求信号，用户甚至可以考虑直接将
                                                                        ///< 节点接口的 #sink_blk 变量连接至本信号端口上
);
   logic sinksop, sinkvalid;
   always_ff @(posedge ifi.clk, posedge ifi.aclr) begin
      if      (ifi.aclr)sinkvalid <= '0;
      else if (ifi.sclr)sinkvalid <= '0;
      else              sinkvalid <= (ifi.clken&(~sink_blk)) ? 1'b1 : sinkvalid;
   end
   always_ff @(posedge ifi.clk, posedge ifi.aclr) begin
      if      (ifi.aclr)sinksop <= '0;
      else if (ifi.sclr)sinksop <= '0;
      else              sinksop <= (ifi.clken&(~sink_blk)) ? (~sinkvalid)|(ifi.sink_eop) : sinksop;
   end
   avalon_makesink_withcnt #(
      .IC(IC)
   ) makesinki(
      .crp        (ifi.crp    ),
      .sinkp      (ifi.sinkp  ),
      .sink_valid (sinkvalid  ),
      .sink_sop   (sinksop    ),
      .sink_cnt   (sink_cnt   ),
      .sinkcnt_rdy(sinkcnt_rdy),
      .sink_blk   (sink_blk   )
   );
endmodule
module avalon_makesink_forhead_maxsink #(
   parameter avalon_pkg::ifCfg IC = avalon_pkg::deft_ifCfg
) (
   avalon_if    ifi,                               ///< Avalon接口实例
   output logic sink_blk                           ///< 输入数据序列阻塞请求标志，高电平(1)有效。
                                                   ///< \attention 
                                                   ///< - 当 #sink_blk 置位时，本模块的输入数据计数器将暂停更新，此时用户应保持当前数据输入接口上的数据状态不更新，直
                                                   ///< 到 #sink_blk 清零为止。否则本模块的输入数据计数器将与实际输入数据失去同步，可能造成数据丢失。
                                                   ///< - 本结点的处理器在输出 #sink_blk 请求时还应综合考虑本模块输出的 #sink_blk 请求信号，用户甚至可以考虑直接将
                                                   ///< 节点接口的 #sink_blk 变量连接至本信号端口上
);
   localparam int bitwof_sinkcnt = avalon_pkg::bitwOfSinkCnt_of_ifCfg(IC);
   localparam bit[bitwof_sinkcnt-1:0] sinkcnt = (bitwof_sinkcnt)'(avalon_pkg::maxSink_of_ifCfg(IC));
   avalon_makesink_forhead #(
      .IC(IC)
   ) makesinki(
      .ifi        (ifi     ),
      .sink_cnt   (sinkcnt ),
      .sinkcnt_rdy(1'b1    ),
      .sink_blk   (sink_blk)
   );
endmodule
module avalon_makesink_fortdm #(
   parameter avalon_pkg::ifCfg TDMIC = avalon_pkg::deft_ifCfg
) (
   avalon_if    tdmifi,    ///< 时分复用分拍Avalon接口实例
   avalon_if    hostifi,   ///< 时分复用分拍宿主Avalon接口实例
   output logic sink_blk   ///< 输入数据序列阻塞请求标志，高电平(1)有效。
                           ///< \attention 
                           ///< - 当 #sink_blk 置位时，本模块的输入数据计数器将暂停更新，此时用户应保持当前数据输入接口上的数据状态不更新，直
                           ///< 到 #sink_blk 清零为止。否则本模块的输入数据计数器将与实际输入数据失去同步，可能造成数据丢失。
                           ///< - 本结点的处理器在输出 #sink_blk 请求时还应综合考虑本模块输出的 #sink_blk 请求信号，用户甚至可以考虑直接将
                           ///< 节点接口的 #sink_blk 变量连接至本信号端口上
);
   avalon_makesink_witheop #(
      .IC(TDMIC)
   ) tdmsink_make(
      .crp        (tdmifi.crp          ),
      .sinkp      (tdmifi.sinkp        ),
      .sink_valid (hostifi.sink_valid  ),
      .sink_sop   (hostifi.sink_valid  ),
      .sink_eop   (hostifi.sink_valid  ),
      .sink_blk   (sink_blk            )
   );
endmodule
/*!
 * \brief Avalon接口产生输出端信号
 * \attention 当使用本模块来产生Avalon接口的输出端信号时，用户应避免直接对 #avalon_if 接口中的所有输出端信号执行写操作，
 * 而必须经过本模块来实现对这些信号的写，以避免产生重复赋值的错误
 */
module avalon_makesrc #(
   parameter avalon_pkg::ifCfg IC = avalon_pkg::deft_ifCfg
) (
   avalon_if.crp  crp,                             ///< Avalon接口时钟及复位信号端口列表
   avalon_if.srcp srcp                             ///< Avalon接口输出端服务器用信号端口列表
);
   // 输出数据序列计数器
   localparam int maxSrc = avalon_pkg::maxSrc_of_ifCfg(IC);
   localparam int bitsof_srcidx = avalon_pkg::bitwOfDataSeqIdx(maxSrc);
   localparam int bitsof_srccnt = avalon_pkg::bitwOfDataSeqLen(maxSrc);
   logic[bitsof_srcidx-1:0] out_cntr, outcntr2upd;
   wire [bitsof_srccnt-1:0] outcntr_inc = (bitsof_srccnt)'(out_cntr) + (bitsof_srccnt)'(1);
   always_comb begin
      if      (crp.aclr) outcntr2upd = '0;
      else if (crp.sclr) outcntr2upd = '0;
      else if (srcp.src_valid) begin
         if (crp.clken) begin
            if      (srcp.src_blk) outcntr2upd = out_cntr;
            // #src_eop 完全由 #out_cntr 的值决定，而 #outcntr 的值需要在 #src_sop 时刻初始化
            else if (srcp.src_sop) outcntr2upd = ((bitsof_srccnt)'(srcp.src_cnt) == (bitsof_srccnt)'(1)) ? '0 : (bitsof_srcidx)'(1);
            else if (srcp.src_eop) outcntr2upd = '0;
            else                   outcntr2upd = ((bitsof_srccnt)'(srcp.src_cnt) != '0 && outcntr_inc >= (bitsof_srccnt)'(srcp.src_cnt)) ? (bitsof_srcidx)'((bitsof_srccnt)'(srcp.src_cnt) - (bitsof_srccnt)'(1)) : (bitsof_srcidx)'(outcntr_inc);
         end
         else if (srcp.src_sop) outcntr2upd = '0;
         else                   outcntr2upd = out_cntr;
      end else           outcntr2upd = out_cntr;   // \attention #src_valid 为0时不能直接置 #outcntr2upd 为0，这会在数据序列未输出完毕时， #src_valid 变低导致输出序列被重新输出
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
      if (crp.aclr) out_cntr <= '0;
      else          out_cntr <= outcntr2upd;
   end
   assign srcp.src_idx = srcp.src_sop ? '0 : out_cntr;
   assign srcp.src_nxtidx = outcntr2upd;
   wire[bitsof_srccnt-1:0] src_lastidx = (bitsof_srccnt)'(srcp.src_cnt) - (bitsof_srccnt)'(1);
   assign srcp.src_eop = (srcp.src_valid == 1'b1 && (bitsof_srccnt)'(out_cntr) == src_lastidx && (srcp.src_sop == 1'b0 || srcp.src_cnt <= (bitsof_srccnt)'(1))) ? 1'b1 : 1'b0;
endmodule
/*!
 * \brief Avalon接口直通模块
 * \details 本模块实现Avalon接口输入输出直通功能
 */
module avalon_directsrc #(
   parameter avalon_pkg::ifCfg IC          = avalon_pkg::deft_ifCfg,
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0                    ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if.procp procp,                          ///< 本级节点Avalon接口的数据处理用交互信号端口列表
   input  wire     blksink,                        ///< 用户定义的输入阻塞标志，当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                                   ///< \attention
                                                   ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                                   ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire     blkprcsr,                       ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                                   ///< \attention
                                                   ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                                   ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   avalon_if.srcp  srcp                            ///< 本级节点Avalon接口的输出端服务器访问端口列表
);
   localparam bit bufSrc = avalon_pkg::bufSrc_of_ifCfg(IC);
   initial begin
      if (bufSrc) $error("avalon_directsrc : IC.bufSrc(%0b) should only be 0 for this module!", bufSrc);
      if ($bits(procp.src_cnt) != $bits(procp.sink_cnt))
         $error("avalon_directsrc: The bitwidth of procp.src_cnt(%0d) and procp.sink_cnt(%0d) does not match, this may cause bit-losing!", $bits(procp.src_cnt), $bits(procp.sink_cnt));
      if ($bits(procp.src_idx) != $bits(procp.sink_idx))
         $error("avalon_directsrc: The bitwidth of procp.src_idx(%0d) and procp.sink_idx(%0d) does not match, this may cause bit-losing!", $bits(procp.src_idx), $bits(procp.sink_idx));
      if ($bits(procp.src_nxtidx) != $bits(procp.sink_nxtidx))
         $error("avalon_directsrc: The bitwidth of procp.src_nxtidx(%0d) and procp.sink_nxtidx(%0d) does not match, this may cause bit-losing!", $bits(procp.src_nxtidx), $bits(procp.sink_nxtidx));
   end
   wire prcsrblk_2use, sinkblk_2use, sinkvalid2use;
   generate
   if (BLKPRCSR_EN) assign prcsrblk_2use = blkprcsr | procp.src_blk;
   else             assign prcsrblk_2use = procp.src_blk;
   if (BLKSINK_EN)assign sinkblk_2use = blksink | prcsrblk_2use;
   else           assign sinkblk_2use = prcsrblk_2use;
   if (BLKSINK_EN)assign sinkvalid2use = procp.sink_valid&(~blksink);
   else           assign sinkvalid2use = procp.sink_valid;
   endgenerate
   assign procp.prcsr_blk  = prcsrblk_2use;
   assign procp.sink_blk   = sinkblk_2use;
   assign procp.src_cnt    = procp.sink_cnt;
   assign procp.src_valid  = sinkvalid2use;
   assign procp.src_sop    = procp.sink_sop;
   assign procp.src_bufsel = '0;
   assign srcp.src_idx     = procp.sink_idx;
   assign srcp.src_nxtidx  = procp.sink_nxtidx;
   assign srcp.src_eop     = procp.sink_eop;
endmodule
/*! \brief Avalon接口输出端完结链接 */
module avalon_endsrc(
   avalon_if.nextp nextp,
   input wire      src_blk
);
   assign nextp.src_blk = src_blk;
endmodule
/*! \brief Avalon接口输入端序列异常检测 */
module avalon_errchk_sink #(
   parameter avalon_pkg::ifCfg IC                   = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter bit               KEEP2SCLR_CNTUSSOP   = 1'b0,      ///< 连续SOP的异常状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_BADSOP     = 1'b0,      ///< 非法SOP的异常状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_NOVLDSOP   = 1'b0,      ///< 无序列有效标志的SOP异常状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_NOVLDEOP   = 1'b0,      ///< 无序列有效标志的EOP异常状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_UNCNTUSIDX = 1'b0,      ///< 不连续输入索引的异常状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_NOVLDIDXCH = 1'b0,      ///< 无序列有效标志的索引值变动状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_VLDNOSOP   = 1'b0       ///< 无序列起始标志标记过的VLD置位异常状态置位后是否保持直到同步复位
) (
   avalon_if.crp  crp,
   avalon_if.auxp auxp,                            ///< 待检测 Avalon 接口的辅助信号传递用交互端口
   output logic   continuous_sop,                  ///< 检测到连续的 #sop 标志
   output logic   bad_sop,                         ///< 检测到非法的 #sop 标志：序列输入过程中收到 #eop 之前又收到的 #sop
   output logic   novld_sop,                       ///< 检测到没有 #vld 置位的 #sop 标志
   output logic   novld_eop,                       ///< 检测到没有 #vld 置位的 #eop 标志
   output logic   uncontinuous_idx,                ///< 检测到不连续的 #idx 
   output logic   novld_idxchg,                    ///< 检测到没有 #vld 置位的 #idx 值变动
   output logic   vldnosop                         ///< 检测到未经 #sop 标记起始的 #vld 置位
);
   seqs_errchk #(
      .IDXBW               (avalon_pkg::bitwOfSinkIdx_of_ifCfg(IC)),
      .KEEP2SCLR_CNTUSSOP  (KEEP2SCLR_CNTUSSOP                    ),
      .KEEP2SCLR_BADSOP    (KEEP2SCLR_BADSOP                      ),
      .KEEP2SCLR_NOVLDSOP  (KEEP2SCLR_NOVLDSOP                    ),
      .KEEP2SCLR_NOVLDEOP  (KEEP2SCLR_NOVLDEOP                    ),
      .KEEP2SCLR_UNCNTUSIDX(KEEP2SCLR_UNCNTUSIDX                  ),
      .KEEP2SCLR_NOVLDIDXCH(KEEP2SCLR_NOVLDIDXCH                  ),
      .KEEP2SCLR_VLDNOSOP  (KEEP2SCLR_VLDNOSOP                    )
   ) chksink(
      .clk              (crp.clk                   ),
      .aclr             (crp.aclr                  ),
      .sclr             (crp.sclr                  ),
      .clken            (crp.clken&(~auxp.sink_blk)),
      .vld              (auxp.sink_valid           ),
      .sop              (auxp.sink_sop             ),
      .eop              (auxp.sink_eop             ),
      .idx              (auxp.sink_idx             ),
      .continuous_sop   (continuous_sop            ),
      .bad_sop          (bad_sop                   ),
      .novld_sop        (novld_sop                 ),
      .novld_eop        (novld_eop                 ),
      .uncontinuous_idx (uncontinuous_idx          ),
      .novld_idxchg     (novld_idxchg              ),
      .vldnosop         (vldnosop                  )
   );
endmodule
/*! \brief Avalon接口输出端序列异常检测 */
module avalon_errchk_src #(
   parameter avalon_pkg::ifCfg IC                   = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter bit               KEEP2SCLR_CNTUSSOP   = 1'b0,      ///< 连续SOP的异常状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_BADSOP     = 1'b0,      ///< 非法SOP的异常状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_NOVLDSOP   = 1'b0,      ///< 无序列有效标志的SOP异常状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_NOVLDEOP   = 1'b0,      ///< 无序列有效标志的EOP异常状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_UNCNTUSIDX = 1'b0,      ///< 不连续输入索引的异常状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_NOVLDIDXCH = 1'b0,      ///< 无序列有效标志的索引值变动状态置位后是否保持直到同步复位
   parameter bit               KEEP2SCLR_VLDNOSOP   = 1'b0       ///< 无序列起始标志标记过的VLD置位异常状态置位后是否保持直到同步复位
) (
   avalon_if.crp  crp,
   avalon_if.auxp auxp,                            ///< 待检测 Avalon 接口的辅助信号传递用交互端口
   output logic   continuous_sop,                  ///< 检测到连续的 #sop 标志
   output logic   bad_sop,                         ///< 检测到非法的 #sop 标志：序列输入过程中收到 #eop 之前又收到的 #sop
   output logic   novld_sop,                       ///< 检测到没有 #vld 置位的 #sop 标志
   output logic   novld_eop,                       ///< 检测到没有 #vld 置位的 #eop 标志
   output logic   uncontinuous_idx,                ///< 检测到不连续的 #idx 
   output logic   novld_idxchg,                    ///< 检测到没有 #vld 置位的 #idx 值变动
   output logic   vldnosop                         ///< 检测到未经 #sop 标记起始的 #vld 置位
);
   seqs_errchk #(
      .IDXBW               (avalon_pkg::bitwOfSinkIdx_of_ifCfg(IC)),
      .KEEP2SCLR_CNTUSSOP  (KEEP2SCLR_CNTUSSOP                    ),
      .KEEP2SCLR_BADSOP    (KEEP2SCLR_BADSOP                      ),
      .KEEP2SCLR_NOVLDSOP  (KEEP2SCLR_NOVLDSOP                    ),
      .KEEP2SCLR_NOVLDEOP  (KEEP2SCLR_NOVLDEOP                    ),
      .KEEP2SCLR_UNCNTUSIDX(KEEP2SCLR_UNCNTUSIDX                  ),
      .KEEP2SCLR_NOVLDIDXCH(KEEP2SCLR_NOVLDIDXCH                  ),
      .KEEP2SCLR_VLDNOSOP  (KEEP2SCLR_VLDNOSOP                    )
   ) chksrc(
      .clk              (crp.clk                   ),
      .aclr             (crp.aclr                  ),
      .sclr             (crp.sclr                  ),
      .clken            (crp.clken&(~auxp.src_blk) ),
      .vld              (auxp.src_valid            ),
      .sop              (auxp.src_sop              ),
      .eop              (auxp.src_eop              ),
      .idx              (auxp.src_idx              ),
      .continuous_sop   (continuous_sop            ),
      .bad_sop          (bad_sop                   ),
      .novld_sop        (novld_sop                 ),
      .novld_eop        (novld_eop                 ),
      .uncontinuous_idx (uncontinuous_idx          ),
      .novld_idxchg     (novld_idxchg              ),
      .vldnosop         (vldnosop                  )
   );
endmodule
/*!
 * \brief 链接Avalon接口输入端至前一Avalon接口的输出端
 * \details 本模块可用于将两个Avalon接口连接成一个Avalon接口链
 * \attention 模块默认要求连接的两个Avalon接口信号位宽必须一致，若不满足则给出编译错误，以协助排查设计问题。当两个Avalon接口在设计时确实
 */
module avalon_link #(
   parameter avalon_pkg::ifCfg SINKP_IC = avalon_pkg::deft_ifCfg, ///< 输入端Avalon接口配置参数
   parameter bit BLKPREVSRC_EN          = 1'b0,                   ///< 引入用户定义的输出阻塞状态信号的标志（输入信号 #blksrc 使能标志），1-使能 #blksrc 信号， 0-禁用 #blksrc 信号
   parameter bit BITW_UNMATCH           = 0,                      ///< 指示连接的两个Avalon接口信号位宽不一致的标志，用于提示编译器被连接的两个Avalon接口信号位宽被显示设计为不一致
   parameter bit SHAREPREVIF            = 1'b0                    ///< 表示本级节点是与其他模块共享前级节点的标志，1'b0-本级节点独占前级节点，1'b1-本级节点与其他模块共享前级节点
                                                                  ///< \attention 对共享的前级节点，本级节点将不向前级节点反馈阻塞信号
) (
   avalon_if.nextp prevp,                          ///< 前一Avalon接口的输出端信号列表
   input wire      blkprevsrc,                     ///< 用户定义的输出阻塞状态信号
   avalon_if.sinkp sinkp                           ///< 本Avalon接口的输入端信号端口
);
   localparam int maxSink_onSinkp = avalon_pkg::maxSink_of_ifCfg(SINKP_IC);
   localparam int bitwof_sinkcnt  = avalon_pkg::bitwOfDataSeqLen(maxSink_onSinkp);
   localparam int bitwof_sinkidx  = avalon_pkg::bitwOfDataSeqIdx(maxSink_onSinkp);
   initial begin
      if (bitwof_sinkcnt != $bits(sinkp.sink_cnt))
         $error("avalon_link: the bitwidth of sinkcnt(%0d) with parameter SINKP_IC.maxSink(%0d) does not match the bitwidth of sinkp.sink_cnt(%0d)", bitwof_sinkcnt, maxSink_onSinkp, $bits(sinkp.sink_cnt));
      if (bitwof_sinkidx != $bits(sinkp.sink_idx))
         $error("avalon_link: the bitwidth of sinkidx(%0d) with parameter SINKP_IC.maxSink(%0d) does not match the bitwidth of sinkp.sink_idx(%0d)", bitwof_sinkidx, maxSink_onSinkp, $bits(sinkp.sink_idx));
      if (BITW_UNMATCH == 0 && $bits(sinkp.sink_cnt) < $bits(prevp.src_cnt))
         $error("avalon_link: The bitwidth of sinkp.sink_cnt(%0d) is not enough to hold all the bits of prevp.src_cnt(%0d), this may cause bit-losing!", $bits(sinkp.sink_cnt), $bits(prevp.src_cnt));
      if (BITW_UNMATCH == 0 && $bits(sinkp.sink_idx) < $bits(prevp.src_idx))
         $error("avalon_link: The bitwidth of sinkp.sink_idx(%0d) is not enough to hold all the bits of prevp.src_idx(%0d), this may cause bit-losing!", $bits(sinkp.sink_idx), $bits(prevp.src_idx));
   end
   // 输入上一接口的输出信号
   assign sinkp.sink_idx    = (bitwof_sinkidx)'(prevp.src_idx);
   assign sinkp.sink_nxtidx = (bitwof_sinkidx)'(prevp.src_nxtidx);
   assign sinkp.sink_cnt    = (bitwof_sinkcnt)'(prevp.src_cnt);
   assign sinkp.sink_sop    = prevp.src_sop;
   // \attention #prevp.src_sop 不能与 ~sinkp.sink_blk 相与后赋值 #sinkp.sink_sop 因为当时分复用信号不是最后一拍时， #sinkp.sink_blk 将置位，这会导致
   // #sinkp.sink_sop 无法置位，并造成时分复用后的 #src_sop 无法置位
   assign sinkp.sink_eop    = prevp.src_eop;
   assign sinkp.sink_valid  = prevp.src_valid;
   // 向上一接口输出信号
   wire blksrc2use;
   generate
   if (BLKPREVSRC_EN)assign blksrc2use = blkprevsrc;
   else              assign blksrc2use = 1'b0;
   if (~SHAREPREVIF) assign prevp.src_blk = sinkp.sink_blk | blksrc2use;
   endgenerate
endmodule
/*!
 * \brief Avalon接口输入端与前一级Avalon接口输出端的复选连接器
 * \details 本模块可用于将数个前级Avalon接口和数个本级Avalon接口连接成Avalon接口分叉树。
 * \attention
 * - 当 #BITW_UNMATCH 不为0时，所有Avalon接口的 #sink_idx 、 #sink_cnt 、 #src_idx 、 #src_cnt 信号位宽必须一致；
 * - 为了不至于干扰未连接本级Avalon接口的前级Avalon接口的工作：
 *   - 被选通的前级Avalon接口输出端信号列表 #nextp 中的输出向信号将仅连接至被选通的本级Avalon接口输入端信号列表 #sinkp 中的输入向信号；
 *   - 被选通的本级Avalon接口输入端信号列表 #sinkp 中的输出向信号将仅连接至被选通的前级Avalon接口输出端信号列表 #nextp 中的输入向信号。
 * - 对 #prevp_idx 和 #sinkp_idx ，当有多个选通信号为高电平时，在端口信号中比特位最低的信号被选中的优先级最高；
 * - 模块端口信号 #prevp_idx 说明的“信号输出时刻”指的是下图中 T0 时刻；
 * - 模块端口信号 #sinkp_cs 说明的“信号从前级Avalon接口多路复用选通输出时刻”指的是下图中 T1 时刻。
 *                      |->T0
 *  clk:             ^__^^__^^__^^__^^
 *  previfi:         ^^^|_____...
 *  previfi_muxout:  ^^^^^....^|_____...
 *                             |->T1
 *  sinkifi          ^^^^^^^^^^^^^^|_____...
 * - 因Avalon接口信号中的 #sink_valid 、 #src_valid 要参与 #sink_blk 、 #src_blk 信号的生成，为避免产生组合逻辑电路循环，这些信号不可
 * 直接或通过组合逻辑电路间接的用于 #prevp_idx 、 #sinkp_cs 接口信号的生成。
 */
module avalon_linkmux_prevpbycs #(
   parameter avalon_pkg::ifCfg      PREV_IC      = avalon_pkg::deft_ifCfg,///< 前级Avalon接口配置参数
   parameter avalon_pkg::ifCfg      SINK_IC      = avalon_pkg::deft_ifCfg,///< 本级Avalon接口配置参数
   parameter bit                    BITW_UNMATCH = 0,                     ///< 指示连接的两个Avalon接口信号位宽不一致的标志，用于提示编译器被连接的两个Avalon接口信号位宽被显示设计为不一致
   parameter bit                    MUXSINKP     = 1'b1,                  ///< 本级Avalon接口多选一选通模式，1'b1-本级Avalon接口多选一选通，1'b0-本级Avalon接口按选通信号选通
   parameter avalon_pkg::linkMuxCfg LMC          = avalon_pkg::make_linkMuxCfg(1, 0, 1, 0)
) (
   avalon_if                                                   previfi[avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC)-1:0], ///< 待选通的前级Avalon接口输出端信号列表数组
   input wire[avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC)-1:0]  prevp_cs,                                                ///< 前级Avalon接口输出端信号列表在“信号输出时刻”的索引信号
   input wire[avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC)-1:0]  blkprev4nocs,                                            ///< 前级Avalon接口在后级Avalon接口未选通时自动阻塞标志：
                                                                                                                        ///< 高电平(1)-当未选通后级Avalon接口时，本连接器在前级Avalon接口输出数据有效时自动置位前级Avalon接口的 #src_blk 信号，以实现自动阻塞功能
                                                                                                                        ///< 低电平(0)-当未选通后级Avalon接口时，本连接器不自动阻塞前级Avalon接口的输出数据，输出的数据将被丢弃
   avalon_if                                                   sinkifi[avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC)-1:0], ///< 待选通的本级Avalon接口输入端信号列表数组
   input wire[avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC)-1:0]  sinkp_cs,                                                ///< 本级Avalon接口输入端信号列表在“信号从前级Avalon接口多路复用选通输出时刻”的选通信号
                                                                                                                        ///< \attention 
                                                                                                                        ///< - 当有多个输入端信号列表被选通时，仅比特位索引最低的选通信号对应的信号列表被选中
                                                                                                                        ///< - 当 LMC.sinkPortBufSig == 1'b1 时，本信号同步于前级Avalon接口输出端信号的前一拍，否则本信号同步于Avalon接口输出端信号。
   avalon_linkmux_if.ifmuxp                                    muxp                                                     ///< 多路复用器控制信号接口端口
);
   localparam int maxSinkOnSinkIFI = avalon_pkg::maxSink_of_ifCfg(SINK_IC);
   localparam int maxSrcOnPrevIFI  = avalon_pkg::maxSrc_of_ifCfg(PREV_IC);
   localparam int sinkidxbitw = avalon_pkg::bitwOfDataSeqIdx(maxSinkOnSinkIFI);
   initial if (sinkidxbitw != $bits(sinkifi[0].sink_idx))
      $error("avalon_linkmux_prevpbycs: the bitwidth of sinkidx(%0d) on SINK_IC.maxSink(%0d) does not match the bitwidth of sinkifi[0].sink_idx(%0d)", sinkidxbitw, maxSinkOnSinkIFI, $bits(sinkifi[0].sink_idx));
   localparam int sinkcntbitw = avalon_pkg::bitwOfDataSeqLen(maxSinkOnSinkIFI);
   initial if (sinkcntbitw != $bits(sinkifi[0].sink_cnt))
      $error("avalon_linkmux_prevpbycs: the bitwidth of sinkcnt(%0d) on SINK_IC.maxSink(%0d) does not match the bitwidth of sinkifi[0].sink_cnt(%0d)", sinkcntbitw, maxSinkOnSinkIFI, $bits(sinkifi[0].sink_cnt));
   localparam int srcidxbitw  = avalon_pkg::bitwOfDataSeqIdx(maxSrcOnPrevIFI);
   initial if (srcidxbitw != $bits(previfi[0].src_idx))
      $error("avalon_linkmux_prevpbycs: the bitwidth of srcidx(%0d) on PREV_IC.maxSrc(%0d) does not match the bitwidth of previfi[0].src_idx(%0d)", srcidxbitw, maxSrcOnPrevIFI, $bits(previfi[0].src_idx));
   localparam int srccntbitw  = avalon_pkg::bitwOfDataSeqLen(maxSrcOnPrevIFI);
   initial if (srccntbitw != $bits(previfi[0].src_cnt))
      $error("avalon_linkmux_prevpbycs: the bitwidth of srccnt(%0d) on PREV_IC.maxSrc(%0d) does not match the bitwidth of previfi[0].src_cnt(%0d)", srccntbitw, maxSrcOnPrevIFI, $bits(previfi[0].src_cnt));
   localparam int idxbitw = sinkidxbitw > srcidxbitw ? sinkidxbitw : srcidxbitw;
   localparam int cntbitw = sinkcntbitw > srccntbitw ? sinkcntbitw : srccntbitw;
   typedef struct packed {
      logic             sop, eop, valid;
      logic[idxbitw-1:0]idx, nxtidx;
      logic[cntbitw-1:0]cnt;
   } sigs_t;
   localparam int bitwof_sigs_t = 3 + 2*idxbitw + cntbitw;
   localparam int prevport_cnt = avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC);
   localparam int prevpmuxtaps = avalon_pkg::prevPortMuxTaps_of_linkMuxCfg(LMC);
   localparam bit sinkport_bufsig = avalon_pkg::sinkPortBufSig_of_linkMuxCfg(LMC);
   initial if ((prevport_cnt > 1 || sinkport_bufsig == 1'b1) && prevpmuxtaps < 1)
      $error("avalon_linkmux_prevpbycs: LMC.prevPortMuxTaps(%0d) should not be zero while LMC.prevPortCnt(%0d) is greator than 1 or LMC.sinkPortBufSig(%0d) is 1.", prevpmuxtaps, prevport_cnt, sinkport_bufsig);
   localparam int prevp2mcstaps = prevpmuxtaps;// - (int'(sinkport_bufsig));
   localparam int sinkport_cnt = avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC);
   initial if ($bits(sigs_t) != bitwof_sigs_t)
      $fatal("avalon_linkmux_prevpbycs: local parameter bitwof_sigs_t(%0d) does not match the bitwidth of sigs_t(%0d)", bitwof_sigs_t, $bits(sigs_t));
   localparam int bitwof_prevportidx = mux_pkg::idxbitw_ofmux(prevport_cnt);
   localparam int prev_sigs_cnt = prevport_cnt > 1 ? prevport_cnt : 1;
   sigs_t prev_sigs[prev_sigs_cnt-1:0], sink_sigs[sinkport_cnt-1:0];
   logic src_blks[prevport_cnt-1:0];
   genvar i, j; generate
   for (i = 0; i < prevport_cnt; i++) begin: PREV_PORTS
      initial if (BITW_UNMATCH == 0 && $bits(previfi[i].src_idx) != idxbitw)
         $error("avalon_linkmux_prevpbycs: the bitwidth of port previfi[%0d].src_idx (%0d) does not match the other(sink_idx) port", $bits(previfi[i].src_idx), i);
      initial if (BITW_UNMATCH == 0 && $bits(previfi[i].src_cnt) != cntbitw)
         $error("avalon_linkmux_prevpbycs: the bitwidth of port previfi[%0d].src_cnt (%0d) does not match the other(sink_cnt) port", $bits(previfi[i].src_cnt), i);
      assign previfi[i].src_blk = src_blks[i];
      assign prev_sigs[i].sop      = previfi[i].src_sop;
      assign prev_sigs[i].eop      = previfi[i].src_eop;
      assign prev_sigs[i].valid    = previfi[i].src_valid;
      assign prev_sigs[i].idx      = (idxbitw)'(previfi[i].src_idx);
      assign prev_sigs[i].nxtidx   = (idxbitw)'(previfi[i].src_nxtidx);
      assign prev_sigs[i].cnt      = (cntbitw)'(previfi[i].src_cnt);
   end: PREV_PORTS
   for (i = 0; i < sinkport_cnt; i++) begin: SINK_PORTS
      initial if (BITW_UNMATCH == 0 && $bits(sinkifi[i].sink_idx) != idxbitw)
         $error("avalon_linkmux_prevpbycs: the bitwidth of port sinkifi[%0d].sink_idx (%0d) does not match the other(src_idx) ports", $bits(sinkifi[i].sink_idx), i);
      initial if (BITW_UNMATCH == 0 && $bits(sinkifi[i].sink_cnt) != cntbitw)
         $error("avalon_linkmux_prevpbycs: the bitwidth of port sinkifi[%0d].sink_cnt (%0d) does not match the other(src_cnt) ports", $bits(sinkifi[i].sink_cnt), i);
      assign sinkifi[i].sink_sop      = sink_sigs[i].sop;
      assign sinkifi[i].sink_eop      = sink_sigs[i].eop;
      assign sinkifi[i].sink_valid    = sink_sigs[i].valid;
      assign sinkifi[i].sink_idx      = (sinkidxbitw)'(sink_sigs[i].idx);
      assign sinkifi[i].sink_nxtidx   = (sinkidxbitw)'(sink_sigs[i].nxtidx);
      assign sinkifi[i].sink_cnt      = (sinkcntbitw)'(sink_sigs[i].cnt);
   end: SINK_PORTS
   initial if (prevport_cnt != $bits(muxp.prevp_cs))
      $error("avalon_linkmux_prevpbycs: parameter LMC.prevPortCnt(%0d) does not match the bitwidth of auxp.prevp_cs(%0d)", avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC), $size(muxp.prevp_cs, 1));
   initial if (sinkport_cnt != $bits(muxp.sinkp_cs))
      $error("avalon_linkmux_prevpbycs: parameter LMC.sinkPortCnt(%0d) does not match the bitwidth of muxp.sinkp_cs(%0d)", avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC), $size(muxp.sinkp_cs, 2));
   wire [sinkport_cnt-1:0] sinkblk_sinkports, sinkblk4prevports, blkby_nocs;
   wire                    combined_sinkblk_4prevports;
   logic[sinkport_cnt-1:0][prevpmuxtaps:0]sinkp_cs_pipe;
   logic                                  sinkp_selsig;
   always_comb begin
      sinkp_selsig = 1'b0;
      for (int ii = 0; ii < sinkport_cnt; ii++) begin
         sinkp_selsig = sinkp_selsig|sinkp_cs_pipe[ii][prevpmuxtaps];
      end
   end
   for (i = 0; i < sinkport_cnt; i++) begin: SINK_SIGS
      // \attention 每个输入端分配一个多路复用器的原因，是为了适应输入端使用不同的时钟信号的情况
      sigs_t prevsig_sel;
      logic muxblk2sink;
      assign muxp.blkbysinkp[i]    = sinkblk_sinkports[i],
             muxp.blkbynocs[i]     = blkby_nocs[i],
             muxp.sink_muxblk[i]   = muxblk2sink,
             muxp.prevpmuxclken[i] = sinkifi[i].clken&(~muxblk2sink)&(|sinkp_cs_pipe[i]);
      mux_bycs #(
         .UNITBITW   (bitwof_sigs_t ),
         .INPUTCNT   (prevport_cnt  ),
         .DELAYTAPS  (prevp2mcstaps )
      ) prevsig_muxer(
         .clk        (sinkifi[i].clk                        ),
         .aclr       (sinkifi[i].aclr                       ),
         .sclr       (sinkifi[i].sclr                       ),
         .clken      (muxp.prevpmuxclken[i]                 ),
         .data_in    (prev_sigs                             ),
         .data4nocs  ('0                                    ),
         .cs         (prevp_cs&{(prevport_cnt){sinkp_cs[i]}}),
         .data_out   (prevsig_sel                           )
      );
      assign muxp.sink_clk[i]   = sinkifi[i].clk;
      assign muxp.sink_aclr[i]  = sinkifi[i].aclr;
      assign muxp.sink_sclr[i]  = sinkifi[i].sclr;
      assign muxp.sink_clken[i] = sinkifi[i].clken;
      if      (i == 0)  assign sinkp_cs_pipe[i][0] = sinkp_cs[i];
      else if (MUXSINKP)assign sinkp_cs_pipe[i][0] = sinkp_cs[i] & (~(|sinkp_cs[i-1:0])); // \attention 不要从前级的 #sinkp_cs 级联产生 ~(|sinkp_cs[i-1:0]) ，因为这会导致组合逻辑电路路径过长，影响时序性能
      else              assign sinkp_cs_pipe[i][0] = sinkp_cs[i];
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(sinkifi[i].clk, sinkifi[i].aclr)) begin
         if     (sinkifi[i].aclr)sinkp_cs_pipe[i][prevpmuxtaps:1] <= {(prevpmuxtaps){1'b0}};
         else if(sinkifi[i].sclr)sinkp_cs_pipe[i][prevpmuxtaps:1] <= {(prevpmuxtaps){1'b0}};
         else                    sinkp_cs_pipe[i][prevpmuxtaps:1] <= sinkifi[i].clken
                                                                        ? sinkp_cs_pipe[i][prevpmuxtaps-1:0]
                                                                        : sinkp_cs_pipe[i][prevpmuxtaps:1];
      end
      assign muxp.sinkp_cs[i] = sinkp_cs_pipe[i][prevp2mcstaps];
      // 后面的 avalon_auxsig_syncwith_linkmux 要求 muxp.sinkp_cs 同步于 sinksigs4connect 
      sigs_t sinksigs4connect;
      assign sinksigs4connect = prevsig_sel;
      // MUXSINKP == 1'b1 时：
      // - sinkp 未被选通时 prevp 默认是被阻塞状态；
      // - 当有 sinkp 被选通且被选通的 sinkp 未输出阻塞状态时， prevp 的阻塞状态才被取消。
      // 要求：
      // - sinkp 未被选通时， #sinkblk4prevports[i] 输出阻塞状态；
      // - sinkp 被选通时，当 #sink_blk 和 #sink_valid 均置位时， #sinkblk4prevports[i] 输出阻塞状态，否则输出导通状
      // 态以允许前级节点输入数据。
      // MUXSINKP == 1'b0 时：
      // - sinkp 未被选通时 prevp 默认是被阻塞状态；
      // - 有 sinkp 被选通时，仅当所有被选通的 sinkp 都未输出阻塞状态时， prevp 的阻塞状态才被取消，
      // 当有一个或以上被选通的 sinkp 输出阻塞状态，则 prevp 的阻塞状态被置位，且 prevp 送给 sinkp 的 valid 信号被清零。
      // 要求：
      // - sinkp 未被选通时， #sinkblk4prevports[i] 不输出阻塞状态（因为所有 sinkp 未被选通时， prevp 的阻塞状态才置位）；
      // - sinkp 被选通时， #sinkblk4prevports[i] 输出 sinkp 的阻塞状态，以供 prevp 选择
      if(MUXSINKP)assign blkby_nocs[i]        = ((~sinkp_cs_pipe[i][prevp2mcstaps])&sinksigs4connect.valid),
                         sinkblk_sinkports[i] = sinkifi[i].sink_blk|blkby_nocs[i];//(sinkifi[i].sink_blk&sinkifi[i].sink_valid&muxp.sinkp_cs[i])|blkby_nocs[i];
      else        assign blkby_nocs[i]        = ((~sinkp_selsig)&sinksigs4connect.valid),
                         sinkblk_sinkports[i] = sinkifi[i].sink_blk|blkby_nocs[i];//(sinkifi[i].sink_blk&sinkifi[i].sink_valid&muxp.sinkp_cs[i])|blkby_nocs[i];
      assign sinkblk4prevports[i] = (~sinkp_selsig)|(muxblk2sink&sinkp_cs_pipe[i][prevpmuxtaps]);
      if (sinkport_bufsig) begin
         genr_bufselblk4bufsrc #(
            .FLOWCNT(1)
         ) sink_bufsel_genr(
            .clk     (sinkifi[i].clk         ),
            .aclr    (sinkifi[i].aclr        ),
            .sclr    (sinkifi[i].sclr        ),
            .clken   (sinkifi[i].clken       ),
            .srcblk  (sinkblk_sinkports[i]   ),
            .vld2src (sinksigs4connect.valid ),
            .bufsel  (muxp.sink_bufsel[i]    ),
            .blkprcsr(muxblk2sink            )
         );
         bufsrc4blk #(
            .SIGBITW (bitwof_sigs_t                         ),
            .MSK4UBLK({3'b111, {(idxbitw*2+cntbitw){1'b0}}} ),
            .VAL4UBLK({(idxbitw*2+cntbitw+3){1'b0}}         )
         ) sinksigs_bufsrc(
            .clk     (sinkifi[i].clk               ),
            .aclr    (sinkifi[i].aclr              ),
            .sclr    (sinkifi[i].sclr              ),
            .clken   (sinkifi[i].clken             ),
            .outsel  (muxp.sinkp_cs[i]             ),
            .sig4nos ({(idxbitw*2+cntbitw+3){1'b0}}),
            .srcblk  (sinkblk_sinkports[i]         ),
            .pblk4src(muxblk2sink                  ),
            .blkbyusr(blkby_nocs[i]                ),
            .bufsel  (muxp.sink_bufsel[i]          ),
            .sig2src (sinksigs4connect             ),
            .sigsrced(sink_sigs[i]                 )
         );
         // \attention #sink_sigs[i] 不必响应 #sinkifi[i].sink_blk 的阻塞状态，因为 #sink_sigs[i] 必须按
         // 时序逻辑转移 #prevsig_sel 的各种状态到 #sinkifi[i] ，而 #sinkifi[i] 对应的输入端是否接收输入数据取
         // 决于 #sinkifi[i] 对应的处理器的阻塞状态；当 #sinkifi[i].sink_blk 置位时，表示 #sinkifi[i] 对应的
         // 处理器已读入一个时钟节拍的数据，后续 #sinkifi[i].sink_blk 置位情况下的数据则须由数据缓冲区维持以供处理
         // 器使用。
      end else begin
         assign muxp.sink_bufsel[i] = '0;
         assign muxblk2sink         = sinkblk_sinkports[i];
         assign sink_sigs[i]        = sinksigs4connect;
      end
   end
   assign combined_sinkblk_4prevports = (|sinkblk4prevports);
   assign muxp.prevp_cs = prevp_cs;
   for (i = 0; i < prevport_cnt; i++) begin: PREV_SIGS
      wire autoblk_onprevp = prev_sigs[i].valid & blkprev4nocs[i];
      wire this_prevport_sel = muxp.prevp_cs[i];//(muxp.prevp_idx == (bitwof_prevportidx)'(i)) ? 1'b1 : 1'b0;
      logic sinkp_selsig_onsrcblk;
      if (sinkport_bufsig) always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(previfi[i].clk, previfi[i].aclr)) begin
         if     (previfi[i].aclr)sinkp_selsig_onsrcblk <= 1'b0;
         else if(previfi[i].sclr)sinkp_selsig_onsrcblk <= 1'b0;
         else                    sinkp_selsig_onsrcblk <= previfi[i].clken ? sinkp_selsig : sinkp_selsig_onsrcblk;
      end
      else assign sinkp_selsig_onsrcblk = sinkp_selsig;
      assign src_blks[i] = (this_prevport_sel&sinkp_selsig_onsrcblk) ? combined_sinkblk_4prevports : autoblk_onprevp;
   end
   endgenerate
endmodule
module avalon_linkmux_prevpbyidx #(
   parameter avalon_pkg::ifCfg      PREV_IC       = avalon_pkg::deft_ifCfg,///< 前级Avalon接口配置参数
   parameter avalon_pkg::ifCfg      SINK_IC       = avalon_pkg::deft_ifCfg,///< 本级Avalon接口配置参数
   parameter bit                    BITW_UNMATCH  = 0,                     ///< 指示连接的两个Avalon接口信号位宽不一致的标志，用于提示编译器被连接的两个Avalon接口信号位宽被显示设计为不一致
   parameter bit                    MUXSINKP      = 1'b1,                  ///< 本级Avalon接口多选一选通模式，1'b1-本级Avalon接口多选一选通，1'b0-本级Avalon接口按选通信号选通
   parameter bit                    PREVPIDXPRSET = 1'b0,
   parameter avalon_pkg::linkMuxCfg LMC           = avalon_pkg::make_linkMuxCfg(1, 0, 1, 0)
) (
   avalon_if.crp                                               crp4idx2cs,                ///< 用于选通信号转换选通索引的时钟及复位信号端口列表
   avalon_if                                                   previfi[avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC)-1:0], ///< 待选通的前级Avalon接口输出端信号列表数组
   input wire[mux_pkg::idxbitw_ofmux(avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC))-1:0]  prevp_idx,                  ///< 前级Avalon接口输出端信号列表在“信号输出时刻”( #PREVPORT_CS_PRESET_FLAG = 0)或前一时钟( #PREVPORT_CS_PRESET_FLAG = 1)的索引信号
   input wire[avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC)-1:0]  blkprev4nocs,              ///< 前级Avalon接口在后级Avalon接口未选通时自动阻塞标志：
                                                                                          ///< 高电平(1)-当未选通后级Avalon接口时，本连接器在前级Avalon接口输出数据有效时自动置位前级Avalon接口的 #src_blk 信号，以实现自动阻塞功能
                                                                                          ///< 低电平(0)-当未选通后级Avalon接口时，本连接器不自动阻塞前级Avalon接口的输出数据，输出的数据将被丢弃
   avalon_if                                                   sinkifi[avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC)-1:0], ///< 待选通的本级Avalon接口输入端信号列表数组
   input wire[avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC)-1:0]  sinkp_cs,                  ///< 本级Avalon接口输入端信号列表在“信号从前级Avalon接口多路复用选通输出时刻”的选通信号
                                                                                          ///< \attention 当有多个输入端信号列表被选通时，仅比特位索引最低的选通信号对应的信号列表被选中
   avalon_linkmux_if.ifmuxp                                    muxp                       ///< 多路复用器控制信号接口端口
);
   localparam int prevportCnt = avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC);
   wire [prevportCnt-1:0] csofidx;
   idx2selsig #(
      .SELSIG_CNT (prevportCnt   ),
      .DELAYTAPS  (PREVPIDXPRSET )
   ) idx2cs(
      .clk     (crp4idx2cs.clk   ),
      .aclr    (crp4idx2cs.aclr  ),
      .sclr    (crp4idx2cs.sclr  ),
      .clken   (crp4idx2cs.clken ),
      .idx     (prevp_idx        ),
      .cs      (csofidx          )
   );
   avalon_linkmux_prevpbycs #(
      .PREV_IC       (PREV_IC       ),
      .SINK_IC       (SINK_IC       ),
      .BITW_UNMATCH  (BITW_UNMATCH  ),
      .MUXSINKP      (MUXSINKP      ),
      .LMC           (LMC           )
   )almi(
      .previfi       (previfi       ),
      .prevp_cs      (csofidx       ),
      .blkprev4nocs  (blkprev4nocs  ),
      .sinkifi       (sinkifi       ),
      .sinkp_cs      (sinkp_cs      ),
      .muxp          (muxp          )
   );
endmodule
/*! \brief 将辅助信号与Avalon接口多路复用选择器的输入、输出端时序同步 */
module avalon_auxsig_syncwith_linkmux_nomux #(
   parameter int                    SIGBITW     = 1,  ///< 待同步信号位宽
   parameter int signed             IPRVP2SYNC  = -1, ///< 待同步的前级Avalon接口的索引， < 0 表示不依赖前级Avalon接口的选通信号同步
   parameter int                    ISNKP2SYNC  = 0,  ///< 待与之同步的本级Avalon接口的索引
   parameter avalon_pkg::linkMuxCfg LMC = avalon_pkg::make_linkMuxCfg(1, 0, 1, 0)
) (
   avalon_linkmux_if.auxmuxp  auxp,                ///< Avalon接口多路复用器控制信号输入端口
   input  wire[SIGBITW-1:0]   sig2link,            ///< 前级Avalon接口输出的信号
   input  wire[SIGBITW-1:0]   signocs,             ///< 没有输入端被选通时输出的辅助信号
   output wire[SIGBITW-1:0]   sig2out              ///< 向本级Avalon接口输入的信号
);
   initial if (ISNKP2SYNC < 0 || ISNKP2SYNC >= $bits(auxp.sink_clk))
      $error("avalon_auxsig_syncwith_linkmux_nomux: parameter ISNKP2SYNC(%0d) is illegal to specified auxp(should be greator or equal to 0 and less than %0d)", ISNKP2SYNC, $bits(auxp.sink_clk));
   localparam bit sinkport_bufsig = avalon_pkg::sinkPortBufSig_of_linkMuxCfg(LMC);
   localparam int prevp2mcstaps = avalon_pkg::prevPortMuxTaps_of_linkMuxCfg(LMC);// - (int'(sinkport_bufsig));
   wire[SIGBITW-1:0] sig2tap[0:0], sig_taped;
   wire              prevp_cs;
   wire              sink_clken_noblk = auxp.sink_clken[ISNKP2SYNC]&auxp.prevpmuxclken[ISNKP2SYNC];
   assign sig2tap[0] = sig2link;
   mux_bycs #(
      .UNITBITW   (SIGBITW       ),
      .INPUTCNT   (1             ),
      .DELAYTAPS  (prevp2mcstaps )
   ) sig2mux_muxer(
      .clk        (auxp.sink_clk [ISNKP2SYNC]),
      .aclr       (auxp.sink_aclr[ISNKP2SYNC]),
      .sclr       (auxp.sink_sclr[ISNKP2SYNC]),
      .clken      (sink_clken_noblk          ),
      .data_in    (sig2tap                   ),
      .data4nocs  (signocs                   ),
      .cs         (prevp_cs                  ),
      .data_out   (sig_taped                 )
   );
   generate if (sinkport_bufsig) begin
      bufsrc4blk #(
         .SIGBITW (SIGBITW          ),
         .MSK4UBLK({(SIGBITW){1'b0}}),
         .VAL4UBLK({(SIGBITW){1'b0}})
      ) bufsrci(
         .clk     (auxp.sink_clk[ISNKP2SYNC]    ),
         .aclr    (auxp.sink_aclr[ISNKP2SYNC]   ),
         .sclr    (auxp.sink_sclr[ISNKP2SYNC]   ),
         .clken   (auxp.sink_clken[ISNKP2SYNC]  ),
         .outsel  (auxp.sinkp_cs[ISNKP2SYNC]    ),
         .sig4nos (signocs                            ),
         .srcblk  (auxp.blkbysinkp[ISNKP2SYNC]  ),
         .pblk4src(auxp.sink_muxblk[ISNKP2SYNC] ),
         .blkbyusr(auxp.blkbynocs[ISNKP2SYNC]   ),
         .bufsel  (auxp.sink_bufsel[ISNKP2SYNC] ),
         .sig2src (sig_taped                          ),
         .sigsrced(sig2out                            )
      );
   end
   else assign sig2out = sig_taped;
   if (IPRVP2SYNC < 0) assign prevp_cs = 1'b1;
   else                assign prevp_cs = auxp.prevp_cs[IPRVP2SYNC];
   endgenerate
endmodule
/*! \brief 将辅助信号在Avalon接口多路复用器上同步 */
module avalon_auxsig_syncwith_linkmux #(
   parameter int                    SIGBITW = 1,///< 待同步信号位宽
   parameter avalon_pkg::linkMuxCfg LMC     = avalon_pkg::make_linkMuxCfg(1, 0, 1, 0),
   parameter bit[avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC)-1:0]SINKPORTINSTMASK={(avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC)){1'b1}}
                                                ///< 本级输入端辅助信号数组例化掩码，从低至高对应 #sigsink 信号数组的各元素，
                                                ///< 1'b1-例化输出比特位对应的数组元素，1'b0-不例化输出比特位对应的数组元素
) (
   avalon_linkmux_if.auxmuxp  auxp,                                                    ///< Avalon接口多路复用器控制信号输入端口
   input  wire [SIGBITW-1:0]  sig2mux[avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC)-1:0], ///< 待选通同步的输入端辅助信号数组
   input  wire [SIGBITW-1:0]  signocs,                                                 ///< 没有输入端被选通时输出的辅助信号
   output wire [SIGBITW-1:0]  sigsink[avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC)-1:0]  ///< 待选通同步的输出端辅助信号数组
);
   localparam int prevportCnt = avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC);
   localparam int sinkportCnt = avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC);
   initial if (prevportCnt > $bits(auxp.prevp_cs))
      $error("avalon_auxsig_syncwith_linkmux: parameter LMC.prevPortCnt(%0d) does not match the bitwidth of auxp.prevp_cs(%0d)", avalon_pkg::prevPortCnt_of_linkMuxCfg(LMC), $bits(auxp.prevp_cs));
   initial if (sinkportCnt != $bits(auxp.sinkp_cs))
      $error("avalon_auxsig_syncwith_linkmux: parameter LMC.sinkPortCnt(%0d) does not match the bitwidth of auxp.sinkp_cs(%0d)", avalon_pkg::sinkPortCnt_of_linkMuxCfg(LMC), $bits(auxp.sinkp_cs));
   localparam bit sinkport_bufsig = avalon_pkg::sinkPortBufSig_of_linkMuxCfg(LMC);
   localparam int prevp2mcstaps = avalon_pkg::prevPortMuxTaps_of_linkMuxCfg(LMC);// - (int'(avalon_pkg::sinkPortBufSig_of_linkMuxCfg(LMC)));
   genvar i; generate for (i = 0; i < sinkportCnt; i++) begin: SINKSIG_BUF
      if (SINKPORTINSTMASK[i]) begin
         logic[SIGBITW-1:0]sig2mux_sel;
         wire              sink_clken_noblk = auxp.sink_clken[i]&auxp.prevpmuxclken[i];
         mux_bycs #(
            .UNITBITW   (SIGBITW       ),
            .INPUTCNT   (prevportCnt   ),
            .DELAYTAPS  (prevp2mcstaps )
         ) sig2mux_muxer(
            .clk        (auxp.sink_clk[i] ),
            .aclr       (auxp.sink_aclr[i]),
            .sclr       (auxp.sink_sclr[i]),
            .clken      (sink_clken_noblk ),
            .data_in    (sig2mux          ),
            .data4nocs  (signocs          ),
            .cs         (auxp.prevp_cs    ),
            .data_out   (sig2mux_sel      )
         );
         if (sinkport_bufsig) begin
            bufsrc4blk #(
               .SIGBITW (SIGBITW          ),
               .MSK4UBLK({(SIGBITW){1'b0}}),
               .VAL4UBLK({(SIGBITW){1'b0}})
            ) bufsrci(
               .clk     (auxp.sink_clk[i]    ),
               .aclr    (auxp.sink_aclr[i]   ),
               .sclr    (auxp.sink_sclr[i]   ),
               .clken   (auxp.sink_clken[i]  ),
               .outsel  (auxp.sinkp_cs[i]    ),
               .sig4nos (signocs             ),
               .srcblk  (auxp.blkbysinkp[i]  ),
               .pblk4src(auxp.sink_muxblk[i] ),
               .blkbyusr(auxp.blkbynocs[i]   ),
               .bufsel  (auxp.sink_bufsel[i] ),
               .sig2src (sig2mux_sel         ),
               .sigsrced(sigsink[i]          )
            );
         end else assign sigsink[i] = auxp.sinkp_cs[i] ? sig2mux_sel : signocs;
      end else assign sigsink[i] = signocs;
   end endgenerate
endmodule
/*!
 * \brief Avalon接口镜像制作器
 * \details 本模块可用于将Avalon接口数组的单个元素制作为某个单独Avalon接口的镜像，以匹配 #avalon_linkmux_prevpbyidx 、 #avalon_linkmux_prevpbycs
 * 和 #avalon_mirrormux_sinkbyidx 、 #avalon_mirrormux_sinkbycs 的参数需求
 */
module avalon_mirror_make #(
   parameter avalon_pkg::ifCfg LOC_IC       = avalon_pkg::deft_ifCfg,///< 被镜像的源Avalon接口配置参数
   parameter avalon_pkg::ifCfg MIR_IC       = avalon_pkg::deft_ifCfg,///< 镜像Avalon接口配置参数
   parameter bit               BITW_UNMATCH = 1'b0,                  ///< 指示镜像Avalon接口信号位宽不一致的标志，用于提示编译器被连接的两个Avalon接口信号位宽被显式设计为不一致
   parameter bit               MSINKP       = 1'b0,                  ///< 指示镜像Avalon接口信号将用于产生输入端接口信号的标志
   parameter bit               MPROCP       = 1'b0,                  ///< 指示镜像Avalon接口信号将用于产生处理器接口信号的标志
   parameter bit               MSRCP        = 1'b0,                  ///< 指示镜像Avalon接口信号将用于产生输出端接口信号的标志
   parameter bit               MNEXTP       = 1'b0                   ///< 指示镜像Avalon接口信号将用于连接下一节点Avalon接口信号的标志
) (
   avalon_if   ifi,                                ///< 将被镜像的源Avalon接口实例
   avalon_if   ifim                                ///< 将制作成镜像的Avalon接口实例
);
   initial if (BITW_UNMATCH == 0 && $bits(ifi.sink_idx) != $bits(ifim.sink_idx))
      $error("avalon_mirror_make: bitwidth of ifi.sink_idx(%0d) and ifim.sink_idx(%0d) does not match!", $bits(ifi.sink_idx) ,$bits(ifim.sink_idx));
   initial if (BITW_UNMATCH == 0 && $bits(ifi.sink_nxtidx) != $bits(ifim.sink_nxtidx))
      $error("avalon_mirror_make: bitwidth of ifi.sink_nxtidx(%0d) and ifim.sink_nxtidx(%0d) does not match!", $bits(ifi.sink_nxtidx) ,$bits(ifim.sink_nxtidx));
   initial if (BITW_UNMATCH == 0 && $bits(ifi.sink_cnt) != $bits(ifim.sink_cnt))
      $error("avalon_mirror_make: bitwidth of ifi.sink_cnt(%0d) and ifim.sink_cnt(%0d) does not match!", $bits(ifi.sink_cnt) ,$bits(ifim.sink_cnt));
   initial if (BITW_UNMATCH == 0 && $bits(ifi.src_idx) != $bits(ifim.src_idx))
      $error("avalon_mirror_make: bitwidth of ifi.src_idx(%0d) and ifim.src_idx(%0d) does not match!", $bits(ifi.src_idx) ,$bits(ifim.src_idx));
   initial if (BITW_UNMATCH == 0 && $bits(ifi.src_nxtidx) != $bits(ifim.src_nxtidx))
      $error("avalon_mirror_make: bitwidth of ifi.src_nxtidx(%0d) and ifim.src_nxtidx(%0d) does not match!", $bits(ifi.src_nxtidx) ,$bits(ifim.src_nxtidx));
   initial if (BITW_UNMATCH == 0 && $bits(ifi.src_cnt) != $bits(ifim.src_cnt))
      $error("avalon_mirror_make: bitwidth of ifi.src_cnt(%0d) and ifim.src_cnt(%0d) does not match!", $bits(ifi.src_cnt) ,$bits(ifim.src_cnt));
   localparam int locMaxSink = avalon_pkg::maxSink_of_ifCfg(LOC_IC);
   localparam int locsinkidxbitw = avalon_pkg::bitwOfDataSeqIdx(locMaxSink);
   initial if (locsinkidxbitw != $bits(ifi.sink_idx))
      $error("avalon_mirror_make: the bitwidth of sinkidx(%0d) on LOC_IC.maxSink(%0d) does not match the bitwidth of ifi.sink_idx(%0d)", locsinkidxbitw, locMaxSink, $bits(ifi.sink_idx));
   localparam int locsinkcntbitw = avalon_pkg::bitwOfDataSeqLen(locMaxSink);
   initial if (locsinkcntbitw != $bits(ifi.sink_cnt))
      $error("avalon_mirror_make: the bitwidth of sinkcnt(%0d) on LOC_IC.maxSink(%0d) does not match the bitwidth of ifi.sink_cnt(%0d)", locsinkcntbitw, locMaxSink, $bits(ifi.sink_cnt));
   localparam int locMaxSrc = avalon_pkg::maxSrc_of_ifCfg(LOC_IC);
   localparam int locsrcidxbitw  = avalon_pkg::bitwOfDataSeqIdx(locMaxSrc);
   initial if (locsrcidxbitw != $bits(ifi.src_idx))
      $error("avalon_mirror_make: the bitwidth of srcidx(%0d) on LOC_IC.maxSrc(%0d) does not match the bitwidth of ifi.src_idx(%0d)", locsrcidxbitw, locMaxSrc, $bits(ifi.src_idx));
   localparam int locsrccntbitw  = avalon_pkg::bitwOfDataSeqLen(locMaxSrc);
   initial if (locsrccntbitw != $bits(ifi.src_cnt))
      $error("avalon_mirror_make: the bitwidth of srccnt(%0d) on LOC_IC.maxSrc(%0d) does not match the bitwidth of ifi.src_cnt(%0d)", locsrccntbitw, locMaxSrc, $bits(ifi.src_cnt));
   localparam int mirMaxSink = avalon_pkg::maxSink_of_ifCfg(MIR_IC);
   localparam int mirsinkidxbitw = avalon_pkg::bitwOfDataSeqIdx(mirMaxSink);
   initial if (mirsinkidxbitw != $bits(ifim.sink_idx))
         $error("avalon_mirror_make: the bitwidth of sinkidx(%0d) on MIR_IC.maxSink(%0d) does not match the bitwidth of ifim.sink_idx(%0d)", mirsinkidxbitw, mirMaxSink, $bits(ifim.sink_idx));
   localparam int mirsinkcntbitw = avalon_pkg::bitwOfDataSeqLen(mirMaxSink);
   initial if (mirsinkcntbitw != $bits(ifim.sink_cnt))
      $error("avalon_mirror_make: the bitwidth of sinkcnt(%0d) on MIR_IC.maxSink(%0d) does not match the bitwidth of ifi.sink_cnt(%0d)", mirsinkcntbitw, mirMaxSink, $bits(ifim.sink_cnt));
   localparam int mirMaxSrc = avalon_pkg::maxSrc_of_ifCfg(MIR_IC);
   localparam int mirsrcidxbitw  = avalon_pkg::bitwOfDataSeqIdx(mirMaxSrc);
   initial if (mirsrcidxbitw != $bits(ifim.src_idx))
      $error("avalon_mirror_make: the bitwidth of srcidx(%0d) on MIR_IC.maxSrc(%0d) does not match the bitwidth of ifi.src_idx(%0d)", mirsrcidxbitw, mirMaxSrc, $bits(ifim.src_idx));
   localparam int mirsrccntbitw  = avalon_pkg::bitwOfDataSeqLen(mirMaxSrc);
   initial if (mirsrccntbitw != $bits(ifim.src_cnt))
      $error("avalon_mirror_make: the bitwidth of srccnt(%0d) on MIR_IC.maxSrc(%0d) does not match the bitwidth of ifi.src_cnt(%0d)", mirsrccntbitw, mirMaxSrc, $bits(ifim.src_cnt));
   generate if(MSINKP) begin
      assign ifi.sink_idx    = (locsinkidxbitw)'(ifim.sink_idx);
      assign ifi.sink_nxtidx = (locsinkidxbitw)'(ifim.sink_nxtidx);
      assign ifi.sink_cnt    = (locsinkcntbitw)'(ifim.sink_cnt);
      assign ifi.sink_sop    = ifim.sink_sop;
      assign ifi.sink_eop    = ifim.sink_eop;
      assign ifi.sink_valid  = ifim.sink_valid;
   end else begin
      assign ifim.sink_idx    = (mirsinkidxbitw)'(ifi.sink_idx);
      assign ifim.sink_nxtidx = (mirsinkidxbitw)'(ifi.sink_nxtidx);
      assign ifim.sink_cnt    = (mirsinkcntbitw)'(ifi.sink_cnt);
      assign ifim.sink_sop    = ifi.sink_sop;
      assign ifim.sink_eop    = ifi.sink_eop;
      assign ifim.sink_valid  = ifi.sink_valid;
   end
   if (MPROCP) begin
      assign ifi.sink_blk   = ifim.sink_blk;
      assign ifi.prcsr_blk  = ifim.prcsr_blk;
      assign ifi.src_cnt    = (locsrccntbitw)'(ifim.src_cnt);
      assign ifi.src_sop    = ifim.src_sop;
      assign ifi.src_valid  = ifim.src_valid;
      assign ifi.src_bufsel = ifim.src_bufsel;
   end else begin
      assign ifim.sink_blk   = ifi.sink_blk;
      assign ifim.prcsr_blk  = ifi.prcsr_blk;
      assign ifim.src_cnt    = (mirsrccntbitw)'(ifi.src_cnt);
      assign ifim.src_sop    = ifi.src_sop;
      assign ifim.src_valid  = ifi.src_valid;
      assign ifim.src_bufsel = ifi.src_bufsel;
   end
   if (MSRCP) begin
      assign ifi.src_idx    = (locsrcidxbitw)'(ifim.src_idx);
      assign ifi.src_nxtidx = (locsrcidxbitw)'(ifim.src_nxtidx);
      assign ifi.src_eop    = ifim.src_eop;
   end else begin
      assign ifim.src_idx    = (mirsrcidxbitw)'(ifi.src_idx);
      assign ifim.src_nxtidx = (mirsrcidxbitw)'(ifi.src_nxtidx);
      assign ifim.src_eop    = ifi.src_eop;
   end
   if (MNEXTP) assign ifi.src_blk = ifim.src_blk;
   else        assign ifim.src_blk = ifi.src_blk;
   endgenerate
endmodule
/*! \brief 将辅助信号与Avalon镜像连接复用选择器的输入端复用选择时序同步 */
module avalon_auxsig_syncwith_syncsigofmirrormux_sinknomux #(
   parameter int                      SINK_SIGBITW = 1,     ///< 待同步输入端信号位宽
   parameter avalon_pkg::mirrorMuxCfg MMC          = avalon_pkg::make_mirrorMuxCfg(2,2,0)
) (
   input  bit                    clk,              ///< 驱动时钟
   input  wire                   aclr,             ///< 异步复位信号，高电平(1)有效
   input  wire                   sclr,             ///< 同步复位信号，高电平(1)有效
   input  wire                   clken,
   input  wire                   isinkblk,         ///< 被镜像Avalon接口实力输入端阻塞请求信号，高电平(1)有效
   input  wire                   sinkmuxidle,      ///< 被镜像Avalon接口实例输入端信号缓冲区保持信号，1'b1-信号缓冲区状态保持，1'b0-信号缓冲区按时序更新
   input  wire                   sink_bufsel,      ///< 被镜像Avalon接口实例输入端信号缓冲区选择信号，1'b1-选择缓冲区信号输出，1'b0-选择直连信号输出
   input  wire                   msink_cs,         ///< 本地Avalon接口选通信号，高电平(1)有效
   input  wire[SINK_SIGBITW-1:0] msinksig,         ///< Avalon镜像接口处理器向本地Avalon接口处理器输入的信号数组
   output wire[SINK_SIGBITW-1:0] sig2sink          ///< 本地Avalon接口处理器实际输入的信号数组
);
   wire [SINK_SIGBITW-1:0] msinksig2mux[0:0], msinksig_muxsel;
   localparam int m2isinkMuxTaps = avalon_pkg::m2isinkMuxTaps_of_mirrorMuxCfg(MMC);
   localparam bit ixm_delayout   = avalon_pkg::ixmDelayOut_of_mirrorMuxCfg(MMC);
   localparam int m2isinkmuxtap  = m2isinkMuxTaps;// - (int'(ixm_delayout));
   assign msinksig2mux[0] = msinksig;
   mux_bycs #(
      .UNITBITW(SINK_SIGBITW           ),
      .INPUTCNT(1                      ),
      .INITNOCS({(SINK_SIGBITW){1'b0}} ),
      .DELAYTAPS(m2isinkMuxTaps        ),
      .BALNCDLY(1'b0                   )
   ) auxsig_mux(
      .clk     (clk                    ),
      .aclr    (aclr                   ),
      .sclr    (sclr                   ),
      .clken   (clken&(~sinkmuxidle)   ),
      .data_in (msinksig2mux           ),
      .data4nocs({(SINK_SIGBITW){1'b0}}),
      .cs      (msink_cs               ),
      .data_out(msinksig_muxsel        )
   );
   generate if (ixm_delayout) begin
      bufsrc4blk #(
         .SIGBITW (SINK_SIGBITW           ),
         .MSK4UBLK({(SINK_SIGBITW){1'b0}} ),
         .VAL4UBLK({(SINK_SIGBITW){1'b0}} )
      ) auxsig_bufsrc(
         .clk     (clk                    ),
         .aclr    (aclr                   ),
         .sclr    (sclr                   ),
         .clken   (clken                  ),
         .outsel  (1'b1                   ),
         .sig4nos ({(SINK_SIGBITW){1'b0}} ),
         .srcblk  (isinkblk               ),
         .pblk4src(sinkmuxidle            ),
         .blkbyusr(1'b0                   ),
         .bufsel  (sink_bufsel            ),
         .sig2src (msinksig_muxsel        ),
         .sigsrced(sig2sink               )
      );
   end else assign sig2sink = msinksig_muxsel;
   endgenerate
endmodule
/*!
 * \brief Avalon接口镜像连接选择器
 * \details 本模块可用于将一个Avalon接口实例与数个Avalon镜像接口数组之间做选通连接
 * \attention
 * - 当 #BITW_UNMATCH 不为0时，所有Avalon接口的 #sink_idx 、 #sink_cnt 、 #src_idx 、 #src_cnt 信号位宽必须一致；
 * - Avalon镜像接口数组中被选通的接口的输入信号、输出信号均将与被连接Avalon接口的对应信号连接；
 * - 模块端口信号 #msink_idx 的说明中“信号从被选通的镜像Avalon接口输出的时刻”指的是下图中的T0时刻；
 *                 |->T0
 *  clk_sink:      ^__^^__^^__^^__^^
 *  ifim_sink:  ^^^|___
 *  ifi_sink :  ^^^^^^|_____
 * - 模块端口信号 #src_autoblk4nocs 的说明中“向镜像Avalon接口输出信号的时刻”指的是下图中的T0时刻；
 * - 模块端口信号 #msrc_cs 的说明中“镜像Avalon接口接收到输入信号的时刻”指的是下图中的T1时刻；
 *                |->T0
 *  clk_src :     ^__^^__^^__^^__^^
 *  ifi_src :  ^^^|___
 *  ifim_src:  ^^^^^^|_____
 *                   |->T1
 * - 因Avalon接口信号中的 #sink_valid 、 #src_valid 要参与 #sink_blk 、 #src_blk 信号的生成，为避免产生组合逻辑电路循环，这些信号不可
 * 直接或通过组合逻辑电路间接的用于 #msink_idx 、 #msrc_cs 接口信号的生成。
 */
module avalon_mirrormux_sinkbycs #(
   parameter avalon_pkg::ifCfg        SVR_IC       = avalon_pkg::deft_ifCfg,  ///< 被镜像连接的Avalon接口配置参数
   parameter avalon_pkg::ifCfg        MIR_IC       = avalon_pkg::deft_ifCfg,  ///< 镜像Avalon接口配置参数
   parameter bit                      BITW_UNMATCH = 0,                       ///< 指示连接的Avalon接口信号位宽不一致的标志，用于提示编译器被连接的两个Avalon接口信号位宽被显示设计为不一致
   parameter avalon_pkg::mirrorMuxCfg MMC          = avalon_pkg::make_mirrorMuxCfg(2,2,0)
) (
   avalon_if                                                   ifi,                 ///< 等待被镜像连接的Avalon接口实例
   input wire                                                  src_autoblk4nocs,    ///< 等待被镜像连接的Avalon接口实例在输出端“向镜像Avalon接口输出信号的时刻”未被选通时自动阻塞的标志：
                                                                                    ///< 高电平(1)-输出端 #src_valid 置位时自动置位 #src_blk 以阻塞数据输出；
                                                                                    ///< 低电平(0)-输出端 #src_valid 置位时保持 #src_blk 为0，输出的数据将被丢弃。
   avalon_if                                                   ifim[avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC)-1:0], ///< 用作镜像的Avalon接口实例数组
   input wire[avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC)-1:0]  msink_cs,            ///< 镜像Avalon接口实例输入端信号在“信号从被选通的镜像Avalon接口输出的时刻”（ #MSINKCSPRESET == 1'b0 ）或前一时刻（ #MSINKCSPRESET == 1'b1 ）的选通信号数组
   input wire[avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC)-1:0]  msink_autoblk4nocs,  ///< 镜像Avalon接口实例输入端未被选通时自动阻塞的标志：
                                                                                    ///< 高电平(1)-输入端 #sink_valid 置位时自动置位 #sink_blk 以阻塞数据输入；
                                                                                    ///< 低电平(0)-输入端 #sink_valid 置位时保持 #sink_blk 为0，输入的数据将被丢弃。
   avalon_mirrormux_if.ifmuxp                                  muxp                 ///< 镜像Avalon接口连接器控制信号输出端口
);
   localparam int mirrorCnt = avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC);
   localparam int bitwof_msinkidx = mux_pkg::idxbitw_ofmux(mirrorCnt);
   initial if (mirrorCnt != $bits(muxp.msink_cs))
      $error("avalon_mirrormux_sinkbyidx: parameter MMC.mirrorCnt(%0d) does not match the bitwidth of auxp.msink_cs(%0d)", mirrorCnt, $bits(muxp.msink_cs));
   initial if (mirrorCnt != $bits(muxp.mclk))
      $error("avalon_mirrormux_sinkbyidx: the bitwidth of muxp.mclk(%0d) does not match parameter MMC.mirrorCnt(%0d)", $bits(muxp.mclk), mirrorCnt);
   initial if (mirrorCnt != $bits(muxp.maclr))
      $error("avalon_mirrormux_sinkbyidx: the bitwidth of muxp.maclr(%0d) does not match parameter MMC.mirrorCnt(%0d)", $bits(muxp.maclr), mirrorCnt);
   initial if (mirrorCnt != $bits(muxp.msclr))
      $error("avalon_mirrormux_sinkbyidx: the bitwidth of muxp.msclr(%0d) does not match parameter MMC.mirrorCnt(%0d)", $bits(muxp.msclr), mirrorCnt);
   initial if (mirrorCnt != $bits(muxp.msrci_cs))
      $error("avalon_mirrormux_sinkbyidx: the bitwidth of muxp.msrci_cs(%0d) does not match MMC.mirrorCnt(%0d)", $bits(muxp.msrci_cs), mirrorCnt);
   initial if (mirrorCnt != $bits(muxp.msrc_bufsel))
      $error("avalon_mirrormux_sinkbyidx: the bitwidth of muxp.msrc_bufsel(%0d) does not match parameter MMC.mirrorCnt(%0d)", $bits(muxp.msrc_bufsel), mirrorCnt);
   localparam int ifiMaxSink = avalon_pkg::maxSink_of_ifCfg(SVR_IC);
   localparam int sinkidxbitw = avalon_pkg::bitwOfDataSeqIdx(ifiMaxSink);
   initial if (sinkidxbitw != $bits(ifi.sink_idx))
      $error("avalon_mirrormux_sinkbyidx: the bitwidth of sinkidx(%0d) on SVR_IC.maxSink(%0d) does not match the bitwidth of ifi.sink_idx(%0d)", sinkidxbitw, ifiMaxSink, $bits(ifi.sink_idx));
   localparam int sinkcntbitw = avalon_pkg::bitwOfDataSeqLen(ifiMaxSink);
   initial if (sinkcntbitw != $bits(ifi.sink_cnt))
      $error("avalon_mirrormux_sinkbyidx: the bitwidth of sinkcnt(%0d) on SVR_IC.maxSink(%0d) does not match the bitwidth of ifi.sink_cnt(%0d)", sinkcntbitw, ifiMaxSink, $bits(ifi.sink_cnt));
   localparam int ifiMaxSrc = avalon_pkg::maxSrc_of_ifCfg(SVR_IC);
   localparam int srcidxbitw = avalon_pkg::bitwOfDataSeqIdx(ifiMaxSrc);
   initial if (srcidxbitw != $bits(ifi.src_idx))
      $error("avalon_mirrormux_sinkbyidx: the bitwidth of srcidx(%0d) on SVR_IC.maxSrc(%0d) does not match the bitwidth of ifi.src_idx(%0d)", srcidxbitw, ifiMaxSrc, $bits(ifi.src_idx));
   localparam int srccntbitw = avalon_pkg::bitwOfDataSeqLen(ifiMaxSrc);
   initial if (srccntbitw != $bits(ifi.src_cnt))
      $error("avalon_mirrormux_sinkbyidx: the bitwidth of srccnt(%0d) on SVR_IC.maxSrc(%0d) does not match the bitwidth of ifi.src_cnt(%0d)", srccntbitw, ifiMaxSrc, $bits(ifi.src_cnt));
   typedef struct packed {
      logic[sinkidxbitw-1:0] sink_idx, sink_nxtidx;
      logic[sinkcntbitw-1:0] sink_cnt;
      logic                  sink_sop, sink_eop, sink_valid;
   } sigs_m2isink_t;
   typedef struct packed {
      logic sink_blk, prcsr_blk;
   } sigs_i2msink_t;
   typedef struct packed {
      logic src_blk;
   } sigs_m2isrc_t;
   typedef struct packed {
      logic[srcidxbitw-1:0] src_idx, src_nxtidx;
      logic[srccntbitw-1:0] src_cnt;
      logic                 src_sop, src_eop, src_valid, src_bufsel;
   } sigs_i2msrc_t;
   wire [mirrorCnt-1:0] msink_cs_ofmuxp_upden_bym;
   sigs_m2isink_t m2isinkm[mirrorCnt-1:0], m2isinki, m2isinki4connect;
   localparam int bitwof_sigs_m2isink = sinkidxbitw*2 + sinkcntbitw + 3;
   sigs_i2msink_t i2msinkm[mirrorCnt-1:0];
   sigs_m2isrc_t  m2isrci;
   sigs_i2msrc_t  i2msrcm[mirrorCnt-1:0], i2msrci;
   localparam int bitwof_sigs_i2msrc = srcidxbitw*2 + srccntbitw + 4;
   logic sinkblk2m, prcsrblk2m;
   logic msrcmuxblk2i[mirrorCnt-1:0], msrcmuxblk2idle[mirrorCnt-1:0];
   assign ifi.sink_idx    = m2isinki.sink_idx,
          ifi.sink_nxtidx = m2isinki.sink_nxtidx,
          ifi.sink_cnt    = m2isinki.sink_cnt,
          ifi.sink_sop    = m2isinki.sink_sop,
          ifi.sink_eop    = m2isinki.sink_eop,
          ifi.sink_valid  = m2isinki.sink_valid,
          ifi.src_blk     = m2isrci.src_blk;
   assign i2msrci.src_idx    = ifi.src_idx,
          i2msrci.src_nxtidx = ifi.src_nxtidx,
          i2msrci.src_cnt    = ifi.src_cnt,
          i2msrci.src_sop    = ifi.src_sop,
          i2msrci.src_eop    = ifi.src_eop,
          i2msrci.src_valid  = ifi.src_valid,
          i2msrci.src_bufsel = ifi.src_bufsel;
   localparam int ifimMaxSink  = avalon_pkg::maxSink_of_ifCfg(MIR_IC);
   localparam int msinkidxbitw = avalon_pkg::bitwOfDataSeqIdx(ifimMaxSink);
   localparam int msinkcntbitw = avalon_pkg::bitwOfDataSeqLen(ifimMaxSink);
   localparam int ifimMaxSrc  = avalon_pkg::maxSrc_of_ifCfg(MIR_IC);
   localparam int msrcidxbitw = avalon_pkg::bitwOfDataSeqIdx(ifimMaxSrc);
   localparam int msrccntbitw = avalon_pkg::bitwOfDataSeqLen(ifimMaxSrc);
   localparam bit ixmDelayOut = avalon_pkg::ixmDelayOut_of_mirrorMuxCfg(MMC);
   genvar i; generate
   // SINK端复选隔离
   assign muxp.msink_cs = msink_cs;//msink_cs_ofmuxp;
   localparam int m2isinkMuxTaps = avalon_pkg::m2isinkMuxTaps_of_mirrorMuxCfg(MMC);
   localparam int m2isinkmuxtap  = m2isinkMuxTaps;// - (int'(ixmDelayOut));
   /* \attention #m2isink_muxer 必须受 #muxp.sinkmuxidle 控制实现阻塞，否则：
    * 当 #ifi.sink_blk 置位时， #ifi 对应模块已停止接收输入数据，但 #m2isink_muxer 继续向 #ifi 递推输出信号，则这些输出的信号将被丢失
    */
   wire muxp_sink_clken = muxp.clken&(~muxp.sinkmuxidle);
   mux_bycs #(
      .UNITBITW   (bitwof_sigs_m2isink ),
      .INPUTCNT   (mirrorCnt           ),
      .DELAYTAPS  (m2isinkmuxtap       )
   ) m2isink_muxer(
      .clk        (muxp.clk         ),
      .aclr       (muxp.aclr        ),
      .sclr       (muxp.sclr        ),
      .clken      (muxp_sink_clken  ),
      .data_in    (m2isinkm         ),
      .data4nocs  ('0               ),
      .cs         (muxp.msink_cs    ),
      .data_out   (m2isinki4connect )
   );
   avalon_auxsig_syncwith_syncsigofmirrormux_sinknomux #(
      .SINK_SIGBITW  (mirrorCnt  ),
      .MMC           (MMC        )
   ) midx_msink2svrsink(
      .clk        (muxp.clk         ),
      .aclr       (muxp.aclr        ),
      .sclr       (muxp.sclr        ),
      .clken      (muxp.clken       ),
      .isinkblk   (muxp.isinkblk    ),
      .sinkmuxidle(muxp.sinkmuxidle ),
      .sink_bufsel(muxp.sink_bufsel ),
      .msink_cs   (1'b1             ),
      .msinksig   (muxp.msink_cs    ),
      .sig2sink   (muxp.isink_cs    )
   );
   assign muxp.clk      = ifi.clk,
          muxp.aclr     = ifi.aclr,
          muxp.sclr     = ifi.sclr,
          muxp.clken    = ifi.clken,
          muxp.isinkblk = ifi.sink_blk&ifi.sink_valid;
   if (ixmDelayOut) begin
      genr_bufselblk4bufsrc #(
         .FLOWCNT(1)
      ) sink_bufsel_genr(
         .clk     (ifi.clk                      ),
         .aclr    (ifi.aclr                     ),
         .sclr    (ifi.sclr                     ),
         .clken   (ifi.clken                    ),
         .srcblk  (muxp.isinkblk                ),
         .vld2src (m2isinki4connect.sink_valid  ),
         .bufsel  (muxp.sink_bufsel             ),
         .blkprcsr(sinkblk2m                    )
      );
      bufsrc4blk #(
         .SIGBITW (bitwof_sigs_m2isink                      ),
         .MSK4UBLK({{(sinkidxbitw*2+sinkcntbitw+3){1'b0}}}  ),
         .VAL4UBLK({{(sinkidxbitw*2+sinkcntbitw+3){1'b0}}}  )
      ) sinksig_bufsrc(
         .clk     (ifi.clk                                  ),
         .aclr    (ifi.aclr                                 ),
         .sclr    (ifi.sclr                                 ),
         .clken   (ifi.clken                                ),
         .outsel  (1'b1                                     ),
         .sig4nos ({{(sinkidxbitw*2+sinkcntbitw+3){1'b0}}}  ),
         .srcblk  (muxp.isinkblk                            ),
         .pblk4src(sinkblk2m                                ),
         .blkbyusr(1'b0                                     ),
         .bufsel  (muxp.sink_bufsel                         ),
         .sig2src (m2isinki4connect                         ),
         .sigsrced(m2isinki                                 )
      );
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(ifi.clk, ifi.aclr)) begin
         if      (ifi.aclr)   prcsrblk2m <= '0;
         else if (ifi.sclr)   prcsrblk2m <= '0;
         else if (ifi.clken)  prcsrblk2m <= ifi.prcsr_blk;
         else                 prcsrblk2m <= prcsrblk2m;
      end
   end else begin
      assign m2isinki         = m2isinki4connect,
             sinkblk2m        = ifi.sink_blk & ifi.sink_valid,
             prcsrblk2m       = ifi.prcsr_blk,
             muxp.sink_bufsel = '0;
   end
   localparam int svrLatency = avalon_pkg::prclat_of_ifCfg(SVR_IC);
   /* \attention 无论如何，阻塞信号都必须从收端立即反馈给发端，以确保发端能立即停止更新输出端信号状态，避免输出的有效信号被收端丢弃；
    * 如果阻塞信号需要延迟输出给发端，那么发端在检测到阻塞信号前输出的有效信号就必须缓存起来以避免丢失。
    * 因目前的Avalon接口程序设计仅能缓存一拍的数据，这决定了m端的 #src_blk 信号的复选过程只能有最多一拍的时延。
    */
   initial if (svrLatency < int'(ixmDelayOut)) $error("avalon_mirrormux_sinkbyidx : SVR_IC.prclat(%0d) should not be less than %0d because of MMC.ixmDelayOut(%0d)", svrLatency, int'(ixmDelayOut), ixmDelayOut);
   shiftfixtaps #(
      .DATABITW   (mirrorCnt  ),
      .TAP_DIST   (svrLatency ),
      .SCLR_ONRAM (1'b0       ),
      .IMPLBYLOGIC(1'b0       )
   ) midx_svrsink2src(
      .clk     (muxp.clk                  ),
      .aclr    (muxp.aclr                 ),
      .sclr    (muxp.sclr                 ),
      .clken   (ifi.clken&(~ifi.prcsr_blk)),
      .shiftin (muxp.isink_cs             ),
      .shiftout(muxp.msrci_cs             ),
      .reseting(                          )
   );
   wire[mirrorCnt-1:0]ifi_seled_srcblk;
   assign m2isrci.src_blk = |ifi_seled_srcblk;
   for (i = 0; i < mirrorCnt; i++) begin: MIRROR_ARRAY
      initial if (msinkidxbitw != $bits(ifim[i].sink_idx))
         $error("avalon_mirrormux_sinkbyidx : the bitwidth of sinkidx(%0d) on MIR_IC.maxSink(%0d) does not match the bitwidth of ifim.sink_idx(%0d)", msinkidxbitw, ifimMaxSink, $bits(ifim[i].sink_idx));
      initial if (msinkcntbitw != $bits(ifim[i].sink_cnt))
         $error("avalon_mirrormux_sinkbyidx : the bitwidth of sinkcnt(%0d) on MIR_IC.maxSink(%0d) does not match the bitwidth of ifim.sink_cnt(%0d)", msinkcntbitw, ifimMaxSink, $bits(ifim[i].sink_cnt));
      initial if (msrcidxbitw != $bits(ifim[i].src_idx))
         $error("avalon_mirrormux_sinkbyidx : the bitwidth of srcidx(%0d) on MIR_IC.maxSrc(%0d) does not match the bitwidth of ifim.src_idx(%0d)", msrcidxbitw, ifimMaxSrc, $bits(ifim[i].src_idx));
      initial if (msrccntbitw != $bits(ifim[i].src_cnt))
         $error("avalon_mirrormux_sinkbyidx : the bitwidth of srccnt(%0d) on MIR_IC.maxSrc(%0d) does not match the bitwidth of ifim.src_cnt(%0d)", msrccntbitw, ifimMaxSrc, $bits(ifim[i].src_cnt));
      initial if (BITW_UNMATCH == 0) begin
         if (msinkidxbitw != sinkidxbitw)
            $error("avalon_mirrormux_sinkbyidx : ifim[%0d].sink_idx's bitwidth(%0d) does not match the one of ifi.sinkidx(%0d)", i, msinkidxbitw, sinkidxbitw);
         if (msinkcntbitw != sinkcntbitw)
            $error("avalon_mirrormux_sinkbyidx : ifim[%0d].sink_cnt's bitwidth(%0d) does not match the one of ifi.sinkcnt(%0d)", i, msinkcntbitw, sinkcntbitw);
         if (msrcidxbitw != srcidxbitw)
            $error("avalon_mirrormux_sinkbyidx : ifim[%0d].src_idx's bitwidth(%0d) does not match the one of ifi.srcidx(%0d)", i, msrcidxbitw, srcidxbitw);
         if (msrccntbitw != srccntbitw)
            $error("avalon_mirrormux_sinkbyidx : ifim[%0d].src_cnt's bitwidth(%0d) does not match the one of ifi.srccnt(%0d)", i, msrccntbitw, srccntbitw);
      end
      sigs_m2isink_t m2isinkm2s;
      assign m2isinkm[i].sink_idx    = (sinkidxbitw)'(ifim[i].sink_idx),
             m2isinkm[i].sink_nxtidx = (sinkidxbitw)'(ifim[i].sink_nxtidx),
             m2isinkm[i].sink_cnt    = (sinkcntbitw)'(ifim[i].sink_cnt),
             m2isinkm[i].sink_sop    = ifim[i].sink_sop,
             m2isinkm[i].sink_eop    = ifim[i].sink_eop,
             m2isinkm[i].sink_valid  = ifim[i].sink_valid;
      assign ifim[i].sink_blk   = i2msinkm[i].sink_blk,
             ifim[i].prcsr_blk  = i2msinkm[i].prcsr_blk,
             ifim[i].src_idx    = (msrcidxbitw)'(i2msrcm[i].src_idx),
             ifim[i].src_nxtidx = (msrcidxbitw)'(i2msrcm[i].src_nxtidx),
             ifim[i].src_cnt    = (msrccntbitw)'(i2msrcm[i].src_cnt),
             ifim[i].src_sop    = i2msrcm[i].src_sop,
             ifim[i].src_eop    = i2msrcm[i].src_eop,
             ifim[i].src_valid  = i2msrcm[i].src_valid,
             ifim[i].src_bufsel = i2msrcm[i].src_bufsel;
      wire sink_blk_i = m2isinkm[i].sink_valid & msink_autoblk4nocs[i];
      assign muxp.msrcmuxidle[i] = msrcmuxblk2idle[i],
             ifi_seled_srcblk[i] = msrcmuxblk2idle[i]&ifi.src_valid&muxp.msrci_cs[i];
      /*
                   IDX1(msrci_idx)
                    |                                 msrc_bufsel[i]
               ifi.src_xxx                               |  ifim[i].src_xxx
            i2msrc4connect-(ixmDelayOut)-->i2msrcm2o  ------> i2msrcm
                                             |           /
                            msrcmuxidle[i] --|          /
                                             v         /
                                          i2msrcmbuf -/

              msrcmuxidle[i]==msrcmuxblk2idle[i] <--(ixmDelayOut)-- 
                                                                   \
                                                                    ---msrcmuxblk2i[i]( ifim[i].src_blk )
                                                                   /
                        m2isrci<-----------(ixmDelayOut)-----------
                                                                  |
                                                                 IDX2(msrcm_idx)
       */
      if (ixmDelayOut) begin
         assign msrcmuxblk2i[i] = ifim[i].src_blk & ifim[i].src_valid&muxp.msrci_cs[i];
         genr_bufselblk4bufsrc #(
            .FLOWCNT(1)
         ) src_bufsel_genr(
            .clk     (ifim[i].clk         ),
            .aclr    (ifim[i].aclr        ),
            .sclr    (ifim[i].sclr        ),
            .clken   (ifim[i].clken       ),
            .srcblk  (msrcmuxblk2i[i]     ),
            .vld2src (i2msrci.src_valid   ),
            .bufsel  (muxp.msrc_bufsel[i] ),
            .blkprcsr(msrcmuxblk2idle[i]  )
         );
         bufsrc4blk #(
            .SIGBITW (bitwof_sigs_i2msrc                          ),
            .MSK4UBLK({{(srcidxbitw*2+srccntbitw){1'b0}}, 4'b1110}),
            .VAL4UBLK({(srcidxbitw*2+srccntbitw+4){1'b0}}         )
         ) srcsigs_bufsrc(
            .clk     (ifim[i].clk                        ),
            .aclr    (ifim[i].aclr                       ),
            .sclr    (ifim[i].sclr                       ),
            .clken   (ifim[i].clken                      ),
            .outsel  (muxp.msrci_cs[i]                   ),
            .sig4nos ({(srcidxbitw*2+srccntbitw+4){1'b0}}),
            .srcblk  (msrcmuxblk2i[i]                    ),
            .pblk4src(msrcmuxblk2idle[i]                 ),
            .blkbyusr(~muxp.msrci_cs[i]                  ),
            .bufsel  (muxp.msrc_bufsel[i]                ),
            .sig2src (i2msrci                            ),
            .sigsrced(i2msrcm[i]                         )
         );
      end else begin                               // DELAY_OUT == 1'b0
         assign msrcmuxblk2i[i]     = ifim[i].src_blk,
                msrcmuxblk2idle[i]  = msrcmuxblk2i[i],
                muxp.msrc_bufsel[i] = '0,
                i2msrcm[i]          = muxp.msrci_cs[i]
                                      ? i2msrci
                                      : '0;
      end
      assign muxp.mclk[i]    = ifim[i].clk,
             muxp.maclr[i]   = ifim[i].aclr,
             muxp.msclr[i]   = ifim[i].sclr,
             muxp.mclken[i]  = ifim[i].clken,
             muxp.msrcblk[i] = msrcmuxblk2i[i];
      /*
       * \attention
       * 被选通的输入端和输出端镜像Avalon接口都被赋值 #prcsr_blk 信号，是因为无论输入端被选通的镜像
       * Avalon接口还是输出端被选通的镜像Avalon接口，它们的数据输入和输出由依赖被镜像Avalon接口的处
       * 理器的阻塞状态，因此有必要向它们提供处理器阻塞状态，以使它们能够正确同步辅助信号
       */
      /* \attention
       * #i2msinkm[i].sink_blk 必须通过 #muxp.msink_cs[i] 选择，造成镜像Avalon接口选通信号改变时
       * 产生一拍阻塞信号，目的在于给下面的 #msink_cs_ofmuxp 信号保留非阻塞赋值的更新时间，避免该
       * 信号在阻塞赋值时造成组合逻辑路径过长、电路时序过于紧张的问题。
       */
      assign /*msink_cs_ofmuxp_upden_bym[i] = (msink_cs[i]|muxp.msink_cs[i])
                                            ? (ifim[i].clken & ((~m2isinkm[i].sink_valid) | (m2isinkm[i].sink_eop & (~i2msinkm[i].sink_blk))))
                                            : 1'b0,*/
             i2msinkm[i].sink_blk         = muxp.msink_cs[i]
                                            ? sinkblk2m
                                            : sink_blk_i,
             i2msinkm[i].prcsr_blk        = prcsrblk2m;
   end endgenerate
   shiftfixtaps #(
      .DATABITW   (mirrorCnt        ),
      .TAP_DIST   (int'(ixmDelayOut)),
      .SCLR_ONRAM (1'b0             ),
      .IMPLBYLOGIC(1'b1             )
   ) midx_svrsrc2m2(
      .clk     (muxp.clk                  ),
      .aclr    (muxp.aclr                 ),
      .sclr    (muxp.sclr                 ),
      .clken   (ifi.clken&(~ifi.prcsr_blk)),
      .shiftin (muxp.msrci_cs             ),
      .shiftout(muxp.msrcm_cs             ),
      .reseting(                          )
   );
   assign muxp.sinkmuxidle = sinkblk2m;
endmodule
module avalon_mirrormux_sinkbyidx #(
   parameter avalon_pkg::ifCfg        SVR_IC        = avalon_pkg::deft_ifCfg, ///< 被镜像连接的Avalon接口配置参数
   parameter avalon_pkg::ifCfg        MIR_IC        = avalon_pkg::deft_ifCfg, ///< 镜像Avalon接口配置参数
   parameter bit                      BITW_UNMATCH  = 0,                      ///< 指示连接的Avalon接口信号位宽不一致的标志，用于提示编译器被连接的两个Avalon接口信号位宽被显示设计为不一致
   parameter bit                      MSINKIDXPRSET = 1'b1,                   ///< 镜像Avalon接口输入端信号的选通信号提前一拍置位标志：
                                                                              ///< 1'b0-选通信号与镜像Avalon接口阵列同时置位，可节省寄存器资源；
                                                                              ///< 1'b1-选通信号比镜像Avalon接口阵列提前一个时钟置位，可获得更高的时序性能。
   parameter avalon_pkg::mirrorMuxCfg MMC           = avalon_pkg::make_mirrorMuxCfg(2,2,0)
) (
   avalon_if                                                   ifi,                 ///< 等待被镜像连接的Avalon接口实例
   input wire                                                  src_autoblk4nocs,    ///< 等待被镜像连接的Avalon接口实例在输出端未被选通时自动阻塞的标志：
                                                                                    ///< 高电平(1)-输出端 #src_valid 置位时自动置位 #src_blk 以阻塞数据输出；
                                                                                    ///< 低电平(0)-输出端 #src_valid 置位时保持 #src_blk 为0，输出的数据将被丢弃。
   avalon_if                                                   ifim[avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC)-1:0],///< 用作镜像的Avalon接口实例数组
   input wire[mux_pkg::idxbitw_ofmux(avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC))-1:0]  msink_idx,           ///< 镜像Avalon接口实例输入端信号在“信号从被选通的镜像Avalon接口输出的时刻”( #M2ISINK_CS_PRESET_FLAG = 0 )或前一时钟( #M2ISINK_CS_PRESET_FLAG = 1 )的选通信号数组
   input wire[avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC)-1:0]  msink_autoblk4nocs,  ///< 镜像Avalon接口实例输入端未被选通时自动阻塞的标志：
                                                                                    ///< 高电平(1)-输入端 #sink_valid 置位时自动置位 #sink_blk 以阻塞数据输入；
                                                                                    ///< 低电平(0)-输入端 #sink_valid 置位时保持 #sink_blk 为0，输入的数据将被丢弃。
   avalon_mirrormux_if.ifmuxp                                  muxp                 ///< 镜像Avalon接口连接器控制信号输出端口
);
   localparam int mirrorCnt = avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC);
   localparam int bitwof_msink_idx = mux_pkg::idxbitw_ofmux(mirrorCnt);
   wire[mirrorCnt-1:0]msink_cs;
   idx2selsig #(
      .SELSIG_CNT (mirrorCnt     ),
      .DELAYTAPS  (MSINKIDXPRSET )
   ) idx2cs(
      .clk     (ifi.clk    ),
      .aclr    (ifi.aclr   ),
      .sclr    (ifi.sclr   ),
      .clken   (ifi.clken  ),
      .idx     (msink_idx  ),
      .cs      (msink_cs   )
   );
   avalon_mirrormux_sinkbycs #(
      .SVR_IC        (SVR_IC        ),
      .MIR_IC        (MIR_IC        ),
      .BITW_UNMATCH  (BITW_UNMATCH  ),
      .MMC           (MMC           )
   ) ammsbi(
      .ifi                 (ifi                 ),
      .ifim                (ifim                ),
      .msink_cs            (msink_cs            ),
      .msink_autoblk4nocs  (msink_autoblk4nocs  ),
      .src_autoblk4nocs    (src_autoblk4nocs    ),
      .muxp                (muxp                )
   );
endmodule
/*! \brief 将辅助信号与Avalon镜像连接复用选择器的输入端复用选择时序同步 */
module avalon_auxsig_syncwith_mirrormux_sinknomux #(
   parameter int                      SINK_SIGBITW = 1,     ///< 待同步输入端信号位宽
   parameter int                      SINKPIDX2SYN = 0,     ///< 待与之同步的镜像Avalon接口索引
   parameter avalon_pkg::mirrorMuxCfg MMC          = avalon_pkg::make_mirrorMuxCfg(2,2,0)
) (
   avalon_mirrormux_if.auxmuxp   auxp,             ///< 辅助信号同步用控制信号输入端口
   input  wire[SINK_SIGBITW-1:0] msinksig,         ///< Avalon镜像接口处理器向本地Avalon接口处理器输入的信号数组
   output wire[SINK_SIGBITW-1:0] sig2sink          ///< 本地Avalon接口处理器实际输入的信号数组
);
   initial if (SINKPIDX2SYN < 0 || SINKPIDX2SYN >= avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC))
      $error("avalon_auxsig_syncwith_mirrormux_sinknomux: illegal SINKPIDX2SYN(%0d) specified, only value between 0 and MMC.mirrorCnt(%0d)-1 is allowed", SINKPIDX2SYN, avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC));
   avalon_auxsig_syncwith_syncsigofmirrormux_sinknomux #(
      .SINK_SIGBITW  (SINK_SIGBITW  ),
      .MMC           (MMC           )
   ) aaswssommsnm(
      .clk        (auxp.clk                     ),
      .aclr       (auxp.aclr                    ),
      .sclr       (auxp.sclr                    ),
      .clken      (auxp.clken                   ),
      .isinkblk   (auxp.isinkblk                ),
      .sinkmuxidle(auxp.sinkmuxidle             ),
      .sink_bufsel(auxp.sink_bufsel             ),
      .msink_cs   (auxp.msink_cs[SINKPIDX2SYN]  ),
      .msinksig   (msinksig                     ),
      .sig2sink   (sig2sink                     )
   );
endmodule
/*! \brief 将辅助信号与Avalon镜像连接复用选择器的输出端复用选择时序同步 */
module avalon_auxsig_syncwith_mirrormux_srcnomux #(
   parameter int                      SRC_SIGBITW = 1,///< 待同步输出信号位宽
   parameter int                      SRCIDX2SYNC = 0,///< 同步用目标镜像Avalon接口索引
   parameter avalon_pkg::mirrorMuxCfg MMC         = avalon_pkg::make_mirrorMuxCfg(2,2,0)
) (
   avalon_mirrormux_if.auxmuxp   auxp,             ///< 辅助信号同步用控制信号输入端口
   input  wire [SRC_SIGBITW -1:0]sig2src,          ///< 本地Avalon接口处理器实际输出的信号数组
   output logic[SRC_SIGBITW -1:0]msrcsig           ///< Avalon镜像接口处理器从本地Avalon接口处理器输入的信号数组
);
   initial begin
      if      (SRCIDX2SYNC < 0)
         $error("avalon_auxsig_syncwith_mirrormux_src: parameter SRCIDX2SYNC(%0d) should not be negative", SRCIDX2SYNC);
      else if (SRCIDX2SYNC >= $bits(auxp.mclk))
         $error("avalon_auxsig_syncwith_mirrormux_src: parameter SRCIDX2SYNC(%0d) should not be greator than bitwidth of auxp.mclk(%0d)", SRCIDX2SYNC, $bits(auxp.mclk));
      else if (SRCIDX2SYNC >= $bits(auxp.maclr))
         $error("avalon_auxsig_syncwith_mirrormux_src: parameter SRCIDX2SYNC(%0d) should not be greator than bitwidth of auxp.maclr(%0d)", SRCIDX2SYNC, $bits(auxp.maclr));
      else if (SRCIDX2SYNC >= $bits(auxp.msclr))
         $error("avalon_auxsig_syncwith_mirrormux_src: parameter SRCIDX2SYNC(%0d) should not be greator than bitwidth of auxp.msclr(%0d)", SRCIDX2SYNC, $bits(auxp.msclr));
      else if (SRCIDX2SYNC >= $bits(auxp.msrcmuxidle))
         $error("avalon_auxsig_syncwith_mirrormux_src: parameter SRCIDX2SYNC(%0d) should not be greator than bitwidth of auxp.msrcmuxidle(%0d)", SRCIDX2SYNC, $bits(auxp.msrcmuxidle));
   end
   localparam bit ixm_delayout      = avalon_pkg::ixmDelayOut_of_mirrorMuxCfg(MMC);
   localparam int mirrorCnt         = avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC);
   localparam int idxBitwOfSinkPort = mux_pkg::idxbitw_ofmux(mirrorCnt);
   localparam bit[idxBitwOfSinkPort-1:0] srcidx2sync4cmp = (idxBitwOfSinkPort)'(SRCIDX2SYNC);
   generate if (ixm_delayout) begin
      bufsrc4blk #(
         .SIGBITW (SRC_SIGBITW            ),
         .MSK4UBLK({(SRC_SIGBITW){1'b0}}  ),
         .VAL4UBLK({(SRC_SIGBITW){1'b0}}  )
      ) bufsrc_sig(
         .clk     (auxp.mclk[SRCIDX2SYNC]       ),
         .aclr    (auxp.maclr[SRCIDX2SYNC]      ),
         .sclr    (auxp.msclr[SRCIDX2SYNC]      ),
         .clken   (auxp.mclken[SRCIDX2SYNC]     ),
         .outsel  (auxp.msrci_cs[SRCIDX2SYNC]   ),
         .sig4nos ({(SRC_SIGBITW){1'b0}}        ),
         .srcblk  (auxp.msrcblk[SRCIDX2SYNC]    ),
         .pblk4src(auxp.msrcmuxidle[SRCIDX2SYNC]),
         .blkbyusr(1'b0                         ),
         .bufsel  (auxp.msrc_bufsel[SRCIDX2SYNC]),
         .sig2src (sig2src                      ),
         .sigsrced(msrcsig                      )
      );
   end else assign msrcsig = sig2src;
   endgenerate
endmodule
/*! \brief 将辅助信号与Avalon镜像连接选择器同步 */
module avalon_auxsig_syncwith_mirrormux #(
   parameter int SINK_SIGBITW             = 1,     ///< 待同步输入信号位宽
   parameter int SRC_SIGBITW              = 1,     ///< 待同步输出信号位宽
   parameter avalon_pkg::mirrorMuxCfg MMC = avalon_pkg::make_mirrorMuxCfg(2,2,0)
) (
   avalon_mirrormux_if.auxmuxp   auxp,                                                    ///< 辅助信号同步用控制信号输入端口
   input  wire[SINK_SIGBITW-1:0] msinksig[avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC)-1:0],///< Avalon镜像接口处理器向本地Avalon接口处理器输入的信号数组
   input  wire[SINK_SIGBITW-1:0] msinksig4nocs,                                           ///< Avalon镜像接口没有接口被选通时输出给本地Avalon接口处理器的信号数组
   output wire[SINK_SIGBITW-1:0] sig2sink,                                                ///< 本地Avalon接口处理器实际输入的信号数组
   input  wire[SRC_SIGBITW -1:0] sig2src,                                                 ///< 本地Avalon接口处理器实际输出的信号数组
   input  wire[SRC_SIGBITW -1:0] srcsig4nocs,                                             ///< 为未选通的输出端辅助信号赋值的信号
   output wire[SRC_SIGBITW -1:0] msrcsig[avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC)-1:0]  ///< Avalon镜像接口处理器从本地Avalon接口处理器输入的信号数组
);
   localparam int mirrorCnt = avalon_pkg::mirrorCnt_of_mirrorMuxCfg(MMC);
   localparam int bitwof_m2isinkidx = mux_pkg::idxbitw_ofmux(mirrorCnt);
   initial if (mirrorCnt != $bits(auxp.msink_cs))
      $error("avalon_auxsig_syncwith_mirrormux: parameter MMC.mirrorCnt(%0d) does not match bitwidth of auxp.msink_cs(%0d)", mirrorCnt, $bits(auxp.msink_cs));
   initial if (mirrorCnt != $bits(auxp.mclk))
      $error("avalon_auxsig_syncwith_mirrormux: the bitwidth of auxp.mclk(%0d) does not match parameter MMC.mirrorCnt(%0d)", $bits(auxp.mclk), mirrorCnt);
   initial if (mirrorCnt != $bits(auxp.maclr))
      $error("avalon_auxsig_syncwith_mirrormux: the bitwidth of auxp.maclr(%0d) does not match parameter MMC.mirrorCnt(%0d)", $bits(auxp.maclr), mirrorCnt);
   initial if (mirrorCnt != $bits(auxp.msclr))
      $error("avalon_auxsig_syncwith_mirrormux: the bitwidth of auxp.msclr(%0d) does not match parameter MMC.mirrorCnt(%0d)", $bits(auxp.msclr), mirrorCnt);
   initial if (mirrorCnt != $bits(auxp.msrci_cs))
      $error("avalon_auxsig_syncwith_mirrormux: the bitwidth of auxp.msrci_cs(%0d) does not match parameter MMC.mirrorCnt(%0d)", $bits(auxp.msrci_cs), mirrorCnt);
   initial if (mirrorCnt != $bits(auxp.msrcmuxidle))
      $error("avalon_auxsig_syncwith_mirrormux: the bitwidth of auxp.msrc_bufsel(%0d) does not match parameter MMC.mirrorCnt(%0d)", $bits(auxp.msrc_bufsel), mirrorCnt);
   wire [SINK_SIGBITW-1:0] msinksig_muxsel;
   localparam bit ixm_delayout = avalon_pkg::ixmDelayOut_of_mirrorMuxCfg(MMC);
   localparam int m2isinkMuxTaps = avalon_pkg::m2isinkMuxTaps_of_mirrorMuxCfg(MMC);
   localparam int m2isinkmuxtap = m2isinkMuxTaps;// - (int'(ixm_delayout));
    mux_bycs #(
      .UNITBITW   (SINK_SIGBITW  ),
      .INPUTCNT   (mirrorCnt     ),
      .DELAYTAPS  (m2isinkmuxtap )
   ) msinksig2mux_muxer(
      .clk        (auxp.clk                        ),
      .aclr       (auxp.aclr                       ),
      .sclr       (auxp.sclr                       ),
      .clken      (auxp.clken&(~auxp.sinkmuxidle)  ),
      .data_in    (msinksig                        ),
      .data4nocs  (msinksig4nocs                   ),
      .cs         (auxp.msink_cs                   ),
      .data_out   (msinksig_muxsel                 )
   );
  genvar i; generate if (ixm_delayout) begin
      bufsrc4blk #(
         .SIGBITW (SINK_SIGBITW  ),
         .MSK4UBLK({(SINK_SIGBITW){1'b0}} ),
         .VAL4UBLK({(SINK_SIGBITW){1'b0}} )
      ) bufsrc_msinksig(
         .clk     (auxp.clk         ),
         .aclr    (auxp.aclr        ),
         .sclr    (auxp.sclr        ),
         .clken   (auxp.clken       ),
         .outsel  (1'b1             ),
         .sig4nos (msinksig4nocs    ),
         .srcblk  (auxp.isinkblk    ),
         .pblk4src(auxp.sinkmuxidle ),
         .blkbyusr(1'b0             ),
         .bufsel  (auxp.sink_bufsel ),
         .sig2src (msinksig_muxsel  ),
         .sigsrced(sig2sink         )
      );
   end else assign sig2sink = msinksig_muxsel;
   for (i = 0; i < mirrorCnt; i++) begin: SRCSIG_BUF
      if (ixm_delayout) begin
         bufsrc4blk #(
            .SIGBITW (SRC_SIGBITW            ),
            .MSK4UBLK({(SRC_SIGBITW){1'b0}}  ),
            .VAL4UBLK({(SRC_SIGBITW){1'b0}}  )
         ) bufsrc_msrcsig(
            .clk     (auxp.mclk[i]        ),
            .aclr    (auxp.maclr[i]       ),
            .sclr    (auxp.msclr[i]       ),
            .clken   (auxp.mclken[i]      ),
            .outsel  (auxp.msrci_cs[i]    ),
            .sig4nos (srcsig4nocs         ),
            .srcblk  (auxp.msrcblk[i]     ),
            .pblk4src(auxp.msrcmuxidle[i] ),
            .blkbyusr(1'b0                ),
            .bufsel  (auxp.msrc_bufsel[i] ),
            .sig2src (sig2src             ),
            .sigsrced(msrcsig[i]          )
         );
      end else assign msrcsig[i] = auxp.msrci_cs[i]
                                   ? sig2src
                                   : srcsig4nocs;
   end endgenerate
endmodule
/*!
 * \brief 封装模块内部Avalon接口链表到模块外部的Avalon接口
 * \details 本模块应用于Avalon接口处理器内部，使用端口列表 #topnodp 与处理器内部待封装子链表的头节点的 #sinkp 、 尾节点的 #nextp 连接来实现上层节点对子链表的封装
 * \attention 
 * - 因本模块需要用端口列表 #topnodp 对本节点的 #sink_blk 变量赋值，所以上层节点的端口列表 #procp 将不再被允许使用，否则将引起对上层节点的 #sink_blk 变量重复赋值的冲突；
 * - 当使用端口列表 #topnodp 从上层节点连接子链表表头节点时：
 *   - 因子链表表头节点的输入端信号与上层节点的输入端信号直接连接，子链表表头节点不可再调用 #avalon_makesink 来为其做输入端服务处理，子链表表头节点的输出端服务处理不变；
 *   - 因上层节点的输出端信号与子链表表尾节点的输出端直接连接，上层节点不可再调用 #avalon_makesrc 来为其做输出端服务处理，上层节点的输入端服务处理不变。
 */
module avalon_chain2node #(
   parameter avalon_pkg::ifCfg TOPIC            = avalon_pkg::deft_ifCfg,  ///< 上层Avalon接口节点配置参数
   parameter avalon_pkg::ifCfg HEADIC           = avalon_pkg::deft_ifCfg,  ///< 本层Avalon接口链表头节点配置参数
   parameter bit               SHAREDTOPIF      = 1'b0,                    ///< 上层Avalon接口节点是共享其他模块的Avalon接口节点标志，对共享的上层Avalon接口节点，本层Avalon接口链表头节点将仅连接输入信号，不连接输出信号
                                                                           ///< 1'b1-上层Avalon接口节点是共享节点，1'b0-上层Avalon接口节点是本层Avalon接口链表自有的节点
   parameter bit               BITWUNMATCH_HEAD = 1'b0,                    ///< 本层Avalon接口链表头节点序列参数位宽与上层节点序列参数位宽不一致标志，用于提示编译器被连接的Avalon接口链表头节点和上层节点信号位宽被显示设计为不一致
   parameter bit               BITWUNMATCH_TAIL = 1'b0                     ///< 本层Avalon接口链表尾节点序列参数位宽与上层节点序列参数位宽不一致标志，用于提示编译器被连接的Avalon接口链表尾节点和上层节点信号位宽被显示设计为不一致
) (
   avalon_if.topnodp p,                            ///< 用于封装子链表的上层节点封装端口
   avalon_if.sinkp   chainheadp,                   ///< 待封装子链表的表头节点输入端服务器访问端口列表
   avalon_if.nextp   chaintailp,                   ///< 待封装子链表的表尾节点与下一节点交互端口列表
   input  wire       top_sink_blk                  ///< 父节点输出的外部输入阻塞信号 #sink_blk ，必须由用户给出。
                                                   ///< \attention 父节点的外部输入阻塞信号 #sink_blk 不单独赋值，避免某些编译器在本模块中未对
                                                   ///< 父节点的 #sink_blk 信号赋值时静默赋值默认值，从而产生父节点 #sink_blk 多重驱动的问题。
);
   initial begin
      if (BITWUNMATCH_HEAD == 1'b0 && $bits(chainheadp.sink_nxtidx) != $bits(p.sink_nxtidx))
         $error("avalon_chain2node: the bitwidth of chainheadp.sink_nxtidx(%0d) and p.sink_nxtidx(%0d) does not match!", $bits(chainheadp.sink_nxtidx), $bits(p.sink_nxtidx));
      if (BITWUNMATCH_HEAD == 1'b0 && $bits(chainheadp.sink_idx) != $bits(p.sink_idx))
         $error("avalon_chain2node: the bitwidth of chainheadp.sink_idx(%0d) and p.sink_idx(%0d) does not match!", $bits(chainheadp.sink_idx), $bits(p.sink_idx));
      if (BITWUNMATCH_HEAD == 1'b0 && $bits(chainheadp.sink_cnt) != $bits(p.sink_cnt))
         $error("avalon_chain2node: The bitwidth of chainheadp.sink_cnt(%0d) and p.sink_cnt(%0d) does not match!", $bits(chainheadp.sink_cnt), $bits(p.sink_cnt));
      if (BITWUNMATCH_TAIL == 1'b0 && $bits(chaintailp.src_nxtidx) != $bits(p.sink_nxtidx))
         $error("avalon_chain2node: the bitwidth of chaintailp.src_nxtidx(%0d) and p.src_nxtidx(%0d) does not match!", $bits(chaintailp.src_nxtidx), $bits(p.src_nxtidx));
      if (BITWUNMATCH_TAIL == 1'b0 && $bits(chaintailp.src_idx) != $bits(p.sink_idx))
         $error("avalon_chain2node: the bitwidth of chaintailp.src_idx(%0d) and p.src_idx(%0d) does not match!", $bits(chaintailp.src_idx), $bits(p.src_idx));
      if (BITWUNMATCH_TAIL == 1'b0 && $bits(chaintailp.src_cnt) != $bits(p.src_cnt))
         $error("avalon_chain2node: The bitwidth of chaintailp.src_cnt(%0d) and p.src_cnt(%0d) does not match!", $bits(chaintailp.src_cnt), $bits(p.src_cnt));
   end
   // 连接子链表的头结点
   localparam int bitwof_headsinkidx = avalon_pkg::bitwOfSinkIdx_of_ifCfg(HEADIC);
   localparam int bitwof_headsinkcnt = avalon_pkg::bitwOfSinkCnt_of_ifCfg(HEADIC);
   generate if (SHAREDTOPIF == 1'b0) begin
      assign p.prcsr_blk = chainheadp.prcsr_blk;
      assign p.sink_blk  = top_sink_blk;
      assign p.usr_blk   = chainheadp.usr_blk;
   end endgenerate
   assign chainheadp.sink_idx    = (bitwof_headsinkidx)'(p.sink_idx);
   assign chainheadp.sink_nxtidx = (bitwof_headsinkidx)'(p.sink_nxtidx);
   assign chainheadp.sink_cnt    = (bitwof_headsinkcnt)'(p.sink_cnt);
   assign chainheadp.sink_sop    = p.sink_sop;
   assign chainheadp.sink_eop    = p.sink_eop;
   assign chainheadp.sink_valid  = p.sink_valid;
   // 连接子链表的尾节点
   localparam int bitwof_topsrcidx = avalon_pkg::bitwOfSrcIdx_of_ifCfg(TOPIC);
   localparam int bitwof_topsrccnt = avalon_pkg::bitwOfSrcCnt_of_ifCfg(TOPIC);
   assign chaintailp.src_blk = p.src_blk;
   generate if (SHAREDTOPIF == 1'b0) begin
      assign p.src_idx    = (bitwof_topsrcidx)'(chaintailp.src_idx);
      assign p.src_nxtidx = (bitwof_topsrcidx)'(chaintailp.src_nxtidx);
      assign p.src_cnt    = (bitwof_topsrccnt)'(chaintailp.src_cnt);
      assign p.src_sop    = chaintailp.src_sop;
      assign p.src_eop    = chaintailp.src_eop;
      assign p.src_valid  = chaintailp.src_valid;
      assign p.src_bufsel = chaintailp.src_bufsel;
   end endgenerate
endmodule
/*!
 * \brief 封装模块内部Avalon接口链表到一个父链表的头节点
 * \details 本模块应用于Avalon接口处理器内部，使用端口列表 #topheadp 与待封装子链表的头节点的 #sinkp 、 尾节点的 #nextp 连接来实现上层节点对子链表的封装
 * \attention 
 * - 因本模块需要用端口列表 #topheadp 对本节点的 #sink_blk 变量赋值，所以上层节点的端口列表 #topheadp 将不再被允许使用，否则将引起对上层节点的 #sink_blk 变量重复赋值的冲突；
 * - 当使用端口列表 #topheadp 从上层节点连接子链表表头节点时：
 *   - 因子链表表头节点的输入端信号与上层节点的输入端信号直接连接，而子链表表头节点需要同时产生起始的sink、src系列信号，所以子链表表头节点必须使用 #avalon_makesink 产生输入信号，而上层节点不可使用该模块；
 *   - 而上层节点的输出端信号与子链表表尾节点的输出端直接连接，上层节点不可再调用 #avalon_makesrc 来为其做输出端服务处理，上层节点的输入端服务处理不变。
 */
module avalon_chain2head #(
   parameter avalon_pkg::ifCfg TOPIC            = avalon_pkg::deft_ifCfg,  ///< 上层Avalon接口节点配置参数
   parameter bit               SHAREDTOPIF      = 1'b0,                    ///< 上层Avalon接口节点是共享其他模块的Avalon接口节点标志，对共享的上层Avalon接口节点，本层Avalon接口链表头节点将仅连接输入信号，不连接输出信号
                                                                           ///< 1'b1-上层Avalon接口节点是共享节点，1'b0-上层Avalon接口节点是本层Avalon接口链表自有的节点
   parameter bit               BITWUNMATCH_HEAD = 1'b0,                    ///< 本层Avalon接口链表头节点序列参数位宽与上层节点序列参数位宽不一致标志，用于提示编译器被连接的Avalon接口链表头节点和上层节点信号位宽被显示设计为不一致
   parameter bit               BITWUNMATCH_TAIL = 1'b0                     ///< 本层Avalon接口链表尾节点序列参数位宽与上层节点序列参数位宽不一致标志，用于提示编译器被连接的Avalon接口链表尾节点和上层节点信号位宽被显示设计为不一致
) (
   avalon_if.topheadp  p,                          ///< 用于封装子链表的上层头节点封装端口
   avalon_if.sink2topp chainheadp,                 ///< 待封装子链表的表头节点输入端服务器访问端口列表
   avalon_if.nextp     chaintailp,                 ///< 待封装子链表的表尾节点与下一节点交互端口列表
   input  wire         top_sink_blk                ///< 父节点输出的外部输入阻塞信号 #sink_blk ，必须由用户给出。
                                                   ///< \attention 父节点的外部输入阻塞信号 #sink_blk 不单独赋值，避免某些编译器在本模块中未对
                                                   ///< 父节点的 #sink_blk 信号赋值时静默赋值默认值，从而产生父节点 #sink_blk 多重驱动的问题。
);
   initial begin
      if (BITWUNMATCH_HEAD == 1'b0 && $bits(chainheadp.sink_nxtidx) != $bits(p.sink_nxtidx))
         $error("avalon_chain2head: the bitwidth of chainheadp.sink_nxtidx(%0d) and p.sink_nxtidx(%0d) does not match!", $bits(chainheadp.sink_nxtidx), $bits(p.sink_nxtidx));
      if (BITWUNMATCH_HEAD == 1'b0 && $bits(chainheadp.sink_idx) != $bits(p.sink_idx))
         $error("avalon_chain2head: the bitwidth of chainheadp.sink_idx(%0d) and p.sink_idx(%0d) does not match!", $bits(chainheadp.sink_idx), $bits(p.sink_idx));
      if (BITWUNMATCH_HEAD == 1'b0 && $bits(chainheadp.sink_cnt) != $bits(p.sink_cnt))
         $error("avalon_chain2head: The bitwidth of chainheadp.sink_cnt(%0d) and p.sink_cnt(%0d) does not match!", $bits(chainheadp.sink_cnt), $bits(p.sink_cnt));
      if (BITWUNMATCH_TAIL == 1'b0 && $bits(chaintailp.src_nxtidx) != $bits(p.sink_nxtidx))
         $error("avalon_chain2head: the bitwidth of chaintailp.src_nxtidx(%0d) and p.src_nxtidx(%0d) does not match!", $bits(chaintailp.src_nxtidx), $bits(p.src_nxtidx));
      if (BITWUNMATCH_TAIL == 1'b0 && $bits(chaintailp.src_idx) != $bits(p.sink_idx))
         $error("avalon_chain2head: the bitwidth of chaintailp.src_idx(%0d) and p.src_idx(%0d) does not match!", $bits(chaintailp.src_idx), $bits(p.src_idx));
      if (BITWUNMATCH_TAIL == 1'b0 && $bits(chaintailp.src_cnt) != $bits(p.src_cnt))
         $error("avalon_chain2head: The bitwidth of chainheadp.src_cnt(%0d) and p.src_cnt(%0d) does not match!", $bits(chaintailp.src_cnt), $bits(p.src_cnt));
   end
   generate if (SHAREDTOPIF == 1'b0) begin
      // 连接子链表的头结点
      localparam int bitwof_topsinkidx = avalon_pkg::bitwOfSinkIdx_of_ifCfg(TOPIC);
      localparam int bitwof_topsinkcnt = avalon_pkg::bitwOfSinkCnt_of_ifCfg(TOPIC);
      assign p.prcsr_blk   = chainheadp.prcsr_blk;
      assign p.usr_blk     = chainheadp.usr_blk;
      assign p.sink_blk    = top_sink_blk;
      assign p.sink_idx    = (bitwof_topsinkidx)'(chainheadp.sink_idx);
      assign p.sink_nxtidx = (bitwof_topsinkidx)'(chainheadp.sink_nxtidx);
      assign p.sink_cnt    = (bitwof_topsinkcnt)'(chainheadp.sink_cnt);
      assign p.sink_sop    = chainheadp.sink_sop;
      assign p.sink_eop    = chainheadp.sink_eop;
      assign p.sink_valid  = chainheadp.sink_valid;
      // 连接子链表的尾节点
      localparam int bitwof_topsrcidx = avalon_pkg::bitwOfSrcIdx_of_ifCfg(TOPIC);
      localparam int bitwof_topsrccnt = avalon_pkg::bitwOfSrcCnt_of_ifCfg(TOPIC);
      assign p.src_idx    = (bitwof_topsrcidx)'(chaintailp.src_idx);
      assign p.src_nxtidx = (bitwof_topsrcidx)'(chaintailp.src_nxtidx);
      assign p.src_cnt    = (bitwof_topsrccnt)'(chaintailp.src_cnt);
      assign p.src_sop    = chaintailp.src_sop;
      assign p.src_eop    = chaintailp.src_eop;
      assign p.src_valid  = chaintailp.src_valid;
      assign p.src_bufsel = chaintailp.src_bufsel;
   end endgenerate
   assign chaintailp.src_blk = p.src_blk;
endmodule
/*! \brief 根据输出数据阻塞状态选择直连信号或者缓存信号输出 */
module avalon_srcsig_bybufsel #(
   parameter int SIGBITW = 1                       ///< 信号位宽
) (
   avalon_if.crp           crp,                    ///< Avalon接口的时钟及复位信号端口
   input  wire             src_blk,                ///< Avalon接口输出端阻塞请求信号，高电平(1)有效
   input  wire             prcsr_blk,              ///< 处理器阻塞标志信号，高电平(1)有效
   input  wire             blkbyusr,               ///< 用户指示的处理器阻塞信号，高电平(1)有效
   input  wire             src_bufsel,             ///< 输出缓存数据选择信号，高电平(1)-输出缓存数据，低电平(0)-输出直连数据
   input  wire[SIGBITW-1:0]sig2src,                ///< 待输出的直连信号
   output wire[SIGBITW-1:0]sigsrced                ///< 按阻塞状态选择的输出信号
);
   bufsrc4blk #(
      .SIGBITW (SIGBITW          ),
      .MSK4UBLK({(SIGBITW){1'b0}}),
      .VAL4UBLK({(SIGBITW){1'b0}})
   ) bufsrci(
      .clk     (crp.clk          ),
      .aclr    (crp.aclr         ),
      .sclr    (crp.sclr         ),
      .clken   (crp.clken        ),
      .outsel  (1'b1             ),
      .sig4nos ({(SIGBITW){1'b0}}),
      .srcblk  (src_blk          ),
      .pblk4src(prcsr_blk        ),
      .blkbyusr(blkbyusr         ),
      .bufsel  (src_bufsel       ),
      .sig2src (sig2src          ),
      .sigsrced(sigsrced         )
   );
endmodule
/*! \brief 根据Avalon接口辅助信号传递用交互信号端口列表的输出端阻塞状态选择直连信号或缓存信号输出 */
module avalon_srcsig_bybufsel_auxp #(
   parameter int SIGBITW = 1                       ///< 信号位宽
) (
   avalon_if.crp           crp,                    ///< Avalon接口的时钟及复位信号端口列表
   avalon_if.auxp          auxp,                   ///< Avalon接口的辅助信号传递用交互信号端口列表
   input  wire[SIGBITW-1:0]sig2src,                ///< 待输出的直连信号
   output wire[SIGBITW-1:0]sigsrced                ///< 按阻塞状态选择的输出信号
);
   bufsrc4blk #(
      .SIGBITW (SIGBITW          ),
      .MSK4UBLK({(SIGBITW){1'b0}}),
      .VAL4UBLK({(SIGBITW){1'b0}})
   ) bufsrci(
      .clk     (crp.clk          ),
      .aclr    (crp.aclr         ),
      .sclr    (crp.sclr         ),
      .clken   (crp.clken        ),
      .outsel  (1'b1             ),
      .sig4nos ({(SIGBITW){1'b0}}),
      .srcblk  (auxp.src_blk     ),
      .pblk4src(auxp.prcsr_blk   ),
      .blkbyusr(auxp.usr_blk     ),
      .bufsel  (auxp.src_bufsel  ),
      .sig2src (sig2src          ),
      .sigsrced(sigsrced         )
   );
endmodule
/*! 根据Avalon接口配置参数及接口辅助信号传递用交互信号端口列表的输出端阻塞状态选择直连信号或缓存信号输出 */
module avalon_srcsig_byauxp_ifCfg #(
   parameter avalon_pkg::ifCfg IC      = avalon_pkg::deft_ifCfg,  ///< Avalon接口配置参数
   parameter int               SIGBITW = 1                        ///< 信号位宽
) (
   avalon_if.crp           crp,                    ///< Avalon接口的时钟及复位信号端口列表
   avalon_if.auxp          auxp,                   ///< Avalon接口的辅助信号传递用交互信号端口列表
   input  wire[SIGBITW-1:0]sig2src,                ///< 待输出的直连信号
   output wire[SIGBITW-1:0]sigsrced                ///< 按阻塞状态选择的输出信号
);
   generate
      if (avalon_pkg::bufSrc_of_ifCfg(IC)) begin
         avalon_srcsig_bybufsel_auxp #(
            .SIGBITW (SIGBITW )
         ) bufsi(
            .crp     (crp     ),
            .auxp    (auxp    ),
            .sig2src (sig2src ),
            .sigsrced(sigsrced)
         );
      end
      else assign sigsrced = sig2src;
   endgenerate
endmodule
/*! \brief 产生同步于信号产生使能信号的信号 */
module avalon_auxsig_sync #(
   parameter int        SIGBITW = 1,               ///< 待同步的信号位宽
   parameter int signed LATENCY = 1,               ///< 延迟输出时钟数，<= 0 时表示无延迟输出
   parameter bit        SCLRRAM = 1'b0,            ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        REG_PRI = 1'b0             ///< 优先使用寄存器实现移阶标志，1'b1:优先使用寄存器资源实现移阶寄存器，1'b0:按配置自动选择寄存器或者RAM资源实现移阶寄存器
) (
   input  bit              clk,                    ///< 驱动时钟
   input  wire             aclr, sclr, clken,      ///< aclr-异步复位信号，sclr-同步复位信号，clken-接口信号产生使能信号，高电平有效
   input  wire[SIGBITW-1:0]sink_sig,               ///< 输入待同步信号
   output wire[SIGBITW-1:0]src_sig,                ///< 输出同步后信号
   output wire             reseting                ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #sink_sig 上所有的输入都将被忽略
);
   shiftfixtaps #(
      .DATABITW   (SIGBITW),
      .TAP_DIST   (LATENCY),
      .SCLR_ONRAM (SCLRRAM),
      .IMPLBYLOGIC(REG_PRI)
   ) sta_i(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken   (clken   ),
      .shiftin (sink_sig),
      .shiftout(src_sig ),
      .reseting(reseting)
   );
endmodule
/*! \brief 产生并通过Avalon辅助信号传递接口输出Avalon接口的非标准接口信号 */
module avalon_auxsigifi_sync #(
   parameter int        SIGBITW = 1,               ///< 待同步信号数组元素位宽
   parameter int signed LATENCY = 1,               ///< 延迟输出时钟数，<= 0 时表示无延迟输出
   parameter bit        SCLRRAM = 1'b0,            ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        REG_PRI = 1'b0             ///< 优先使用寄存器实现移阶标志，1'b1:优先使用寄存器资源实现移阶寄存器，1'b0:按配置自动选择寄存器或者RAM资源实现移阶寄存器
) (
   input  bit      clk,                            ///< 驱动时钟
   input  wire     aclr, sclr, clken,              ///< aclr-异步复位信号，sclr-同步复位信号，clken-接口信号产生使能信号，高电平有效
   avalon_auxsigif ifi,                            ///< Avalon辅助信号传递接口实例
   output wire     reseting                        ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #sink_sig 上所有的输入都将被忽略
);
   initial if ($bits(ifi.sink_sig) != SIGBITW)
      $error("avalon_auxsigifi_sync : bitwidth of ifi.sink_sig(%0d) does not match parameter SIGBITW(%0d)", $bits(ifi.sink_sig), SIGBITW);
   avalon_auxsig_sync #(
      .SIGBITW(SIGBITW),
      .LATENCY(LATENCY),
      .SCLRRAM(SCLRRAM),
      .REG_PRI(REG_PRI)
   ) aas_i(
      .clk     (clk           ),
      .aclr    (aclr          ),
      .sclr    (sclr          ),
      .clken   (clken         ),
      .sink_sig(ifi.sink_sig  ),
      .src_sig (ifi.src_sig   ),
      .reseting(reseting      )
   );
endmodule
/*! \brief 产生并通过Avalon辅助信号合并数组传递接口输出Avalon接口的非标准接口信号 */
module avalon_packedarray_auxsigifi_sync #(
   parameter int        SIGBITW  = 1,              ///< 待同步信号数组元素位宽
   parameter int        ARRAYSIZ = 1,              ///< 待同步信号数组元素个数
   parameter int signed LATENCY  = 1,              ///< 延迟输出时钟数，<= 0 时表示无延迟输出
   parameter bit        SCLRRAM  = 1'b0,           ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        REG_PRI  = 1'b0            ///< 优先使用寄存器实现移阶标志，1'b1:优先使用寄存器资源实现移阶寄存器，1'b0:按配置自动选择寄存器或者RAM资源实现移阶寄存器
) (
   input  bit                    clk,              ///< 驱动时钟
   input  wire                   aclr, sclr, clken,///< aclr-异步复位信号，sclr-同步复位信号，clken-接口信号产生使能信号，高电平有效
   avalon_packedarray_auxsigif   ifi,
   output wire                   reseting          ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #sink_sig 上所有的输入都将被忽略
);
   initial if (SIGBITW != $size(ifi.sink_sigs, 2))
      $error("avalon_packedarray_auxsigifi_sync: parameter SIGBITW(%0d) does not match the element's bitwidth of array ifi.sink_sigs(%0d)", SIGBITW, $size(ifi.sink_sigs, 2));
   initial if (ARRAYSIZ != $size(ifi.sink_sigs,1))
      $error("avalon_packedarray_auxsigifi_sync: parameter ARRAYSIZ(%0d) does not match the size of array ifi.sink_sigs(%0d)", ARRAYSIZ, $size(ifi.sink_sigs, 1));
   avalon_packedarray_auxsig_sync #(
      .SIGBITW (SIGBITW ),
      .ARRAYSIZ(ARRAYSIZ),
      .LATENCY (LATENCY ),
      .SCLRRAM (SCLRRAM ),
      .REG_PRI (REG_PRI )
   ) apaasisi(
      .clk        (clk           ),
      .aclr       (aclr          ),
      .sclr       (sclr          ),
      .clken      (clken         ),
      .sink_sigs  (ifi.sinksigs  ),
      .src_sigs   (ifi.srcsigs   ),
      .reseting   (reseting      )
   );
endmodule
/*! \brief 产生并通过Avalon辅助信号非合并数组传递接口输出Avalon接口的非标准接口信号 */
module avalon_unpackedarray_auxsigifi_sync #(
   parameter int        SIGBITW  = 1,              ///< 待同步信号数组元素位宽
   parameter int        ARRAYSIZ = 1,              ///< 待同步信号数组元素个数
   parameter int signed LATENCY  = 1,              ///< 延迟输出时钟数，<= 0 时表示无延迟输出
   parameter bit        SCLRRAM  = 1'b0,           ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        REG_PRI  = 1'b0            ///< 优先使用寄存器实现移阶标志，1'b1:优先使用寄存器资源实现移阶寄存器，1'b0:按配置自动选择寄存器或者RAM资源实现移阶寄存器
) (
   input  bit                    clk,              ///< 驱动时钟
   input  wire                   aclr, sclr, clken,///< aclr-异步复位信号，sclr-同步复位信号，clken-接口信号产生使能信号，高电平有效
   avalon_unpackedarray_auxsigif ifi,
   output wire                   reseting          ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #sink_sig 上所有的输入都将被忽略
);
   initial if (SIGBITW != $size(ifi.sink_sigs, 2))
      $error("avalon_unpackedarray_auxsigifi_sync: parameter SIGBITW(%0d) does not match the element's bitwidth of array ifi.sink_sigs(%0d)", SIGBITW, $size(ifi.sink_sigs, 2));
   initial if (ARRAYSIZ != $size(ifi.sink_sigs,1))
      $error("avalon_unpackedarray_auxsigifi_sync: parameter ARRAYSIZ(%0d) does not match the size of array ifi.sink_sigs(%0d)", ARRAYSIZ, $size(ifi.sink_sigs, 1));
   avalon_unpackedarray_auxsig_sync #(
      .SIGBITW (SIGBITW ),
      .ARRAYSIZ(ARRAYSIZ),
      .LATENCY (LATENCY ),
      .SCLRRAM (SCLRRAM ),
      .REG_PRI (REG_PRI )
   ) apaasisi(
      .clk        (clk           ),
      .aclr       (aclr          ),
      .sclr       (sclr          ),
      .clken      (clken         ),
      .sink_sigs  (ifi.sinksigs  ),
      .src_sigs   (ifi.srcsigs   ),
      .reseting   (reseting      )
   );
endmodule
/*! \brief 产生并通过Avalon辅助信号合并数组及额外数据传递接口输出Avalon接口的非标准接口信号 */
module avalon_packedarray_extd_auxsigifi_sync #(
   parameter int        SIGBITW  = 1,              ///< 待同步信号数组元素位宽
   parameter int        ARRAYSIZ = 1,              ///< 待同步信号数组元素个数
   parameter int        EXTDBITW = 1,              ///< 待同步额外信号位宽
   parameter int signed LATENCY  = 1,              ///< 延迟输出时钟数，<= 0 时表示无延迟输出
   parameter bit        SCLRRAM  = 1'b0,           ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        REG_PRI  = 1'b0            ///< 优先使用寄存器实现移阶标志，1'b1:优先使用寄存器资源实现移阶寄存器，1'b0:按配置自动选择寄存器或者RAM资源实现移阶寄存器
) (
   input  bit                       clk,              ///< 驱动时钟
   input  wire                      aclr, sclr, clken,///< aclr-异步复位信号，sclr-同步复位信号，clken-接口信号产生使能信号，高电平有效
   avalon_packedarray_extd_auxsigif ifi,
   output wire                      reseting          ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                      ///< \attention 当模块处于正在复位状态时， #sink_sig 上所有的输入都将被忽略
);
   initial if (SIGBITW != $size(ifi.sink_sigs, 2))
      $error("avalon_packedarray_auxsigifi_sync: parameter SIGBITW(%0d) does not match the element's bitwidth of array ifi.sink_sigs(%0d)", SIGBITW, $size(ifi.sink_sigs, 2));
   initial if (ARRAYSIZ != $size(ifi.sink_sigs,1))
      $error("avalon_packedarray_auxsigifi_sync: parameter ARRAYSIZ(%0d) does not match the size of array ifi.sink_sigs(%0d)", ARRAYSIZ, $size(ifi.sink_sigs, 1));
   avalon_packedarray_extd_auxsig_sync #(
      .SIGBITW (SIGBITW ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .LATENCY (LATENCY ),
      .SCLRRAM (SCLRRAM ),
      .REG_PRI (REG_PRI )
   ) apaasisi(
      .clk        (clk           ),
      .aclr       (aclr          ),
      .sclr       (sclr          ),
      .clken      (clken         ),
      .sink_sigs  (ifi.sink_sigs ),
      .sink_extd  (ifi.sink_extd ),
      .src_sigs   (ifi.src_sigs  ),
      .src_extd   (ifi.src_extd  ),
      .reseting   (reseting      )
   );
endmodule
/*! \brief 产生并通过Avalon辅助信号非合并数组及额外数据传递接口输出Avalon接口的非标准接口信号 */
module avalon_unpackedarray_extd_auxsigifi_sync #(
   parameter int        SIGBITW  = 1,              ///< 待同步信号数组元素位宽
   parameter int        ARRAYSIZ = 1,              ///< 待同步信号数组元素个数
   parameter int        EXTDBITW = 1,              ///< 待同步额外信号位宽
   parameter int signed LATENCY  = 1,              ///< 延迟输出时钟数，<= 0 时表示无延迟输出
   parameter bit        SCLRRAM  = 1'b0,           ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        REG_PRI  = 1'b0            ///< 优先使用寄存器实现移阶标志，1'b1:优先使用寄存器资源实现移阶寄存器，1'b0:按配置自动选择寄存器或者RAM资源实现移阶寄存器
) (
   input  bit                          clk,              ///< 驱动时钟
   input  wire                         aclr, sclr, clken,///< aclr-异步复位信号，sclr-同步复位信号，clken-接口信号产生使能信号，高电平有效
   avalon_unpackedarray_extd_auxsigif  ifi,
   output wire                         reseting          ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                         ///< \attention 当模块处于正在复位状态时， #sink_sig 上所有的输入都将被忽略
);
   initial if (SIGBITW != $size(ifi.sink_sigs, 2))
      $error("avalon_unpackedarray_auxsigifi_sync: parameter SIGBITW(%0d) does not match the element's bitwidth of array ifi.sink_sigs(%0d)", SIGBITW, $size(ifi.sink_sigs, 2));
   initial if (ARRAYSIZ != $size(ifi.sink_sigs,1))
      $error("avalon_unpackedarray_auxsigifi_sync: parameter ARRAYSIZ(%0d) does not match the size of array ifi.sink_sigs(%0d)", ARRAYSIZ, $size(ifi.sink_sigs, 1));
   avalon_unpackedarray_extd_auxsig_sync #(
      .SIGBITW (SIGBITW ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .LATENCY (LATENCY ),
      .SCLRRAM (SCLRRAM ),
      .REG_PRI (REG_PRI )
   ) apaasisi(
      .clk        (clk           ),
      .aclr       (aclr          ),
      .sclr       (sclr          ),
      .clken      (clken         ),
      .sink_sigs  (ifi.sink_sigs ),
      .sink_extd  (ifi.sink_extd ),
      .src_sigs   (ifi.src_sigs  ),
      .src_extd   (ifi.src_extd  ),
      .reseting   (reseting      )
   );
endmodule
/*!
 * \brief 产生同步于Avalon接口的信号
 * \attention 
 * - 本模块仅适用于使用 #avalon_prcsrmake 模块产生接口信号的Avalon接口节点，对处理器内部存在多级级联的Avalon节点，
 * 需要在内部逐级调用本模块才能产生与节点完全同步的辅助信号。
 * - 本模块的同步延迟量可自由设置
 */
module avalon_auxsig_syncwith_avalonif #(
   parameter int        SIGBITW    = 1,            ///< 待同步信号位宽
   parameter bit        BUF_SRCSIG = 1'b1,         ///< 缓存输出信号标志，用于对输出信号作时序缓存，并在 #src_valid 置位时 #src_blk 信号置位后下一个时钟切换至缓存输出。
                                                   ///< 1'b1 - 对输出信号做时序缓存， 1'b0 - 不做时序缓存。
                                                   ///< \attention 对输出信号做时序缓存的目的是以消耗额外的寄存器资源为代价，将Avalon接口 #src_blk 到 #sink_blk 的信
                                                   ///< 号传递电路以时序逻辑代替组合逻辑，避免Avalon接口链中从尾节点 #src_blk 传递至首节点 #sink_blk 产生路径过长的组合
                                                   ///< 逻辑电路，从而恶化时序性能。
   parameter int signed LATENCY    = 1,            ///< 延迟输出时钟数，<= 0 时表示无延迟输出
   parameter bit        SCLRRAM    = 1'b0,         ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        REG_PRI    = 1'b0          ///< 优先使用寄存器实现移阶标志，1'b1:优先使用寄存器资源实现移阶寄存器，1'b0:按配置自动选择寄存器或者RAM资源实现移阶寄存器
) (
   avalon_if.crp           crp,                    ///< Avalon接口时钟及复位信号端口列表
   avalon_if.auxp          auxp,                   ///< Avalon接口的辅助信号传递用交互信号端口列表
   input  wire[SIGBITW-1:0]sink_sig,               ///< 输入待同步信号
   output wire[SIGBITW-1:0]src_sig,                ///< 输出同步后信号
   output wire             reseting                ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #sink_sig 上所有的输入都将被忽略);
);
   wire[SIGBITW-1:0] buf_sinksig;
   avalon_auxsig_sync #(
      .SIGBITW(SIGBITW),
      .LATENCY(LATENCY),
      .SCLRRAM(SCLRRAM),
      .REG_PRI(REG_PRI)
   ) aasi(
      .clk     (crp.clk                      ),
      .aclr    (crp.aclr                     ),
      .sclr    (crp.sclr                     ),
      .clken   ((~auxp.prcsr_blk)&crp.clken  ),
      // \attention
      // -# #clken 不用考虑 ~p.src_blk ，因为 p.src_blk 有效时是否阻塞输入数据由用户定义的处理器决定
      // -# #clken 也不考虑 ~p.sink_blk，因为当节点处理器以时分复用模式处理前级节点输入数据时， p.sink_blk 带有节点处理器因时分复用而向前级节点提出的阻塞请求，而本节点处理器实际上并未阻塞
      .sink_sig(sink_sig                     ),
      .src_sig (buf_sinksig                  ),
      .reseting(reseting                     )
   );
   generate if (BUF_SRCSIG) begin
      avalon_srcsig_bybufsel_auxp #(
         .SIGBITW(SIGBITW)
      ) bufsrci(
         .crp     (crp        ),
         .auxp    (auxp       ),
         .sig2src (buf_sinksig),
         .sigsrced(src_sig    )
      );
   end else assign src_sig = buf_sinksig;
   endgenerate
endmodule
/*!
 * \brief 产生同步于Avalon接口的信号
 * \attention 
 * - 本模块仅适用于使用 #avalon_prcsrmake 模块产生接口信号的Avalon接口节点，对处理器内部存在多级级联的Avalon节点，
 * 需要在内部逐级调用本模块才能产生与节点完全同步的辅助信号。
 * - 本模块的同步延迟量固定为与Avalon接口处理延迟相同，不可自由设置
 */
module avalon_auxsig_syncwith_avalonifcfg #(
   parameter int               SIGBITW = 1,                       ///< 待同步信号位宽
   parameter avalon_pkg::ifCfg IC      = avalon_pkg::deft_ifCfg,  ///< Avalon接口配置参数
   parameter bit               SCLRRAM = 1'b0,                    ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit               REG_PRI = 1'b0                     ///< 优先使用寄存器实现移阶标志，1'b1:优先使用寄存器资源实现移阶寄存器，1'b0:按配置自动选择寄存器或者RAM资源实现移阶寄存器
) (
   avalon_if.crp           crp,                    ///< Avalon接口时钟及复位信号端口列表
   avalon_if.auxp          auxp,                   ///< Avalon接口的辅助信号传递用交互信号端口列表
   input  wire[SIGBITW-1:0]sink_sig,               ///< 输入待同步信号
   output wire[SIGBITW-1:0]src_sig,                ///< 输出同步后信号
   output wire             reseting                ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #sink_sig 上所有的输入都将被忽略);
);
   avalon_auxsig_syncwith_avalonif #(
      .SIGBITW    (SIGBITW                         ),
      .BUF_SRCSIG (avalon_pkg::bufSrc_of_ifCfg(IC) ),
      .LATENCY    (avalon_pkg::prclat_of_ifCfg(IC) ),
      .SCLRRAM    (SCLRRAM                         ),
      .REG_PRI    (REG_PRI                         )
   ) aasai(
      .crp     (crp     ),
      .auxp    (auxp    ),
      .sink_sig(sink_sig),
      .src_sig (src_sig ),
      .reseting(reseting)
   );
endmodule
/*!
 * \brief 产生同步于Avalon接口的Avalon辅助信号接口数组
 * \attention 
 * - 本模块仅适用于使用 #avalon_prcsrmake 模块产生接口信号的Avalon接口节点，对处理器内部存在多级级联的Avalon节点，
 * 需要在内部逐级调用本模块才能产生与节点完全同步的辅助信号。
 * - 本模块的同步延迟量可自由设置
 */
module avalon_auxsigifi_syncwith_avalonif #(
   parameter int        SIGBITW    = 1,            ///< 待同步信号位宽
   parameter bit        BUF_SRCSIG = 1'b1,         ///< 缓存输出信号标志，用于对输出信号作时序缓存，并在 #src_valid 置位时 #src_blk 信号置位后下一个时钟切换至缓存输出。
                                                   ///< 1'b1 - 对输出信号做时序缓存， 1'b0 - 不做时序缓存。
                                                   ///< \attention 对输出信号做时序缓存的目的是以消耗额外的寄存器资源为代价，将Avalon接口 #src_blk 到 #sink_blk 的信
                                                   ///< 号传递电路以时序逻辑代替组合逻辑，避免Avalon接口链中从尾节点 #src_blk 传递至首节点 #sink_blk 产生路径过长的组合
                                                   ///< 逻辑电路，从而恶化时序性能。
   parameter int signed LATENCY    = 1,            ///< 延迟输出时钟数，<= 0 时表示无延迟输出
   parameter bit        SCLRRAM    = 1'b0,         ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit        REG_PRI    = 1'b0          ///< 优先使用寄存器实现移阶标志，1'b1:优先使用寄存器资源实现移阶寄存器，1'b0:按配置自动选择寄存器或者RAM资源实现移阶寄存器
) (
   avalon_if.crp     crp,                          ///< Avalon接口时钟及复位信号端口列表
   avalon_if.auxp    auxp,                         ///< Avalon接口的辅助信号传递用交互信号端口列表
   avalon_auxsigif   ifi,                          ///< Avalon辅助信号传递接口实例
   output wire       reseting                      ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #sink_sig 上所有的输入都将被忽略);
);
   initial if ($bits(ifi.sink_sig) != SIGBITW)
      $error("avalon_auxsigifi_syncwith_avalonif: bitwidth of ifi.sink_sig(%0d) does not match parameter SIGBITW(%0d)", $bits(ifi.sink_sig), SIGBITW);
   avalon_auxsig_syncwith_avalonif #(
      .SIGBITW    (SIGBITW    ),
      .BUF_SRCSIG (BUF_SRCSIG ),
      .LATENCY    (LATENCY    ),
      .SCLRRAM    (SCLRRAM    ),
      .REG_PRI    (REG_PRI    )
   ) aasai(
      .crp     (crp           ),
      .auxp    (auxp          ),
      .sink_sig(ifi.sink_sig  ),
      .src_sig (ifi.src_sig   ),
      .reseting(reseting      )
   );
endmodule
/*!
 * \brief 产生同步于Avalon接口的Avalon辅助信号接口数组
 * \attention 
 * - 本模块仅适用于使用 #avalon_prcsrmake 模块产生接口信号的Avalon接口节点，对处理器内部存在多级级联的Avalon节点，
 * 需要在内部逐级调用本模块才能产生与节点完全同步的辅助信号。
 * - 本模块的同步延迟量固定为与Avalon接口处理延迟相同，不可自由设置
 */
module avalon_auxsigifi_syncwith_avalonifcfg #(
   parameter int               SIGBITW = 1,                       ///< 待同步信号位宽
   parameter avalon_pkg::ifCfg IC      = avalon_pkg::deft_ifCfg,  ///< Avalon接口配置参数
   parameter bit               SCLRRAM = 1'b0,                    ///< 用同步复位信号触发对使用的RAM资源写入全零数据，1'b1:同步复位信号触发对RAM资源写入全零数据，1'b0:同步复位信号不触发RAM资源的清零
   parameter bit               REG_PRI = 1'b0                     ///< 优先使用寄存器实现移阶标志，1'b1:优先使用寄存器资源实现移阶寄存器，1'b0:按配置自动选择寄存器或者RAM资源实现移阶寄存器
) (
   avalon_if.crp     crp,                          ///< Avalon接口时钟及复位信号端口列表
   avalon_if.auxp    auxp,                         ///< Avalon接口的辅助信号传递用交互信号端口列表
   avalon_auxsigif   ifi,                          ///< Avalon辅助信号传递接口实例
   output wire       reseting                      ///< 正在复位状态信号，高电平(1)表示模块正在复位，低电平(0)表示模块已准备好工作
                                                   ///< \attention 当模块处于正在复位状态时， #sink_sig 上所有的输入都将被忽略);
);
   initial if ($bits(ifi.sink_sig) != SIGBITW)
      $error("avalon_auxsigifi_syncwith_avalonif: bitwidth of ifi.sink_sig(%0d) does not match parameter SIGBITW(%0d)", $bits(ifi.sink_sig), SIGBITW);
   avalon_auxsigifi_syncwith_avalonif #(
      .SIGBITW    (SIGBITW                         ),
      .BUF_SRCSIG (avalon_pkg::bufSrc_of_ifCfg(IC) ),
      .LATENCY    (avalon_pkg::prclat_of_ifCfg(IC) ),
      .SCLRRAM    (SCLRRAM                         ),
      .REG_PRI    (REG_PRI                         )
   ) aasai(
      .crp     (crp     ),
      .auxp    (auxp    ),
      .ifi     (ifi     ),
      .reseting(reseting)
   );
endmodule
/*!
 * \brief Avalon接口从输入端数据序列长度产生输出端数据序列长度及载入信号
 * \details 输出端数据序列长度及载入信号在输入序列对应的输出序列的输出时间范围内，最早与输出序列的 #src_sop 对齐，最晚与输出序列的 #src_eop对齐：
 * \attention 本模块仅适用于输出数据序列与输入输出序列时序存在严格的对应关系的数据处理任务，
 * 对不满足该条件的任务，需要单独设计输出端数据序列长度及载入信号。
 */
module avalon_srccnt_onsink #(
   parameter avalon_pkg::ifCfg IC      = avalon_pkg::deft_ifCfg,  ///< Avalon接口配置参数
   parameter int               TDMTAPS = 1                        ///< 时分复用处理拍数
) (
   avalon_if.crp                                         crp,     ///< Avalon接口时钟及复位信号端口列表
   avalon_if.auxp                                        auxp,    ///< Avalon接口的辅助信号传递用交互信号端口列表
   output wire[avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC)-1:0]src_cnt, ///< 待载入输出数据序列长度
   output wire                                           rdysig   ///< 输出序列长度就绪信号，高电平(1)有效，
);
   // \attention #src_cnt 的计算必须同步至Avalon接口时序，因为当前一序列长度大于1，而紧接着的序列
   // 长度为1时，在 #LATENCY >= 1 的情况下会在前一序列正在输出时破坏掉前一序列的 #src_cnt ，从而破
   // 坏前一序列的输出。
   localparam int maxSink = avalon_pkg::maxSink_of_ifCfg(IC);
   localparam int bitwof_sinkcnt = avalon_pkg::bitwOfDataSeqLen(maxSink);
   initial if (bitwof_sinkcnt != $bits(auxp.sink_cnt)) 
      $error("avalon_srccnt_onsink: the bitwidth of sinkcnt(%0d) on IC.maxSink(%0d) does not match the bitwidth of auxp.sink_cnt(%0d)", bitwof_sinkcnt, maxSink, $bits(auxp.sink_cnt));
   localparam int maxSrc = avalon_pkg::maxSrc_of_ifCfg(IC);
   localparam int bitwof_srccnt = avalon_pkg::bitwOfDataSeqLen(maxSrc);
   initial if (bitwof_srccnt != $bits(auxp.src_cnt))
      $error("avalon_srccnt_onsink: the bitwidth of srccnt(%0d) on IC.maxSrc(%0d) does not match the bitwidth of auxp.src_cnt(%0d)", bitwof_srccnt, maxSrc, $bits(auxp.src_cnt));
   avalon_auxsigif #(
      .AUXSIG_BITW(1 + bitwof_sinkcnt)
   ) data2calc_ifi();
   assign data2calc_ifi.sink_sig = {(auxp.sink_eop & ~auxp.sink_blk), auxp.sink_cnt};
   localparam int signed latency = avalon_pkg::prclat_of_ifCfg(IC);
   avalon_auxsigifi_sync #(
      .SIGBITW(bitwof_sinkcnt + 1   ),
      .LATENCY(latency > 2 ? 1 : 0  ),
      .SCLRRAM(1'b0                 ),
      .REG_PRI(1'b0                 )
   ) data2calc_sync_i(
      .clk     (crp.clk                      ),
      .aclr    (crp.aclr                     ),
      .sclr    (crp.sclr                     ),
      .clken   ((~auxp.prcsr_blk)&crp.clken  ),
      .ifi     (data2calc_ifi                ),
      .reseting(                             )
   );
   avalon_auxsigif #(
      .AUXSIG_BITW(1 + bitwof_srccnt)
   ) data2lat_ifi();
   localparam int bitwof_multres = avalon_pkg::bitwOfDataSeqLen(maxSink*TDMTAPS);
   wire[bitwof_multres-1:0] multres;
   umultconst #(
      .MINOF_VAR  (0       ),
      .MAXOF_VAR  (maxSink ),
      .CONSTARG   (TDMTAPS ),
      .RESBITW    (0       ),
      .USEHRDCOR  (1'b0    ),
      .RNDRESLSB  (1'b1    ),
      .DELAYTAPS  (0       )
   ) sinkcnt2srccnt_mult(
      .clk        (crp.clk                                  ),
      .aclr       (crp.aclr                                 ),
      .sclr       (crp.sclr                                 ),
      .clken      (crp.clken&~auxp.prcsr_blk                ),
      .var_arg    (data2calc_ifi.src_sig[bitwof_sinkcnt-1:0]),
      .var_valid  (1'b1                                     ),
      .res        (multres                                  ),
      .res_valid  (                                         )
   );
   assign data2lat_ifi.sink_sig[bitwof_srccnt-1:0] = (bitwof_srccnt)'(multres);
   assign data2lat_ifi.sink_sig[bitwof_srccnt]     = data2calc_ifi.src_sig[bitwof_sinkcnt];
   avalon_auxsigifi_sync #(
      .SIGBITW(bitwof_srccnt + 1    ),
      .LATENCY(latency > 1 ? 1 : 0  ),
      .SCLRRAM(1'b0                 ),
      .REG_PRI(1'b0                 )
   ) data2lat_sync_i(
      .clk     (crp.clk                      ),
      .aclr    (crp.aclr                     ),
      .sclr    (crp.sclr                     ),
      .clken   ((~auxp.prcsr_blk)&crp.clken  ),
      .ifi     (data2lat_ifi                 ),
      .reseting(                             )
   );
   wire[bitwof_srccnt-1:0] srccnt2lat, srccnt2o;
   assign srccnt2lat = data2lat_ifi.src_sig[bitwof_srccnt-1:0];
   wire rdysig2lat, rdysig2o;
   assign rdysig2lat = data2lat_ifi.src_sig[bitwof_srccnt];
   localparam bit bufSrc = avalon_pkg::bufSrc_of_ifCfg(IC);
   genvar i; generate if (latency <= 3) begin
      assign srccnt2o = srccnt2lat;
      assign rdysig2o = rdysig2lat;
   end else begin
      /*
       * #sink_cnt < #latency 时，队列输出 #src_cnt 和 #loadsig
       * #sink_cnt >= #latency 时，直接输出 #src_cnt 和 #loadsig
       */
      /*
       * \details - #onway_q 存储输入数据序列在途状态在延迟处理过程中的延迟拍数索引：
       * \p sink:         -----[SOP]------------------------------[EOP]------------------------------
       * \p srccnt2lat:   --------------------------------------------------[SCO]--------------------
       * \p src:          -----------------------------------------------------------------[SOP]-----
       * \p onway_q{0=>1}:----------[ 1 ][ 2 ]..............................[ISC]..........[ L ]-----
       * \p onway_q{1=>0}:---------------------------------------------[ 1 ][ 2 ]........
       * \p 当 #srccnt2lat 和 #rdysig2lat 在 [SCO]时刻输出时， #onway_q[ISC] 刚好从0变为1，此时 #srccnt2lat
       * 和 #rdysig2lat 必须再延迟 L - ISC 拍才能向Avalon接口输出端赋值。
       * \p 为此，可设计类似于FIFO的存储设备，存储在 [SCO] / [ISC] 时刻输出的 #srccnt2lat 和 #rdysig2lat ，存储
       * 设备每个时钟向外输出相对 [SOP] 延迟 #LATENCY 拍的数据。
       * \p [SCO]的发生时刻范围对应于 #onway_q 的 [ 2 ] 到 [ L-1 ] 。当 #srccnt2lat 和 #rdysig2lat 输出时，可
       * 对 #onway_q 从MSB向LSB搜索比特值为1的比特位位置，以该比特位置作为索引将 #srccnt2lat 和 #rdysig2lat 存
       * 入类似FIFO存储设备，则再延迟 L - ISC 拍即可从类似FIFO存储设备的输出端采样到 #srccnt2lat 和 #rdysig2lat 。
       * - 基于上述分析，有：
       *   - 类似FIFO存储设备只需存储 [ 2 ] 至 [L-1] 时刻的数据，存储器深度 L-2 ；
       *   - [ISC] 对应存储设备的存储索引是 ISC-2 ；
       *   - FIFO存储设备的底部读取索引应该是 L-2-1 ；
       *   - 从 #onway_q 提取 [ISC] 对应存储索引的比特位范围是 2 －－ L-1
       */
      logic[latency-1:1]onway_q, sinkeop_q;
      // \attention 
      // - onway_q[1]由0变1是 #sink_sop 后的第二拍；
      // - onway_q[LATENCY-1]由0变1是 #src_sop 为1对应的时刻
      assign sinkeop_q[1] = auxp.sink_eop&(~auxp.sink_blk);
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
         if      (crp.aclr)                  onway_q <= '0;
         else if (crp.sclr)                  onway_q <= '0;
         else if (auxp.prcsr_blk|~crp.clken) onway_q <= onway_q;
         else begin
            /* \attention 应用由 sop 和 eop 产生的 onway 信号而不是直接用 valid 信号来标识输入数据序列在途，
             * 原因是 valid 信号有时会因为前一节点处理器没有数据可输出而主动变低，从而错误展示输入数据序列在途状态。
             */
            if      (auxp.sink_sop&~auxp.sink_blk) onway_q[1] <= 1'b1;
            else if (auxp.sink_eop&~auxp.sink_blk) onway_q[1] <= 1'b0;
            else                                   onway_q[1] <= onway_q[1];
            onway_q[latency-1:2] <= onway_q[latency-2:1];
         end
         if      (crp.aclr)sinkeop_q[latency-1:2] <= '0;
         else if (crp.sclr)sinkeop_q[latency-1:2] <= '0;
         else              sinkeop_q[latency-1:2] <= (auxp.prcsr_blk|(~crp.clken)) ? sinkeop_q[latency-1:2] : sinkeop_q[latency-2:1];
      end
      localparam int bitwOfLatIdx = mux_pkg::idxbitw_ofmux(latency - 3);
      logic[bitwOfLatIdx-1:0] latidx;
      selsig2idx #(
         .SELSIGBITW (latency - 3),
         .PRI_MSB    (1'b1       ),
         .DLYTAPS    (1          )
      ) onway_q_2_lastLatIdx_i(
         .clk     (crp.clk                      ),
         .aclr    (crp.aclr                     ),
         .sclr    (crp.sclr                     ),
         .clken   ((~auxp.prcsr_blk)&crp.clken  ),
         .selsig  (onway_q[latency-3:1]         ),
         .idx     (latidx                       ),
         .valid   (                             )
      );
      wire outTim = onway_q[latency-1];
      wire[bitwof_srccnt:0]srccnt_rdy_fifo_in, srccnt_rdy_fifo_out;
      wire fifo_empty, fifo_wr_en, fifo_rd_en;
      assign srccnt_rdy_fifo_in = {rdysig2lat, srccnt2lat};
      fifo_1clk #(
         .UNITBITW   (bitwof_srccnt+1              ),
         .DEPTH      (latency <= 4 ? 2 : latency-3 ),
         .SHOWAHEAD  (1'b1                         )
      ) srccnt_rdy_fifo(
         .clk     (crp.clk                                                                ),
         .aclr    (crp.aclr                                                               ),
         .sclr    (crp.sclr                                                               ),
         .wrreq   (crp.clken & (~auxp.prcsr_blk) & rdysig2lat & ((~fifo_empty)|fifo_wr_en)),
         .rdreq   (crp.clken & (~auxp.prcsr_blk) & (~rdysig2lat) & fifo_rd_en             ),
         .d       (srccnt_rdy_fifo_in                                                     ),
         .q       (srccnt_rdy_fifo_out                                                    ),
         .qlk     (                                                                       ),
         .qp      (                                                                       ),
         .usedw   (                                                                       ),
         .empty   (fifo_empty                                                             ),
         .full    (                                                                       ),
         .overflow(                                                                       ),
         .undrflow(                                                                       )
      );
      wire[bitwof_srccnt-1:0] srccnt_queue_out = srccnt_rdy_fifo_out[bitwof_srccnt-1:0];
      wire                    rdysig_queue_out = srccnt_rdy_fifo_out[bitwof_srccnt]&(~fifo_empty);
      logic rdysig_qo, rdysig_outted;
      wire  rdysig_qo_en = (~rdysig_queue_out)&(~rdysig_outted);
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
         if      (crp.aclr)                  rdysig_qo <= '0;
         else if (crp.sclr)                  rdysig_qo <= '0;
         else if (auxp.prcsr_blk|~crp.clken) rdysig_qo <= rdysig_qo;
         else if (sinkeop_q[latency-1])      rdysig_qo <= '0;
         else                                rdysig_qo <= (outTim&rdysig2lat&rdysig_qo_en) ? '1 : rdysig_qo;
         if      (crp.aclr)                                 rdysig_outted <= '0;
         else if (crp.sclr)                                 rdysig_outted <= '0;
         else if (auxp.prcsr_blk|~crp.clken)                rdysig_outted <= rdysig_outted;
         else if (sinkeop_q[1]&(~rdysig_qo)&(~rdysig_qo_en))rdysig_outted <= '0;
         else if (sinkeop_q[latency-1])                     rdysig_outted <= '0;
         else                                               rdysig_outted <= rdysig2o ? '1 : rdysig_outted;
      end
      assign fifo_wr_en = (~outTim)|rdysig_outted;
      assign fifo_rd_en = outTim&(~rdysig_outted);
      assign rdysig2o = outTim&(rdysig2lat|rdysig_queue_out)&(~rdysig_outted);
      assign srccnt2o = (outTim&(~rdysig_outted)) ? (rdysig_queue_out ? srccnt_queue_out : (rdysig2lat ? srccnt2lat : '0)) : '0;
   end
   /*!
    * \attention 输出的 #srccnt2o 是用来在接口处理器中执行载入操作的，而不是用于接口输出的，不应按接口输出的规则做缓冲处理
    */
   assign rdysig  = rdysig2o;
   assign src_cnt = srccnt2o;
   endgenerate
endmodule
/*!
 * \brief Avalon接口处理器基本逻辑信号管理器
 * \details 生成和管理Avalon接口的 #prcsr_blk 、 #sink_blk 、 #src_bufsel 、 #src_cnt 信号
 * -# 输出数据帧长度 #src_cnt 由调用者载入并保持至输出序列结束后立刻清零；
 * -# 输出数据帧索引 #src_idx 在 #src_sop 有效后根据本节点Avalon接口信号同步计数，与输入端信号独立；
 * -# 输出数据帧尾标志 #src_eop 根据 #src_idx 的值决定置位，与输入端信号独立。
 * -# 实现 #src_blk 信号向 #sink_blk 信号的传递；
 */
module avalon_prcsr_basic_mgr #(
   parameter avalon_pkg::ifCfg IC          = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter int               AUXBITW2SRC = 0,                      ///< Avalon接口需要同步缓存输出的信号位宽
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0                    ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if.crp                                         crp,           ///< Avalon接口时钟及复位信号端口列表
   avalon_if.procp                                       procp,         ///< Avalon接口数据处理用交互信号端口列表
   input  wire                                           blksink,       ///< 用户定义的输入阻塞标志，当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire                                           blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire                                           sop2src,       ///< 接口输出端等待缓存输出的序列起始标志
   input  wire                                           nxtsop2src,    ///< 接口输出端下一拍等待输出的序列起始标志
   input  wire                                           valid2src,     ///< 接口输出端等待缓存输出的序列有效标志
   input  wire                                           nxtvalid2src,  ///< 接口输出端下一拍等待输出的序列有效标志
   input  wire[((AUXBITW2SRC>1)?AUXBITW2SRC:1)      -1:0]aux2src,       ///< 接口输出端同步等待缓存输出的辅助信号
   input  wire[avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC)-1:0]src_cnt,       ///< 待上报给Avalon接口的输出数据序列长度
   input  wire                                           srccnt_rdysig, ///< 输出数据序列长度有效信号，高电平(1)有效，当 #nxtvalid2src 为高，或者 #procp.src_nxtidx 非0时，本信号的第一个高电平触发载入 #src_cnt
   output wire[((AUXBITW2SRC>1)?AUXBITW2SRC:1)      -1:0]auxsrcd,       ///< 接口输出端已同步缓存输出的辅助信号
   output wire                                           running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic                                          sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   localparam int maxSrc = avalon_pkg::maxSrc_of_ifCfg(IC);
   localparam int bitwof_srccnt = avalon_pkg::bitwOfDataSeqLen(maxSrc);
   initial if (MIRROR_SINK == 1'b1 && BLKSINK_EN == 1'b1)
      $error("avalon_prcsr_basic_mgr: BLKSINK_EN(%0d) should be zero to avoid multiple-assignment while MIRROR_SINK(%0d) is set!", BLKSINK_EN, MIRROR_SINK);
   initial if (bitwof_srccnt != $bits(procp.src_cnt))
      $error("avalon_prcsr_basic_mgr: the bitwidth of srccnt(%0d) on IC.maxSrc(%0d) does not match the bitwidth of procp.src_cnt(%0d)", bitwof_srccnt, maxSrc, $bits(procp.src_cnt));
   localparam bit bufSrc = avalon_pkg::bufSrc_of_ifCfg(IC);//|((TDMOP_MODE > 0) ? 1'b1 : 1'b0);// BUG:或上后面的条件后， #zerocol_prcsr 中tdm2mult_ifi的处理输出将在 prcsr_blk时延迟一个时钟输出，导致时序出错
   wire blkprcsr_2use, blksink_2use;
   generate
   if (BLKPRCSR_EN) assign blkprcsr_2use = blkprcsr;
   else             assign blkprcsr_2use = 1'b0;
   if (BLKSINK_EN)assign blksink_2use = blksink;
   else           assign blksink_2use = 1'b0;
   logic sink_ongoing;
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
      if     (crp.aclr)          sink_ongoing <= 1'b0;
      else if(crp.sclr)          sink_ongoing <= 1'b0;
      else if(~crp.clken)        sink_ongoing <= sink_ongoing;
      else if(~procp.sink_valid) sink_ongoing <= sink_ongoing;
      else if(procp.sink_eop)    sink_ongoing <= 1'b0;
      else if(procp.sink_sop)    sink_ongoing <= 1'b1;
      else                       sink_ongoing <= sink_ongoing;
   end
   wire sinkbroken = sink_ongoing&(~procp.sink_valid);
   if (bufSrc == 1'b1) begin
      ///< 产生 #prcsr_blk 和 procp.src_bufsel
      logic prcsrblk2o;
      genr_bufselblk4bufsrc #(
         // \attention 
         // - 对输出端，认为数据读取发生在 #src_blk 为0的第一个时钟，因此 #src_bufsel 在 #src_blk 变0后下一个时钟变0是可取的
         // - 对输入端，则认为数据读取发生在 #src_valid 变1的第一个时钟，因此对输入端的bufsel信号则不能在blk信号变0的下一个时钟变0
         .FLOWCNT(1)
      ) src_bufsel_genr(
         .clk     (crp.clk          ),
         .aclr    (crp.aclr         ),
         .sclr    (crp.sclr         ),
         .clken   (crp.clken        ),
         .srcblk  (procp.src_blk    ),
         .vld2src (valid2src        ),
         .bufsel  (procp.src_bufsel ),
         .blkprcsr(prcsrblk2o       )
      );
      assign procp.prcsr_blk = prcsrblk2o | blkprcsr_2use | sinkbroken,
             procp.usr_blk   = blkprcsr_2use;
      ///< 产生 #procp.src_sop 、 #procp.src_valid
      wire[AUXBITW2SRC+1:0]sig2bufsrc, sigbufsrcd;
      assign sig2bufsrc[1:0] = {sop2src, valid2src},
             procp.src_sop   = sigbufsrcd[1],
             procp.src_valid = sigbufsrcd[0];
      if (AUXBITW2SRC > 0) assign sig2bufsrc[AUXBITW2SRC+1:2] = aux2src,
                                  auxsrcd                     = sigbufsrcd[AUXBITW2SRC+1:2];
      localparam bit[1+AUXBITW2SRC:0]sig4nocs = {(2+AUXBITW2SRC){1'b0}};
      bufsrc4blk #(
         .SIGBITW (2+AUXBITW2SRC          ),
         .MSK4UBLK({(2+AUXBITW2SRC){1'b1}}),
         .VAL4UBLK(sig4nocs               )
      ) srcsigsi(
         .clk     (crp.clk          ),
         .aclr    (crp.aclr         ),
         .sclr    (crp.sclr         ),
         .clken   (crp.clken        ),
         .outsel  (1'b1             ),
         .sig4nos (sig4nocs         ),
         .srcblk  (procp.src_blk    ),
         .pblk4src(procp.prcsr_blk  ),
         .blkbyusr(blkprcsr_2use    ),
         .bufsel  (procp.src_bufsel ),
         .sig2src (sig2bufsrc       ),
         .sigsrced(sigbufsrcd       )
      );
   end else begin
      ///< 产生 #prcsr_blk 和 procp.src_bufsel
      assign procp.src_bufsel = 1'b0;
      assign procp.prcsr_blk  = (procp.src_blk & valid2src) | blkprcsr_2use | sinkbroken,
             procp.usr_blk    = blkprcsr_2use;
      ///< 产生 #valid2src_use
      ///< 产生 #procp.src_sop 和 #procp.src_valid
      assign procp.src_sop   = sop2src,
             procp.src_valid = valid2src,
             auxsrcd         = aux2src;
   end
   // 维持 #src_cnt
   logic[bitwof_srccnt-1:0]srccnt2o;
   if (maxSrc > 1 || avalon_pkg::totlat_of_ifCfg(IC) > 0) begin
      wire srccnt_canload = (nxtvalid2src|(|procp.src_nxtidx));
      wire srccnt_rdy2load = srccnt_canload&srccnt_rdysig;
      logic prev_srccnt_rdy2load;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
         if      (crp.aclr)                  prev_srccnt_rdy2load <= '0;
         else if (crp.sclr)                  prev_srccnt_rdy2load <= '0;
         else if ((~crp.clken)|procp.src_blk)prev_srccnt_rdy2load <= prev_srccnt_rdy2load;
         else                                prev_srccnt_rdy2load <= srccnt_rdy2load;
         if      (crp.aclr)                                    srccnt2o <= '0;
         else if (crp.sclr)                                    srccnt2o <= '0;
         else if (~(crp.clken&srccnt_canload))                 srccnt2o <= srccnt2o;
         else if ((~prev_srccnt_rdy2load)&srccnt_rdy2load)     srccnt2o <= src_cnt;
         else if (srccnt_rdysig&nxtsop2src)                    srccnt2o <= src_cnt;
         else if ((~procp.src_blk)&procp.src_eop&(~nxtsop2src))srccnt2o <= '0;
         else                                                  srccnt2o <= srccnt2o;
      end
   end else begin
      dff_latch #(
         .UNITBITW(bitwof_srccnt)
      ) srccnt2o_latch(
         .clk  (crp.clk                                  ),
         .aclr (crp.aclr                                 ),
         .sclr (crp.sclr|(procp.src_eop&(~procp.src_blk))),
         .d    (src_cnt                                  ),
         .we   (srccnt_rdysig                            ),
         .q    (srccnt2o                                 )
      );
   end
   assign procp.src_cnt = srccnt2o;
   ///< 模拟实现同步复位信号
   always_ff @(posedge crp.clk) begin
      if (crp.sclr) sclr2aclr <= 1'b1;
      else          sclr2aclr <= 1'b0;
   end
   assign running = (~procp.prcsr_blk) & crp.clken;
   ///< 生成 #ifi.sink_blk
   if (~MIRROR_SINK) assign procp.sink_blk = (procp.prcsr_blk&procp.sink_valid) | blksink_2use;
   endgenerate
endmodule
/*!
 * \brief 普适型Avalon接口处理器信号产生器
 * \details
 * -# 待输出数据产生时刻与输出时刻之间的延迟拍数可灵活配置；
 * -# 输出数据帧长度 #src_cnt 由调用者载入并保持至输出序列结束后立刻清零；
 * -# 输出数据帧索引 #src_idx 在 #src_sop 有效后根据本节点Avalon接口信号同步计数，与输入端信号独立；
 * -# 输出数据帧尾标志 #src_eop 根据 #src_idx 的值决定置位，与输入端信号独立。
 * -# 实现 #src_blk 信号向 #sink_blk 信号的传递；
 * \attention 
 * - 本接口处理器信号产生器可兼容输出序列长度与输入序列长度有或无数学关系的应用场景；
 * - 本处理器信号产生器是普适型信号产生器，但这意味着调用者需要编写额外的代码来生成待输出数据的 #sop2src 、 #valid2src 信号；
 */
module avalon_prcsrmake #(
   parameter avalon_pkg::ifCfg IC          = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter int               TAPS2SRC    = 0,                      ///< #sop2src 、 #valid2src 信号有效时刻距接口输出时刻的延迟拍数
                                                                     ///< \attention
                                                                     ///< - 当 #IC.bufSrc == 1'b1 时，本参数应包含输出缓存的一拍延迟
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0                    ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if.crp                                         crp,           ///< Avalon接口时钟及复位信号端口列表
   avalon_if.procp                                       procp,         ///< Avalon接口数据处理用交互信号端口列表
   avalon_if.srcp                                        srcp,          ///< Avalon接口输出端信号端口列表
   input  wire                                           sop2src,       ///< 待输出数据序列起始标志，高电平(1)有效
   input  wire                                           valid2src,     ///< 待输出数据序列有效标志，高电平(1)有效
   input  wire                                           blksink,       ///< 用户定义的输入阻塞标志，当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire                                           blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire[avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC)-1:0]src_cnt,       ///< 待上报给Avalon接口的输出数据序列长度
   input  wire                                           srccnt_rdysig, ///< 输出数据序列长度有效信号，高电平(1)有效，当 #nxtvalid2src 为高，或者 #procp.src_nxtidx 非0时，本信号的第一个高电平触发载入 #src_cnt
   output wire                                           running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic                                          sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   localparam int lat_ic = avalon_pkg::prclat_of_ifCfg(IC);
   localparam int lat_bufsrc = avalon_pkg::bufSrc_of_ifCfg(IC);
   initial if (TAPS2SRC > lat_ic)
      $error("avalon_prcsrmake: TAPS2SRC(%0d) should not be greator than IC.prclat(%0d) - IC.bufSrc(%0d)", TAPS2SRC, lat_ic, lat_bufsrc);
   else if (TAPS2SRC <= lat_bufsrc)
      $error("avalon_prcsrmake: TAPS2SRC(%0d) should not be less than IC.bufSrc(%0d)!", TAPS2SRC, lat_bufsrc);
   // 假定处理器是无法挤出中间级空隙的FIFO模式，则为确保输出端数据不会在下级节点取走之前被丢弃，
   // 处理器是否可以对内部数据作移阶直接决定于两个条件：
   // 1.本级节点输出数据是否无效，即 #src_valid 是否为低电平：若满足，则说明本级处理器FIFO的内部有效数据
   // 还未到达输出端，处理器可以继续接收输入数据；否则需要查看条件2；
   // 2.下级节点上报给本级节点的 #src_blk 信号是否是低电平：若满足，则本级处理器FIFO的输出数据在本时钟周期
   // 被下级节点采样，本时钟周期的输出端数据可以被丢弃了，处理器可以继续接收一拍输入数据。
   // 
   // 为实现 #src_blk 信号向 #sink_blk 信号的传递，有两种实现方案。
   // 一种方案是直接用组合逻辑产生 #prcsr_blk 信号，进而用组合逻辑联合 #sink_lasttdm 信号产生 #sink_blk
   // 信号，该方案在级联的节点较多是会产生较长的组合逻辑路径，造成电路时序紧张，而且目前看来该方案的缺陷暂时无解。
   // 另一方案是 #src_blk 按时序逻辑打一拍后对 #prcsr_blk 赋值，再用组合逻辑联合 #prcsr_blk 和 #sink_lasttdm
   // 产生 #sink_blk 信号，从而用时序逻辑将各节点的 #sink_blk 和 #src_blk 隔离。
   // 该方案的弊端之一是：在 #src_blk 置位时无法立即使处理器的FIFO移位停止，使得 #src_blk 变高的第一个时钟内输出
   // 端的数据仍会依序改变一拍从而造成数据丢失；解决的办法是对输出端数据执行时序缓存，在 #src_blk 置位时立即切换为
   // 缓存 数据输出，同时停止更新缓存的数据，这样虽然处理器输出端虽然依序更新了一拍数据，但缓存的数据仍可用于接口输出
   // 来保证 #src_blk 为高时输出数据不变的条件。
   // 该方案的弊端之二是：在 #src_blk 由高变低时，输出数据将立即由缓存数据切换为处理器输出端数据，使得 #src_blk 变
   // 低的第一个时钟内输出端数据无法保持，从而产生丢失数据的风险；解决办法是延迟保存一个 #src_blk 的状态到寄存器
   // #prv_srcblk ，当 #src_blk 与 #prv_srcblk 中有一个是高电平时，即选择缓存数据输出，而缓存数据的更新依然根据
   // #src_blk 是否为低电平来决定。
   // 因第二种方案的弊端有办法解决，故采用第二种方案
   ///< 产生 #procp.src_sop 、 #procp.src_valid
   logic valid2buf, sop2buf;
   wire[1:0]sinksig2buf, buf_sig2presrc, buf_sig2src;
   assign sinksig2buf = {sop2src, valid2src};
   wire sig2presrc_reseting;
   localparam int lat2psrc = (TAPS2SRC <= 1)
                             ? 0
                             : (TAPS2SRC - 1);
   avalon_auxsig_sync #(
      .SIGBITW(2        ),
      .LATENCY(lat2psrc ),
      .SCLRRAM(1'b1     ),
      .REG_PRI(1'b0     )
   ) apasi(
      .clk     (crp.clk                      ),
      .aclr    (crp.aclr                     ),
      .sclr    (crp.sclr                     ),
      .clken   ((~procp.prcsr_blk)&crp.clken ),
      .sink_sig(sinksig2buf                  ),
      .src_sig (buf_sig2presrc               ),
      .reseting(sig2presrc_reseting          )
   );
   localparam bit bufSrc = avalon_pkg::bufSrc_of_ifCfg(IC);
   generate
      if (TAPS2SRC <= 0) assign sop2buf   = (procp.prcsr_blk&(~procp.src_blk)) ? 1'b0 : buf_sig2presrc[1],
                                valid2buf = (procp.prcsr_blk&(~procp.src_blk)) ? 1'b0 : buf_sig2presrc[0];
      else begin
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
            if      (crp.aclr)                     sop2buf <= 1'b0;
            else if (crp.sclr|sig2presrc_reseting) sop2buf <= 1'b0;
            else if (~crp.clken)                   sop2buf <= sop2buf;
            else if (procp.prcsr_blk)              sop2buf <= procp.src_blk ? sop2buf : 1'b0;
            else                                   sop2buf <= buf_sig2presrc[1];
         end
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
            if      (crp.aclr)                     valid2buf <= 1'b0;
            else if (crp.sclr|sig2presrc_reseting) valid2buf <= 1'b0;
            else if (~crp.clken)                   valid2buf <= valid2buf;
            else if (procp.prcsr_blk)              valid2buf <= procp.src_blk ? valid2buf : 1'b0;
            else                                   valid2buf <= buf_sig2presrc[0];
         end
      end
   endgenerate
   /// 生成输出信号
   avalon_prcsr_basic_mgr #(
      .IC         (IC         ),
      .AUXBITW2SRC(0          ),
      .MIRROR_SINK(MIRROR_SINK),
      .BLKPRCSR_EN(BLKPRCSR_EN),
      .BLKSINK_EN (1'b1       )
   ) basic_prcsr_mgri(
      .crp           (crp                                      ),
      .procp         (procp                                    ),
      .blksink       ((blksink&BLKSINK_EN)|sig2presrc_reseting ),
      .blkprcsr      (blkprcsr                                 ),
      .sop2src       (sop2buf                                  ),
      .nxtsop2src    (buf_sig2presrc[1]                        ),
      .valid2src     (valid2buf                                ),
      .nxtvalid2src  (buf_sig2presrc[0]                        ),
      .aux2src       (1'b0                                     ),
      .src_cnt       (src_cnt                                  ),
      .srccnt_rdysig (srccnt_rdysig                            ),
      .auxsrcd       (                                         ),
      .running       (running                                  ),
      .sclr2aclr     (sclr2aclr                                )
   );
   ///< 产生输出端Avalon接口信号
   avalon_makesrc #(
      .IC(IC)
   ) srcmake(
      .crp  (crp  ),
      .srcp (srcp )
   );
endmodule
module avalon_prcsrmake_maxsrc #(
   parameter avalon_pkg::ifCfg IC          = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter int               TAPS2SRC    = 0,                      ///< #sop2src 、 #valid2src 信号有效时刻距接口输出时刻的延迟拍数
                                                                     ///< \attention
                                                                     ///< - 当 #IC.bufSrc == 1'b1 时，本参数应包含输出缓存的一拍延迟
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0                    ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if.crp     crp,           ///< Avalon接口时钟及复位信号端口列表
   avalon_if.procp   procp,         ///< Avalon接口数据处理用交互信号端口列表
   avalon_if.srcp    srcp,          ///< Avalon接口输出端信号端口列表
   input  wire       sop2src,       ///< 待输出数据序列起始标志，高电平(1)有效
   input  wire       valid2src,     ///< 待输出数据序列有效标志，高电平(1)有效
   input  wire       blksink,       ///< 用户定义的输入阻塞标志，当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire       blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   output wire       running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic      sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   localparam int bitwof_srccnt            = avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC);
   localparam bit[bitwof_srccnt-1:0]srccnt = (bitwof_srccnt)'(avalon_pkg::maxSrc_of_ifCfg(IC));
   avalon_prcsrmake #(
      .IC         (IC         ),
      .TAPS2SRC   (TAPS2SRC   ),
      .MIRROR_SINK(MIRROR_SINK),
      .BLKSINK_EN (BLKSINK_EN ),
      .BLKPRCSR_EN(BLKPRCSR_EN)
   ) prcsri(
      .crp           (crp           ),
      .procp         (procp         ),
      .srcp          (srcp          ),
      .sop2src       (sop2src       ),
      .valid2src     (valid2src     ),
      .blksink       (blksink       ),
      .blkprcsr      (blkprcsr      ),
      .src_cnt       (srccnt        ),
      .srccnt_rdysig (srcp.src_sop  ),
      .running       (running       ),
      .sclr2aclr     (sclr2aclr     )
   );
endmodule
/*!
 * \brief 基于输入信号产生处理器信号的Avalon接口处理器信号产生器
 * \details
 * -# 待输出数据产生时刻默认为输入数据序列输入时刻；
 * -# 输入数据有效标志 #sink_valid 根据本节点Avalon接口信号同步延迟产生 #src_valid；
 * -# 输出数据帧头标志 #src_sop 根据本节点Avalon接口信号同步延迟产生；
 * -# 输出数据帧长度 #src_cnt 由调用者载入并保持至输出序列结束后立刻清零；
 * -# 输出数据帧索引 #src_idx 在 #src_sop 有效后根据本节点Avalon接口信号同步计数，与输入端信号独立；
 * -# 输出数据帧尾标志 #src_eop 根据 #src_idx 的值决定置位，与输入端信号独立；
 * -# 实现 #src_blk 信号向 #sink_blk 信号的传递。
 * \attention 
 * - 本处理器信号产生器仅适用于无法挤出中间级空隙的FIFO型处理器！不可用于非FIFO型的处理器！！
 */
module avalon_prcsrmake_4sink #(
   parameter avalon_pkg::ifCfg IC          = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter bit               PIPE_PRCSR  = 1'b0,                   ///< 管道工作模式：
                                                                     ///< 1'b1-处理器以管道的工作方式将信号从输入端传递至输出端。该模式要求输入和输出数据流长度一致，不支持时分复用信号，需要消耗额外的寄存器或RAM资源；
                                                                     ///< 1'b0-处理器普通工作模式根据从输入端传入的信号产生输出端信号。该模式不要求输入和输出数据流长度一致，且支持时分复用信号，仅需要消耗一定的逻辑和寄存器资源。
                                                                     ///< \attention 管道工作模式在满足输入流长度和输出流长度一致的必要前提下，通常用于下列情况之一：
                                                                     ///< -# 处理器延迟很短，没必要花费过多的逻辑资源去单独产生输出端Avalon信号；
                                                                     ///< -# 处理器应用于镜像服务中（比如服务于 #avalon_mirrormux_sinkbyidx 镜像的节点），且需要在客户端的一段完整数据流处理未完成前频繁切换服务的客户端的情况下，
                                                                     ///< 需要保证输出给客户端的接口信号一致。
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0                    ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if.crp                                         crp,           ///< Avalon接口时钟及复位信号端口列表
   avalon_if.procp                                       procp,         ///< Avalon接口数据处理用交互信号端口列表
   avalon_if.srcp                                        srcp,          ///< Avalon接口输出端信号端口列表
   input  wire                                           blksink,       ///< 用户定义的输入阻塞标志，除了置位Avalon接口的 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                                                        ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire                                           blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire[avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC)-1:0]src_cnt,       ///< 待上报给Avalon接口的输出数据序列长度
   input  wire                                           srccnt_rdysig, ///< 输出数据序列长度有效信号，高电平(1)有效，当 #nxtvalid2src 为高，或者 #procp.src_nxtidx 非0时，本信号的第一个高电平触发载入 #src_cnt
   output wire                                           running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic                                          sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   initial if (avalon_pkg::maxSink_of_ifCfg(IC) != avalon_pkg::maxSrc_of_ifCfg(IC))
      $error("avalon_prcsrmake_4sink : IC.maxSink(%0d) should be equal to IC.maxSrc(%0d)", avalon_pkg::maxSink_of_ifCfg(IC), avalon_pkg::maxSrc_of_ifCfg(IC));
   localparam int lat_ic = avalon_pkg::prclat_of_ifCfg(IC);
   localparam int lat_bufsrc = avalon_pkg::bufSrc_of_ifCfg(IC);
   initial if (lat_ic < lat_bufsrc)
      $error("avalon_prcsrmake_4sink : IC.prclat(%0d) should not be less than IC.bufSrc(%0d)", lat_ic, lat_bufsrc);
   localparam int bitwof_srccnt = avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC);
   localparam bit pipe_prcsr = (bitwof_srccnt*lat_ic) < (2**bitwof_srccnt) ? 1'b1 : 1'b0;
   wire blksink2use, blkprcsr2use;
   generate
   if (BLKSINK_EN)assign blksink2use = blksink;
   else           assign blksink2use = 1'b0;
   if(BLKPRCSR_EN)assign blkprcsr2use = blkprcsr;
   else           assign blkprcsr2use = 1'b0;
   if ((PIPE_PRCSR|pipe_prcsr) == 1'b1) begin
      localparam int bitwof_sinkidx = avalon_pkg::bitwOfSinkIdx_of_ifCfg(IC);
      logic[2*bitwof_sinkidx+2:0]isig_pipesink, isig_pipe2prebuf;
      assign isig_pipesink = {(procp.sink_valid&(~blksink2use)), procp.sink_sop, procp.sink_eop, procp.sink_idx, procp.sink_nxtidx};
      // localparam int prclat_of_ic = avalon_pkg::prclat_of_ifCfg(IC);
      localparam int lat2psrc = (lat_ic <= 1)
                                ? 0
                                : (lat_ic - 1);
      wire prebuf_reseting;
      avalon_auxsig_sync #(
         .SIGBITW(2*bitwof_sinkidx + 3 ),
         .LATENCY(lat2psrc             ),
         .SCLRRAM(1'b1                 ),
         .REG_PRI(1'b0                 )
      ) pipe2prebuf_isig(
         .clk     (crp.clk                      ),
         .aclr    (crp.aclr                     ),
         .sclr    (crp.sclr                     ),
         .clken   (crp.clken&(~procp.prcsr_blk) ),
         .sink_sig(isig_pipesink                ),
         .src_sig (isig_pipe2prebuf             ),
         .reseting(prebuf_reseting              )
      );
      localparam int lat2src = (lat_ic <= lat_bufsrc) ? 0 : 1;
      wire[bitwof_sinkidx*2:0]idx_nxtidx_2src;
      avalon_auxsig_sync #(
         .SIGBITW(2*bitwof_sinkidx),
         .LATENCY(lat2src              ),
         .SCLRRAM(1'b0                 ),
         .REG_PRI(1'b0                 )
      ) pipe2buf_isig(
         .clk     (crp.clk                               ),
         .aclr    (crp.aclr                              ),
         .sclr    (crp.sclr|prebuf_reseting              ),
         .clken   (crp.clken&(~procp.prcsr_blk)          ),
         .sink_sig(isig_pipe2prebuf[2*bitwof_sinkidx-1:0]),
         .src_sig (idx_nxtidx_2src [2*bitwof_sinkidx-1:0]),
         .reseting(                                      )
      );
      logic[2:0]  seqsflg2src;// 2:valid2src, 1:sop2src, 0:eop2src
      if (lat2src > 0) begin
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
            if      (crp.aclr)                 seqsflg2src <= 3'b000;
            else if (crp.sclr|prebuf_reseting) seqsflg2src <= 3'b000;
            else if (~crp.clken)               seqsflg2src <= seqsflg2src;
            else if (procp.prcsr_blk)          seqsflg2src <= procp.src_blk
                                                              ? seqsflg2src
                                                              : 3'b000;
            else                               seqsflg2src <= isig_pipe2prebuf[2*bitwof_sinkidx+2:2*bitwof_sinkidx];
         end
      end
      else assign seqsflg2src = (procp.prcsr_blk&(~procp.src_blk))
                                ? 3'b000
                                : isig_pipe2prebuf[2*bitwof_sinkidx+2:2*bitwof_sinkidx];
      assign idx_nxtidx_2src[2*bitwof_sinkidx] = seqsflg2src[0];  // eop2src
      avalon_prcsr_basic_mgr #(
         .IC         (IC                  ),
         .AUXBITW2SRC(2*bitwof_sinkidx + 1),
         .MIRROR_SINK(MIRROR_SINK         ),
         .BLKPRCSR_EN(BLKPRCSR_EN         ),
         .BLKSINK_EN (1'b1                )
      ) basic_prcsr_mgri(
         .crp           (crp                                         ),
         .procp         (procp                                       ),
         .blksink       (blksink2use|prebuf_reseting                 ),
         .blkprcsr      (blkprcsr                                    ),
         .sop2src       (seqsflg2src[1]                              ),
         .nxtsop2src    (isig_pipe2prebuf[2*bitwof_sinkidx+1]        ),
         .valid2src     (seqsflg2src[2]                              ),
         .nxtvalid2src  (isig_pipe2prebuf[2*bitwof_sinkidx+2]        ),
         .aux2src       (idx_nxtidx_2src                             ),
         .src_cnt       (src_cnt                                     ),
         .srccnt_rdysig (srccnt_rdysig                               ),
         .auxsrcd       ({srcp.src_eop,srcp.src_idx,srcp.src_nxtidx} ),
         .running       (running                                     ),
         .sclr2aclr     (sclr2aclr                                   )
      );
   end else avalon_prcsrmake #(
         .IC         (IC         ),
         .TAPS2SRC   (lat_ic     ),
         .MIRROR_SINK(MIRROR_SINK),
         .BLKSINK_EN (BLKSINK_EN ),
         .BLKPRCSR_EN(BLKPRCSR_EN)
      ) prcsr_i(
         .crp           (crp                             ),
         .procp         (procp                           ),
         .srcp          (srcp                            ),
         .sop2src       (procp.sink_sop                  ),
         .valid2src     (procp.sink_valid&(~blksink2use) ),
         .blksink       (blksink2use                     ),
         .blkprcsr      (blkprcsr                        ),
         .src_cnt       (src_cnt                         ),
         .srccnt_rdysig (srccnt_rdysig                   ),
         .running       (running                         ),
         .sclr2aclr     (sclr2aclr                       )
      );
   endgenerate
endmodule
module avalon_prcsrmake_4sink_maxsrc #(
   parameter avalon_pkg::ifCfg IC          = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter bit               PIPE_PRCSR  = 1'b0,                   ///< 管道工作模式：
                                                                     ///< 1'b1-处理器以管道的工作方式将信号从输入端传递至输出端。该模式要求输入和输出数据流长度一致，不支持时分复用信号，需要消耗额外的寄存器或RAM资源；
                                                                     ///< 1'b0-处理器普通工作模式根据从输入端传入的信号产生输出端信号。该模式不要求输入和输出数据流长度一致，且支持时分复用信号，仅需要消耗一定的逻辑和寄存器资源。
                                                                     ///< \attention 管道工作模式在满足输入流长度和输出流长度一致的必要前提下，通常用于下列情况之一：
                                                                     ///< -# 处理器延迟很短，没必要花费过多的逻辑资源去单独产生输出端Avalon信号；
                                                                     ///< -# 处理器应用于镜像服务中（比如服务于 #avalon_mirrormux_sinkbyidx 镜像的节点），且需要在客户端的一段完整数据流处理未完成前频繁切换服务的客户端的情况下，
                                                                     ///< 需要保证输出给客户端的接口信号一致。
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0                    ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if.crp     crp,           ///< Avalon接口时钟及复位信号端口列表
   avalon_if.procp   procp,         ///< Avalon接口数据处理用交互信号端口列表
   avalon_if.srcp    srcp,          ///< Avalon接口输出端信号端口列表
   input  wire       blksink,       ///< 用户定义的输入阻塞标志，除了置位Avalon接口的 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                    ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire       blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   output wire       running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic      sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   localparam int bitwof_srccnt            = avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC);
   localparam bit[bitwof_srccnt-1:0]srccnt = (bitwof_srccnt)'(avalon_pkg::maxSrc_of_ifCfg(IC));
   avalon_prcsrmake_4sink #(
      .IC         (IC         ),
      .PIPE_PRCSR (PIPE_PRCSR ),
      .MIRROR_SINK(MIRROR_SINK),
      .BLKSINK_EN (BLKSINK_EN ),
      .BLKPRCSR_EN(BLKPRCSR_EN)
   ) prcsri(
      .crp           (crp           ),
      .procp         (procp         ),
      .srcp          (srcp          ),
      .blksink       (blksink       ),
      .blkprcsr      (blkprcsr      ),
      .src_cnt       (srccnt        ),
      .srccnt_rdysig (srcp.src_sop  ),
      .running       (running       ),
      .sclr2aclr     (sclr2aclr     )
   );
endmodule
/*!
 * \brief 基于前级Avalon接口节点输出信号产生处理器信号的本级Avalon接口处理器
 * \details #avalon_link + #avalon_prcsrmake_4sink 的组合，省去了例化 #avalon_link 的麻烦
 */
module avalon_prcsrmake_4sink_frmprevp #(
   parameter avalon_pkg::ifCfg IC          = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter bit               BITWUNMATCH = 0,                      ///< 指示连接的两个Avalon接口信号位宽不一致的标志，用于提示编译器被连接的两个Avalon接口信号位宽被显示设计为不一致
   parameter bit               PIPE_PRCSR  = 1'b0,                   ///< 管道工作模式：
                                                                     ///< 1'b1-处理器以管道的工作方式将信号从输入端传递至输出端。该模式要求输入和输出数据流长度一致，不支持时分复用信号，需要消耗额外的寄存器或RAM资源；
                                                                     ///< 1'b0-处理器普通工作模式根据从输入端传入的信号产生输出端信号。该模式不要求输入和输出数据流长度一致，且支持时分复用信号，仅需要消耗一定的逻辑和寄存器资源。
                                                                     ///< \attention 管道工作模式在满足输入流长度和输出流长度一致的必要前提下，通常用于下列情况之一：
                                                                     ///< -# 处理器延迟很短，没必要花费过多的逻辑资源去单独产生输出端Avalon信号；
                                                                     ///< -# 处理器应用于镜像服务中（比如服务于 #avalon_mirrormux_sinkbyidx 镜像的节点），且需要在客户端的一段完整数据流处理未完成前频繁切换服务的客户端的情况下，
                                                                     ///< 需要保证输出给客户端的接口信号一致。
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0,                   ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
   parameter bit               SHAREPREVIF = 1'b0                    ///< 表示本级节点是与其他模块共享前级节点的标志，1'b0-本级节点独占前级节点，1'b1-本级节点与其他模块共享前级节点
                                                                     ///< \attention 对共享的前级节点，本级节点将不向前级节点反馈阻塞信号
) (
   avalon_if                                             ifi,           ///< 本级Avalon接口
   avalon_if.nextp                                       prevp,         ///< 前级Avalon接口的下级节点交互信号列表
   input  wire                                           blksink,       ///< 用户定义的输入阻塞标志，除了置位Avalon接口的 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                                                        ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire                                           blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire[avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC)-1:0]src_cnt,       ///< 待上报给Avalon接口的输出数据序列长度
   input  wire                                           srccnt_rdysig, ///< 输出数据序列长度有效信号，高电平(1)有效，当 #nxtvalid2src 为高，或者 #ifi.src_nxtidx 非0时，本信号的第一个高电平触发载入 #src_cnt
   output wire                                           running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic                                          sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   avalon_link #(
      .SINKP_IC      (IC         ),
      .BLKPREVSRC_EN (1'b0       ),
      .BITW_UNMATCH  (BITWUNMATCH),
      .SHAREPREVIF   (SHAREPREVIF)
   ) link2prevp(
      .prevp      (prevp      ),
      .blkprevsrc (1'b0       ),
      .sinkp      (ifi.sinkp  )
   );
   avalon_prcsrmake_4sink #(
      .IC         (IC         ),
      .PIPE_PRCSR (PIPE_PRCSR ),
      .MIRROR_SINK(MIRROR_SINK),
      .BLKSINK_EN (BLKSINK_EN ),
      .BLKPRCSR_EN(BLKPRCSR_EN)
   ) prcsr_i(
      .crp           (ifi.crp       ),
      .procp         (ifi.procp     ),
      .srcp          (ifi.srcp      ),
      .blksink       (blksink       ),
      .blkprcsr      (blkprcsr      ),
      .src_cnt       (src_cnt       ),
      .srccnt_rdysig (srccnt_rdysig ),
      .running       (running       ),
      .sclr2aclr     (sclr2aclr     )
   );
endmodule
module avalon_prcsrmake_4sink_frmprevp_maxsrc #(
   parameter avalon_pkg::ifCfg IC          = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter bit               BITWUNMATCH = 0,                      ///< 指示连接的两个Avalon接口信号位宽不一致的标志，用于提示编译器被连接的两个Avalon接口信号位宽被显示设计为不一致
   parameter bit               PIPE_PRCSR  = 1'b0,                   ///< 管道工作模式：
                                                                     ///< 1'b1-处理器以管道的工作方式将信号从输入端传递至输出端。该模式要求输入和输出数据流长度一致，不支持时分复用信号，需要消耗额外的寄存器或RAM资源；
                                                                     ///< 1'b0-处理器普通工作模式根据从输入端传入的信号产生输出端信号。该模式不要求输入和输出数据流长度一致，且支持时分复用信号，仅需要消耗一定的逻辑和寄存器资源。
                                                                     ///< \attention 管道工作模式在满足输入流长度和输出流长度一致的必要前提下，通常用于下列情况之一：
                                                                     ///< -# 处理器延迟很短，没必要花费过多的逻辑资源去单独产生输出端Avalon信号；
                                                                     ///< -# 处理器应用于镜像服务中（比如服务于 #avalon_mirrormux_sinkbyidx 镜像的节点），且需要在客户端的一段完整数据流处理未完成前频繁切换服务的客户端的情况下，
                                                                     ///< 需要保证输出给客户端的接口信号一致。
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0,                   ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
   parameter bit               SHAREPREVIF = 1'b0                    ///< 表示本级节点是与其他模块共享前级节点的标志，1'b0-本级节点独占前级节点，1'b1-本级节点与其他模块共享前级节点
                                                                     ///< \attention 对共享的前级节点，本级节点将不向前级节点反馈阻塞信号
) (
   avalon_if         ifi,           ///< 本级Avalon接口
   avalon_if.nextp   prevp,         ///< 前级Avalon接口的下级节点交互信号列表
   input  wire       blksink,       ///< 用户定义的输入阻塞标志，除了置位Avalon接口的 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                    ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire       blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   output wire       running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic      sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   localparam int bitwof_srccnt            = avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC);
   localparam bit[bitwof_srccnt-1:0]srccnt = (bitwof_srccnt)'(avalon_pkg::maxSrc_of_ifCfg(IC));
   avalon_prcsrmake_4sink_frmprevp #(
      .IC         (IC         ),
      .BITWUNMATCH(BITWUNMATCH),
      .PIPE_PRCSR (PIPE_PRCSR ),
      .MIRROR_SINK(MIRROR_SINK),
      .BLKSINK_EN (BLKSINK_EN ),
      .BLKPRCSR_EN(BLKPRCSR_EN),
      .SHAREPREVIF(SHAREPREVIF)
   ) prcsri(
      .ifi           (ifi        ),
      .prevp         (prevp      ),
      .blksink       (blksink    ),
      .blkprcsr      (blkprcsr   ),
      .src_cnt       (srccnt     ),
      .srccnt_rdysig (ifi.src_sop),
      .running       (running    ),
      .sclr2aclr     (sclr2aclr  )
   );
endmodule
/*! \brief 用于产生时分复用信号的Avalon接口处理器信号产生器 */
module avalon_tdmmake #(
   parameter avalon_pkg::ifCfg TDMIC       = avalon_pkg::deft_ifCfg, ///< 时分复用信号产生用Avalon接口配置参数，其延迟量表示主机接口信号输入时刻到产生时分复用信号时刻之间的延迟量
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的主机Avalon接口输入阻塞状态信号标识（输入信号 #blksink 使能标志），1-使能 #hblksink 信号， 0-禁用 #hblksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0                    ///< 引入用户定义的主机Avalon接口处理器阻塞状态信号的标志（输入信号 #hblkprcsr 使能标志），1-使能 #hblkprcsr 信号，0-禁用 #hblkprcsr 信号。
) (
   avalon_if   ifi,           ///< 时分复用Avalon接口
   input  wire hsinkvalid,    ///< 需要产生时分复用信号的主机Avalon接口输入数据有效标志，高电平(1)有效。
   input  wire hs_syncsig,    ///< 时分复用时隙同步信号，高电平(1)有效。
                              ///< \attention
                              ///< - 要求必须与 #hsinkvalid 信号同步；
                              ///< - 可以是 #hostauxp.sink_sop ，也可以是时分复用Avalon接口链表传递的与 #hsinkvalid 信号同步的 #src_sop 信号
   input  wire blksink,       ///< 用户定义的输入阻塞标志，除了置位 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                              ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                              ///< \attention
                              ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                              ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire blkprcsr       ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                              ///< \attention
                              ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #HBLKPRCSR_EN 为1，则本信号须置常数1'b0。
                              ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
);
   localparam int maxSink = avalon_pkg::maxSink_of_ifCfg(TDMIC);
   initial if (maxSink != 1)
      $error("avalon_tdmmake : TDMIC.maxSink(%0d) should only be 1 for making tdm-signal", maxSink);
   avalon_makesink_witheop #(
      .IC(TDMIC)
   ) tdm_sink(
      .crp        (ifi.crp    ),
      .sinkp      (ifi.sinkp  ),
      .sink_valid (hsinkvalid ),
      .sink_sop   (hsinkvalid ),
      .sink_eop   (hsinkvalid ),
      .sink_blk   (           )
   );
   wire blksink2use;
   generate
   if (BLKSINK_EN)assign blksink2use = blksink;
   else           assign blksink2use = 1'b0;
   endgenerate
   wire[1:0]sigs2tdm, sigs_pretdm;
   assign sigs2tdm = {(hsinkvalid&(~blksink2use)), (hs_syncsig&(~blksink2use))};
   localparam int prclat_of_ic = avalon_pkg::prclat_of_ifCfg(TDMIC);
   wire blkby_srceop = (~ifi.src_eop)&ifi.src_valid;
   pipedelay_taps #(
      .DATABITW   (2                                           ),
      .DELAYTAPS  ((prclat_of_ic <= 1) ? 0 : (prclat_of_ic - 1))
   ) pipe2pretdm(
      .clk     (ifi.clk                   ),
      .aclr    (ifi.aclr                  ),
      .sclr    (ifi.sclr                  ),
      .clken   (ifi.clken&(~ifi.prcsr_blk)),
      .x       (sigs2tdm                  ),
      .pipe_x  (sigs_pretdm               )
   );
   logic pretdmsop_hs_syncsig, valid2src;
   edge_detectr #(
      .EDGE_WANT  (1    ),
      .CLKEN_PULS (1'b1 ),
      .DELAY_OUT  (1'b0 ),
      .CLKEN_OUT  (1'b0 )
   ) pretdm_hs_syncsig_risingedge_chkr(
      .clk        (ifi.clk                   ),
      .aclr       (ifi.aclr                  ),
      .sclr       (ifi.sclr                  ),
      .clken_puls (ifi.clken&(~ifi.prcsr_blk)),
      .insig      (sigs_pretdm[0]            ),
      .clken_out  (1'b1                      ),
      .edgsig     (pretdmsop_hs_syncsig      )
   );
   generate
      if (prclat_of_ic > 0) begin
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(ifi.clk, ifi.aclr)) begin
            if      (ifi.aclr)                  valid2src <= 1'b0;
            else if (ifi.sclr)                  valid2src <= 1'b0;
            else if ((~ifi.clken)|blkby_srceop) valid2src <= valid2src;
            else if (ifi.prcsr_blk)             valid2src <= ifi.src_blk ? valid2src : 1'b0;
            else                                valid2src <= sigs_pretdm[1];
         end
      end
      else assign valid2src = (ifi.prcsr_blk&(~ifi.src_blk)) ? 1'b0 : sigs_pretdm[1];
      logic nxtsrcsop_2sync, srcsop_sync, srcsop2src;
      if (prclat_of_ic == 0) assign nxtsrcsop_2sync = (ifi.src_eop&sigs_pretdm[1]);
      else                   assign nxtsrcsop_2sync = (ifi.src_eop&sigs_pretdm[1])|pretdmsop_hs_syncsig;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(ifi.clk, ifi.aclr)) begin
         if      (ifi.aclr)      srcsop_sync <= '0;
         else if (ifi.sclr)      srcsop_sync <= '0;
         else if (~ifi.clken)    srcsop_sync <= srcsop_sync;
         else if (ifi.prcsr_blk) srcsop_sync <= ifi.src_blk ? srcsop_sync : 1'b0;
         else                    srcsop_sync <= nxtsrcsop_2sync;
      end
      if (prclat_of_ic == 0) assign srcsop2src = srcsop_sync|pretdmsop_hs_syncsig;
      else                   assign srcsop2src = srcsop_sync;
   endgenerate
   localparam int tdmtaps = avalon_pkg::maxSrc_of_ifCfg(TDMIC);
   localparam int bitwof_tdmtaps = avalon_pkg::bitwOfDataSeqLen(tdmtaps);
   localparam bit[bitwof_tdmtaps-1:0]tdm_srccnt = (bitwof_tdmtaps)'(tdmtaps);
   avalon_prcsr_basic_mgr #(
      .IC         (TDMIC      ),
      .AUXBITW2SRC(0          ),
      .MIRROR_SINK(MIRROR_SINK),
      .BLKSINK_EN (1'b1       ),
      .BLKPRCSR_EN(BLKPRCSR_EN)
   ) basic_prcsr_mgri(
      .crp           (ifi.crp                   ),
      .procp         (ifi.procp                 ),
      .blkprcsr      (blkprcsr                  ),
      .blksink       (blksink2use|blkby_srceop  ),
      .sop2src       (srcsop2src                ),
      .nxtsop2src    (nxtsrcsop_2sync           ),
      .valid2src     (valid2src                 ),
      .nxtvalid2src  (sigs_pretdm[1]            ),
      .aux2src       (1'b0                      ),
      .src_cnt       (tdm_srccnt                ),
      .srccnt_rdysig (1'b1                      ),
      .auxsrcd       (                          ),
      .running       (                          ),
      .sclr2aclr     (                          )
   );
   avalon_makesrc #(
      .IC(TDMIC)
   ) srcmake(
      .crp  (ifi.crp ),
      .srcp (ifi.srcp)
   );
endmodule
/*!
 * \brief 基于本级时分复用Avalon接口输入信号产生处理器信号的本级时分复用Avalon接口处理器
 * \attention 本处理器专用于时分复用Avalon接口，非时分复用Avalon接口禁用
 */
module avalon_tdmprcsrmake_4sink #(
   parameter avalon_pkg::ifCfg TDMIC       = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter bit               PIPE_PRCSR  = 1'b0,                   ///< 管道工作模式：
                                                                     ///< 1'b1-处理器以管道的工作方式将信号从输入端传递至输出端。该模式要求输入和输出数据流长度一致，不支持时分复用信号，需要消耗额外的寄存器或RAM资源；
                                                                     ///< 1'b0-处理器普通工作模式根据从输入端传入的信号产生输出端信号。该模式不要求输入和输出数据流长度一致，且支持时分复用信号，仅需要消耗一定的逻辑和寄存器资源。
                                                                     ///< \attention 管道工作模式在满足输入流长度和输出流长度一致的必要前提下，通常用于下列情况之一：
                                                                     ///< -# 处理器延迟很短，没必要花费过多的逻辑资源去单独产生输出端Avalon信号；
                                                                     ///< -# 处理器应用于镜像服务中（比如服务于 #avalon_mirrormux_sinkbyidx 镜像的节点），且需要在客户端的一段完整数据流处理未完成前频繁切换服务的客户端的情况下，
                                                                     ///< 需要保证输出给客户端的接口信号一致。
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0                    ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if.crp     tdmcrp,        ///< 时分复用Avalon接口时钟及复位信号端口列表
   avalon_if.procp   tdmprocp,      ///< 时分复用Avalon接口数据处理用交互信号端口列表
   avalon_if.srcp    tdmsrcp,       ///< 时分复用Avalon接口输出端信号端口列表
   input  wire       blksink,       ///< 用户定义的输入阻塞标志，除了置位Avalon接口的 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                    ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire       blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   output wire       running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic      sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   localparam int maxSink = avalon_pkg::maxSink_of_ifCfg(TDMIC);
   localparam int maxSrc  = avalon_pkg::maxSrc_of_ifCfg(TDMIC);
   initial if (maxSink != maxSrc)
      $error("avalon_tdmprcsrmake_4sink_frmprevp : TDMIC.maxSink(%0d) should be equal with TDMIC.maxSrc(%0d)", maxSink, maxSrc);
   localparam int tdmtaps = avalon_pkg::maxSrc_of_ifCfg(TDMIC);
   localparam int bitwof_tdmtaps = avalon_pkg::bitwOfDataSeqLen(tdmtaps);
   localparam bit[bitwof_tdmtaps-1:0]tdm_srccnt = (bitwof_tdmtaps)'(tdmtaps);
   avalon_prcsrmake_4sink #(
      .IC         (TDMIC      ),
      .PIPE_PRCSR (PIPE_PRCSR ),
      .MIRROR_SINK(MIRROR_SINK),
      .BLKSINK_EN (BLKSINK_EN ),
      .BLKPRCSR_EN(BLKPRCSR_EN)
   ) tdmprcsri(
      .crp           (tdmcrp     ),
      .procp         (tdmprocp   ),
      .srcp          (tdmsrcp    ),
      .blksink       (blksink    ),
      .blkprcsr      (blkprcsr   ),
      .src_cnt       (tdm_srccnt ),
      .srccnt_rdysig (1'b1       ),
      .running       (running    ),
      .sclr2aclr     (sclr2aclr  )
   );
endmodule
/*!
 * \brief 基于前级时分复用Avalon接口节点输出信号产生处理器信号的本级时分复用Avalon接口处理器
 * \details #avalon_link + #avalon_prcsrmake_4sink 的组合，省去了例化 #avalon_link 的麻烦
 * \attention 本处理器专用于时分复用Avalon接口，非时分复用Avalon接口禁用
 */
module avalon_tdmprcsrmake_4sink_frmprevp #(
   parameter avalon_pkg::ifCfg TDMIC       = avalon_pkg::deft_ifCfg, ///< Avalon接口配置参数
   parameter bit               PIPE_PRCSR  = 1'b0,                   ///< 管道工作模式：
                                                                     ///< 1'b1-处理器以管道的工作方式将信号从输入端传递至输出端。该模式要求输入和输出数据流长度一致，不支持时分复用信号，需要消耗额外的寄存器或RAM资源；
                                                                     ///< 1'b0-处理器普通工作模式根据从输入端传入的信号产生输出端信号。该模式不要求输入和输出数据流长度一致，且支持时分复用信号，仅需要消耗一定的逻辑和寄存器资源。
                                                                     ///< \attention 管道工作模式在满足输入流长度和输出流长度一致的必要前提下，通常用于下列情况之一：
                                                                     ///< -# 处理器延迟很短，没必要花费过多的逻辑资源去单独产生输出端Avalon信号；
                                                                     ///< -# 处理器应用于镜像服务中（比如服务于 #avalon_mirrormux_sinkbyidx 镜像的节点），且需要在客户端的一段完整数据流处理未完成前频繁切换服务的客户端的情况下，
                                                                     ///< 需要保证输出给客户端的接口信号一致。
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0,                   ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
   parameter bit               SHAREPREVIF = 1'b0                    ///< 表示本级节点是与其他模块共享前级节点的标志，1'b0-本级节点独占前级节点，1'b1-本级节点与其他模块共享前级节点
                                                                     ///< \attention 对共享的前级节点，本级节点将不向前级节点反馈阻塞信号
) (
   avalon_if       tdmifi,                         ///< 本级时分复用Avalon接口
   avalon_if.nextp tdmprevp,                       ///< 前级时分复用Avalon接口的下级节点交互信号列表
   input  wire     blksink,                        ///< 用户定义的输入阻塞标志，除了置位Avalon接口的 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                                   ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                                   ///< \attention
                                                   ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                                   ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire     blkprcsr,                       ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                                   ///< \attention
                                                   ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                                   ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   output wire     running,                        ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic    sclr2aclr                       ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   localparam int maxSink = avalon_pkg::maxSink_of_ifCfg(TDMIC);
   localparam int maxSrc  = avalon_pkg::maxSrc_of_ifCfg(TDMIC);
   initial if (maxSink != maxSrc)
      $error("avalon_tdmprcsrmake_4sink_frmprevp : TDMIC.maxSink(%0d) should be equal with TDMIC.maxSrc(%0d)", maxSink, maxSrc);
   localparam int tdmtaps = avalon_pkg::maxSrc_of_ifCfg(TDMIC);
   localparam int bitwof_tdmtaps = avalon_pkg::bitwOfDataSeqLen(tdmtaps);
   localparam bit[bitwof_tdmtaps-1:0]tdm_srccnt = (bitwof_tdmtaps)'(tdmtaps);
   avalon_prcsrmake_4sink_frmprevp #(
      .IC         (TDMIC      ),
      .BITWUNMATCH(1'b0       ),
      .PIPE_PRCSR (PIPE_PRCSR ),
      .MIRROR_SINK(MIRROR_SINK),
      .BLKSINK_EN (BLKSINK_EN ),
      .BLKPRCSR_EN(BLKPRCSR_EN),
      .SHAREPREVIF(SHAREPREVIF)
   ) tdmprcsri(
      .ifi           (tdmifi     ),
      .prevp         (tdmprevp   ),
      .blksink       (blksink    ),
      .blkprcsr      (blkprcsr   ),
      .src_cnt       (tdm_srccnt ),
      .srccnt_rdysig (1'b1       ),
      .running       (running    ),
      .sclr2aclr     (sclr2aclr  )
   );
endmodule
/*! \brief 根据时分复用序列起始标志恢复时分复用Avalon接口信号 */
module avalon_tdmresume #(
   parameter avalon_pkg::ifCfg TDMIC       = avalon_pkg::deft_ifCfg, ///< 时分复用信号恢复用Avalon接口配置参数：
                                                                     ///< -# 其延迟量表示Avalon接口输入端至输出端的信号延迟量
                                                                     ///< -# 其输入、输出序列长度应相等，并且这两个序列长度被用于表示时分复用信号分拍数
   parameter bit               PIPE_PRCSR  = 1'b0,                   ///< 管道工作模式：
                                                                     ///< 1'b1-处理器以管道的工作方式将信号从输入端传递至输出端。该模式要求输入和输出数据流长度一致，不支持时分复用信号，需要消耗额外的寄存器或RAM资源；
                                                                     ///< 1'b0-处理器普通工作模式根据从输入端传入的信号产生输出端信号。该模式不要求输入和输出数据流长度一致，且支持时分复用信号，仅需要消耗一定的逻辑和寄存器资源。
                                                                     ///< \attention 管道工作模式在满足输入流长度和输出流长度一致的必要前提下，通常用于下列情况之一：
                                                                     ///< -# 处理器延迟很短，没必要花费过多的逻辑资源去单独产生输出端Avalon信号；
                                                                     ///< -# 处理器应用于镜像服务中（比如服务于 #avalon_mirrormux_sinkbyidx 镜像的节点），且需要在客户端的一段完整数据流处理未完成前频繁切换服务的客户端的情况下，
   parameter bit               MIRROR_SINK = 1'b0,                   ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN  = 1'b0,                   ///< 引入用户定义的主机Avalon接口输入阻塞状态信号标识（输入信号 #blksink 使能标志），1-使能 #hblksink 信号， 0-禁用 #hblksink 信号
   parameter bit               BLKPRCSR_EN = 1'b0                    ///< 引入用户定义的主机Avalon接口处理器阻塞状态信号的标志（输入信号 #hblkprcsr 使能标志），1-使能 #hblkprcsr 信号，0-禁用 #hblkprcsr 信号。
) (
   avalon_if   ifi,                                ///< 时分复用Avalon接口
   input wire  tdmhvalid,                          ///< 主机Avalon接口输入序列有效标志，高电平(1)有效
   input wire  sinktdmsop,                         ///< 输入时分复用序列起始标志，高电平(1)有效。
                                                   ///< \attention
                                                   ///< - 要求必须与 #tdmhvalid 信号同步；
                                                   ///< - 必须是时分复用Avalon接口链表传递的与 #tdmhvalid 信号同步的 #src_sop 信号
   input  wire blksink,                            ///< 用户定义的输入阻塞标志，除了置位 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                                   ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                                   ///< \attention
                                                   ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                                   ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire blkprcsr                            ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                                   ///< \attention
                                                   ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #HBLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                                   ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
);
   localparam int maxSink = avalon_pkg::maxSink_of_ifCfg(TDMIC);
   localparam int maxSrc  = avalon_pkg::maxSrc_of_ifCfg(TDMIC);
   initial if (maxSink != maxSrc)
      $error("avalon_tdmresume : TDMIC.maxSink(%0d) should be equal with TDMIC.maxSrc(%0d)", maxSink, maxSrc);
   localparam int bitwof_tdmtaps = avalon_pkg::bitwOfTdmCnt(maxSrc);
   localparam bit [bitwof_tdmtaps-1:0] tdmtaps = (bitwof_tdmtaps)'(maxSrc);
   avalon_makesink_withcnt #(
      .IC(TDMIC)
   ) tdmr_sink(
      .crp        (ifi.crp    ),
      .sinkp      (ifi.sinkp  ),
      .sink_valid (tdmhvalid  ),
      .sink_sop   (sinktdmsop ),
      .sink_cnt   (tdmtaps    ),
      .sinkcnt_rdy(1'b1       ),
      .sink_blk   (           )
   );
   avalon_prcsrmake_4sink #(
      .IC         (TDMIC      ),
      .PIPE_PRCSR (PIPE_PRCSR ),
      .MIRROR_SINK(MIRROR_SINK),
      .BLKSINK_EN (BLKSINK_EN ),
      .BLKPRCSR_EN(BLKPRCSR_EN)
   ) prcsr_i(
      .crp           (ifi.crp    ),
      .procp         (ifi.procp  ),
      .srcp          (ifi.srcp   ),
      .blksink       (blksink    ),
      .blkprcsr      (blkprcsr   ),
      .src_cnt       (tdmtaps    ),
      .srccnt_rdysig (1'b1       ),
      .running       (           ),
      .sclr2aclr     (           )
   );
endmodule
/*!
 * \brief 适配时分复用处理的Avalon接口处理器信号产生器
 * \details
 * -# 待输出数据序列长度与输入数据序列长度应呈整数倍关系
 * -# 时分复用同步信号产生时间可定制；
 * -# 输入数据有效标志 #sink_valid 根据本节点Avalon接口信号同步延迟产生 #src_valid；
 * -# 输出数据帧头标志 #src_sop 由输入数据帧头标志联合时分复用同步信号的同步头标志做逻辑与后，根据本节点Avalon接口信号同步延迟产生；
 * -# 输出数据帧长度 #src_cnt 由调用者载入并保持至输出序列结束后立刻清零；
 * -# 输出数据帧索引 #src_idx 在 #src_sop 有效后根据本节点Avalon接口信号同步计数，与输入端信号独立；
 * -# 输出数据帧尾标志 #src_eop 根据 #src_idx 的值决定置位，与输入端信号独立；
 * -# 实现 #src_blk 信号向 #sink_blk 信号的传递。
 * \attention 
 * - 本处理器信号产生器仅适用于无法挤出中间级空隙的FIFO型处理器！不可用于非FIFO型的处理器！！
 * - 当时分复用信号与某些非时分复用信号的运算在一个处理器中执行时，二者应视为并行处理，处理器的时延应取二者时延的最大值。
 */
module avalon_prcsrmake_4tdm #(
   parameter avalon_pkg::ifCfg IC            = avalon_pkg::deft_ifCfg,  ///< Avalon接口配置参数
   parameter int               SINK2TDM_TAPS = 0,                       ///< 信号输入时刻到产生时分复用信号时刻的延迟拍数
   parameter bit               PURGE_TDM     = 1'b0,                    ///< 是否去除时分复用信号标识的标志，1'b0-实现时分复用信号，1'b1-去除时分复用信号标识
   parameter bit               MIRROR_SINK   = 1'b0,                    ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN    = 1'b0,                    ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN   = 1'b0                     ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if.crp                                         crp,           ///< Avalon接口时钟及复位信号端口列表
   avalon_if.procp                                       procp,         ///< Avalon接口数据处理用交互信号端口列表
   avalon_if.srcp                                        srcp,          ///< Avalon接口输出端信号端口列表
   input  wire                                           tdmsrcsop,     ///< 时分复用信号序列起始标志，高电平(1)有效。
   input  wire                                           tdmsrceop,     ///< 时分复用信号序列结束标志，高电平(1)有效。
   input  wire                                           blksink,       ///< 用户定义的输入阻塞标志，除了置位Avalon接口的 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                                                        ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire                                           blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire[avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC)-1:0]src_cnt,       ///< 待上报给Avalon接口的输出数据序列长度
   input  wire                                           srccnt_rdysig, ///< 输出数据序列长度有效信号，高电平(1)有效，当 #nxtvalid2src 为高，或者 #procp.src_nxtidx 非0时，本信号的第一个高电平触发载入 #src_cnt
   output wire                                           running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic                                          sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   localparam int maxSink = avalon_pkg::maxSink_of_ifCfg(IC);
   localparam int maxSrc  = avalon_pkg::maxSrc_of_ifCfg(IC);
   initial if (PURGE_TDM == 1'b1 && maxSink % maxSrc != 0)
      $error("avalon_prcsrmake_4tdm : IC.maxSink(%0d) should be integer times of IC.maxSrc(%0d) while PURGE_TDM(%0b)", maxSink, maxSrc, PURGE_TDM);
   else if (PURGE_TDM == 1'b0 && maxSrc % maxSink != 0)
      $error("avalon_prcsrmake_4tdm : IC.maxSrc(%0d) should be integer times of IC.maxSink(%0d) while PURGE_TDM(%0b)", maxSrc, maxSink, PURGE_TDM);
   localparam bit bufSrc = avalon_pkg::bufSrc_of_ifCfg(IC);
   localparam int tdm2src_taps = avalon_pkg::prclat_of_ifCfg(IC) - SINK2TDM_TAPS;
   logic[1:0]sigs2tdm, sigs_tdm, sigs2pipe, sigs2presrc, sigs2src;
   wire sinkblk_bytdm, blksink2use;
   assign sigs2tdm = {(procp.sink_valid&(~blksink2use)), procp.sink_sop};
   pipedelay_taps #(
      .DATABITW   (2             ),
      .DELAYTAPS  (SINK2TDM_TAPS )
   ) pipe2tdm(
      .clk     (crp.clk                                     ),
      .aclr    (crp.aclr                                    ),
      .sclr    (crp.sclr                                    ),
      .clken   (crp.clken&(~(procp.prcsr_blk|sinkblk_bytdm))),
      .x       (sigs2tdm                                    ),
      .pipe_x  (sigs_tdm                                    )
   );
   generate
   if (PURGE_TDM) begin
      assign sigs2pipe[1] = (sigs_tdm[1] & tdmsrceop);
      wire sop2go = (sigs_tdm[0] & sigs_tdm[1] & tdmsrcsop);
      logic sop2o;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
         if      (crp.aclr)                  sop2o <= '0;
         else if (crp.sclr)                  sop2o <= '0;
         else if (procp.prcsr_blk|~crp.clken)sop2o <= sop2o;
         else if (tdmsrceop)                 sop2o <= '0;
         else if (sop2go)                    sop2o <= '1;
         else                                sop2o <= sop2o;
      end
      assign sigs2pipe[0] = (sop2go|sop2o);
      assign sinkblk_bytdm = 1'b0;
      /* \attention 按照前面 #avalon_tdmmake 的实现，TDM序列同步信号(sop,eop)在Avalon接口的输出端产生，因此应使用 #tdmsrcsop 和 #tdmsrceop 来产生宿主序列的同步信号 */
   end else assign sigs2pipe = {sigs_tdm[1], (sigs_tdm[0] & sigs_tdm[1] & tdmsrcsop)},
                   sinkblk_bytdm = ((~tdmsrceop)&sigs_tdm[1]);
   if (BLKSINK_EN)assign blksink2use = blksink;
   else           assign blksink2use = 1'b0;
   pipedelay_taps #(
      .DATABITW   (2                                           ),
      .DELAYTAPS  ((tdm2src_taps <= 1) ? 0 : (tdm2src_taps - 1))
   ) pipe2presrc(
      .clk     (crp.clk                      ),
      .aclr    (crp.aclr                     ),
      .sclr    (crp.sclr                     ),
      .clken   (crp.clken&(~procp.prcsr_blk) ),
      .x       (sigs2pipe                    ),
      .pipe_x  (sigs2presrc                  )
   );
   if (tdm2src_taps <= 0) assign sigs2src = (procp.prcsr_blk&(~procp.src_blk)) ? 2'b00 : sigs2presrc;
   else begin
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(crp.clk, crp.aclr)) begin
         if     (crp.aclr)       sigs2src <= 1'b0;
         else if(crp.sclr)       sigs2src <= 1'b0;
         else if(~crp.clken)     sigs2src <= sigs2src;
         else if(procp.prcsr_blk)sigs2src <= procp.src_blk ? sigs2src : 2'b00;
         else                    sigs2src <= sigs2presrc;
      end
   end
   endgenerate
   avalon_makesrc #(
      .IC(IC)
   ) srcmake(
      .crp  (crp  ),
      .srcp (srcp )
   );
   avalon_prcsr_basic_mgr #(
      .IC         (IC         ),
      .AUXBITW2SRC(0          ),
      .MIRROR_SINK(MIRROR_SINK),
      .BLKSINK_EN (1'b1       ),
      .BLKPRCSR_EN(BLKPRCSR_EN)
   ) basic_prcsr_mgri(
      .crp           (crp                       ),
      .procp         (procp                     ),
      .blksink       (blksink2use|sinkblk_bytdm ),
      .blkprcsr      (blkprcsr                  ),
      .sop2src       (sigs2src[0]               ),
      .nxtsop2src    (sigs2presrc[0]            ),
      .valid2src     (sigs2src[1]               ),
      .nxtvalid2src  (sigs2presrc[1]            ),
      .aux2src       (1'b0                      ),
      .src_cnt       (src_cnt                   ),
      .srccnt_rdysig (srccnt_rdysig             ),
      .auxsrcd       (                          ),
      .running       (running                   ),
      .sclr2aclr     (sclr2aclr                 )
   );
endmodule
module avalon_prcsrmake_4tdm_maxsrc #(
   parameter avalon_pkg::ifCfg IC            = avalon_pkg::deft_ifCfg,  ///< Avalon接口配置参数
   parameter int               SINK2TDM_TAPS = 0,                       ///< 信号输入时刻到产生时分复用信号时刻的延迟拍数
   parameter bit               PURGE_TDM     = 1'b0,                    ///< 是否去除时分复用信号标识的标志，1'b0-实现时分复用信号，1'b1-去除时分复用信号标识
   parameter bit               MIRROR_SINK   = 1'b0,                    ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN    = 1'b0,                    ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN   = 1'b0                     ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if.crp     crp,           ///< Avalon接口时钟及复位信号端口列表
   avalon_if.procp   procp,         ///< Avalon接口数据处理用交互信号端口列表
   avalon_if.srcp    srcp,          ///< Avalon接口输出端信号端口列表
   input  wire       tdmsrcsop,     ///< 时分复用信号序列起始标志，高电平(1)有效。
   input  wire       tdmsrceop,     ///< 时分复用信号序列结束标志，高电平(1)有效。
   input  wire       blksink,       ///< 用户定义的输入阻塞标志，除了置位Avalon接口的 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                    ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire       blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   output wire       running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic      sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   localparam int bitwof_srccnt            = avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC);
   localparam bit[bitwof_srccnt-1:0]srccnt = (bitwof_srccnt)'(avalon_pkg::maxSrc_of_ifCfg(IC));
   avalon_prcsrmake_4tdm #(
      .IC            (IC            ),
      .SINK2TDM_TAPS (SINK2TDM_TAPS ),
      .PURGE_TDM     (PURGE_TDM     ),
      .MIRROR_SINK   (MIRROR_SINK   ),
      .BLKSINK_EN    (BLKSINK_EN    ),
      .BLKPRCSR_EN   (BLKPRCSR_EN   )
   ) prcsri(
      .crp           (crp           ),
      .procp         (procp         ),
      .srcp          (srcp          ),
      .tdmsrcsop     (tdmsrcsop     ),
      .tdmsrceop     (tdmsrceop     ),
      .blksink       (blksink       ),
      .blkprcsr      (blkprcsr      ),
      .src_cnt       (srccnt        ),
      .srccnt_rdysig (srcp.src_sop  ),
      .running       (running       ),
      .sclr2aclr     (sclr2aclr     )
   );
endmodule
/*!
 * \brief 连接前级Avalon接口节点输出信号且适配时分复用处理的Avalon接口处理器
 * \details #avalon_link + #avalon_prcsrmake_4tdm_frmprevp 的组合，省去了例化 #avalon_link 的麻烦
 */
module avalon_prcsrmake_4tdm_frmprevp #(
   parameter avalon_pkg::ifCfg IC            = avalon_pkg::deft_ifCfg,  ///< Avalon接口配置参数
   parameter bit               BITWUNMATCH   = 0,                       ///< 指示连接的两个Avalon接口信号位宽不一致的标志，用于提示编译器被连接的两个Avalon接口信号位宽被显示设计为不一致
   parameter int               SINK2TDM_TAPS = 0,                       ///< 本级Avalon接口信号输入时刻到产生时分复用信号时刻的延迟拍数
   parameter bit               PURGE_TDM     = 1'b0,                    ///< 是否去除时分复用信号标识的标志，1'b0-实现时分复用信号，1'b1-去除时分复用信号标识
   parameter bit               MIRROR_SINK   = 1'b0,                    ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN    = 1'b0,                    ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN   = 1'b0                     ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if                                             ifi,           ///< 本级Avalon接口
   avalon_if.nextp                                       prevp,         ///< 前级Avalon接口的下级节点交互信号列表
   input  wire                                           tdmsrcsop,     ///< 时分复用信号序列起始标志，高电平(1)有效。
   input  wire                                           tdmsrceop,     ///< 时分复用信号序列结束标志，高电平(1)有效。
   input  wire                                           blksink,       ///< 用户定义的输入阻塞标志，除了置位Avalon接口的 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                                                        ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire                                           blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                                                        ///< \attention
                                                                        ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                                                        ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire[avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC)-1:0]src_cnt,       ///< 待上报给Avalon接口的输出数据序列长度
   input  wire                                           srccnt_rdysig, ///< 输出数据序列长度有效信号，高电平(1)有效，当 #nxtvalid2src 为高，或者 #procp.src_nxtidx 非0时，本信号的第一个高电平触发载入 #src_cnt
   output wire                                           running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic                                          sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   avalon_link #(
      .SINKP_IC      (IC         ),
      .BLKPREVSRC_EN (1'b0       ),
      .BITW_UNMATCH  (BITWUNMATCH),
      .SHAREPREVIF   (1'b0       )
   ) link2prevp(
      .prevp      (prevp      ),
      .blkprevsrc (1'b0       ),
      .sinkp      (ifi.sinkp  )
   );
   avalon_prcsrmake_4tdm #(
      .IC            (IC            ),
      .SINK2TDM_TAPS (SINK2TDM_TAPS ),
      .PURGE_TDM     (PURGE_TDM     ),
      .MIRROR_SINK   (MIRROR_SINK   ),
      .BLKSINK_EN    (BLKSINK_EN    ),
      .BLKPRCSR_EN   (BLKPRCSR_EN   )
   ) prcsr_i(
      .crp           (ifi.crp       ),
      .procp         (ifi.procp     ),
      .srcp          (ifi.srcp      ),
      .tdmsrcsop     (tdmsrcsop     ),
      .tdmsrceop     (tdmsrceop     ),
      .blksink       (blksink       ),
      .blkprcsr      (blkprcsr      ),
      .src_cnt       (src_cnt       ),
      .srccnt_rdysig (srccnt_rdysig ),
      .running       (running       ),
      .sclr2aclr     (sclr2aclr     )
   );
endmodule
module avalon_prcsrmake_4tdm_frmprevp_maxsrc #(
   parameter avalon_pkg::ifCfg IC            = avalon_pkg::deft_ifCfg,  ///< Avalon接口配置参数
   parameter bit               BITWUNMATCH   = 0,                       ///< 指示连接的两个Avalon接口信号位宽不一致的标志，用于提示编译器被连接的两个Avalon接口信号位宽被显示设计为不一致
   parameter int               SINK2TDM_TAPS = 0,                       ///< 本级Avalon接口信号输入时刻到产生时分复用信号时刻的延迟拍数
   parameter bit               PURGE_TDM     = 1'b0,                    ///< 是否去除时分复用信号标识的标志，1'b0-实现时分复用信号，1'b1-去除时分复用信号标识
   parameter bit               MIRROR_SINK   = 1'b0,                    ///< Avalon接口输入端是其他接口的镜像的标志：当Avalon接口的输入端是其他接口的镜像时，接口的 #sink_blk 将不被赋值以避免重复赋值的错误
   parameter bit               BLKSINK_EN    = 1'b0,                    ///< 引入用户定义的输入阻塞状态信号的标志（输入信号 #blksink 使能标志），1-使能 #blksink 信号， 0-禁用 #blksink 信号
   parameter bit               BLKPRCSR_EN   = 1'b0                     ///< 引入用户定义的处理器阻塞状态信号的标志（输入信号 #blkprcsr 使能标志），1-使能 #blkprcsr 信号，0-禁用 #blkprcsr 信号。
) (
   avalon_if         ifi,           ///< 本级Avalon接口
   avalon_if.nextp   prevp,         ///< 前级Avalon接口的下级节点交互信号列表
   input  wire       tdmsrcsop,     ///< 时分复用信号序列起始标志，高电平(1)有效。
   input  wire       tdmsrceop,     ///< 时分复用信号序列结束标志，高电平(1)有效。
   input  wire       blksink,       ///< 用户定义的输入阻塞标志，除了置位Avalon接口的 #sink_blk 信号外，还会屏蔽输入的 #sink_valid 信号（即使 #sink_valid 信号置位
                                    ///< ，也不会传递给处理器内部或者下一级Avalon接口），当例化参数 #BLKSINK_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若输入数据的阻塞状态完全取决于本级Avalon接口的 #prcsr_blk 信号，且例化参数 #BLKSINK_EN 为1，则本信号须置常数 1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   input  wire       blkprcsr,      ///< 用户定义的处理器阻塞标志。当例化参数 #BLKPRCSR_EN 为0时，本信号忽略
                                    ///< \attention
                                    ///< -# 若处理器的阻塞状态完全取决于下级Avalon接口送过来的 #src_blk 信号，且例化参数 #BLKPRCSR_EN 为1，则本信号须置常数1'b0。
                                    ///< -# 建议输入经过寄存器整理时序后的信号，以降低Avlaon接口链表中的阻塞信号组合电路长度，避免影响电路时序性能。
   output wire       running,       ///< 本级节点处理器正在运行标志，高电平(1)有效
   output logic      sclr2aclr      ///< 由Avalon接口的同步复位信号转换来的异步复位信号，用于向未提供同步复位接口的处理器模拟同步复位信号效果
);
   localparam int bitwof_srccnt            = avalon_pkg::bitwOfSrcCnt_of_ifCfg(IC);
   localparam bit[bitwof_srccnt-1:0]srccnt = (bitwof_srccnt)'(avalon_pkg::maxSrc_of_ifCfg(IC));
   avalon_prcsrmake_4tdm_frmprevp #(
      .IC            (IC            ),
      .BITWUNMATCH   (BITWUNMATCH   ),
      .SINK2TDM_TAPS (SINK2TDM_TAPS ),
      .PURGE_TDM     (PURGE_TDM     ),
      .MIRROR_SINK   (MIRROR_SINK   ),
      .BLKSINK_EN    (BLKSINK_EN    ),
      .BLKPRCSR_EN   (BLKPRCSR_EN   )
   ) prcsri(
      .ifi           (ifi        ),
      .prevp         (prevp      ),
      .tdmsrcsop     (tdmsrcsop  ),
      .tdmsrceop     (tdmsrceop  ),
      .blksink       (blksink    ),
      .blkprcsr      (blkprcsr   ),
      .src_cnt       (srccnt     ),
      .srccnt_rdysig (ifi.src_sop),
      .running       (running    ),
      .sclr2aclr     (sclr2aclr  )
   );
endmodule
/*!
 * \brief 将Avalon输入端序列范围内出现的由例化参数指定的信号在输出端扩展到序列全范围
 * \attention 当处理器时延少于序列长度时，在输出端SOP信号之后出现的信号将无法扩展到输出端SOP开始时刻
 */
module avalon_expandsig_in_duration #(
   parameter avalon_pkg::ifCfg IC        = avalon_pkg::deft_ifCfg,
   parameter int               EXPSIGCNT = 2,
   parameter bit[EXPSIGCNT-1:0]VAL2EXPND = {(EXPSIGCNT){1'b1}},
   parameter int               EXPBGNIDX = 0,
   parameter int               EXPENDIDX = avalon_pkg::maxSrc_of_ifCfg(IC)-1,
   parameter bit               UNFULLEXP = 1'b0                   ///< 是否允许非全范围扩展，1'b0-当可能出现非全范围扩展时报警，1'b1-不报警
) (
   avalon_if                  ifi,
   input  wire[EXPSIGCNT-1:0] sig2exp,
   output wire[EXPSIGCNT-1:0] sigexpd
);
   wire[1:0]ififlg4pexp, ififlg4exp;
   localparam int lat_ic = avalon_pkg::prclat_of_ifCfg(IC);
   localparam int seqlen = avalon_pkg::maxSink_of_ifCfg(IC);
   initial if (EXPBGNIDX < 0 || EXPBGNIDX >= seqlen)
      $error("avalon_expandsig_in_duration: illegal EXPBGNIDX(%0d) specified, it must be in range of [0, %0d]", EXPBGNIDX, seqlen-1);
   initial if (EXPENDIDX < 0 || EXPENDIDX >= seqlen)
      $error("avalon_expandsig_in_duration: illegal EXPENDIDX(%0d) specified, it must be in range of [0, %0d]", EXPENDIDX, seqlen-1);
   localparam int expwid = EXPENDIDX - EXPBGNIDX + 1;
   initial if (lat_ic + EXPBGNIDX < expwid && UNFULLEXP == 1'b0)
      $error("avalon_expandsig_in_duration: unfull expansion may occure because IC.prclat(%0d) + EXPBGNIDX(%0d) is less than EXPENDIDX(%0d) - EXPBGNIDX(%0d) + 1", lat_ic, EXPBGNIDX, EXPENDIDX, EXPBGNIDX);
   localparam int lat_exp = (lat_ic + EXPBGNIDX >= expwid)
                            ? expwid
                            : (lat_ic + EXPBGNIDX);
   localparam int bwofidx = avalon_pkg::bitwOfSinkIdx_of_ifCfg(IC);
   localparam bit[bwofidx-1:0]iexpbgn = (bwofidx)'(EXPBGNIDX);
   localparam bit[bwofidx-1:0]iexpend = (bwofidx)'(EXPENDIDX);
   wire[1:0]ififlg2pipe;
   assign ififlg2pipe[0] = (ifi.sink_idx == iexpbgn)
                           ? ifi.sink_valid
                           : 1'b0,
          ififlg2pipe[1] = (ifi.sink_idx == iexpend)
                           ? ifi.sink_valid
                           : 1'b0;
   avalon_auxsig_syncwith_avalonif #(
      .SIGBITW    (2                               ),
      .BUF_SRCSIG (1'b0                            ),
      .LATENCY    (lat_exp > 0 ? (lat_exp - 1) : 0 ),
      .SCLRRAM    (1'b0                            ),
      .REG_PRI    (1'b0                            )
   ) ififlg_sink2pexp(
      .crp     (ifi.crp    ),
      .auxp    (ifi.auxp   ),
      .sink_sig(ififlg2pipe),
      .src_sig (ififlg4pexp),
      .reseting(           )
   );
   avalon_auxsig_syncwith_avalonif #(
      .SIGBITW    (2                   ),
      .BUF_SRCSIG (1'b0                ),
      .LATENCY    (lat_exp > 0 ? 1 : 0 ),
      .SCLRRAM    (1'b0                ),
      .REG_PRI    (1'b0                )
   ) ififlg_sink2exp(
      .crp     (ifi.crp    ),
      .auxp    (ifi.auxp   ),
      .sink_sig(ififlg4pexp),
      .src_sig (ififlg4exp ),
      .reseting(           )
   );
   logic[EXPSIGCNT-1:0] regsig, expsig2p;
   genvar i; generate
      for (i = 0; i < EXPSIGCNT; i++) begin: EXPSIG
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(ifi.clk, ifi.aclr)) begin
            if     (ifi.aclr)                   regsig[i] <= ~VAL2EXPND[i];
            else if(ifi.sclr)                   regsig[i] <= ~VAL2EXPND[i];
            else if((~ifi.clken)|ifi.prcsr_blk) regsig[i] <= regsig[i];
            else if(sig2exp[i] == VAL2EXPND[i]) regsig[i] <= VAL2EXPND[i];
            else if(ififlg4pexp[0])             regsig[i] <= ~VAL2EXPND[i];
            else                                regsig[i] <= ififlg4exp[1]
                                                             ? (~VAL2EXPND[i])
                                                             : regsig[i];
         end
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(ifi.clk, ifi.aclr)) begin
            if     (ifi.aclr)                   expsig2p[i] <= ~VAL2EXPND[i];
            else if(ifi.sclr)                   expsig2p[i] <= ~VAL2EXPND[i];
            else if((~ifi.clken)|ifi.prcsr_blk) expsig2p[i] <= expsig2p[i];
            else if(ififlg4pexp[0])             expsig2p[i] <= (sig2exp[i] == VAL2EXPND[i] || regsig[i] == VAL2EXPND[i])
                                                               ? VAL2EXPND[i]
                                                               : (~VAL2EXPND[i]);
            else                                expsig2p[i] <= ififlg4exp[1]
                                                               ? (~VAL2EXPND[i])
                                                               : expsig2p[i];
         end
      end
   endgenerate
   localparam bit bufsrc_ic = avalon_pkg::bufSrc_of_ifCfg(IC);
   avalon_auxsig_syncwith_avalonif #(
      .SIGBITW    (EXPSIGCNT        ),
      .BUF_SRCSIG (bufsrc_ic        ),
      .LATENCY    (lat_ic - lat_exp ),
      .SCLRRAM    (1'b0             ),
      .REG_PRI    (1'b0             )
   ) ififlg_exp2src(
      .crp     (ifi.crp ),
      .auxp    (ifi.auxp),
      .sink_sig(expsig2p),
      .src_sig (sigexpd ),
      .reseting(        )
   );
endmodule
/*!
 * \brief 将内部Avalon接口的输入端信号传递至父节点Avalon接口的输入端的处理信号连接
 * \details 本模块应用于包含Avalon接口链表的父节点Avalon接口的处理器中，用于将子链表头结点的输入端信号连接至父节点Avalon接口的输入端
 */
module avalon_prcsr_attachfrmsink #(
   parameter avalon_pkg::ifCfg TOPIC       = avalon_pkg::deft_ifCfg, ///< 上层Avalon接口节点配置参数
   parameter bit               SHAREDTOPIF = 1'b0,                   ///< 上层Avalon接口节点是共享其他模块的Avalon接口节点标志，对共享的上层Avalon接口节点，本层Avalon接口链表头节点将仅连接输入信号，不连接输出信号
                                                                     ///< 1'b1-上层Avalon接口节点是共享节点，1'b0-上层Avalon接口节点是本层Avalon接口链表自有的节点
   parameter bit               BITWUNMATCH = 1'b0                    ///< 本层Avalon接口链表头节点序列参数位宽与上层节点序列参数位宽不一致标志，用于提示编译器被连接的Avalon接口链表头节点和上层节点信号位宽被显示设计为不一致
) (
   avalon_if.topsinkfrmnodp   topsinkp,            ///< 父节点Avalon接口的输入端接收子节点输入端信号的端口信号列表
   avalon_if.sink2topp        sinkp,               ///< 子节点输出的输入端信号列表
   input  wire                top_sink_blk,        ///< 父节点输出的外部输入阻塞信号 #sink_blk ，必须由用户给出。
                                                   ///< \attention 父节点的外部输入阻塞信号 #sink_blk 不单独赋值，避免某些编译器在本模块中未对
                                                   ///< 父节点的 #sink_blk 信号赋值时静默赋值默认值，从而产生父节点 #sink_blk 多重驱动的问题。
   input  wire                top_prcsr_blk,       ///< 父节点输出的处理器阻塞信号 #prcsr_blk ，必须由用户给出。
                                                   ///< \attention 父节点的外部输入阻塞信号 #prcsr_blk 不单独赋值，避免某些编译器在本模块中未对
                                                   ///< 父节点的 #prcsr_blk 赋值时静默赋值默认值，从而产生父节点 #prcsr_blk 多重驱动的问题。
   input  wire                top_usr_blk          ///< 用户指定给父节点的处理器阻塞信号 #usr_blk ，必须由用户给出，用户不使用则可置 0 。
);
   initial begin
      if (BITWUNMATCH == 1'b0 && $bits(sinkp.sink_nxtidx) != $bits(topsinkp.sink_nxtidx))
         $error("avalon_prcsr_attachfrmsink: the bitwidth of sinkp.sink_nxtidx(%0d) and topsinkp.sink_nxtidx(%0d) does not match!", $bits(sinkp.sink_nxtidx), $bits(topsinkp.sink_nxtidx));
      if (BITWUNMATCH == 1'b0 && $bits(sinkp.sink_idx) != $bits(topsinkp.sink_idx))
         $error("avalon_prcsr_attachfrmsink: the bitwidth of sinkp.sink_idx(%0d) and topsinkp.sink_idx(%0d) does not match!", $bits(sinkp.sink_idx), $bits(topsinkp.sink_idx));
      if (BITWUNMATCH == 1'b0 && $bits(sinkp.sink_cnt) != $bits(topsinkp.sink_cnt))
         $error("avalon_prcsr_attachfrmsink: The bitwidth of sinkp.sink_cnt(%0d) and topsinkp.sink_cnt(%0d) does not match!", $bits(sinkp.sink_cnt), $bits(topsinkp.sink_cnt));
   end
   localparam int bitwof_topsinkidx = avalon_pkg::bitwOfSinkIdx_of_ifCfg(TOPIC);
   localparam int bitwof_topsinkcnt = avalon_pkg::bitwOfSinkCnt_of_ifCfg(TOPIC);
   generate if (SHAREDTOPIF == 1'b0) begin
      assign topsinkp.sink_idx    = (bitwof_topsinkidx)'(sinkp.sink_idx);
      assign topsinkp.sink_nxtidx = (bitwof_topsinkidx)'(sinkp.sink_nxtidx);
      assign topsinkp.sink_cnt    = (bitwof_topsinkcnt)'(sinkp.sink_cnt);
      assign topsinkp.sink_sop    = sinkp.sink_sop;
      assign topsinkp.sink_eop    = sinkp.sink_eop;
      assign topsinkp.sink_valid  = sinkp.sink_valid;
      assign topsinkp.prcsr_blk   = top_prcsr_blk;
      assign topsinkp.usr_blk     = top_usr_blk;
      assign topsinkp.sink_blk    = top_sink_blk;
   end endgenerate
endmodule
/*!
 * \brief 将父节点Avalon接口的输入端信号传递至Avalon接口子链表头结点的输入端的处理信号连接
 * \details 本模块应用于同时包含Avalon接口子链表和父节点Avalon接口的模块中，用于将父节点Avalon接口的输入端信号传递至子链表头结点的输入端
 */
module avalon_prcsr_attach2sink #(
   parameter avalon_pkg::ifCfg SINKPIC     = avalon_pkg::deft_ifCfg, ///< 本层Avalon接口链表头节点配置参数
   parameter bit               SHAREDTOPIF = 1'b0,                   ///< 上层Avalon接口节点是共享其他模块的Avalon接口节点标志，对共享的上层Avalon接口节点，本层Avalon接口链表头节点将仅连接输入信号，不连接输出信号
                                                                     ///< 1'b1-上层Avalon接口节点是共享节点，1'b0-上层Avalon接口节点是本层Avalon接口链表自有的节点
   parameter bit               BITWUNMATCH = 1'b0                    ///< 本层Avalon接口链表头节点序列参数位宽与上层节点序列参数位宽不一致标志，用于提示编译器被连接的Avalon接口链表头节点和上层节点信号位宽被显示设计为不一致
) (
   avalon_if.topsink2nodp  topsinkp,               ///< 父节点Avalon接口的输入端信号向子节点输入端传递的端口信号列表
   avalon_if.sinkp         sinkp,                  ///< 子节点输入端信号列表
   input  wire             top_sink_blk,           ///< 父节点输出的外部输入阻塞信号 #sink_blk ，必须由用户给出。
                                                   ///< \attention 父节点的外部输入阻塞信号 #sink_blk 不单独赋值，避免某些编译器在本模块中未对
                                                   ///< 父节点的 #sink_blk 信号赋值时静默赋值默认值，从而产生父节点 #sink_blk 多重驱动的问题。
   input  wire             top_prcsr_blk,          ///< 父节点输出的外部输入阻塞信号 #prcsr_blk ，必须由用户给出。
                                                   ///< \attention 父节点的外部输入阻塞信号 #prcsr_blk 不单独赋值，避免某些编译器在本模块中未对
                                                   ///< 父节点的 #prcsr_blk 赋值时静默赋值默认值，从而产生父节点 #prcsr_blk 多重驱动的问题。
   input  wire             top_usr_blk             ///< 用户指定给父节点的处理器阻塞信号 #usr_blk ，必须由用户给出，用户不使用则可置 0 。
);
   initial begin
      if (BITWUNMATCH == 1'b0 && $bits(sinkp.sink_nxtidx) != $bits(topsinkp.sink_nxtidx))
         $error("avalon_prcsr_attach2sink: the bitwidth of sinkp.sink_nxtidx(%0d) and topsinkp.sink_nxtidx(%0d) does not match!", $bits(sinkp.sink_nxtidx), $bits(topsinkp.sink_nxtidx));
      if (BITWUNMATCH == 1'b0 && $bits(sinkp.sink_idx) != $bits(topsinkp.sink_idx))
         $error("avalon_prcsr_attach2sink: the bitwidth of sinkp.sink_idx(%0d) and topsinkp.sink_idx(%0d) does not match!", $bits(sinkp.sink_idx), $bits(topsinkp.sink_idx));
      if (BITWUNMATCH == 1'b0 && $bits(sinkp.sink_cnt) != $bits(topsinkp.sink_cnt))
         $error("avalon_prcsr_attach2sink: The bitwidth of sinkp.sink_cnt(%0d) and topsinkp.sink_cnt(%0d) does not match!", $bits(sinkp.sink_cnt), $bits(topsinkp.sink_cnt));
   end
   localparam int bitwof_sinkidx = avalon_pkg::bitwOfSinkIdx_of_ifCfg(SINKPIC);
   localparam int bitwof_sinkcnt = avalon_pkg::bitwOfSinkCnt_of_ifCfg(SINKPIC);
   assign sinkp.sink_idx    = (bitwof_sinkidx)'(topsinkp.sink_idx);
   assign sinkp.sink_nxtidx = (bitwof_sinkidx)'(topsinkp.sink_nxtidx);
   assign sinkp.sink_cnt    = (bitwof_sinkcnt)'(topsinkp.sink_cnt);
   assign sinkp.sink_sop    = topsinkp.sink_sop;
   assign sinkp.sink_eop    = topsinkp.sink_eop;
   assign sinkp.sink_valid  = topsinkp.sink_valid;
   generate if (SHAREDTOPIF == 1'b0) begin
      assign topsinkp.prcsr_blk = top_prcsr_blk,
             topsinkp.sink_blk  = top_sink_blk,
             topsinkp.usr_blk   = top_usr_blk;
   end endgenerate
endmodule
/*!
 * \brief 将内部Avalon接口的输出端信号传递至父节点Avalon接口的输出端的处理信号连接
 * \details 本模块应用于包含Avalon接口链表的父节点Avalon接口的处理器中，用于将子链表尾节点的输出端信号传递至父节点Avalon接口的输出端
 */
module avalon_prcsr_attachfrmsrc #(
   parameter avalon_pkg::ifCfg TOPIC       = avalon_pkg::deft_ifCfg, ///< 上层Avalon接口节点配置参数
   parameter bit               SHAREDTOPIF = 1'b0,                   ///< 上层Avalon接口节点是共享其他模块的Avalon接口节点标志，对共享的上层Avalon接口节点，本层Avalon接口链表头节点将仅连接输入信号，不连接输出信号
                                                                     ///< 1'b1-上层Avalon接口节点是共享节点，1'b0-上层Avalon接口节点是本层Avalon接口链表自有的节点
   parameter bit               BITWUNMATCH = 1'b0                    ///< 本层Avalon接口链表尾节点序列参数位宽与上层节点序列参数位宽不一致标志，用于提示编译器被连接的Avalon接口链表尾节点和上层节点信号位宽被显示设计为不一致
) (
   avalon_if.topsrcfrmnodp topsrcp,                ///< 父节点Avalon接口的输出端接收子节点输出端信号的端口信号列表
   avalon_if.nextp         nextp                   ///< 子节点输出端信号列表
);
   initial begin
      if (BITWUNMATCH == 1'b0 && $bits(topsrcp.src_nxtidx) != $bits(nextp.src_nxtidx))
         $error("avalon_prcsr_attachfrmsrc: the bitwidth of topsrcp.src_nxtidx(%0d) and nextp.src_nxtidx(%0d) does not match!", $bits(topsrcp.src_nxtidx), $bits(nextp.src_nxtidx));
      if (BITWUNMATCH == 1'b0 && $bits(topsrcp.src_idx) != $bits(nextp.src_idx))
         $error("avalon_prcsr_attachfrmsrc: the bitwidth of topsrcp.src_idx(%0d) and nextp.src_idx(%0d) does not match!", $bits(topsrcp.src_idx), $bits(nextp.src_idx));
      if (BITWUNMATCH == 1'b0 && $bits(topsrcp.src_cnt) != $bits(nextp.src_cnt))
         $error("avalon_prcsr_attachfrmsrc: The bitwidth of topsrcp.src_cnt(%0d) and nextp.src_cnt(%0d) does not match!", $bits(topsrcp.src_cnt), $bits(nextp.src_cnt));
   end
   localparam int bitwof_topsrcidx = avalon_pkg::bitwOfSrcIdx_of_ifCfg(TOPIC);
   localparam int bitwof_topsrccnt = avalon_pkg::bitwOfSrcCnt_of_ifCfg(TOPIC);
   generate if (SHAREDTOPIF == 1'b0) begin
      assign topsrcp.src_idx    = (bitwof_topsrcidx)'(nextp.src_idx);
      assign topsrcp.src_nxtidx = (bitwof_topsrcidx)'(nextp.src_nxtidx);
      assign topsrcp.src_cnt    = (bitwof_topsrccnt)'(nextp.src_cnt);
      assign topsrcp.src_eop    = nextp.src_eop;
      assign topsrcp.src_sop    = nextp.src_sop;
      assign topsrcp.src_valid  = nextp.src_valid;
      assign topsrcp.src_bufsel = nextp.src_bufsel;
   end endgenerate
   assign nextp.src_blk = topsrcp.src_blk;
endmodule

