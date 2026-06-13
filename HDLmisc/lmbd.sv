/*!
 * \license SPDX-License-Identifier: MIT
 * \file lmbd.sv
 * \brief 从高位向低位搜索给定值的比特位，并返回搜索到的比特位的位置索引。
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, pipedelay
 */
`include "miscs.svh"
`define __INC_FROM_LMBD__
`include "lmbd.svh"
/*! \brief 从高位向低位搜索的比特位搜索器 */
module lmbd #(
   parameter int unsigned DATABITW        = 32,    ///< 输入数据位宽
   parameter int unsigned POSBITW         = 6,     ///< 输出位置索引的位宽
   parameter bit          IDXFRMLSB       = 0,     ///< 从最低位开始计数索引标志：
                                                   ///< 1'b0-从最高位开始计数索引，ipos(MSB) = 0
                                                   ///< 1'b1-从最低位开始计数索引，ipos(LSB) = 0
   parameter int          DELAYTAPS       = 0,     ///< 模块运算时延拍数
   parameter bit          PIPELINE        = 0,     ///< 流水线使能标志， #DELAYTAPS != 0时有效，1- 增加寄存器以使能流水线操作，0- 禁用流水线操作以减少寄存器的使用
   parameter bit          PIPEINPUT       = 0      ///< 使能流水线保存和输出输入数据标志， 1- 流水线保持和输出输入数据， 0- 流水线不保持输入数据
) (
   input  bit                 clk,                 ///< 驱动时钟，当 #DELAYTAPS 为 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                aclr,                ///< 异步复位信号，高电平(1)有效，当 #DELAYTAPS 为 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                sclr,                ///< 同步复位信号，高电平(1)有效，当 #DELAYTAPS 为 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                clken,               ///< 模块使能信号，高电平(1)有效
   input  wire [DATABITW-1:0] x,                   ///< 待搜索的数值， \attention 当 #PIPELINE == 0 时，输入数据时序间隔必须大于等于 #DELAYTAPS 指示的延迟量，否则输出结果不可靠
   input  bit                 bit2s,               ///< 待搜索的比特值， \attention 当 #PIPELINE == 0 时，输入数据时序间隔必须大于等于 #DELAYTAPS 指示的延迟量，否则输出结果不可靠
   output logic[POSBITW -1:0] ipos,                ///< 给定比特值的位置索引， #DATABITW 表示未找到给定的比特值
   output logic[DATABITW-1:0] pipe_x               ///< 流水线同步保持输出的输入数据，当 #PIPEINPUT == 0 时，本端口输出信号与端口 #x 一致
);
   localparam int minbitw_ofipos = miscs::minbitw_of_integer(DATABITW, $bits(int));
   localparam int bitw_ofidx = miscs::minbitw_of_integer(DATABITW-1, $bits(int)); // 索引最大值为 DATABITW
   initial assert(lmbd_pkg::stageCountOfDataBitw(.databitw(DATABITW)) == bitw_ofidx+1);
   initial if (POSBITW < minbitw_ofipos) $error("lmbd : parameter 'POSBITW'(%0d) is too small to hold all the bit position, it should not be less than %0d", POSBITW, minbitw_ofipos);
   genvar i; generate
      for (i = bitw_ofidx; i >= 0; i--) begin: STAGE
         localparam int delaytaps_stage = miscs::delaytaps4stage(bitw_ofidx + 1, i, DELAYTAPS, 1'b0);
         logic               bit2s_stage;          // 待搜索比特值的取反值
         logic[(2**i)  -1:0] stage_input;
         logic[bitw_ofidx:i] ipos_stage;
         wire                msbs_notfind;         // 高位一半比特位未找到待搜索比特值标志，1-未找到，0-找到
         if (i > 0) begin: IPOSGEN
            logic                 bit2s_stage_out;
            logic[ bitw_ofidx :i] ipos_stage_out;
            logic[(2**(i-1))-1:0] stage_out;
            wire [(2**(i-1))-1:0] stage2out = msbs_notfind ? stage_input[(2**(i-1))-1:0] : stage_input[(2**i)-1:(2**(i-1))];
            // 时序延迟
            pipedelay_taps #(
               .DATABITW(2**(i-1)), .DELAYTAPS(delaytaps_stage)
            ) pipe_stage_out(
               .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),  .x(stage2out), .pipe_x(stage_out)
            );
            pipedelay_taps #(
               .DATABITW(bitw_ofidx-i+1), .DELAYTAPS(delaytaps_stage)
            ) pipe_ipos_stage_out(
               .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),  .x(ipos_stage),.pipe_x(ipos_stage_out)
            );
            pipedelay_taps #(
               .DATABITW(1),  .DELAYTAPS(PIPELINE ? delaytaps_stage : 0)
            ) pipe_bit2s_stage_out(
               .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),  .x(bit2s_stage),  .pipe_x(bit2s_stage_out)
            );
         end: IPOSGEN
         else begin: IPOS0
            // \attention 分层搜索的起始比特索引是2**bitw_ofidx，比实际起始比特索引多，需要修正
            wire[minbitw_ofipos-1:0]ipos2out;
            // IDXFRMLSB == 1'b1 : ipos_stage[0] == 1'b1 表明 #msbs_notfind == 1'b0 ，说明给定的比特在输入的数据中被找到，前级搜索的索引有效
            //                     ipos_stage[0] == 1'b0 表明 #msbs_notfind == 1'b1 ，说明给定的比特在输入的数据中没找到，前级搜索的索引无效，应设置表示未找到的值
            if (IDXFRMLSB) assign ipos2out = ipos_stage[0] ? (minbitw_ofipos)'(ipos_stage[bitw_ofidx:1]) : (minbitw_ofipos)'(DATABITW);
            // IDXFRMLSB == 1'b0 : ipos_stage[0] == 1'b1 表明，#msbs_notfind == 1'b1 ，说明给定的比特在输入的数据中没找到，前级搜索的索引无效，应设置表示未找到的值
            //                     ipos_stage[0] == 1'b0 表明 #msbs_notfind == 1'b0 ，说明给定的比特在输入的数据中被找到，前级搜索的索引有效
            else           assign ipos2out = ipos_stage[0] ? (minbitw_ofipos)'(DATABITW) : (minbitw_ofipos)'(ipos_stage[bitw_ofidx:1] - (bitw_ofidx)'(2**bitw_ofidx - DATABITW));
            if (delaytaps_stage > 0) begin
               logic[delaytaps_stage:1][minbitw_ofipos-1:0] ipos_dly, ipos_dly_2upd;
               /* Left Most Bit Distance, 默认初始化/复位时输入端口数值为0：
                * bits2s   IDXFRMLSB      ipos_init
                *  1'b0      1'b0             0
                *  1'b0      1'b1         DATABITW-1
                *  1'b1      1'b0          DATABITW
                *  1'b1      1'b1          DATABITW
                */
               localparam bit[minbitw_ofipos-1:0]ipos_init4bs0 = IDXFRMLSB == 1'b0 ? (minbitw_ofipos)'(0) : (minbitw_ofipos)'(DATABITW-1);
               localparam bit[minbitw_ofipos-1:0]ipos_init4bs1 = (minbitw_ofipos)'(DATABITW);
               wire[minbitw_ofipos-1:0]ipos_init = bit2s ? ipos_init4bs1 : ipos_init4bs0;
               if (delaytaps_stage > 1)assign ipos_dly_2upd = {ipos_dly[delaytaps_stage-1:1], ipos2out};
               else                    assign ipos_dly_2upd = ipos2out;
               always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
                  if      (aclr) ipos_dly <= {(delaytaps_stage){ipos_init}};
                  else if (sclr) ipos_dly <= {(delaytaps_stage){ipos_init}};
                  else           ipos_dly <= clken ? ipos_dly_2upd : ipos_dly;
               end
               assign ipos[minbitw_ofipos-1:0] = ipos_dly[delaytaps_stage];
            end
            else assign ipos[minbitw_ofipos-1:0] = ipos2out;
            if (POSBITW > minbitw_ofipos) assign ipos[POSBITW-1:minbitw_ofipos] = '0;
         end
         if (i == bitw_ofidx) begin
            assign stage_input = (2**i)'(x);
            assign bit2s_stage =  bit2s;
         end
         else begin
            assign ipos_stage[bitw_ofidx:i+1] = STAGE[i+1].IPOSGEN.ipos_stage_out;
            assign stage_input = STAGE[i+1].IPOSGEN.stage_out;
            assign bit2s_stage = STAGE[i+1].IPOSGEN.bit2s_stage_out;  // ...
         end
         // 检测高位比特位是否存在待搜索比特值，存在，则高位ipos置0，不存在则高位ipos置1
         if (i > 0) assign msbs_notfind = &(stage_input[(2**i)-1:(2**(i-1))] ^ {(2**(i-1)){bit2s_stage}});// 异或：相同为0，不同为1，
         else       assign msbs_notfind = stage_input[0]^bit2s_stage;
         // IDXFRMLSB == 1'b1 : 索引从低位开始编号（即低位的索引值趋向于小，高位的索引值趋向于大），
         // #msbs_notfind == 1'b1 则输出的索引值应该趋向小（索引的高位比特应该为0），输出的 #ipos_stage 高位部分应该是0，反之（ #msbs_notfind == 1'b0）则高位部分应该是1；
         if (IDXFRMLSB) assign ipos_stage[i] = ~msbs_notfind;
         // IDXFRMLSB == 1'b0 : 索引从高位开始编号（即高位的索引值趋向于小，低位的索引值趋向于大），
         // #msbs_notfind == 1'b1 则输出的索引应该趋向于大（索引的高位比特应该为1），输出的 #ipos_stage 高位部分应该是1，反之（ #msbs_notfind == 1'b0）则高位部分应该是0；
         else           assign ipos_stage[i] = msbs_notfind;
      end: STAGE
   endgenerate
   pipedelay_taps #( .DATABITW(DATABITW), .DELAYTAPS(PIPEINPUT ? DELAYTAPS : '0))
    pdxi(.clk(clk), .aclr(aclr), .sclr(sclr),.clken(clken),  .x(x),.pipe_x(pipe_x));
endmodule

