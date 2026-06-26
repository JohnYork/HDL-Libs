/*!
 * \license SPDX-License-Identifier: MIT
 * \brief 序列异常状态检测
 * \author JohnYork <johnyork@yeah.net>
 */
`include "miscs.svh"
module seqs_errchk #(
   parameter int IDXBW                = 7,         ///< 序列索引位宽
   parameter bit KEEP2SCLR_CNTUSSOP   = 1'b0,      ///< 连续SOP的异常状态置位后是否保持直到同步复位
   parameter bit KEEP2SCLR_BADSOP     = 1'b0,      ///< 非法SOP的异常状态置位后是否保持直到同步复位
   parameter bit KEEP2SCLR_NOVLDSOP   = 1'b0,      ///< 无序列有效标志的SOP异常状态置位后是否保持直到同步复位
   parameter bit KEEP2SCLR_NOVLDEOP   = 1'b0,      ///< 无序列有效标志的EOP异常状态置位后是否保持直到同步复位
   parameter bit KEEP2SCLR_UNCNTUSIDX = 1'b0,      ///< 不连续输入索引的异常状态置位后是否保持直到同步复位
   parameter bit KEEP2SCLR_NOVLDIDXCH = 1'b0,      ///< 无序列有效标志的索引值变动状态置位后是否保持直到同步复位
   parameter bit KEEP2SCLR_VLDNOSOP   = 1'b0       ///< 无序列起始标志标记过的VLD置位异常状态置位后是否保持直到同步复位
) (
   input  bit              clk,                    ///< 驱动时钟
   input  wire             aclr,                   ///< 异步复位信号，高电平(1)有效
   input  wire             sclr,                   ///< 同步复位信号，高电平(1)有效
   input  wire             clken,                  ///< 时序电路翻转使能信号，高电平(1)有效
   input  wire             vld,                    ///< 序列有效标志，高电平(1)有效
   input  wire             sop,                    ///< 序列起始标志，高电平(1)有效
   input  wire             eop,                    ///< 序列结束标志，高电平(1)有效
   input  wire[IDXBW-1:0]  idx,                    ///< 序列索引
   output logic            continuous_sop,         ///< 检测到连续的 #sop 标志
   output logic            bad_sop,                ///< 检测到非法的 #sop 标志：序列输入过程中收到 #eop 之前又收到的 #sop
   output logic            novld_sop,              ///< 检测到没有 #vld 置位的 #sop 标志
   output logic            novld_eop,              ///< 检测到没有 #vld 置位的 #eop 标志
   output logic            uncontinuous_idx,       ///< 检测到不连续的 #idx 
   output logic            novld_idxchg,           ///< 检测到没有 #vld 置位的 #idx 值变动
   output logic            vldnosop                ///< 检测到未经 #sop 标记起始的 #vld 置位
);
   generate
      logic prv_sop;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) prv_sop <= 1'b0;
         else if (sclr) prv_sop <= 1'b0;
         else           prv_sop <= clken ? sop : prv_sop;
      end

      wire chk_continuous_sop = prv_sop&sop;
      if (KEEP2SCLR_CNTUSSOP) begin
         always_latch begin
            if      (aclr) continuous_sop <= 1'b0;
            else if (sclr) continuous_sop <= 1'b0;
            else if (clken)continuous_sop <= chk_continuous_sop;
         end
      end
      else assign continuous_sop = chk_continuous_sop&clken;
      logic ongoing;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if     (aclr)  ongoing <= 1'b0;
         else if(sclr)  ongoing <= 1'b0;
         else if(~clken)ongoing <= ongoing;
         else if(sop)   ongoing <= 1'b1;
         else if(eop)   ongoing <= 1'b0;
         else           ongoing <= ongoing;
      end

      wire chk_bad_sop = ongoing&sop&(~eop);
      if (KEEP2SCLR_BADSOP) begin
         always_latch begin
            if      (aclr) bad_sop <= 1'b0;
            else if (sclr) bad_sop <= 1'b0;
            else if (clken)bad_sop <= chk_bad_sop;
         end
      end
      else assign bad_sop = chk_bad_sop&clken;

      wire chk_novld_sop = sop&(~vld);
      if (KEEP2SCLR_NOVLDSOP) begin
         always_latch begin
            if      (aclr) novld_sop <= 1'b0;
            else if (sclr) novld_sop <= 1'b0;
            else if (clken)novld_sop <= chk_novld_sop;
         end
      end
      else assign novld_sop = chk_novld_sop&clken;

      wire chk_novld_eop = eop&(~vld);
      if (KEEP2SCLR_NOVLDEOP) begin
         always_latch begin
            if      (aclr) novld_eop <= 1'b0;
            else if (sclr) novld_eop <= 1'b0;
            else if (clken)novld_eop <= chk_novld_eop;
         end
      end
      else assign novld_eop = chk_novld_eop&clken;

      logic[IDXBW-1:0] prv_idx;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) prv_idx <= '0;
         else if (sclr) prv_idx <= '0;
         else           prv_idx <= (clken&vld) ? idx : prv_idx;
      end
      wire chk_uncontinuous_idx = (idx != (prv_idx + ((IDXBW)'(1)))) ? vld : 1'b0;
      if (KEEP2SCLR_UNCNTUSIDX) begin
         always_latch begin
            if      (aclr) uncontinuous_idx <= 1'b0;
            else if (sclr) uncontinuous_idx <= 1'b0;
            else if (clken)uncontinuous_idx <= chk_uncontinuous_idx;
         end
      end
      else assign uncontinuous_idx = chk_uncontinuous_idx&clken;

      wire chk_novld_idxchg = (idx != prv_idx) ? ~vld : 1'b0;
      if (KEEP2SCLR_NOVLDIDXCH) begin
         always_latch begin
            if      (aclr) novld_idxchg <= 1'b0;
            else if (sclr) novld_idxchg <= 1'b0;
            else if (clken)novld_idxchg <= chk_novld_idxchg;
         end
      end
      else assign novld_idxchg = chk_novld_idxchg&clken;

      wire chk_vldnosop = vld&(~(ongoing|sop));
      if (KEEP2SCLR_VLDNOSOP) begin
         always_latch begin
            if      (aclr) vldnosop <= 1'b0;
            else if (sclr) vldnosop <= 1'b0;
            else if (clken)vldnosop <= chk_vldnosop;
         end
      end
      else assign vldnosop = chk_vldnosop&clken;
   endgenerate
endmodule
