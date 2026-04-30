/*!
 * \license SPDX-License-Identifier: MIT
 * \file clkdx.sv
 * \brief 跨时钟域传递信号模块
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs
 */
`include "miscs.svh"
module clkdx #(
   parameter int BITW    = 1,       ///< 待传递的信号位宽
   parameter bit REGSRC  = 1'b0,    ///< 锁存源时钟域信号标志，1'b1-对源时钟域的信号执行一拍锁存，1'b0-不执行锁存
   parameter int DSTTAPS = 2,       ///< 目标时钟域中延迟保持的时钟拍数，应至少保持源时钟域一个时钟周期的时间
   parameter int OUTTAPS = 1        ///< 输出目标时钟域中信号的拍数，模块仅输出目标时钟域中延迟的 #DSTTAPS 拍数中的最后 #OUTTAPS 拍
) (
   input  bit                          clksrc,     ///< 源时钟域驱动时钟
   input  wire                         sclrsrc,    ///< 源时钟域同步复位信号，高电平(1)有效
   input  wire[BITW-1:0]               src,        ///< 源时钟域输入信号
   input  wire                         aclr,       ///< 异步复位信号，高电平(1)有效
   input  bit                          clkdst,     ///< 目标时钟域驱动时钟
   input  wire                         sclrdst,    ///< 目标时钟域同步复位信号，高电平(1)有效
   output wire[OUTTAPS-1:0][BITW-1:0]  dst         ///< 目标时钟域输出信号，最后一拍索引为0，倒数第二拍索引为1，依次类推
);
   logic[BITW-1:0]src2x;
   generate
      if (REGSRC) always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clksrc, aclr)) begin
         if      (aclr)    src2x <= '0;
         else if (sclrsrc) src2x <= '0;
         else              src2x <= src;
      end else assign src2x = src;
   endgenerate
   logic[DSTTAPS-1:0][BITW-1:0] dst2o;
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clkdst, aclr)) begin
      if      (aclr)    dst2o <= '0;
      else if (sclrdst) dst2o <= '0;
      else              dst2o <= {src2x, dst2o[DSTTAPS-1:1]};
   end
   assign dst = dst2o[OUTTAPS-1:0];
endmodule
