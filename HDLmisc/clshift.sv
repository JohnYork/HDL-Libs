/*!
 * \license SPDX-License-Identifier: MIT
 * \file clshift.sv
 * \brief 逻辑、算术移位器
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, pipedelay
 */
`include "miscs.svh"
`define __INC_FROM_CLSHIFT__
`include "clshift.svh"
module clshift #(
   parameter int unsigned BITWIDTH     = 1,        ///< 输入/输出数据位宽
   parameter bit          DIRECTION    = 0,        ///< 移位方向，1- shift to LSB, 0- shift to MSB
   parameter bit          ARITHMATIC   = 0,        ///< 算术移位标志，1- 算术移位（右移时带符号位扩展），0- 逻辑移位（右移不带符号位扩展）
   parameter int          DELAYTAPS    = 1,        ///< 模块运算时延拍数
   parameter bit          PIPELINE     = 0,        ///< 流水线使能标志，仅当DELAY_TAPS > 0 时有效，1- 增加寄存器以使能流水线操作，0- 禁用流水线操作以减少寄存器的使用
   parameter bit          PIPEINPUT    = 0,        ///< 使能流水线保存和输出输入数据标志， 1- 流水线保持和输出输入数据， 0- 流水线不保持输入数据
   parameter bit          PIPEDISTANCE = 0         ///< 使能流水线保持和输出移位位数标志， 1- 流水线保持和输出移位位数， 0- 流水线不输出移位位数
) (clk, aclr, sclr, clken, x, distance, result, pipe_x, pipe_distance);
   input  bit                    clk;              ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                   aclr;             ///< 异步复位信号，高电平(1)有效，当 #DELAYTAPS 全为 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                   sclr;             ///< 同步复位信号，高电平(1)有效，当 #DELAYTAPS 全为 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                   clken;           ///< 模块使能信号，高电平(1)有效
   localparam int distancbitw = clshift_pkg::distanceBitwOfDataBitw(BITWIDTH);
   input  wire [BITWIDTH-1:0]    x;                ///< 待移位的数据， \attention 当 #PIPELINE == 0 时，输入数据时序间隔必须大于等于 #DELAYTAPS 指示的延迟量，否则输出结果不可靠
   input  wire [distancbitw-1:0] distance;         ///< 移位位数， \attention 当 #PIPELINE == 0 时，输入数据时序间隔必须大于等于 #DELAYTAPS 指示的延迟量，否则输出结果不可靠
   output wire [BITWIDTH-1:0]    result;           ///< 移位结果
   output logic[BITWIDTH-1:0]    pipe_x;           ///< 流水线同步保持输出的输入数据，当 #PIPEINPUT == 0 时，本端口输出信号与端口 #x 一致
   output logic[distancbitw-1:0] pipe_distance;    ///< 流水线同步保持输出的移位位数，当 #PIPEINPUT == 0 时，本端口输出信号与端口 #distance 一致

   import miscs::*;
   localparam int total_stage = clshift_pkg::stageCountOfDataBitw(BITWIDTH);
   localparam int taps2delay = DELAYTAPS;
   genvar i; generate
      if (DIRECTION == 1) begin: PADBIT
         wire padbit_msb;
         if(ARITHMATIC) assign padbit_msb = x[BITWIDTH-1];
         else           assign padbit_msb = 1'b0;
      end
      for (i = distancbitw-1; i >= 0; i--) begin: SHIFT_STAGE
         localparam int delaytaps = miscs::delaytaps4stage(distancbitw, i, taps2delay, 1'b0);
         localparam int msbidx_ofdistance = PIPEDISTANCE ? (distancbitw - 1) : i;
         wire[msbidx_ofdistance :0] stage_distance, distance_out;
         pipedelay_taps #(
            .DATABITW(msbidx_ofdistance + 1),.DELAYTAPS((PIPEDISTANCE == 1'b1 || i > 0) ? delaytaps : 0)
         ) pipe_distance(
            .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),  .x(stage_distance),  .pipe_x(distance_out)
         );
         logic [BITWIDTH-1:0] stage_input, shift_res, stage_res, stage_out;
         if (i == distancbitw - 1) begin
            assign stage_input    = x;
            assign stage_distance = distance;
         end
         else begin
            assign stage_input    = SHIFT_STAGE[i+1].stage_out;
            assign stage_distance = SHIFT_STAGE[i+1].distance_out[msbidx_ofdistance:0];
         end
         if (DIRECTION == 1) begin: SDIR_R
            logic bit2pad;
            if (i > 0) begin: BIT2PAD_O
               logic bit2pad_o;
               pipedelay_taps #(
                  .DATABITW(1),  .DELAYTAPS((PIPELINE&ARITHMATIC) ? delaytaps : 0)
               ) pipe_padbit(
                  .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),  .x(bit2pad),.pipe_x(bit2pad_o)
               );
            end
            if (i < distancbitw - 1)assign bit2pad = SHIFT_STAGE[i+1].SDIR_R.BIT2PAD_O.bit2pad_o;
            else                    assign bit2pad = PADBIT.padbit_msb;
            if (2**i >= BITWIDTH)assign shift_res = {(BITWIDTH){bit2pad}};
            else                 assign shift_res = {{(2**i){bit2pad}}, stage_input[BITWIDTH-1:(2**i)]};
         end
         else begin: SDIR_L
            if (2**i >= BITWIDTH)assign shift_res = {(BITWIDTH){1'b0}};
            else                 assign shift_res = {stage_input[BITWIDTH-(2**i)-1:0], {(2**i){1'b0}}};
         end
         assign stage_res = ~stage_distance[i] ? stage_input : shift_res;
         pipedelay_taps #(
            .DATABITW(BITWIDTH), .DELAYTAPS(delaytaps)
         ) pipe_stage_res(
            .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),  .x(stage_res), .pipe_x(stage_out)
         );
      end: SHIFT_STAGE
      if (PIPEDISTANCE & (|taps2delay))assign pipe_distance = SHIFT_STAGE[0].distance_out;
      else                             assign pipe_distance = distance;
   endgenerate
   assign result = (BITWIDTH)'(SHIFT_STAGE[0].stage_out);
   pipedelay_taps #(
      .DATABITW(BITWIDTH), .DELAYTAPS(PIPEINPUT ? DELAYTAPS : 0)
   )pdxi(.clk(clk), .aclr(aclr), .sclr(sclr), .clken(clken), .x(x), .pipe_x(pipe_x));
endmodule: clshift

