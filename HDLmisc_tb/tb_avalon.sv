`include "avalon.svh"
`timescale 1ps/1ps
module test_avalon_linkmux #(
   parameter bit DBGUSEOLD = 1'b0
) (
   input bit clk,
   input wire aclr, sclr, clken
);
   // 测试 avalon_linkmux_prevpbyidx
   localparam avalon_pkg::ifCfg icprevlmi0 = avalon_pkg::make_ifCfg(
      .maxSink(10),
      .maxSrc (10),
      .prclat (6),
      .bufSrc(1'b0)
   );
   avalon_if #(
      .IC(icprevlmi0)
   ) prevlmifi[2:0] (
      .clk  (clk  ),
      .aclr (aclr ),
      .sclr (sclr ),
      .clken(clken)
   );
   avalon_makesink_forhead_maxsink #(
      .IC(icprevlmi0)
   ) prevlmifi0_makesink(
      .ifi(prevlmifi[0]),
      .sink_blk()
   );
   avalon_prcsrmake_4sink #(
      .IC (icprevlmi0)
   ) prevlmi0_prcsr(
      .crp           (prevlmifi[0].crp                         ),
      .procp         (prevlmifi[0].procp                       ),
      .srcp          (prevlmifi[0].srcp                        ),
      .blksink       (1'b0                                     ),
      .blkprcsr      (1'b0                                     ),
      .src_cnt       (avalon_pkg::maxSrc_of_ifCfg(icprevlmi0)  ),
      .srccnt_rdysig (prevlmifi[0].src_sop                     ),
      .running       (                                         ),
      .sclr2aclr     (                                         )
   );
   avalon_makesink_forhead_maxsink #(
      .IC(icprevlmi0)
   ) prevlmifi1_makesink(
      .ifi(prevlmifi[1]),
      .sink_blk()
   );
   avalon_prcsrmake_4sink #(
      .IC (icprevlmi0)
   ) prevlmi1_prcsr(
      .crp     (prevlmifi[1].crp  ),
      .procp   (prevlmifi[1].procp),
      .srcp    (prevlmifi[1].srcp ),
      .blksink (1'b0          ),
      .blkprcsr(1'b0          ),
      .src_cnt (avalon_pkg::maxSrc_of_ifCfg(icprevlmi0)),
      .srccnt_rdysig (prevlmifi[1].src_sop),
      .running       (),
      .sclr2aclr     ()
   );
   avalon_makesink_forhead_maxsink #(
      .IC(icprevlmi0)
   ) prevlmifi2_makesink(
      .ifi(prevlmifi[2]),
      .sink_blk()
   );
   avalon_prcsrmake_4sink #(
      .IC (icprevlmi0)
   ) prevlmi2_prcsr(
      .crp     (prevlmifi[2].crp  ),
      .procp   (prevlmifi[2].procp),
      .srcp    (prevlmifi[2].srcp ),
      .blksink (1'b0          ),
      .blkprcsr(1'b0          ),
      .src_cnt (avalon_pkg::maxSrc_of_ifCfg(icprevlmi0)),
      .srccnt_rdysig (prevlmifi[2].src_sop),
      .running       (),
      .sclr2aclr     ()
   );
   avalon_if #(
      .IC(icprevlmi0)
   ) lmsinkifi[1:0](
      .clk  (clk  ),
      .aclr (aclr ),
      .sclr (sclr ),
      .clken(clken)
   );
   localparam avalon_pkg::linkMuxCfg lmc = avalon_pkg::make_linkMuxCfg(
      .prevPortCnt      (3    ),
      .prevPortMuxTaps  (2    ),
      .sinkPortCnt      (2    ),
      .sinkPortBufSig   (1'b1 )
   );
   logic[1:0] prevpidx, prevpidx2o;
   logic[1:0] sinkp_cs, sinkp_cs2o;
   logic[1:0] srcblk, srcblk2o;
   always_ff @(posedge clk) prevpidx2o <= prevpidx;
   always_ff @(posedge clk) sinkp_cs2o <= sinkp_cs;
   always_ff @(posedge clk) srcblk2o <= srcblk;
   initial begin
      prevpidx = 0;
      sinkp_cs = 2'b01;
      srcblk[0] = 0;
      srcblk[1] = 0;
      # 30
         srcblk[0] = 1;
      # 10
         srcblk[0] = 0;
      # 96
         prevpidx = 1;
      # 20
         prevpidx = 0;
      # 30
         sinkp_cs = 2'b00;
      # 10
         sinkp_cs = 2'b01;
      # 30
         sinkp_cs = 2'b00;
      # 10
         sinkp_cs = 2'b10;
   end
   avalon_linkmux_if #(
      .LMC(lmc)
   ) lmifi();
   avalon_linkmux_prevpbyidx #(
      .PREV_IC       (icprevlmi0 ),
      .SINK_IC       (icprevlmi0 ),
      .BITW_UNMATCH  (1'b0       ),
      .MUXSINKP      (1'b0       ),
      .LMC           (lmc        )
   ) lmi(
      .previfi       (prevlmifi     ),
      .prevp_idx     (prevpidx2o    ),
      .blkprev4nocs  (3'b111        ),
      .sinkifi       (lmsinkifi     ),
      .sinkp_cs      (sinkp_cs2o    ),
      .muxp          (lmifi.ifmuxp  )
   );
   avalon_auxsig_syncwith_linkmux_nomux #(
      .SIGBITW(4),
      .SINKPORTIDX2SYNC(0),
      .LMC(lmc)
   ) sync_nomux(
      .auxp    (lmifi.auxmuxp          ),
      .sig2link(prevlmifi[0].src_idx),
      .sig2out (                    )
   );
   avalon_prcsrmake_4sink #(
      .IC (icprevlmi0)
   ) lmsinki0_prcsr(
      .crp     (lmsinkifi[0].crp  ),
      .procp   (lmsinkifi[0].procp),
      .srcp    (lmsinkifi[0].srcp ),
      .blksink (1'b0          ),
      .blkprcsr(1'b0          ),
      .src_cnt (avalon_pkg::maxSrc_of_ifCfg(icprevlmi0)),
      .srccnt_rdysig (lmsinkifi[0].src_sop),
      .running       (),
      .sclr2aclr     ()
   );
   avalon_prcsrmake_4sink #(
      .IC (icprevlmi0)
   ) lmsinki1_prcsr(
      .crp     (lmsinkifi[1].crp  ),
      .procp   (lmsinkifi[1].procp),
      .srcp    (lmsinkifi[1].srcp ),
      .blksink (1'b0          ),
      .blkprcsr(1'b0          ),
      .src_cnt (avalon_pkg::maxSrc_of_ifCfg(icprevlmi0)),
      .srccnt_rdysig (lmsinkifi[1].src_sop),
      .running       (),
      .sclr2aclr     ()
   );
   avalon_endsrc end_sinki0(
      .nextp(lmsinkifi[0].nextp),
      .src_blk(srcblk2o[0])
   );
   avalon_endsrc end_sinki1(
      .nextp(lmsinkifi[1].nextp),
      .src_blk(srcblk2o[1])
   );
endmodule
module test_avalon_mirrormux #(
   parameter bit DBG_USEOLD
) (
   input bit clk,
   input wire aclr, sclr, clken
);
   logic[1:0] sinkidx, sinkidx2o;
   logic[2:0] srcblk, srcblk2o;
   initial begin
      sinkidx = 0;
      srcblk = 0;
      # 100
         srcblk = 3'b001;
      # 10
         srcblk = 3'b000;
      # 10
         sinkidx = 1;
      # 30
         sinkidx = 2;
      # 30
         sinkidx = 1;
      # 30
         sinkidx = 3;
      # 30
         sinkidx = 0;
   end
   always_ff @(posedge clk) sinkidx2o <= sinkidx;
   always_ff @(posedge clk) srcblk2o <= srcblk;
   localparam avalon_pkg::ifCfg icprevlmi0 = avalon_pkg::make_ifCfg(
      .maxSink(10),
      .maxSrc (10),
      .prclat (6),
      .bufSrc(1'b0)
   );
   avalon_if #(
      .IC(icprevlmi0)
   ) ifim[2:0] (
      .clk  (clk  ),
      .aclr (aclr ),
      .sclr (sclr ),
      .clken(clken)
   );
   avalon_makesink_forhead_maxsink #(
      .IC(icprevlmi0)
   ) prevlmifi0_makesink(
      .ifi(ifim[0]),
      .sink_blk()
   );
   avalon_endsrc endifim0(
      .nextp(ifim[0].nextp),
      .src_blk(srcblk2o[0])
   );
   avalon_makesink_forhead_maxsink #(
      .IC(icprevlmi0)
   ) prevlmifi1_makesink(
      .ifi(ifim[1]),
      .sink_blk()
   );
   avalon_endsrc endifim1(
      .nextp(ifim[1].nextp),
      .src_blk(srcblk2o[1])
   );
   avalon_makesink_forhead_maxsink #(
      .IC(icprevlmi0)
   ) prevlmifi2_makesink(
      .ifi(ifim[2]),
      .sink_blk()
   );
   avalon_endsrc endifim2(
      .nextp(ifim[2].nextp),
      .src_blk(srcblk2o[2])
   );
   avalon_if #(
      .IC(icprevlmi0)
   ) ifisvr (
      .clk  (clk  ),
      .aclr (aclr ),
      .sclr (sclr ),
      .clken(clken)
   );
   avalon_prcsrmake_4sink #(
      .IC (icprevlmi0)
   ) lmsinki0_prcsr(
      .crp     (ifisvr.crp  ),
      .procp   (ifisvr.procp),
      .srcp    (ifisvr.srcp ),
      .blksink (1'b0          ),
      .blkprcsr(1'b0          ),
      .src_cnt (avalon_pkg::maxSrc_of_ifCfg(icprevlmi0)),
      .srccnt_rdysig (ifisvr.src_sop),
      .running       (),
      .sclr2aclr     ()
   );
   localparam avalon_pkg::mirrorMuxCfg mmcfg = avalon_pkg::make_mirrorMuxCfg(
      .mirrorCnt     (3    ),
      .m2isinkMuxTaps(2    ),
      .ixmDelayOut   (1'b1 )
   );
   avalon_mirrormux_if #(
      .MMC(mmcfg)
   ) mmifi();
   avalon_mirrormux_sinkbyidx #(
      .SVR_IC        (icprevlmi0 ),
      .MIR_IC        (icprevlmi0 ),
      .BITW_UNMATCH  (1'b0       ),
      .MMC           (mmcfg      )
   ) mmi(
      .ifi                 (ifisvr),
      .src_autoblk4nocs    (1'b1),
      .ifim                (ifim),
      .msink_idx           (sinkidx),
      .msink_autoblk4nocs  (3'b111),
      .muxp                (mmifi.ifmuxp)
   );
   avalon_auxsig_syncwith_mirrormux #(
      .SINK_SIGBITW  (4    ),
      .SRC_SIGBITW   (4    ),
      .MMC           (mmcfg)
   ) sync(
      .auxp          (mmifi.auxmuxp ),
      .msinksig      ('{ifim[2].sink_idx,
                        ifim[1].sink_idx,
                        ifim[0].sink_idx} ),
      .msinksig4nocs (4'd0          ),
      .sig2sink      (              ),
      .sig2src       (ifisvr.src_idx),
      .srcsig4nocs   (4'd0          ),
      .msrcsig       (              )
   );

endmodule
module tb_avalon;
   reg clk;
   initial begin
      clk = 0;
   //   forever # 1 clk = ~clk;
   end
   always # 1 clk = ~clk;
   reg mdl_rst, clken, valid, eop, sop;
   initial begin
      mdl_rst = 0;
      clken = 0;
      valid = 0;
      eop = 0;
      sop = 0;
      # 1 mdl_rst = 1;
      # 4 mdl_rst = 0;
      // 测试正常输入一帧数据
      # 2 clken = 1;
          valid = 1;
          sop = 1;
      # 2 sop = 0;
      # 18 valid = 0;
         
      // 测试正常连续输入二帧数据
      # 10 valid = 1;
           sop = 1;
      # 2  sop = 0;
      # 36 eop = 1;
      # 2  eop = 0;
           valid = 0;
      // 测试正常连续输入1.5帧数据
      # 10 valid = 1;
           sop = 1;
      # 2 sop = 0;
      # 28 valid = 0;
      # 10 valid = 1;
            sop = 1;
      # 2  sop = 0;
      # 8 valid = 0;
      // 测试输入数据前 clken 清零，输入数据过程中 clken 清零
           clken = 0;
      # 10 valid = 1;
           sop = 1;

      # 6 clken = 1;
      # 2 clken = 0;
          sop = 0;
      # 2 clken = 1;
      # 12 eop = 1;
      # 2  eop = 0;
           valid = 0;
   end
   reg[3:0] sig;
   always_ff @(posedge clk) sig <= {sop, clken, valid, eop};
   localparam avalon_pkg::ifCfg ic = avalon_pkg::make_ifCfg(10, 10, 10, 1'b0);
   avalon_if #(.IC(ic))
   ifi0(.clk(clk),.aclr(mdl_rst),.sclr(1'b0),.clken(sig[2])),
   ifi1(.clk(clk),.aclr(mdl_rst),.sclr(1'b0),.clken(sig[2])),
   ifi2(.clk(clk),.aclr(mdl_rst),.sclr(1'b0),.clken(sig[2])),
   ifi3(.clk(clk),.aclr(mdl_rst),.sclr(1'b0),.clken(sig[2])),
   ifitop(.clk(clk),.aclr(mdl_rst),.sclr(1'b0),.clken(sig[2]));
   module procsr #(
      parameter avalon_pkg::ifCfg IC
   ) (
      avalon_if ifi
   );
      wire[avalon_pkg::bitwOfDataSeqLen(avalon_pkg::maxSrc_of_ifCfg(IC))-1:0] src_cnt;
      wire                          srccnt_rdy, srccnt_load;
      avalon_srccnt_onsink #(
         .IC(IC),
         .TDMTAPS(1)
      ) srccnt_smplr(
         .crp(ifi.crp),
         .auxp(ifi.auxp),
         .src_cnt(src_cnt),
         .rdysig(srccnt_rdy)
      );
      edge_detectr #(
         .EDGE_WANT(1),
         .CLKEN_PULS(1'b1),
         .DELAY_OUT(0),
         .CLKEN_OUT(1'b1)
      ) rdy_edge(
         .clk(ifi.clk),
         .aclr(ifi.aclr),
         .sclr(ifi.sclr),
         .clken_puls(1'b1),
         .insig(srccnt_rdy),
         .clken_out(1'b1),
         .edgsig(srccnt_load)
      );
      avalon_prcsrmake_4sink #(
         .IC(IC),
         .PIPE_PRCSR(1'b0),
         .BLKSINK_EN(1'b0),
         .BLKPRCSR_EN(1'b0)
      ) pi(
         .crp(ifi.crp),
         .procp(ifi.procp),
         .srcp(ifi.srcp),
         .blksink(1'b0),
         .blkprcsr(1'b0),
         .src_cnt(src_cnt),
         .srccnt_rdysig(srccnt_load),
         .running(),
         .sclr2aclr()
      );
   endmodule
   localparam int chain_mode = 2;// 0 - 单个链表， 1 - 子链表作为父链表的非头节点， 2 - 子链表作为父链表的头结点
   generate if (chain_mode == 0) begin: SINGLE_CHAIN
      avalon_makesink_witheop #(
         .IC(ic)
      ) node0(
         .crp(ifi0.crp),
         .sinkp(ifi0.sinkp),
         .sink_valid(sig[1]),
         .sink_sop(sig[3]),
         .sink_eop(sig[0]),
         .sink_blk()
      );
      avalon_endsrc endchain(.srcp(ifi3.nextp), .src_blk(1'b0));
   end else if (chain_mode == 1) begin: ENCAPSULATE_NONHEAD_NODE
      avalon_makesink_witheop #(
         .IC(ic)
      ) node0(
         .crp(ifitop.sinkp),
         .sinkp(ifitop.sinkp),
         .sink_valid(sig[1]),
         .sink_sop(sig[3]),
         .sink_eop(sig[0]),
         .sink_blk()
      );
      avalon_chain2node topnode(.p(ifitop.topnodp), .chainheadp(ifi0.sinkp), .chaintailp(ifi3.nextp), .top_sink_blk(ifi0.sink_blk));
      avalon_endsrc endchain(.nextp(ifitop.nextp), .src_blk(1'b0));
   end else if (chain_mode == 2) begin: ENCAPSULATE_HEAD_NODE
      avalon_makesink_witheop #(
         .IC(ic)
      ) node0(
         .crp(ifi0.crp),
         .sinkp(ifi0.sinkp),
         .sink_valid(sig[1]),
         .sink_sop(sig[3]),
         .sink_eop(sig[0]),
         .sink_blk()
      );
      avalon_chain2head tophead(.p(ifitop.topheadp), .chainheadp(ifi0.sink2topp), .chaintailp(ifi3.nextp), .top_sink_blk(ifi0.sink_blk));
      avalon_endsrc endchain(.nextp(ifitop.nextp), .src_blk(1'b0));
   end endgenerate
   localparam avalon_pkg::ifCfg ic5 = avalon_pkg::make_ifCfg(10, 10, 5, 1'b0);
   procsr #(
      .IC(ic5)
   ) pcsr_0(
      .ifi(ifi0)
   );

   avalon_link #(
      .SINKP_IC(ic5),
      .BITW_UNMATCH(1'b0)
   ) linker_0_1(
      .prevp(ifi0.nextp),
      .blkprevsrc(1'b0),
      .sinkp(ifi1.sinkp)
   );
   procsr #(
      .IC(ic5)
   ) pcsr_1(
      .ifi(ifi1)
   );

   localparam avalon_pkg::ifCfg ic7 = avalon_pkg::make_ifCfg(10, 10, 7, 1'b0);
   avalon_link #(
      .SINKP_IC(ic7),
      .BITW_UNMATCH(1'b0)
   ) linker_1_2(
      .prevp(ifi1.nextp),
      .blkprevsrc(1'b0),
      .sinkp(ifi2.sinkp)
   );
   procsr #(
      .IC(ic7)
   ) pcsr_2(
      .ifi(ifi2)
   );

   localparam avalon_pkg::ifCfg ic3 = avalon_pkg::make_ifCfg(10, 10, 3, 1'b0);
   avalon_link #(
      .SINKP_IC(ic3),
      .BITW_UNMATCH(1'b1)
   ) linker_2_3(
      .prevp(ifi2.nextp),
      .blkprevsrc(1'b0),
      .sinkp(ifi3.sinkp)
   );
   procsr #(
      .IC(ic3)
   ) pcsr_3(
      .ifi(ifi3)
   );
   // 仅一个元素输入
   localparam avalon_pkg::ifCfg oic = avalon_pkg::make_ifCfg(1, 1, 10, 1'b0);
   avalon_if #(
      .IC(oic)
   ) oneinput_ifi(.clk(clk),.aclr(mdl_rst),.sclr(1'b0),.clken(sig[2]));
   avalon_makesink_witheop #(
      .IC(oic)
   ) oneinput_sink(
      .crp(oneinput_ifi.crp),
      .sinkp(oneinput_ifi.sinkp),
      .sink_valid(sig[1]),
      .sink_sop(sig[3]),
      .sink_eop(sig[0]),
      .sink_blk()
   );
   localparam avalon_pkg::ifCfg oic3 = avalon_pkg::make_ifCfg(1, 1, 3, 1'b0);
   procsr #(
      .IC(oic3)
   ) oneinput_prcsr(
      .ifi(oneinput_ifi)
   );
   avalon_endsrc oneinput_end(
      .nextp(oneinput_ifi.nextp),
      .src_blk(1'b0)
   );
   // 仅两个元素输入
   localparam avalon_pkg::ifCfg tic3 = avalon_pkg::make_ifCfg(2, 2, 3, 1'b0);
   avalon_if #(
      .IC(tic3)
   ) twoinput_ifi(.clk(clk),.aclr(mdl_rst),.sclr(1'b0),.clken(sig[2]));
   avalon_makesink_witheop #(
      .IC(tic3)
   ) twoinput_sink(
      .crp(twoinput_ifi.crp),
      .sinkp(twoinput_ifi.sinkp),
      .sink_valid(sig[1]),
      .sink_sop(sig[3]),
      .sink_eop(sig[0]),
      .sink_blk()
   );
   procsr #(
      .IC(tic3)
   ) twoinput_prcsr(
      .ifi(twoinput_ifi)
   );
   avalon_endsrc twoinput_end(
      .nextp(twoinput_ifi.nextp),
      .src_blk(1'b0)
   );
   // \TODO: 测试 avalon_auxsig_syncwith_linkmux_nomux 是否正确同步信号
   test_avalon_linkmux #(
      .DBGUSEOLD(1'b0)
   ) lnkmux_new(
      .clk(clk),
      .aclr(1'b0),
      .sclr(mdl_rst),
      .clken(sig[2])
   );
   test_avalon_mirrormux #(
      .DBG_USEOLD(1'b0)
   ) mirrormux_new(
      .clk(clk),
      .aclr(1'b0),
      .sclr(mdl_rst),
      .clken(sig[2])
   );
   // test_avalon_mirrormux #(
   //    .DBG_USEOLD(1'b1)
   // ) mirrormux_old(
   //    .clk(clk),
   //    .aclr(1'b0),
   //    .sclr(mdl_rst),
   //    .clken(sig[2])
   // );

endmodule

