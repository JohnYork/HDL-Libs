/*!
 * \license SPDX-License-Identifier: MIT
 * \file norm.sv
 * \brief 统计有符号数中冗余符号位位数
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, pipedelay
 */
`include "miscs.svh"
`define __INC_FROM_NORM__
`include "norm.svh"
/*! \brief 有符号数冗余符号位数统计器 */
module norm #(
   parameter int unsigned DATABITW        = 32, ///< 输入数据位宽
   parameter int unsigned BITWOF_REDUBITS = 6,  ///< 冗余符号位数数值位宽
   parameter int          DELAYTAPS       = 0,  ///< 延迟输出拍数
   parameter bit          PIPELINE        = 0,  ///< 流水线使能标志，仅当DELAY_MSK != 0时有效，1- 增加寄存器以使能流水线操作，0- 禁用流水线操作以减少寄存器的使用
   parameter bit          PIPEINPUT       = 0   ///< 使能流水线保存和输出输入数据标志， 1- 流水线保持和输出输入数据， 0- 流水线不保持输入数据
) (
   input  bit                       clk,     ///< 驱动时钟，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                      aclr,    ///< 异步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                      sclr,    ///< 同步复位信号，高电平(1)有效，当 #DELAY_MSK == 0 （使用组合逻辑输出）时，本信号可留空
   input  wire                      clken,   ///< 模块使能信号，高电平(1)有效
   input  wire  signed[DATABITW-1:0]x,       ///< 待统计的数值， \attention 当 #PIPELINE == 0 时，输入数据时序间隔必须大于等于 #DELAY_MSK 指示的延迟量，否则输出结果不可靠
   output logic[BITWOF_REDUBITS-1:0]redubits,///< 冗余符号位的位数
   output logic signed[DATABITW-1:0]pipe_x   ///< 流水线同步保持输出的输入数据，当 #PIPEINPUT == 0 时，本端口输出信号与端口 #x 一致
);
	localparam int minbitw_ofredubits = miscs::minbitw_of_integer(DATABITW - 1, 31);  // 最大冗余位数为 DATABITW - 1
   localparam int bitw_ofidx         = miscs::minbitw_of_integer(DATABITW - 1, 31);  // 索引最大值为 DATABITW - 1
   localparam int total_stage        = norm_pkg::stageCountOfDataBitw(DATABITW);
   initial if (BITWOF_REDUBITS  < minbitw_ofredubits)
      $error("norm : parameter 'BITWOF_REDUBITS'(%0d) is too small to hold all the redundant bits, it should not be less than %0d", BITWOF_REDUBITS, minbitw_ofredubits);
	wire notsignbit = ~x[DATABITW-1];
	genvar i; generate
      for (i = bitw_ofidx - 1; i >= 0; i--) begin: STAGE
         localparam int delaytaps_stage = miscs::delaytaps4stage(bitw_ofidx, i, DELAYTAPS, 1'b0);
         logic[(2**(i+1))-1:0] stage_in;
         logic[bitw_ofidx-1:i] rdbits, rdbits_out;
         logic                 nsgn_in, mshbs_redubits;
         if (i > 0) begin: INTMOUT
            logic[(2**i)    -1:0] stage_res, stage_out;
            logic             nsgn_out;
            assign stage_res = mshbs_redubits
                               ? stage_in[(2**i)-1:0]
                               : stage_in[(2**(i+1))-1:(2**i)];
            // 时序延迟
            pipedelay_taps #(
               .DATABITW   (2**i             ),
               .DELAYTAPS  (delaytaps_stage  )
            ) pipe_stage_res(
               .clk  (clk        ),
               .aclr (aclr       ),
               .sclr (sclr       ),
               .clken(clken      ),
               .x    (stage_res  ),
               .pipe_x(stage_out )
            );
            pipedelay_taps #(
               .DATABITW   (bitw_ofidx-i     ),
               .DELAYTAPS  (delaytaps_stage  )
            ) pipe_rdbits(
               .clk  (clk        ),
               .aclr (aclr       ),
               .sclr (sclr       ),
               .clken(clken      ),
               .x    (rdbits     ),
               .pipe_x(rdbits_out)
            );
            pipedelay_taps #(
               .DATABITW   (1       ),
               .DELAYTAPS  (PIPELINE
                            ? delaytaps_stage
                            : 0     )
            ) pipe_nsgn(
               .clk  (clk        ),
               .aclr (aclr       ),
               .sclr (sclr       ),
               .clken(clken      ),
               .x    (nsgn_in    ),
               .pipe_x(nsgn_out  )
            );
         end: INTMOUT
         else begin: RESOUT
            pipedelay_taps #(
               .DATABITW   (bitw_ofidx       ),
               .DELAYTAPS  (delaytaps_stage  )
            ) pdoi(
               .clk  (clk        ),
               .aclr (aclr       ),
               .sclr (sclr       ),
               .clken(clken      ),
               .x    (rdbits     ),
               .pipe_x(rdbits_out)
            );
            assign redubits = rdbits_out;
         end: RESOUT
         if (i == bitw_ofidx - 1) begin
            assign stage_in = (2**(i+1))'(x),
                   nsgn_in  = notsignbit;
         end
         else begin
            assign rdbits[bitw_ofidx-1:i+1] = STAGE[i+1].rdbits_out,
                   stage_in                 = STAGE[i+1].INTMOUT.stage_out,
                   nsgn_in                  = STAGE[i+1].INTMOUT.nsgn_out;
         end
         // 半数高位比特位及半数低位比特位的最高位都是符号位，则半数高位比特位是冗余比特位
         assign mshbs_redubits = &(stage_in[(2**(i+1))-1:(2**i)-1]^{((2**i)+1){nsgn_in}}),
                rdbits[i]      = mshbs_redubits;
      end: STAGE
   endgenerate
   pipedelay_taps #(
      .DATABITW   (DATABITW),
      .DELAYTAPS  (PIPEINPUT
                   ? DELAYTAPS
                   : '0    )
   ) pdxi(
      .clk  (clk     ),
      .aclr (aclr    ),
      .sclr (sclr    ),
      .clken(clken   ),
      .x    (x       ),
      .pipe_x(pipe_x )
   );
endmodule

