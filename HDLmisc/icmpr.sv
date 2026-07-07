/*!
 * \license SPDX-License-Identifier: MIT
 * \file icmpr.sv
 * \brief 整型数比较器
 * \author JohnYork <johnyork@yeah.net>
 * \depends pipedelay
 */
module icmpr #(
   parameter int BITW      = 8,                    ///< 被比较数据位宽
   parameter bit SIGNED    = 1'b0,                 ///< 是否使用有符号数比较模式，1'b1-有符号数，1'b0-无符号数
   parameter int DELAYTAPS = 0                     ///< 结果延迟输出标志
) (
   input  bit           clk,
   input  wire          aclr,
   input  wire          clken,
   input  wire[BITW-1:0]dataa,
   input  wire[BITW-1:0]datab,
   output wire          aeb,
   output wire          agb,
   output wire          ageb,
   output wire          alb,
   output wire          aleb,
   output wire          aneb
);
   wire aeb2o, agb2o, ageb2o, alb2o, aleb2o, aneb2o;
   generate if (SIGNED) begin
      assign aeb2o = (signed'(dataa) == signed'(datab)) ? 1'b1 : 1'b0;
      assign alb2o = (signed'(dataa) <  signed'(datab)) ? 1'b1 : 1'b0;
   end else begin
      assign aeb2o = (unsigned'(dataa) == unsigned'(datab)) ? 1'b1 : 1'b0;
      assign alb2o = (unsigned'(dataa) <  unsigned'(datab)) ? 1'b1 : 1'b0;
   end endgenerate
   assign aleb2o = alb2o | aeb2o;
   assign agb2o  = ~aleb2o;
   assign aneb2o = ~aeb2o;
   assign ageb2o = ~alb2o;
   pipedelay_taps #(
      .DATABITW(6),  .DELAYTAPS(DELAYTAPS)
   ) pipeout(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(1'b1),
      .x({aeb2o, alb2o, aleb2o, agb2o, aneb2o, ageb2o}),
      .pipe_x({aeb, alb, aleb, agb, aneb, ageb})
   );
endmodule
