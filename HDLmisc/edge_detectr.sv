/*!
 * \license SPDX-License-Identifier: MIT
 * \file edge_detectr.sv
 * \brief 上升/下降边沿检测器
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs
 */
`include "miscs.svh"
module edge_detectr #(
   parameter int EDGE_WANT  = 1,                   ///< 边沿检测类型，1-上升沿检测，-1-下降沿检测，0-上升/下降沿检测
   parameter bit CLKEN_PULS = 1'b0,                ///< 边沿检测时钟使能信号 #clken_puls 使能标识，1-使能，0-禁用
   parameter bit DELAY_OUT  = 1'b0,                ///< 延迟输出标志，1-延迟一个系统钟输出，0-以组合逻辑输出
   parameter bit CLKEN_OUT  = 1'b0                 ///< 延迟输出时钟使能信号 #clken_out 使能标识，1-使能，0-禁用
) (
   input  bit   clk,                               ///< 驱动时钟
   input  wire  aclr,                              ///< 异步复位信号，高电平(1)有效
   input  wire  sclr,                              ///< 同步复位信号，高电平(1)有效
   input  wire  clken_puls,                        ///< 边沿检测时钟使能信号，高电平(1)有效， #CLKEN_PULS 为0时本信号忽略
   input  wire  insig,                             ///< 被测信号
   input  wire  clken_out,                         ///< 延迟输出时钟使能信号，高电平(1)有效， #DELAY_OUT 为0或 #CLKEN_OUT 为0时本信号忽略
   output logic edgsig                             ///< 边沿信号，一个clk宽度，高电平(1)有效-探测到被测信号的边沿
);
   wire insig2use;
   generate if (CLKEN_PULS) begin
      logic insig_lat;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr)       insig_lat <= '0;
         else if (sclr)       insig_lat <= '0;
         else if (clken_puls) insig_lat <= insig;
         else                 insig_lat <= insig_lat;
      end
      assign insig2use = clken_puls ? insig : insig_lat;
   end else assign insig2use = insig;
   endgenerate
   reg prev_sig;
   localparam bit RISING = EDGE_WANT <= 0 ? 1'b0 : 1'b1;
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr)                   prev_sig <= RISING;  // 保证复位后第一个信号不会产生错误的边沿信号
      else if (sclr)                   prev_sig <= RISING;  // 保证复位后第一个信号不会产生错误的边沿信号
      else if (CLKEN_PULS&~clken_puls) prev_sig <= prev_sig;
      else                             prev_sig <= insig2use;
   end
   wire edge_pulse;
   generate if (EDGE_WANT > 0) begin: DETECT_RISING
      assign edge_pulse = (~prev_sig) & insig2use;
   end: DETECT_RISING
   else if (EDGE_WANT < 0)begin: DETECT_FALLEN
      assign edge_pulse = prev_sig & (~insig2use);
   end: DETECT_FALLEN
   else begin: DETECT_BOTH
      assign edge_pulse = prev_sig ^ insig2use;
   end: DETECT_BOTH
   if (DELAY_OUT) begin: OUT_DELAYED
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr)                edgsig <= '0;
         else if (sclr)                edgsig <= '0;
         else if (CLKEN_OUT&~clken_out)edgsig <= edgsig;
         else                          edgsig <= edge_pulse;
      end
   end: OUT_DELAYED
   else begin: OUT_DIRECT
      assign edgsig = edge_pulse;
   end:OUT_DIRECT
   endgenerate
endmodule

