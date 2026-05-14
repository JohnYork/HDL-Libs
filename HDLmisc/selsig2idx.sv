/*!
 * \license SPDX-License-Identifier: MIT
 * \file selsig2idx.sv
 * \brief 选通信号至索引转换器
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, shifttaps
 */
`include "miscs.svh"
module selsig2idx #(
   parameter int SELSIGBITW = 4,    ///< 选通信号位宽
   parameter bit PRI_MSB    = 1'b0, ///< 优先选择高位选通信号标志，1'b0-低位优先选通，1'b1-高位优先选通
   parameter int DLYTAPS    = 0     ///< 延迟输出时钟拍数，=0:组合逻辑直接输出，>0:寄存器打拍后输出
) (clk, aclr, sclr, clken, selsig, idx, valid);
   input  bit                 clk;     ///< 驱动时钟
   input  wire                aclr;    ///< 异步复位信号，高电平(1)有效
   input  wire                sclr;    ///< 同步复位信号，高电平(1)有效
   input  wire                clken;   ///< 时序逻辑更新使能标志，高电平(1)使能
   input  wire[SELSIGBITW-1:0]selsig;  ///< 待转换的选通信号阵列，高电平(1)选通
   localparam int idxbitw = miscs::minbitw_of_integer(SELSIGBITW-1,31);
   output logic[idxbitw-1:0]  idx;     ///< 输出经转换后的索引值
   output logic               valid;   ///< 输出索引值有效标志

   logic[idxbitw-1:0]idx_sel;
   logic             valid_sel;
   localparam int istart = PRI_MSB ? SELSIGBITW-1 : 0;
   localparam int iend   = PRI_MSB ? 0            : SELSIGBITW-1;
   always_comb begin
      idx_sel = (idxbitw)'(SELSIGBITW);
      valid_sel   = '0;
      if (PRI_MSB) for (int i = SELSIGBITW-1; i >= 0; i--) begin
         if (selsig[i]) begin
            idx_sel = (idxbitw)'(i);
            valid_sel   = '1;
            break;
         end
      end
      else for (int i = 0; i < SELSIGBITW; i++) begin
         if (selsig[i]) begin
            idx_sel = (idxbitw)'(i);
            valid_sel   = '1;
            break;
         end
      end
   end
   generate if (DLYTAPS > 0) begin
      logic[idxbitw-1:0]  idx2o;             ///< 输出经转换后的索引值
      logic               valid2o;           ///< 输出索引值有效标志
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) idx2o <= '0;
         else if (sclr) idx2o <= '0;
         else if (clken)idx2o <= idx_sel;
         else           idx2o <= idx2o;
         if      (aclr) valid2o <= '0;
         else if (sclr) valid2o <= '0;
         else if (clken)valid2o <= valid_sel;
         else           valid2o <= valid2o;
      end
      shiftfixtaps #(
         .DATABITW   (idxbitw+1  ),
         .TAP_DIST   (DLYTAPS-1  ),
         .SCLR_ONRAM (1'b0       ),
         .IMPLBYLOGIC(1'b0       )
      ) pipe2out(
         .clk     (clk              ),
         .aclr    (aclr             ),
         .sclr    (sclr             ),
         .clken   (clken            ),
         .shiftin ({valid2o, idx2o} ),
         .shiftout({valid, idx}     ),
         .reseting(                 )
      );
   end else begin
      assign idx   = idx_sel;
      assign valid = valid_sel;
   end endgenerate
endmodule

