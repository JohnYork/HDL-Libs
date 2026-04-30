/*!
 * \license SPDX-License-Identifier: MIT
 * \file fifos.sv
 * \brief 单、双时钟FIFO
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, rams, clkdx, greycode
 */
`include "miscs.svh"
`include "rams.svh"
module basic_fifo_status #(
   parameter bit SHOWAHEAD    = 1'b0,  ///< FIFO输出数据提前显示模式使能标志，1'b1:使能，1'b0:禁用（默认）。
                                       ///< \details
                                       ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                       ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                       ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                       ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit DUALCLK      = 1'b0,  ///< 双时钟输入标志， 1'b0- #rclk 和 #wclk 是同一时钟， 1'b1- #rclk 和 #wclk 是不同时钟
   parameter int DEPTH        = 10,    ///< FIFO深度
   parameter int CLKDSYNCTAPS = 2,     ///< 输出数据时钟域同步锁存拍数， #DUALCLK = 1'b0 时本参数被忽略
   parameter bit OUTCLKDWR    = 1'b0,  ///< 输出 #wclk 时钟域的数据标志， 1'b0- 输出 #rclk 时钟域的数据，1'b1-输出 #wclk 时钟域的数据
   parameter int USEDWDLYTAPS = 1      ///< 信号 #usedw 的输出延迟拍数，>0
) (aclr, rclk, rsclr, rdreq, rd_en, rdaddr4empty, rdaddr4full, wclk, wsclr, wrreq, wr_en, wraddr4empty, wraddr4full, empty, full, undrflow, overflow, usedw, rdreq_ocd, emptysig_ocd);
   input  wire             aclr;
   input  bit              rclk;
   input  wire             rsclr;
   input  wire             rdreq;
   input  wire             rd_en;
   localparam int addrBitw = miscs::minbitw_of_integer(DEPTH - 1, 32);
   input  wire [addrBitw:0]rdaddr4empty;  ///< 用于 #empty 信号检测的RAM读端口地址，二进制格式，MSB是地址过周期标志
   input  wire [addrBitw:0]rdaddr4full;   ///< 用于 #full  信号检测的RAM读端口地址，二进制格式，MSB是地址过周期标志
   input  bit              wclk;
   input  wire             wsclr;
   input  wire             wrreq;
   input  wire             wr_en;
   input  wire [addrBitw:0]wraddr4empty;  ///< 用于 #empty 信号检测的RAM写端口地址，二进制格式，MSB是地址过周期标志
   input  wire [addrBitw:0]wraddr4full;   ///< 用于 #full  信号检测的RAM写端口地址，二进制格式，MSB是地址过周期标志
   output logic            empty;
   output logic            full;
   output logic            undrflow;
   output logic            overflow;
   localparam int depBtw = miscs::minbitw_of_integer(DEPTH, 32);
   output logic[depBtw-1:0]usedw;
   output wire             rdreq_ocd;     ///< 同步至输出信号对应时钟域的 #rdreq 信号
   output wire             emptysig_ocd;  ///< 输出信号对应时钟域的 #empty 触发条件信号，组合逻辑电路

   initial if (DUALCLK == 1'b1 && CLKDSYNCTAPS < 2)
      $error("basic_fifo_status: CLKDSYNCTAPS(%0d) should not be less than 2 while DUALCLK(%0d) is enabled!", CLKDSYNCTAPS, DUALCLK);
   // 0-读端口，1-写端口
   logic [addrBitw-1:0] addrchk4empty_ovrclk[1:0], addrchk4full_ovrclk[1:0];
   logic [depBtw-1:0]   addr4usedw[1:0];
   logic                rlov4empty_ovrclk[1:0], rlov4full_ovrclk[1:0], addrvalid4empty_ovrclk[1:0], addrvalid4full_ovrclk[1:0];
   logic                rdreq_ovrclk, wrreq_ovrclk, rden_ovrclk, wren_ovrclk, wren_ovrclk_4emptychk;
   logic                chkempty, chkfull, empty_sig, full_sig, underflow_sig, overflow__sig, osclr;
   wire                 oclk;
   generate if (DUALCLK) begin: XDUALCLK
      // 双时钟驱动模式下，读写地址需转换为格雷码，以利用格雷码的连续数值仅变化一个比特的特性做连续性检测
      wire[addrBitw-1:0]addrchk4empty_grey[1:0], addrchk4full_grey[1:0];
      if (OUTCLKDWR) begin: OCW
         assign osclr = wsclr, oclk = wclk;
         // 读端口地址过周期标志跨时钟域传递
         clkdx #(
            .BITW    (2             ),
            .REGSRC  (1'b1          ),
            .DSTTAPS (CLKDSYNCTAPS  ),
            .OUTTAPS (1             )
         ) rdaddr_rlov_cdx(
            .clksrc  (rclk                                                       ),
            .sclrsrc (rsclr                                                      ),
            .src     ({rdaddr4empty[addrBitw], rdaddr4full[addrBitw]}),.aclr(aclr),
            .clkdst  (wclk                                                       ),
            .sclrdst (wsclr                                                      ),
            .dst     ({rlov4empty_ovrclk[0], rlov4full_ovrclk[0]}                )
         );
         // 读端口地址格雷码跨时钟域传递
         wire[1:0][addrBitw-1:0] rdaddr4empty_ovrclk, rdaddr4full_ovrclk;
         greycode_encode #(
            .BITW(addrBitw)
         ) addrchk4empty0_grey_enc(
            .i(rdaddr4empty[addrBitw-1:0] ),
            .o(addrchk4empty_grey[0]      )
         );
         clkdx #(
            .BITW    (addrBitw      ),
            .REGSRC  (1'b1          ),
            .DSTTAPS (CLKDSYNCTAPS  ),
            .OUTTAPS (2             )
         ) rdaddr4empty_cdx(
            .clksrc  (rclk                   ),
            .sclrsrc (rsclr                  ),
            .src     (addrchk4empty_grey[0]  ),
            .aclr    (aclr                   ),
            .clkdst  (wclk                   ),
            .sclrdst (wsclr                  ),
            .dst     (rdaddr4empty_ovrclk    )
         );
         greycode_continuouschk #(
            .BITW(addrBitw)
         ) addrvalid4empty_chk(
            .greys(rdaddr4empty_ovrclk       ),
            .valid(addrvalid4empty_ovrclk[0] )
         );
         greycode_decode #(
            .BITW(addrBitw)
         ) addrchk4empty0_grey_dec(
            .i(rdaddr4empty_ovrclk[0]  ),
            .o(addrchk4empty_ovrclk[0] )
         );
         greycode_encode #(
            .BITW(addrBitw)
         ) addrchk4full0_grey_enc(
            .i(rdaddr4full[addrBitw-1:0]  ),
            .o(addrchk4full_grey[0]       )
         );
         clkdx #(
            .BITW    (addrBitw      ),
            .REGSRC  (1'b1          ),
            .DSTTAPS (CLKDSYNCTAPS  ),
            .OUTTAPS (2             )
         ) rdaddr4full_cdx(
            .clksrc  (rclk                ),
            .sclrsrc (rsclr               ),
            .src     (addrchk4full_grey[0]),
            .aclr    (aclr                ),
            .clkdst  (wclk                ),
            .sclrdst (wsclr               ),
            .dst     (rdaddr4full_ovrclk  )
         );
         greycode_continuouschk #(
            .BITW(addrBitw)
         ) addrvalid4full_chk(
            .greys(rdaddr4full_ovrclk        ),
            .valid(addrvalid4full_ovrclk[0]  )
         );
         greycode_decode #(
            .BITW(addrBitw)
         ) addrchk4full0_grey_dec(
            .i(rdaddr4full_ovrclk[0]   ),
            .o(addrchk4full_ovrclk[0]  )
         );
         // #rdreq 、 #rd_en 跨时钟域传递
         clkdx #(
            .BITW    (2             ),
            .REGSRC  (1'b1          ),
            .DSTTAPS (CLKDSYNCTAPS  ),
            .OUTTAPS (1             )
         ) rdreq_rd_en_cdx(
            .clksrc  (rclk                         ),
            .sclrsrc (rsclr                        ),
            .src     ({rdreq, rd_en}               ),
            .aclr    (aclr                         ),
            .clkdst  (wclk                         ),
            .sclrdst (wsclr                        ),
            .dst     ({rdreq_ovrclk, rden_ovrclk}  )
         );
         assign rlov4empty_ovrclk[1]      = wraddr4empty[addrBitw],
                rlov4full_ovrclk[1]       = wraddr4full[addrBitw],
                addrvalid4empty_ovrclk[1] = 1'b1,
                addrvalid4full_ovrclk[1]  = 1'b1,
                addrchk4empty_grey[1]     = wraddr4empty,
                addrchk4empty_ovrclk[1]   = addrchk4empty_grey[1],
                addrchk4full_grey[1]      = wraddr4full,
                addrchk4full_ovrclk[1]    = addrchk4full_grey[1],
                wrreq_ovrclk              = wrreq,
                wren_ovrclk               = wr_en;
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(rclk, aclr)) begin
            if      (aclr) wren_ovrclk_4emptychk <= 1'b0;
            else if (rsclr)wren_ovrclk_4emptychk <= 1'b0;
            else           wren_ovrclk_4emptychk <= wr_en;
         end
      end else begin: OCR
         assign osclr = rsclr, oclk = rclk;
         assign rlov4empty_ovrclk[0]      = rdaddr4empty[addrBitw],
                rlov4full_ovrclk[0]       = rdaddr4full[addrBitw],
                addrvalid4empty_ovrclk[0] = 1'b1,
                addrvalid4full_ovrclk[0]  = 1'b1,
                addrchk4empty_grey[0]     = rdaddr4empty,
                addrchk4empty_ovrclk[0]   = addrchk4empty_grey[0],
                addrchk4full_grey[0]      = rdaddr4full,
                addrchk4full_ovrclk[0]    = addrchk4full_grey[0],
                rdreq_ovrclk              = rdreq,
                rden_ovrclk               = rd_en;
         // 写端口地址过周期标志跨时钟域传递
         clkdx #(
            .BITW    (2             ),
            .REGSRC  (1'b1          ),
            .DSTTAPS (CLKDSYNCTAPS  ),
            .OUTTAPS (1             )
         ) wraddr_rlov_cdx(
            .clksrc  (wclk                                           ),
            .sclrsrc (wsclr                                          ),
            .src     ({wraddr4empty[addrBitw], wraddr4full[addrBitw]}),
            .aclr    (aclr                                           ),
            .clkdst  (rclk                                           ),
            .sclrdst (rsclr                                          ),
            .dst     ({rlov4empty_ovrclk[1], rlov4full_ovrclk[1]}    )
         );
         // 写端口地址格雷码跨时钟域传递
         wire[1:0][addrBitw-1:0] wraddr4empty_ovrclk, wraddr4full_ovrclk;
         greycode_encode #(
            .BITW(addrBitw)
         ) addrchk4empty1_grey_enc(
            .i(wraddr4empty[addrBitw-1:0] ),
            .o(addrchk4empty_grey[1]      )
         );
         clkdx #(
            .BITW    (addrBitw      ),
            .REGSRC  (1'b1          ),
            .DSTTAPS (CLKDSYNCTAPS  ),
            .OUTTAPS (2             )
         ) wraddr4empty_cdx(
            .clksrc  (wclk                   ),
            .sclrsrc (wsclr                  ),
            .src     (addrchk4empty_grey[1]  ),
            .aclr    (aclr                   ),
            .clkdst  (rclk                   ),
            .sclrdst (rsclr                  ),
            .dst     (wraddr4empty_ovrclk    )
         );
         greycode_continuouschk #(
            .BITW(addrBitw)
         ) addrvalid4empty_chk(
            .greys(wraddr4empty_ovrclk       ),
            .valid(addrvalid4empty_ovrclk[1] )
         );
         greycode_decode #(
            .BITW(addrBitw)
         ) addrchk4empty1_grey_dec(
            .i(wraddr4empty_ovrclk[0]  ),
            .o(addrchk4empty_ovrclk[1] )
         );
         greycode_encode #(
            .BITW(addrBitw)
         ) addrchk4full1_grey_enc(
            .i(wraddr4full[addrBitw-1:0]  ),
            .o(addrchk4full_grey[1]       )
         );
         clkdx #(
            .BITW    (addrBitw      ),
            .REGSRC  (1'b1          ),
            .DSTTAPS (CLKDSYNCTAPS  ),
            .OUTTAPS (2             )
         ) wraddr4full_cdx(
            .clksrc  (wclk                ),
            .sclrsrc (wsclr               ),
            .src     (addrchk4full_grey[1]),
            .aclr    (aclr                ),
            .clkdst  (rclk                ),
            .sclrdst (rsclr               ),
            .dst     (wraddr4full_ovrclk  )
         );
         greycode_continuouschk #(
            .BITW(addrBitw)
         ) addrvalid4full_chk(
            .greys(wraddr4full_ovrclk        ),
            .valid(addrvalid4full_ovrclk[1]  )
         );
         greycode_decode #(
            .BITW(addrBitw)
         ) addrchk4full1_grey_dec(
            .i(wraddr4full_ovrclk[0]   ),
            .o(addrchk4full_ovrclk[1]  )
         );
         // #wrreq 、 #wr_en 跨时钟域传递
         clkdx #(
            .BITW    (2             ),
            .REGSRC  (1'b1          ),
            .DSTTAPS (CLKDSYNCTAPS  ),
            .OUTTAPS (1             )
         ) wrreq_wr_en_cdx(
            .clksrc  (wclk                         ),
            .sclrsrc (wsclr                        ),
            .src     ({wrreq, wr_en}               ),
            .aclr    (aclr                         ),
            .clkdst  (rclk                         ),
            .sclrdst (rsclr                        ),
            .dst     ({wrreq_ovrclk, wren_ovrclk}  )
         );
         assign wren_ovrclk_4emptychk = wren_ovrclk;
      end
      assign addr4usedw[0] = (depBtw)'(addrchk4empty_ovrclk[0][addrBitw-1:0]);
      assign addr4usedw[1] = (depBtw)'(addrchk4empty_ovrclk[1][addrBitw-1:0]);
      assign underflow_sig = rdreq_ovrclk&empty;
      assign overflow__sig = wrreq_ovrclk&full;
   end else begin: XSINGLECLK
      assign osclr = rsclr, oclk = rclk;
      assign rlov4empty_ovrclk[0] = rdaddr4empty[addrBitw], rlov4full_ovrclk[0] = rdaddr4full[addrBitw],
             addrvalid4empty_ovrclk[0] = 1'b1, addrvalid4full_ovrclk[0] = 1'b1,
             addrchk4empty_ovrclk[0] = rdaddr4empty[addrBitw-1:0], addrchk4full_ovrclk[0] = rdaddr4full[addrBitw-1:0],
             rdreq_ovrclk = rdreq,
             rden_ovrclk = rd_en;
      assign rlov4empty_ovrclk[1] = wraddr4empty[addrBitw], rlov4full_ovrclk[1] = wraddr4full[addrBitw],
             addrvalid4empty_ovrclk[1] = 1'b1, addrvalid4full_ovrclk[1] = 1'b1,
             addrchk4empty_ovrclk[1] = wraddr4empty[addrBitw-1:0], addrchk4full_ovrclk[1] = wraddr4full[addrBitw-1:0],
             wrreq_ovrclk = wrreq,
             wren_ovrclk = wr_en;
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(rclk, aclr)) begin
         if      (aclr) wren_ovrclk_4emptychk <= 1'b0;
         else if (rsclr)wren_ovrclk_4emptychk <= 1'b0;
         else           wren_ovrclk_4emptychk <= wr_en;
      end
      assign addr4usedw[0] = (depBtw)'(addrchk4full_ovrclk[0][addrBitw-1:0]);
      assign addr4usedw[1] = (depBtw)'(addrchk4full_ovrclk[1][addrBitw-1:0]);
      assign underflow_sig = rdreq_ovrclk&empty&((~wrreq_ovrclk)|SHOWAHEAD);
      assign overflow__sig = wrreq_ovrclk&full&(~rdreq_ovrclk);
   end
   if (SHOWAHEAD) begin: FESH
      assign chkempty = (rden_ovrclk|(wren_ovrclk_4emptychk/*|empty*/))&addrvalid4empty_ovrclk[0]&addrvalid4empty_ovrclk[1];
      assign chkfull  = (((wren_ovrclk&(~empty))|(rden_ovrclk&full)))&addrvalid4full_ovrclk[0]&addrvalid4full_ovrclk[1];
   end else begin: FENM
      assign chkempty = (rden_ovrclk|(wren_ovrclk_4emptychk&empty))&addrvalid4empty_ovrclk[0]&addrvalid4empty_ovrclk[1];
      assign chkfull  = ((wren_ovrclk&(~empty))|(rden_ovrclk&full))&addrvalid4full_ovrclk[0]&addrvalid4full_ovrclk[1];
   end
   if (DUALCLK) begin: FEDC
      always @(empty_sig) begin
         empty <= empty_sig;
      end
      always @(full_sig) begin
         full <= full_sig;
      end
   end else begin: FESC
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(oclk, aclr)) begin
         if      (aclr) empty <= '1;
         else if (osclr)empty <= '1;
         else           empty <= chkempty
                                 ? empty_sig
                                 : empty;
      end
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(oclk, aclr)) begin
         if      (aclr) full <= '0;
         else if (osclr)full <= '0;
         else           full <= chkfull
                                ? full_sig
                                : full;
      end
   end
   endgenerate
   /* #empty 信号仅读操作关心，当 #empty 信号置位存在滞后时会有破坏数据的风险。
    * - 当读时钟快于写时钟时，读地址也快于写地址更新，当读地址增加到读时钟采样的写地址位置时， #empty 置位，保护读地址不会越过读时钟采样的写地址，
    * 即使有写操作出现，实际写地址在读时钟域看来也不一定能及时移动到“空”位置后面去，因此此时 #empty 信号的置位不会滞后；
    * - 当读时钟慢于写时钟时，读地址也慢于写地址更新，当读地址增加到读时钟采样的写地址位置时， #empty 置位，保护读地址不会越过读时钟采样的写地址，
    * 即使有写操作出现，实际写地址即使向后移动也不会造成数据破坏，因此此时 #empty 信号的置位不会滞后。
    */
   assign empty_sig = (addrchk4empty_ovrclk[0] == addrchk4empty_ovrclk[1])
                      ? (~(rlov4empty_ovrclk[0]^rlov4empty_ovrclk[1]))
                      : 1'b0;
   /* #full 信号仅写操作关心，当 #full 信号置位存在滞后时会有破坏数据的风险。
    * - 当写时钟快于读时钟时，写地址也快于读地址更新，当写地址增加到写时钟采样的读地址位置时， #full 置位，保护写地址不会越过写时钟采样的读地址，
    * 即使有读操作出现，实际读地址在写时钟域看来也不一定能及时移动到“满”位置后面去，因此此时 #full 信号的置位不会滞后；
    * - 当写时钟慢于读时钟时，写地址也慢于读地址更新，当写地址增加到写时钟采样的读地址位置时， #full 置位，保护写地址不会越过写时钟采样的读地址，
    * 即使有读操作出现，实际读地址即使向后移动也不会造成数据破坏，因此此时 #full 信号的置位不会滞后。
    */
   assign full_sig = (addrchk4full_ovrclk[0] == addrchk4full_ovrclk[1])
                     ? (rlov4full_ovrclk[0]^rlov4full_ovrclk[1])
                     : 1'b0;
   /* #underflow 信号仅读操作关心，当 #underflow 信号置位后表示数据可能已被破坏，需要复位FIFO后才能消除破坏状态
    * 对异步FIFO，只需要在 #empty 置位时，有 #rdreq 信号则触发读溢出状态
    * 对同步FIFO，若 #SHOWAHEAD == 1'b0 ，在 #empty 置位时，若 #rdreq 和 #wrreq 同时置位，则应不触发读溢出状态
    */
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(oclk, aclr)) begin
      if      (aclr)          undrflow <= '0;
      else if (osclr)         undrflow <= '0;
      else if (underflow_sig) undrflow <= '1;
      else                    undrflow <= undrflow;
   end
   /* #overflow 信号仅写操作关心，当 #overflow 信号置位后表示数据可能已被破坏，需要复位FIFO后才能消除破坏状态
    * 对异步FIFO，只需要在 #full 置位时，有 #wrreq 信号则触发读溢出状态
    * 对同步FIFO，在 #full 置位时，若 #rdreq 和 #wrreq 同时置位，则应不触发写溢出状态
    */
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(oclk, aclr)) begin
      if      (aclr)          overflow <= '0;
      else if (osclr)         overflow <= '0;
      else if (overflow__sig) overflow <= '1;
      else                    overflow <= overflow;
   end
   // #usedw
   logic[depBtw-1:0]usedw2o;
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(oclk, aclr)) begin
      if      (aclr)                         usedw2o <= '0;
      else if (osclr)                        usedw2o <= '0;
      else if (addr4usedw[1] > addr4usedw[0])usedw2o <= (depBtw)'(addr4usedw[1]) - (depBtw)'(addr4usedw[0]);
      else if (addr4usedw[1] < addr4usedw[0])usedw2o <= ((depBtw)'(DEPTH) - (depBtw)'(addr4usedw[0]) + (depBtw)'(addr4usedw[1]));
      else                                   usedw2o <= ((rlov4full_ovrclk[0]^rlov4full_ovrclk[1])&wr_en)
                                                        ? (depBtw)'(DEPTH)
                                                        : '0;
   end
   pipedelay_taps #(
      .DATABITW(depBtw),.DELAYTAPS(USEDWDLYTAPS-1)
   ) pipe_usedw(
      .clk(oclk), .aclr(aclr),.sclr(osclr),  .clken(1'b1), .x(usedw2o),.pipe_x(usedw)
   );
   assign rdreq_ocd = rdreq_ovrclk;
   assign emptysig_ocd = empty_sig;
endmodule
/*!
 * \brief 基本FIFO
 * \details 双时钟模式与 Quartus 的 dcfifo_low_latency 输入输出一致；单时钟模式与 Quartus 的 scfifo 输入输出一致。
 */
module basic_fifo #(
   parameter bit                 DUALCLK      = 1'b0,    ///< 双时钟模式使能，1'b0-单时钟模式，1'b1-双时钟模式
                                                         ///< 双时钟模式下，输入的 #clk 信号为2路， #clk[0] 为读时钟， #clk[1] 为写时钟
   parameter bit[DUALCLK:0][31:0]CLKDSYNCTAPS = {32'd2}, ///< 时钟域同步锁存拍数， #DUALCLK = 1'b0 时本参数被忽略，否则本参数必须设置大于1的值。
                                                         ///< #CLKDSYNCTAPS[0] 为读时钟域同步锁存拍数， #CLKDSYNCTAPS[1] 为写时钟域同步锁存拍数
   parameter int                 UNITBITW     = 32,      ///< 数据位宽
   parameter int                 DEPTH        = 10,      ///< FIFO深度
   parameter bit                 SHOWAHEAD    = 1'b0,    ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                         ///< \details
                                                         ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                         ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                         ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                         ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[DUALCLK:0][31:0]USEDWDLYTAPS = {32'd1}  ///< 信号 #usedw 的输出延迟拍数，>0
) (clk, aclr, sclr, wrreq, rdreq, data, q, usedw, empty, full, undrflow, overflow);
   input  bit  [DUALCLK:0]             clk;       ///< 驱动时钟信号
   input  wire                         aclr;      ///< 异步复位信号，高电平(1)有效
   input  wire [DUALCLK:0]             sclr;      ///< 同步复位信号，高电平(1)有效
   input  wire                         wrreq;     ///< 写入请求信号，高电平(1)有效
   input  wire                         rdreq;     ///< 读出请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0]          data;      ///< FIFO输入数据信号
   output wire [UNITBITW-1:0]          q;         ///< FIFO输出数据信号
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output logic[DUALCLK:0][depBitw-1:0]usedw;     ///< FIFO已使用深度，当 #DUALCLK == 1'b1 时，该信号输出常0，以避免读写操作跨时钟域时输出错误状态
   output logic[DUALCLK:0]             empty;     ///< FIFO空标志，高电平(1)有效。 \attention 该信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output logic[DUALCLK:0]             full;      ///< FIFO满标志，高电平(1)有效
   output logic[DUALCLK:0]             undrflow;  ///< 下溢出标志，高电平(1)有效，置位后须复位FIFO才能清零
   output logic[DUALCLK:0]             overflow;  ///< 上溢出标志，高电平(1)有效，置位后须复位FIFO才能清零

   localparam int addrBitw = miscs::minbitw_of_integer(DEPTH - 1, 32);
   initial begin
      automatic int i;
      if (DUALCLK == 1'b1) begin
         for (i = 0; i <= int'(DUALCLK); i++) begin
            if (USEDWDLYTAPS[i] < 1) $error("basic_fifo: USEDWDLYTAPS[%0d](%0d) should not be less than 1 while DUALCLK(%0d) is set", i, USEDWDLYTAPS[i], DUALCLK);
         end
      end
   end
   wire clk_r, clk_w;
   assign clk_r = clk[0], clk_w = clk[DUALCLK];
   wire rsclr = sclr[0];
   wire wsclr = sclr[DUALCLK];
   logic [addrBitw-1:0] addr_w1p, addr_w1p_inc, addr_w, addr_r1p, addr_r1p_inc, addr_r;
   wire addr_w1p_lastaddr = (addr_w1p == (addrBitw)'(DEPTH-1)) ? 1'b1 : 1'b0;
   wire addr_r1p_lastaddr = (addr_r1p == (addrBitw)'(DEPTH-1)) ? 1'b1 : 1'b0;
   assign addr_w1p_inc = addr_w1p_lastaddr ? '0 : addr_w1p + (addrBitw)'(1);
   assign addr_r1p_inc = addr_r1p_lastaddr ? '0 : addr_r1p + (addrBitw)'(1);
   logic wr_en, rd_en, w1p_overroll, wr_overroll, r1p_overroll, rd_overroll;
   wire rdreq_ovrclk[DUALCLK:0];
   assign wr_en = wrreq&((~full[DUALCLK])|rdreq_ovrclk[DUALCLK]);
   assign rd_en = rdreq&(~empty[0]);
   wire[addrBitw-1:0]addr_w1p2upd = wr_en ? addr_w1p_inc : addr_w1p;
   wire[addrBitw-1:0]addr_r1p2upd = rd_en ? addr_r1p_inc : addr_r1p;
   wire w1p_overroll2upd = (addr_w1p_lastaddr^wr_overroll);
   wire r1p_overroll2upd = (addr_r1p_lastaddr^rd_overroll);
   logic[addrBitw -1:0] addr_chkempty_bin[DUALCLK:0][1:0], addr_chkempty_bin4wr[DUALCLK:0], addr_chkfull_bin[DUALCLK:0][1:0], addr2ram_r;
   logic                overroll_chkempty[DUALCLK:0][1:0], overroll_chkempty4wr[DUALCLK:0], overroll_chkfull[DUALCLK:0][1:0];
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk_w, aclr)) begin
      if      (aclr) addr_w1p <= (addrBitw)'(DUALCLK);
      else if (wsclr)addr_w1p <= (addrBitw)'(DUALCLK);
      else           addr_w1p <= addr_w1p2upd;
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk_w, aclr)) begin
      if      (aclr) w1p_overroll <= '0;
      else if (wsclr)w1p_overroll <= '0;
      else           w1p_overroll <= wr_en ? w1p_overroll2upd : w1p_overroll;
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk_r, aclr)) begin
      if      (aclr) addr_r1p <= (addrBitw)'(DUALCLK);
      else if (rsclr)addr_r1p <= (addrBitw)'(DUALCLK);
      else           addr_r1p <= addr_r1p2upd;
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk_r, aclr)) begin
      if      (aclr) r1p_overroll <= '0;
      else if (rsclr)r1p_overroll <= '0;
      else           r1p_overroll <= rd_en ? r1p_overroll2upd : r1p_overroll;
   end
   localparam int sdpram_implmod = rams_pkg::recommend_ramstyle(DEPTH, UNITBITW);
   /*
    * SHOWAHEAD模式：
    * 1. #rdreq 置位前 #addr4ram_r 便已置位；
    * 2. #epmty 置位时， #wrreq 置位而 #rdreq 未置位时， #addr4ram_r 应与 #addr4ram_w 一致。
    * NORMAL模式：
    * 1. #rd_en (#rdreq & ~#empty) 置位时刻 addr4ram_r 才置位；
    * 2. #empty 置位时， #wrreq 置位而 #rd_en 未置位时， #addr4ram_r 应比 #addr4ram_w 小 1。
    */
   wire ramq_en;
   sdpram_2clk #(
      .DATABITW(UNITBITW      ),
      .ADDRLEN (DEPTH         ),
      .IMPLMOD (sdpram_implmod),
      .REGOUTP (1'b0          )
   ) rami(
      .aclr    (aclr       ),
      .clk_w   (clk_w      ),
      .clken_w (1'b1       ),
      .we      (wr_en      ),
      .addr_w  (addr_w     ),
      .data_w  (data       ),
      .clk_q   (clk_r      ),
      .clken_q (ramq_en    ),
      .sclr_q  (rsclr      ),
      .addr_q  (addr2ram_r ),
      .data_q  (q          )
   );
   wire  empty_sig_clk[DUALCLK:0];
   genvar i; generate if (DUALCLK) begin
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk_r, aclr)) begin
         if      (aclr) addr_r <= '0;
         else if (wsclr)addr_r <= '0;
         else           addr_r <= rd_en ? addr_r1p : addr_r;
      end
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk_r, aclr)) begin
         if      (aclr) rd_overroll <= '0;
         else if (wsclr)rd_overroll <= '0;
         else           rd_overroll <= rd_en ? r1p_overroll : rd_overroll;
      end
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk_w, aclr)) begin
         if      (aclr) addr_w <= '0;
         else if (wsclr)addr_w <= '0;
         else           addr_w <= wr_en ? addr_w1p : addr_w;
      end
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk_w, aclr)) begin
         if      (aclr) wr_overroll <= '0;
         else if (wsclr)wr_overroll <= '0;
         else           wr_overroll <= wr_en ? w1p_overroll : wr_overroll;
      end
      if (SHOWAHEAD) assign addr2ram_r = empty[0] ? addr_r : addr_r1p,
                            ramq_en = rd_en|empty_sig_clk[0];//1'b1&(~empty_sig_clk[0]);
      else           assign addr2ram_r = addr_r,
                            ramq_en = rdreq&(~empty_sig_clk[0]);//addr_r2upd;
      // 读时钟域状态判断用地址
      assign addr_chkempty_bin[0][0] = addr_r,//addr_r1p,//addr_r2upd;
             addr_chkempty_bin[0][1] = addr_w,  // 要求 #addr_w 与 #addr_r 初始值一致
             overroll_chkempty[0][0] = rd_overroll,//r1p_overroll,//rd_overroll2upd;
             overroll_chkempty[0][1] = wr_overroll;
      assign addr_chkfull_bin[0][0] = addr_r,//addr_r1p,//addr_r2upd,
             addr_chkfull_bin[0][1] = addr_w,
             overroll_chkfull[0][0] = rd_overroll,//r1p_overroll2upd,//rd_overroll2upd,
             overroll_chkfull[0][1] = wr_overroll;
      // 写时钟域状态判断用地址
      assign addr_chkempty_bin[1][0] = addr_r,
             addr_chkempty_bin[1][1] = addr_w,
             overroll_chkempty[1][0] = rd_overroll,
             overroll_chkempty[1][1] = wr_overroll;
      assign addr_chkfull_bin[1][0] = addr_r,
             addr_chkfull_bin[1][1] = addr_w,//addr_w1p,
             overroll_chkfull[1][0] = rd_overroll,
             overroll_chkfull[1][1] = wr_overroll;//w1p_overroll2upd;
      assign addr_chkempty_bin4wr[0] = addr_chkempty_bin[0][1],
             overroll_chkempty4wr[0] = overroll_chkempty[0][1],
             addr_chkempty_bin4wr[1] = addr_chkempty_bin[1][1],
             overroll_chkempty4wr[1] = overroll_chkempty[1][1];
   end else begin
      assign addr_r = addr_r1p,
             rd_overroll = r1p_overroll,
             addr_w = addr_w1p,
             wr_overroll = w1p_overroll;
      if (SHOWAHEAD) begin
         assign addr2ram_r = addr_r1p2upd;
         assign addr_chkempty_bin[0][0] = addr_r1p2upd,
                addr_chkempty_bin[0][1] = addr_w,
                overroll_chkempty[0][0] = r1p_overroll2upd,
                overroll_chkempty[0][1] = wr_overroll;
         assign addr_chkfull_bin[0][0] = addr_r1p2upd,
                addr_chkfull_bin[0][1] = addr_w1p2upd,
                overroll_chkfull[0][0] = r1p_overroll2upd,
                overroll_chkfull[0][1] = w1p_overroll2upd;
         assign ramq_en = 1'b1&(~empty_sig_clk[0]);
         // >>同步FIFO在 SHOWAHEAD 模式下，用于判断满、空状态的写地址延迟一拍，
         // >>以避免在写脉冲的下一个时钟即翻转FIFO的满、空状态，
         // >>从而避免在FIFO为空时，写脉冲的下一个时钟FIFO的空状态清除，而FIFO的读输出端口未能置位刚写入的有效数据的故障。
         // 因为 #basic_fifo_status 中输出的空状态在判断空状态的组合逻辑电路上延迟了一拍，上述故障并不会发生。
         assign addr_chkempty_bin4wr[0] = addr_chkempty_bin[0][1],
                overroll_chkempty4wr[0] = overroll_chkempty[0][1];
      end else begin
         assign addr2ram_r = addr_r;
         assign addr_chkempty_bin[0][0] = addr_r1p2upd,
                addr_chkempty_bin[0][1] = addr_w1p2upd,  // 要求 #addr_w 与 #addr_r 初始值一致
                overroll_chkempty[0][0] = r1p_overroll2upd,
                overroll_chkempty[0][1] = w1p_overroll2upd;
         assign addr_chkfull_bin[0][0] = addr_r1p2upd,
                addr_chkfull_bin[0][1] = addr_w1p2upd,
                overroll_chkfull[0][0] = r1p_overroll2upd,
                overroll_chkfull[0][1] = w1p_overroll2upd;
         assign ramq_en = rdreq&(~empty/*_sig_clk*/[0]);
         assign addr_chkempty_bin4wr[0] = addr_chkempty_bin[0][1],
                overroll_chkempty4wr[0] = overroll_chkempty[0][1];
      end
   end
   for (i = 0; i <= int'(DUALCLK); i++) begin
      basic_fifo_status #(
         .SHOWAHEAD     (SHOWAHEAD),
         .DUALCLK       (DUALCLK),
         .DEPTH         (DEPTH),
         .CLKDSYNCTAPS  (CLKDSYNCTAPS[i]),
         .OUTCLKDWR     (i),
         .USEDWDLYTAPS  (USEDWDLYTAPS[i])
      ) statusi(
         .aclr          (aclr                                              ),
         .rclk          (clk_r                                             ),
         .rsclr         (rsclr                                             ),
         .rdreq         (rdreq                                             ),
         .rd_en         (rd_en                                             ),
         .rdaddr4empty  ({overroll_chkempty[i][0], addr_chkempty_bin[i][0]}),
         .rdaddr4full   ({overroll_chkfull[i][0], addr_chkfull_bin[i][0]}  ),
         .wclk          (clk_w                                             ),
         .wsclr         (wsclr                                             ),
         .wrreq         (wrreq                                             ),
         .wr_en         (wr_en                                             ),
         .wraddr4empty  ({overroll_chkempty4wr[i], addr_chkempty_bin4wr[i]}),
         .wraddr4full   ({overroll_chkfull[i][1], addr_chkfull_bin[i][1]}  ),
         .empty         (empty[i]                                          ),
         .full          (full[i]                                           ),
         .undrflow      (undrflow[i]                                       ),
         .overflow      (overflow[i]                                       ),
         .usedw         (usedw[i]                                          ),
         .rdreq_ocd     (rdreq_ovrclk[i]                                   ),
         .emptysig_ocd  (empty_sig_clk[i]                                  )
      );
   end endgenerate
endmodule
/*! \brief 双时钟异步FIFO */
module fifo_2clk #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                aclr;                   ///< 异步复位信号，高电平(1)有效
   input  bit                 clkr, clkw;             ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                rsclr, wsclr;           ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                rdreq, wrreq;           ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0] d;                      ///< FIFO输入数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire [UNITBITW-1:0] q;                      ///< FIFO输出数据
   output wire [depBitw-1:0]  rdusedw, wrusedw;       ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                rdempty, wrempty;       ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效。
                                                      ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                rdfull, wrfull;         ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                rdundrflow, wrundrflow; ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                rdoverflow, wroverflow; ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   basic_fifo #(
      .DUALCLK       (1'b1                      ),
      .CLKDSYNCTAPS  ({WCDSYNCTAPS, RCDSYNCTAPS}),
      .UNITBITW      (UNITBITW                  ),
      .DEPTH         (DEPTH                     ),
      .SHOWAHEAD     (SHOWAHEAD                 ),
      .USEDWDLYTAPS  ({WCDUSEDWDLY,RCDUSEDWDLY} )
   ) dcfifoi(
      .clk     ({clkw, clkr}              ),
      .aclr    (aclr                      ),
      .sclr    ({wsclr, rsclr}            ),
      .wrreq   (wrreq                     ),
      .rdreq   (rdreq                     ),
      .data    (d                         ),
      .q       (q                         ),
      .usedw   ({wrusedw, rdusedw}        ),
      .empty   ({wrempty, rdempty}        ),
      .full    ({wrfull, rdfull}          ),
      .undrflow({wrundrflow, rdundrflow}  ),
      .overflow({wroverflow, rdoverflow}  )
   );
endmodule
module fifo_2clk_packedarray #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       ARRAYSIZ    = 2,            ///< 数组元素个数
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                            aclr;                   ///< 异步复位信号，高电平(1)有效
   input  bit                             clkr, clkw;             ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                            rsclr, wsclr;           ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                            rdreq, wrreq;           ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]d;                      ///< FIFO输入数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]q;                      ///< FIFO输出数据
   output wire[depBitw-1:0]               rdusedw, wrusedw;       ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                            rdempty, wrempty;       ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效
                                                                  ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                            rdfull, wrfull;         ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                            rdundrflow, wrundrflow; ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                            rdoverflow, wroverflow; ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   wire[UNITBITW*ARRAYSIZ-1:0]dd, qq;
   packedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d ),
      .out(dd)
   );
   fifo_2clk #(
      .UNITBITW   (UNITBITW*ARRAYSIZ),
      .DEPTH      (DEPTH            ),
      .SHOWAHEAD  (SHOWAHEAD        ),
      .RCDSYNCTAPS(RCDSYNCTAPS      ),
      .WCDSYNCTAPS(WCDSYNCTAPS      ),
      .RCDUSEDWDLY(RCDUSEDWDLY      ),
      .WCDUSEDWDLY(WCDUSEDWDLY      )
   ) dcfifopai(
      .aclr       (aclr       ),
      .clkr       (clkr       ),
      .clkw       (clkw       ),
      .rsclr      (rsclr      ),
      .wsclr      (wsclr      ),
      .rdreq      (rdreq      ),
      .wrreq      (wrreq      ),
      .d          (dd         ),
      .q          (qq         ),
      .rdusedw    (rdusedw    ),
      .wrusedw    (wrusedw    ),
      .rdempty    (rdempty    ),
      .wrempty    (wrempty    ),
      .rdfull     (rdfull     ),
      .wrfull     (wrfull     ),
      .rdundrflow (rdundrflow ),
      .wrundrflow (wrundrflow ),
      .rdoverflow (rdoverflow ),
      .wroverflow (wroverflow )
   );
   unit_split2packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq),
      .out(q )
   );
endmodule
module fifo_2clk_unpackedarray #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       ARRAYSIZ    = 2,            ///< 数组元素个数
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                aclr;                   ///< 异步复位信号，高电平(1)有效
   input  bit                 clkr, clkw;             ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                rsclr, wsclr;           ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                rdreq, wrreq;           ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0] d[ARRAYSIZ-1:0];        ///< FIFO输入数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire [UNITBITW-1:0] q[ARRAYSIZ-1:0];        ///< FIFO输出数据
   output wire [depBitw-1:0]  rdusedw, wrusedw;       ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                rdempty, wrempty;       ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效
                                                      ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                rdfull, wrfull;         ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                rdundrflow, wrundrflow; ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                rdoverflow, wroverflow; ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   wire[UNITBITW*ARRAYSIZ-1:0]dd, qq;
   unpackedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d ),
      .out(dd)
   );
   fifo_2clk #(
      .UNITBITW   (UNITBITW*ARRAYSIZ),
      .DEPTH      (DEPTH            ),
      .SHOWAHEAD  (SHOWAHEAD        ),
      .RCDSYNCTAPS(RCDSYNCTAPS      ),
      .WCDSYNCTAPS(WCDSYNCTAPS      ),
      .RCDUSEDWDLY(RCDUSEDWDLY      ),
      .WCDUSEDWDLY(WCDUSEDWDLY      )
   ) dcfifoupai(
      .aclr       (aclr       ),
      .clkr       (clkr       ),
      .clkw       (clkw       ),
      .rsclr      (rsclr      ),
      .wsclr      (wsclr      ),
      .rdreq      (rdreq      ),
      .wrreq      (wrreq      ),
      .d          (dd         ),
      .q          (qq         ),
      .rdusedw    (rdusedw    ),
      .wrusedw    (wrusedw    ),
      .rdempty    (rdempty    ),
      .wrempty    (wrempty    ),
      .rdfull     (rdfull     ),
      .wrfull     (wrfull     ),
      .rdundrflow (rdundrflow ),
      .wrundrflow (wrundrflow ),
      .rdoverflow (rdoverflow ),
      .wroverflow (wroverflow )
   );
   unit_split2unpackedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq),
      .out(q )
   );
endmodule
module fifo_2clk_packedarray_extd #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       ARRAYSIZ    = 2,            ///< 数组元素个数
   parameter int       EXTDBITW    = 7,            ///< 扩展的非数组数据位宽
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, de, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, qe, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                            aclr;                   ///< 异步复位信号，高电平(1)有效
   input  bit                             clkr, clkw;             ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                            rsclr, wsclr;           ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                            rdreq, wrreq;           ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]d;                      ///< FIFO输入数据
   input  wire[EXTDBITW-1:0]              de;                     ///< FIFO输入扩展数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]q;                      ///< FIFO输出数据
   output wire[EXTDBITW-1:0]              qe;                     ///< FIFO输出扩展数据
   output wire[depBitw-1:0]               rdusedw, wrusedw;       ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                            rdempty, wrempty;       ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效
                                                                  ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                            rdfull, wrfull;         ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                            rdundrflow, wrundrflow; ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                            rdoverflow, wroverflow; ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   wire[UNITBITW*ARRAYSIZ+EXTDBITW-1:0]dd, qq;
   packedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d                        ),
      .out(dd[UNITBITW*ARRAYSIZ-1:0])
   );
   assign dd[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ] = de;
   fifo_2clk #(
      .UNITBITW   (UNITBITW*ARRAYSIZ+EXTDBITW),
      .DEPTH      (DEPTH                     ),
      .SHOWAHEAD  (SHOWAHEAD                 ),
      .RCDSYNCTAPS(RCDSYNCTAPS               ),
      .WCDSYNCTAPS(WCDSYNCTAPS               ),
      .RCDUSEDWDLY(RCDUSEDWDLY               ),
      .WCDUSEDWDLY(WCDUSEDWDLY               )
   ) dcfifopaei(
      .aclr       (aclr       ),
      .clkr       (clkr       ),
      .clkw       (clkw       ),
      .rsclr      (rsclr      ),
      .wsclr      (wsclr      ),
      .rdreq      (rdreq      ),
      .wrreq      (wrreq      ),
      .d          (dd         ),
      .q          (qq         ),
      .rdusedw    (rdusedw    ),
      .wrusedw    (wrusedw    ),
      .rdempty    (rdempty    ),
      .wrempty    (wrempty    ),
      .rdfull     (rdfull     ),
      .wrfull     (wrfull     ),
      .rdundrflow (rdundrflow ),
      .wrundrflow (wrundrflow ),
      .rdoverflow (rdoverflow ),
      .wroverflow (wroverflow )
   );
   unit_split2packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq[UNITBITW*ARRAYSIZ-1:0]),
      .out(q                        )
   );
   assign qe = qq[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ];
endmodule
module fifo_2clk_unpackedarray_extd #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       ARRAYSIZ    = 2,            ///< 合并数组元素个数
   parameter int       EXTDBITW    = 7,            ///< 扩展的非数组数据位宽
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, de, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, qe, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                aclr;                   ///< 异步复位信号，高电平(1)有效
   input  bit                 clkr, clkw;             ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                rsclr, wsclr;           ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                rdreq, wrreq;           ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0] d[ARRAYSIZ-1:0];        ///< FIFO输入数据
   input  wire [EXTDBITW-1:0] de;                     ///< FIFO输入扩展数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire [UNITBITW-1:0] q[ARRAYSIZ-1:0];        ///< FIFO输出数据
   output wire [EXTDBITW-1:0] qe;                     ///< FIFO输出扩展数据
   output wire [depBitw-1:0]  rdusedw, wrusedw;       ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                rdempty, wrempty;       ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效
                                                      ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                rdfull, wrfull;         ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                rdundrflow, wrundrflow; ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                rdoverflow, wroverflow; ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   wire[UNITBITW*ARRAYSIZ+EXTDBITW-1:0]dd, qq;
   unpackedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d                        ),
      .out(dd[UNITBITW*ARRAYSIZ-1:0])
   );
   assign dd[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ] = de;
   fifo_2clk #(
      .UNITBITW   (UNITBITW*ARRAYSIZ+EXTDBITW),
      .DEPTH      (DEPTH                     ),
      .SHOWAHEAD  (SHOWAHEAD                 ),
      .RCDSYNCTAPS(RCDSYNCTAPS               ),
      .WCDSYNCTAPS(WCDSYNCTAPS               ),
      .RCDUSEDWDLY(RCDUSEDWDLY               ),
      .WCDUSEDWDLY(WCDUSEDWDLY               )
   ) dcfifopaei(
      .aclr       (aclr       ),
      .clkr       (clkr       ),
      .clkw       (clkw       ),
      .rsclr      (rsclr      ),
      .wsclr      (wsclr      ),
      .rdreq      (rdreq      ),
      .wrreq      (wrreq      ),
      .d          (dd         ),
      .q          (qq         ),
      .rdusedw    (rdusedw    ),
      .wrusedw    (wrusedw    ),
      .rdempty    (rdempty    ),
      .wrempty    (wrempty    ),
      .rdfull     (rdfull     ),
      .wrfull     (wrfull     ),
      .rdundrflow (rdundrflow ),
      .wrundrflow (wrundrflow ),
      .rdoverflow (rdoverflow ),
      .wroverflow (wroverflow )
   );
   unit_split2unpackedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq[UNITBITW*ARRAYSIZ-1:0]),
      .out(q                        )
   );
   assign qe = qq[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ];
endmodule
module fifo_2clk_packedunit_packedarray #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       AUNITSIZ    = 1,            ///< 数组单元元素个数
   parameter int       ARRAYSIZ    = 2,            ///< 数组单元个数
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                                           aclr;                   ///< 异步复位信号，高电平(1)有效
   input  bit                                            clkr, clkw;             ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                                           rsclr, wsclr;           ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                                           rdreq, wrreq;           ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] d;                      ///< FIFO输入数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] q;                      ///< FIFO输出数据
   output wire[depBitw-1:0]                              rdusedw, wrusedw;       ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                                           rdempty, wrempty;       ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效
                                                                                 ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                                           rdfull, wrfull;         ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                                           rdundrflow, wrundrflow; ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                                           rdoverflow, wroverflow; ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]dd, qq;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d ),
      .out(dd)
   );
   fifo_2clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .DEPTH      (DEPTH                     ),
      .SHOWAHEAD  (SHOWAHEAD                 ),
      .RCDSYNCTAPS(RCDSYNCTAPS               ),
      .WCDSYNCTAPS(WCDSYNCTAPS               ),
      .RCDUSEDWDLY(RCDUSEDWDLY               ),
      .WCDUSEDWDLY(WCDUSEDWDLY               )
   ) dcfifopai(
      .aclr       (aclr       ),
      .clkr       (clkr       ),
      .clkw       (clkw       ),
      .rsclr      (rsclr      ),
      .wsclr      (wsclr      ),
      .rdreq      (rdreq      ),
      .wrreq      (wrreq      ),
      .d          (dd         ),
      .q          (qq         ),
      .rdusedw    (rdusedw    ),
      .wrusedw    (wrusedw    ),
      .rdempty    (rdempty    ),
      .wrempty    (wrempty    ),
      .rdfull     (rdfull     ),
      .wrfull     (wrfull     ),
      .rdundrflow (rdundrflow ),
      .wrundrflow (wrundrflow ),
      .rdoverflow (rdoverflow ),
      .wroverflow (wroverflow )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq),
      .out(q )
   );
endmodule
module fifo_2clk_packedunit_unpackedarray #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       AUNITSIZ    = 1,            ///< 数组单元元素个数
   parameter int       ARRAYSIZ    = 2,            ///< 数组单元个数
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                            aclr;                   ///< 异步复位信号，高电平(1)有效
   input  bit                             clkr, clkw;             ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                            rsclr, wsclr;           ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                            rdreq, wrreq;           ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]d[ARRAYSIZ-1:0];        ///< FIFO输入数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]q[ARRAYSIZ-1:0];        ///< FIFO输出数据
   output wire[depBitw-1:0]               rdusedw, wrusedw;       ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                            rdempty, wrempty;       ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效
                                                                  ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                            rdfull, wrfull;         ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                            rdundrflow, wrundrflow; ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                            rdoverflow, wroverflow; ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]dd, qq;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d ),
      .out(dd)
   );
   fifo_2clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .DEPTH      (DEPTH                     ),
      .SHOWAHEAD  (SHOWAHEAD                 ),
      .RCDSYNCTAPS(RCDSYNCTAPS               ),
      .WCDSYNCTAPS(WCDSYNCTAPS               ),
      .RCDUSEDWDLY(RCDUSEDWDLY               ),
      .WCDUSEDWDLY(WCDUSEDWDLY               )
   ) dcfifoupai(
      .aclr       (aclr       ),
      .clkr       (clkr       ),
      .clkw       (clkw       ),
      .rsclr      (rsclr      ),
      .wsclr      (wsclr      ),
      .rdreq      (rdreq      ),
      .wrreq      (wrreq      ),
      .d          (dd         ),
      .q          (qq         ),
      .rdusedw    (rdusedw    ),
      .wrusedw    (wrusedw    ),
      .rdempty    (rdempty    ),
      .wrempty    (wrempty    ),
      .rdfull     (rdfull     ),
      .wrfull     (wrfull     ),
      .rdundrflow (rdundrflow ),
      .wrundrflow (wrundrflow ),
      .rdoverflow (rdoverflow ),
      .wroverflow (wroverflow )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq),
      .out(q )
   );
endmodule
module fifo_2clk_unpackedunit_unpackedarray #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       AUNITSIZ    = 1,            ///< 数组单元元素个数
   parameter int       ARRAYSIZ    = 2,            ///< 数组单元个数
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                aclr;                         ///< 异步复位信号，高电平(1)有效
   input  bit                 clkr, clkw;                   ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                rsclr, wsclr;                 ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                rdreq, wrreq;                 ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0] d[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< FIFO输入数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire [UNITBITW-1:0] q[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< FIFO输出数据
   output wire [depBitw -1:0] rdusedw, wrusedw;             ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                rdempty, wrempty;             ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效
                                                            ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                rdfull, wrfull;               ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                rdundrflow, wrundrflow;       ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                rdoverflow, wroverflow;       ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]dd, qq;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d ),
      .out(dd)
   );
   fifo_2clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .DEPTH      (DEPTH                     ),
      .SHOWAHEAD  (SHOWAHEAD                 ),
      .RCDSYNCTAPS(RCDSYNCTAPS               ),
      .WCDSYNCTAPS(WCDSYNCTAPS               ),
      .RCDUSEDWDLY(RCDUSEDWDLY               ),
      .WCDUSEDWDLY(WCDUSEDWDLY               )
   ) dcfifoupai(
      .aclr       (aclr       ),
      .clkr       (clkr       ),
      .clkw       (clkw       ),
      .rsclr      (rsclr      ),
      .wsclr      (wsclr      ),
      .rdreq      (rdreq      ),
      .wrreq      (wrreq      ),
      .d          (dd         ),
      .q          (qq         ),
      .rdusedw    (rdusedw    ),
      .wrusedw    (wrusedw    ),
      .rdempty    (rdempty    ),
      .wrempty    (wrempty    ),
      .rdfull     (rdfull     ),
      .wrfull     (wrfull     ),
      .rdundrflow (rdundrflow ),
      .wrundrflow (wrundrflow ),
      .rdoverflow (rdoverflow ),
      .wroverflow (wroverflow )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq),
      .out(q )
   );
endmodule
module fifo_2clk_packedunit_packedarray_extd #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       AUNITSIZ    = 1,            ///< 数组单元元素个数
   parameter int       ARRAYSIZ    = 2,            ///< 数组单元个数
   parameter int       EXTDBITW    = 7,            ///< 扩展的非数组数据位宽
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, de, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, qe, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                                           aclr;                   ///< 异步复位信号，高电平(1)有效
   input  bit                                            clkr, clkw;             ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                                           rsclr, wsclr;           ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                                           rdreq, wrreq;           ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] d;                      ///< FIFO输入数据
   input  wire[EXTDBITW-1:0]                             de;                     ///< FIFO输入扩展数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] q;                      ///< FIFO输出数据
   output wire[EXTDBITW-1:0]                             qe;                     ///< FIFO输出扩展数据
   output wire[depBitw -1:0]                             rdusedw, wrusedw;       ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                                           rdempty, wrempty;       ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效
                                                                                 ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                                           rdfull, wrfull;         ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                                           rdundrflow, wrundrflow; ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                                           rdoverflow, wroverflow; ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:0]dd, qq;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d                                 ),
      .out(dd[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   assign dd[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ] = de;
   fifo_2clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .DEPTH      (DEPTH                              ),
      .SHOWAHEAD  (SHOWAHEAD                          ),
      .RCDSYNCTAPS(RCDSYNCTAPS                        ),
      .WCDSYNCTAPS(WCDSYNCTAPS                        ),
      .RCDUSEDWDLY(RCDUSEDWDLY                        ),
      .WCDUSEDWDLY(WCDUSEDWDLY                        )
   ) dcfifopaei(
      .aclr       (aclr       ),
      .clkr       (clkr       ),
      .clkw       (clkw       ),
      .rsclr      (rsclr      ),
      .wsclr      (wsclr      ),
      .rdreq      (rdreq      ),
      .wrreq      (wrreq      ),
      .d          (dd         ),
      .q          (qq         ),
      .rdusedw    (rdusedw    ),
      .wrusedw    (wrusedw    ),
      .rdempty    (rdempty    ),
      .wrempty    (wrempty    ),
      .rdfull     (rdfull     ),
      .wrfull     (wrfull     ),
      .rdundrflow (rdundrflow ),
      .wrundrflow (wrundrflow ),
      .rdoverflow (rdoverflow ),
      .wroverflow (wroverflow )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]),
      .out(q                                 )
   );
   assign qe = qq[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
endmodule
module fifo_2clk_packedunit_unpackedarray_extd #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       AUNITSIZ    = 1,            ///< 数组单元元素个数
   parameter int       ARRAYSIZ    = 2,            ///< 数组单元个数
   parameter int       EXTDBITW    = 7,            ///< 扩展的非数组数据位宽
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, de, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, qe, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                            aclr;                   ///< 异步复位信号，高电平(1)有效
   input  bit                             clkr, clkw;             ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                            rsclr, wsclr;           ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                            rdreq, wrreq;           ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]d[ARRAYSIZ-1:0];        ///< FIFO输入数据
   input  wire[EXTDBITW-1:0]              de;                     ///< FIFO输入扩展数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]q[ARRAYSIZ-1:0];        ///< FIFO输出数据
   output wire[EXTDBITW-1:0]              qe;                     ///< FIFO输出扩展数据
   output wire[depBitw -1:0]              rdusedw, wrusedw;       ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                            rdempty, wrempty;       ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效
                                                                  ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                            rdfull, wrfull;         ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                            rdundrflow, wrundrflow; ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                            rdoverflow, wroverflow; ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:0]dd, qq;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d                                 ),
      .out(dd[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   assign dd[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ] = de;
   fifo_2clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .DEPTH      (DEPTH                              ),
      .SHOWAHEAD  (SHOWAHEAD                          ),
      .RCDSYNCTAPS(RCDSYNCTAPS                        ),
      .WCDSYNCTAPS(WCDSYNCTAPS                        ),
      .RCDUSEDWDLY(RCDUSEDWDLY                        ),
      .WCDUSEDWDLY(WCDUSEDWDLY                        )
   ) dcfifopaei(
      .aclr       (aclr       ),
      .clkr       (clkr       ),
      .clkw       (clkw       ),
      .rsclr      (rsclr      ),
      .wsclr      (wsclr      ),
      .rdreq      (rdreq      ),
      .wrreq      (wrreq      ),
      .d          (dd         ),
      .q          (qq         ),
      .rdusedw    (rdusedw    ),
      .wrusedw    (wrusedw    ),
      .rdempty    (rdempty    ),
      .wrempty    (wrempty    ),
      .rdfull     (rdfull     ),
      .wrfull     (wrfull     ),
      .rdundrflow (rdundrflow ),
      .wrundrflow (wrundrflow ),
      .rdoverflow (rdoverflow ),
      .wroverflow (wroverflow )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]),
      .out(q                                 )
   );
   assign qe = qq[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
endmodule
module fifo_2clk_unpackedunit_unpackedarray_extd #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       AUNITSIZ    = 1,            ///< 数组单元元素个数
   parameter int       ARRAYSIZ    = 2,            ///< 数组单元个数
   parameter int       EXTDBITW    = 7,            ///< 扩展的非数组数据位宽
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0,         ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
   parameter bit[31:0] RCDSYNCTAPS = 32'd2,        ///< 读时钟域同步锁存拍数， >= 2
   parameter bit[31:0] WCDSYNCTAPS = 32'd2,        ///< 写时钟域同步锁存拍数， >= 2
   parameter bit[31:0] RCDUSEDWDLY = 32'd1,        ///< 读时钟域已使用深度 #rdusedw 的输出延迟拍数， > 0
   parameter bit[31:0] WCDUSEDWDLY = 32'd1         ///< 写时钟域已使用深度 #wrusedw 的输出延迟拍数， > 0
) (aclr, clkr, rsclr, rdreq, d, de, rdusedw, rdempty, rdfull, rdundrflow, rdoverflow, clkw, wsclr, wrreq, q, qe, wrusedw, wrempty, wrfull, wrundrflow, wroverflow);
   input  wire                aclr;                         ///< 异步复位信号，高电平(1)有效
   input  bit                 clkr, clkw;                   ///< clkr-读时钟域驱动时钟，clkw-写时钟域驱动时钟
   input  wire                rsclr, wsclr;                 ///< rsclr-读时钟域同步复位信号，wsclr-写时钟域同步复位信号，高电平(1)有效
   input  wire                rdreq, wrreq;                 ///< rdreq-读请求或通知信号，wrreq-写请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0] d[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< FIFO输入数据
   input  wire [EXTDBITW-1:0] de;                           ///< FIFO输入扩展数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire [UNITBITW-1:0] q[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< FIFO输出数据
   output wire [EXTDBITW-1:0] qe;                           ///< FIFO输出扩展数据
   output wire [depBitw -1:0] rdusedw, wrusedw;             ///< rdusedw-读时钟域FIFO已使用深度，wrusedw-写时钟域FIFO已使用深度
   output wire                rdempty, wrempty;             ///< rdempty-读时钟域FIFO空状态，wrempty-写时钟域FIFO空状态，高电平(1)有效
                                                            ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                rdfull, wrfull;               ///< rdfull-读时钟域FIFO满状态，wrfull-写时钟域FIFO满状态，高电平(1)有效
   output wire                rdundrflow, wrundrflow;       ///< rdundrflow-读时钟域FIFO下溢出标志，wrundrflow-写时钟域FIFO下溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零
   output wire                rdoverflow, wroverflow;       ///< rdoverflow-读时钟域FIFO上溢出标志，wroverflow-写时钟域FIFO上溢出标志，高电平(1)有效，本信号置位后须异步复位或对应时钟域同步复位后FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:0]dd, qq;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d                                 ),
      .out(dd[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   assign dd[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ] = de;
   fifo_2clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .DEPTH      (DEPTH                              ),
      .SHOWAHEAD  (SHOWAHEAD                          ),
      .RCDSYNCTAPS(RCDSYNCTAPS                        ),
      .WCDSYNCTAPS(WCDSYNCTAPS                        ),
      .RCDUSEDWDLY(RCDUSEDWDLY                        ),
      .WCDUSEDWDLY(WCDUSEDWDLY                        )
   ) dcfifopaei(
      .aclr       (aclr       ),
      .clkr       (clkr       ),
      .clkw       (clkw       ),
      .rsclr      (rsclr      ),
      .wsclr      (wsclr      ),
      .rdreq      (rdreq      ),
      .wrreq      (wrreq      ),
      .d          (dd         ),
      .q          (qq         ),
      .rdusedw    (rdusedw    ),
      .wrusedw    (wrusedw    ),
      .rdempty    (rdempty    ),
      .wrempty    (wrempty    ),
      .rdfull     (rdfull     ),
      .wrfull     (wrfull     ),
      .rdundrflow (rdundrflow ),
      .wrundrflow (wrundrflow ),
      .rdoverflow (rdoverflow ),
      .wroverflow (wroverflow )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]),
      .out(q                                 )
   );
   assign qe = qq[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
endmodule
/*! \brief 单时钟同步FIFO */
module fifo_1clk #(
   parameter int       UNITBITW    = 32,           ///< 数据位宽
   parameter int       DEPTH       = 10,           ///< FIFO深度
   parameter bit       SHOWAHEAD   = 1'b0          ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, q, qlk, qp, usedw, empty, full, undrflow, overflow);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr, sclr;          ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                wrreq, rdreq;        ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0] d;                   ///< FIFO输入数据信号
   output wire [UNITBITW-1:0] q;                   ///< FIFO输出数据信号
   output wire                qlk;                 ///< 读泄漏信号，高电平(1)有效。
                                                   ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                   ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output logic[UNITBITW-1:0] qp;                  ///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire [depBitw-1:0]  usedw;               ///< FIFO已使用深度
   output wire                empty, full;         ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                   ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                undrflow, overflow;  ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   basic_fifo #(
      .DUALCLK       (1'b0       ),
      .CLKDSYNCTAPS  ({32'd0}    ),
      .UNITBITW      (UNITBITW   ),
      .DEPTH         (DEPTH      ),
      .SHOWAHEAD     (SHOWAHEAD  ),
      .USEDWDLYTAPS  ({32'd1}    )
   ) scfifoi(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .wrreq   (wrreq   ),
      .rdreq   (rdreq   ),
      .data    (d       ),
      .q       (q       ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   assign qlk = (usedw == (depBitw)'(1) && empty == 1'b1) ? 1'b1 : 1'b0;
   // logic[1:0][UNITBITW-1:0]qpp;
   // always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
   //    if      (aclr) qpp <= {(2){{(UNITBITW){1'b0}}}};
   //    else if (sclr) qpp <= {(2){{(UNITBITW){1'b0}}}};
   //    else           qpp <= wrreq ? {qpp[0], d} : qpp;
   // end
   // assign qp = qpp[1];
   logic[0:0][UNITBITW-1:0]qpp;
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) qpp <= {{(UNITBITW){1'b0}}};
      else if (sclr) qpp <= {{(UNITBITW){1'b0}}};
      else           qpp <= wrreq ? d : qpp;
   end
   assign qp = qpp[0];
endmodule
module fifo_1clk_packedarray #(
   parameter int       UNITBITW  = 32,             ///< 数据位宽
   parameter int       ARRAYSIZ  = 2,              ///< 合并数组元素个数
   parameter int       DEPTH     = 10,             ///< FIFO深度
   parameter bit       SHOWAHEAD = 1'b0            ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, q, qlk, qp, usedw, empty, full, undrflow, overflow);
   input  bit                             clk;                 ///< 驱动时钟
   input  wire                            aclr, sclr;          ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                            wrreq, rdreq;        ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]d;                   ///< FIFO输入数据信号
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]q;                   ///< FIFO输出数据信号
   output wire                            qlk;                 ///< 读泄漏信号，高电平(1)有效。
                                                               ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                               ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output logic[UNITBITW-1:0]             qp;                  ///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[depBitw-1:0]               usedw;               ///< FIFO已使用深度
   output wire                            empty, full;         ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                               ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                            undrflow, overflow;  ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   wire[UNITBITW*ARRAYSIZ-1:0]dd, qq, qqp;
   packedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d ),
      .out(dd)
   );
   fifo_1clk #(
      .UNITBITW   (UNITBITW*ARRAYSIZ),
      .DEPTH      (DEPTH            ),
      .SHOWAHEAD  (SHOWAHEAD        )
   ) scfifopai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .rdreq   (rdreq   ),
      .wrreq   (wrreq   ),
      .d       (dd      ),
      .q       (qq      ),
      .qlk     (qlk     ),
      .qp      (qqp     ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   unit_split2packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq),
      .out(q )
   );
   unit_split2packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) p2a(
      .in (qqp ),
      .out(qp  )
   );
endmodule
module fifo_1clk_unpackedarray #(
   parameter int       UNITBITW  = 32,             ///< 数据位宽
   parameter int       ARRAYSIZ  = 2,              ///< 合并数组元素个数
   parameter int       DEPTH     = 10,             ///< FIFO深度
   parameter bit       SHOWAHEAD = 1'b0            ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, q, qlk, qp, usedw, empty, full, undrflow, overflow);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr, sclr;          ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                wrreq, rdreq;        ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0] d[ARRAYSIZ-1:0];     ///< FIFO输入数据信号
   output wire [UNITBITW-1:0] q[ARRAYSIZ-1:0];     ///< FIFO输出数据信号
   output wire                qlk;                 ///< 读泄漏信号，高电平(1)有效。
                                                   ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                   ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output logic[UNITBITW-1:0] qp[ARRAYSIZ-1:0];    ///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire [depBitw-1:0]  usedw;               ///< FIFO已使用深度
   output wire                empty, full;         ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                   ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                undrflow, overflow;  ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   wire[UNITBITW*ARRAYSIZ-1:0]dd, qq, qqp;
   unpackedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d ),
      .out(dd)
   );
   fifo_1clk #(
      .UNITBITW   (UNITBITW*ARRAYSIZ),
      .DEPTH      (DEPTH            ),
      .SHOWAHEAD  (SHOWAHEAD        )
   ) scfifoupai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .rdreq   (rdreq   ),
      .wrreq   (wrreq   ),
      .d       (dd      ),
      .q       (qq      ),
      .qlk     (qlk     ),
      .qp      (qqp     ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   unit_split2unpackedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq),
      .out(q )
   );
   unit_split2unpackedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) p2a(
      .in (qqp ),
      .out(qp  )
   );
endmodule
module fifo_1clk_packedarray_extd #(
   parameter int       UNITBITW  = 32,             ///< 数据位宽
   parameter int       ARRAYSIZ  = 2,              ///< 合并数组元素个数
   parameter int       EXTDBITW  = 7,              ///< 扩展的非数组数据位宽
   parameter int       DEPTH     = 10,             ///< FIFO深度
   parameter bit       SHOWAHEAD = 1'b0            ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, de, q, qe, qlk, qp, qpe, usedw, empty, full, undrflow, overflow);
   input  bit                             clk;                 ///< 驱动时钟
   input  wire                            aclr, sclr;          ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                            wrreq, rdreq;        ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][UNITBITW-1:0]d;                   ///< FIFO输入数据信号
   input  wire[EXTDBITW-1:0]              de;                  ///< FIFO输入扩展数据
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]q;                   ///< FIFO输出数据信号
   output wire[EXTDBITW-1:0]              qe;                  ///< FIFO输出扩展数据
   output wire                            qlk;                 ///< 读泄漏信号，高电平(1)有效。
                                                               ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                               ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output wire[ARRAYSIZ-1:0][UNITBITW-1:0]qp;                  ///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   output wire[EXTDBITW-1:0]              qpe;                 ///< 读泄漏输出补偿扩展数据信号，仅 #qlk 为高电平时有效
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[depBitw-1:0]               usedw;               ///< FIFO已使用深度
   output wire                            empty, full;         ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                               ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                            undrflow, overflow;  ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   wire[UNITBITW*ARRAYSIZ+EXTDBITW-1:0]dd, qq, qqp;
   packedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d                        ),
      .out(dd[UNITBITW*ARRAYSIZ-1:0])
   );
   assign dd[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ] = de;
   fifo_1clk #(
      .UNITBITW   (UNITBITW*ARRAYSIZ+EXTDBITW),
      .DEPTH      (DEPTH                     ),
      .SHOWAHEAD  (SHOWAHEAD                 )
   ) scfifopai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .rdreq   (rdreq   ),
      .wrreq   (wrreq   ),
      .d       (dd      ),
      .q       (qq      ),
      .qlk     (qlk     ),
      .qp      (qqp     ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   unit_split2packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq[UNITBITW*ARRAYSIZ-1:0]),
      .out(q                        )
   );
   assign qe = qq[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ];
   unit_split2packedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) p2a(
      .in (qqp[UNITBITW*ARRAYSIZ-1:0]  ),
      .out(qp                          )
   );
   assign qpe = qqp[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ];
endmodule
module fifo_1clk_unpackedarray_extd #(
   parameter int       UNITBITW  = 32,             ///< 数据位宽
   parameter int       ARRAYSIZ  = 2,              ///< 合并数组元素个数
   parameter int       EXTDBITW  = 7,              ///< 扩展的非数组数据位宽
   parameter int       DEPTH     = 10,             ///< FIFO深度
   parameter bit       SHOWAHEAD = 1'b0            ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, de, q, qe, qlk, qp, qpe, usedw, empty, full, undrflow, overflow);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr, sclr;          ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                wrreq, rdreq;        ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0] d[ARRAYSIZ-1:0];     ///< FIFO输入数据信号
   input  wire [EXTDBITW-1:0] de;                  ///< FIFO输入扩展数据
   output wire [UNITBITW-1:0] q[ARRAYSIZ-1:0];     ///< FIFO输出数据信号
   output wire [EXTDBITW-1:0] qe;                  ///< FIFO输出扩展数据
   output wire                qlk;                 ///< 读泄漏信号，高电平(1)有效。
                                                   ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                   ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output wire [UNITBITW-1:0] qp[ARRAYSIZ-1:0];    ///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   output wire [EXTDBITW-1:0] qpe;                 ///< 读泄漏输出补偿扩展数据，仅 #qlk 为高电平时有效
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire [depBitw-1:0]  usedw;               ///< FIFO已使用深度
   output wire                empty, full;         ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                   ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                undrflow, overflow;  ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   wire[UNITBITW*ARRAYSIZ+EXTDBITW-1:0]dd, qq, qqp;
   unpackedarray_combine2unit #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d                        ),
      .out(dd[UNITBITW*ARRAYSIZ-1:0])
   );
   assign dd[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ] = de;
   fifo_1clk #(
      .UNITBITW   (UNITBITW*ARRAYSIZ+EXTDBITW),
      .DEPTH      (DEPTH                     ),
      .SHOWAHEAD  (SHOWAHEAD                 )
   ) scfifopai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .rdreq   (rdreq   ),
      .wrreq   (wrreq   ),
      .d       (dd      ),
      .q       (qq      ),
      .qlk     (qlk     ),
      .qp      (qqp     ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   unit_split2unpackedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq[UNITBITW*ARRAYSIZ-1:0]),
      .out(q                        )
   );
   assign qe = qq[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ];
   unit_split2unpackedarray #(
      .UNITBITW(UNITBITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) p2a(
      .in (qqp[UNITBITW*ARRAYSIZ-1:0]  ),
      .out(qp                          )
   );
   assign qpe = qqp[UNITBITW*ARRAYSIZ+EXTDBITW-1:UNITBITW*ARRAYSIZ];
endmodule
module fifo_1clk_packedunit_packedarray #(
   parameter int       UNITBITW  = 32,             ///< 数据位宽
   parameter int       AUNITSIZ  = 1,              ///< 数组单元元素个数
   parameter int       ARRAYSIZ  = 2,              ///< 数组单元个数
   parameter int       DEPTH     = 10,             ///< FIFO深度
   parameter bit       SHOWAHEAD = 1'b0            ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, q, qlk, qp, usedw, empty, full, undrflow, overflow);
   input  bit                                            clk;                 ///< 驱动时钟
   input  wire                                           aclr, sclr;          ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                                           wrreq, rdreq;        ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] d;                   ///< FIFO输入数据信号
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] q;                   ///< FIFO输出数据信号
   output wire                                           qlk;                 ///< 读泄漏信号，高电平(1)有效。
                                                                              ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                                              ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] qp;                  ///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[depBitw -1:0]                             usedw;               ///< FIFO已使用深度
   output wire                                           empty, full;         ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                                              ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                                           undrflow, overflow;  ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]dd, qq, qqp;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d ),
      .out(dd)
   );
   fifo_1clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .DEPTH      (DEPTH                     ),
      .SHOWAHEAD  (SHOWAHEAD                 )
   ) scfifopai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .rdreq   (rdreq   ),
      .wrreq   (wrreq   ),
      .d       (dd      ),
      .q       (qq      ),
      .qlk     (qlk     ),
      .qp      (qqp     ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq),
      .out(q )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) p2a(
      .in (qqp ),
      .out(qp  )
   );
endmodule
module fifo_1clk_packedunit_unpackedarray #(
   parameter int       UNITBITW  = 32,             ///< 数据位宽
   parameter int       AUNITSIZ  = 1,              ///< 数组单元元素个数
   parameter int       ARRAYSIZ  = 2,              ///< 数组单元个数
   parameter int       DEPTH     = 10,             ///< FIFO深度
   parameter bit       SHOWAHEAD = 1'b0            ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, q, qlk, qp, usedw, empty, full, undrflow, overflow);
   input  bit                             clk;                 ///< 驱动时钟
   input  wire                            aclr, sclr;          ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                            wrreq, rdreq;        ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]d[ARRAYSIZ-1:0];     ///< FIFO输入数据
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]q[ARRAYSIZ-1:0];     ///< FIFO输出数据
   output wire                            qlk;                 ///< 读泄漏信号，高电平(1)有效。
                                                               ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                               ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]qp[ARRAYSIZ-1:0];    ///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[depBitw -1:0]              usedw;               ///< FIFO已使用深度
   output wire                            empty, full;         ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                               ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                            undrflow, overflow;  ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]dd, qq, qqp;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d ),
      .out(dd)
   );
   fifo_1clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .DEPTH      (DEPTH                     ),
      .SHOWAHEAD  (SHOWAHEAD                 )
   ) scfifopai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .rdreq   (rdreq   ),
      .wrreq   (wrreq   ),
      .d       (dd      ),
      .q       (qq      ),
      .qlk     (qlk     ),
      .qp      (qqp     ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq),
      .out(q )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) p2a(
      .in (qqp ),
      .out(qp  )
   );
endmodule
module fifo_1clk_unpackedunit_unpackedarray #(
   parameter int       UNITBITW  = 32,             ///< 数据位宽
   parameter int       AUNITSIZ  = 1,              ///< 数组单元元素个数
   parameter int       ARRAYSIZ  = 2,              ///< 数组单元个数
   parameter int       DEPTH     = 10,             ///< FIFO深度
   parameter bit       SHOWAHEAD = 1'b0            ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, q, qlk, qp, usedw, empty, full, undrflow, overflow);
   input  bit                 clk;                          ///< 驱动时钟
   input  wire                aclr, sclr;                   ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                wrreq, rdreq;                 ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0] d[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< FIFO输入数据
   output wire [UNITBITW-1:0] q[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< FIFO输出数据
   output wire                qlk;                          ///< 读泄漏信号，高电平(1)有效。
                                                            ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                            ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output logic[UNITBITW-1:0] qp[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire [depBitw -1:0] usedw;                        ///< FIFO已使用深度
   output wire                empty, full;                  ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                            ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                undrflow, overflow;           ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]dd, qq, qqp;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d ),
      .out(dd)
   );
   fifo_1clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ),
      .DEPTH      (DEPTH                     ),
      .SHOWAHEAD  (SHOWAHEAD                 )
   ) scfifopai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .rdreq   (rdreq   ),
      .wrreq   (wrreq   ),
      .d       (dd      ),
      .q       (qq      ),
      .qlk     (qlk     ),
      .qp      (qqp     ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq),
      .out(q )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) p2a(
      .in (qqp ),
      .out(qp  )
   );
endmodule
module fifo_1clk_packedunit_packedarray_extd #(
   parameter int       UNITBITW  = 32,             ///< 数据位宽
   parameter int       AUNITSIZ  = 1,              ///< 数组单元元素个数
   parameter int       ARRAYSIZ  = 2,              ///< 数组单元个数
   parameter int       EXTDBITW  = 7,              ///< 扩展的非数组数据位宽
   parameter int       DEPTH     = 10,             ///< FIFO深度
   parameter bit       SHOWAHEAD = 1'b0            ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, de, q, qe, qlk, qp, qpe, usedw, empty, full, undrflow, overflow);
   input  bit                                            clk;                 ///< 驱动时钟
   input  wire                                           aclr, sclr;          ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                                           wrreq, rdreq;        ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] d;                   ///< FIFO输入数据
   input  wire[EXTDBITW-1:0]                             de;                  ///< FIFO输入扩展数据
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] q;                   ///< FIFO输出数据
   output wire[EXTDBITW-1:0]                             qe;                  ///< FIFO输出扩展数据
   output wire                                           qlk;                 ///< 读泄漏信号，高电平(1)有效。
                                                                              ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                                              ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][UNITBITW-1:0] qp;                  ///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   output wire[EXTDBITW-1:0]                             qpe;                 ///< 读泄漏输出补偿扩展数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[depBitw -1:0]                             usedw;               ///< FIFO已使用深度
   output wire                                           empty, full;         ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                                              ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                                           undrflow, overflow;  ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:0]dd, qq, qqp;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d                                 ),
      .out(dd[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   assign dd[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ] = de;
   fifo_1clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .DEPTH      (DEPTH                              ),
      .SHOWAHEAD  (SHOWAHEAD                          )
   ) scfifopai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .rdreq   (rdreq   ),
      .wrreq   (wrreq   ),
      .d       (dd      ),
      .q       (qq      ),
      .qlk     (qlk     ),
      .qp      (qqp     ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]),
      .out(q                                 )
   );
   assign qe = qq[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) p2a(
      .in (qqp[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]  ),
      .out(qp                                   )
   );
   assign qpe = qqp[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
endmodule
module fifo_1clk_packedunit_unpackedarray_extd #(
   parameter int       UNITBITW  = 32,             ///< 数据位宽
   parameter int       AUNITSIZ    = 1,            ///< 数组单元元素个数
   parameter int       ARRAYSIZ    = 2,            ///< 数组单元个数
   parameter int       EXTDBITW  = 7,              ///< 扩展的非数组数据位宽
   parameter int       DEPTH     = 10,             ///< FIFO深度
   parameter bit       SHOWAHEAD = 1'b0            ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, de, q, qe, qlk, qp, qpe, usedw, empty, full, undrflow, overflow);
   input  bit                             clk;                 ///< 驱动时钟
   input  wire                            aclr, sclr;          ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                            wrreq, rdreq;        ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire[AUNITSIZ-1:0][UNITBITW-1:0]d[ARRAYSIZ-1:0];     ///< FIFO输入数据
   input  wire[EXTDBITW-1:0]              de;                  ///< FIFO输入扩展数据
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]q[ARRAYSIZ-1:0];     ///< FIFO输出数据
   output wire[EXTDBITW-1:0]              qe;                  ///< FIFO输出扩展数据
   output wire                            qlk;                 ///< 读泄漏信号，高电平(1)有效。
                                                               ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                               ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output wire[AUNITSIZ-1:0][UNITBITW-1:0]qp;                  ///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   output wire[EXTDBITW-1:0]              qpe;                 ///< 读泄漏输出扩展数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire[depBitw -1:0]              usedw;               ///< FIFO已使用深度
   output wire                            empty, full;         ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                               ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                            undrflow, overflow;  ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:0]dd, qq, qqp;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d                                 ),
      .out(dd[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   assign dd[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ] = de;
   fifo_1clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .DEPTH      (DEPTH                              ),
      .SHOWAHEAD  (SHOWAHEAD                          )
   ) scfifopai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .rdreq   (rdreq   ),
      .wrreq   (wrreq   ),
      .d       (dd      ),
      .q       (qq      ),
      .qlk     (qlk     ),
      .qp      (qqp     ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]),
      .out(q                                 )
   );
   assign qe = qq[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) p2a(
      .in (qqp[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]  ),
      .out(qp                                   )
   );
   assign qpe = qqp[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
endmodule
module fifo_1clk_unpackedunit_unpackedarray_extd #(
   parameter int       UNITBITW  = 32,             ///< 数据位宽
   parameter int       AUNITSIZ    = 1,            ///< 数组单元元素个数
   parameter int       ARRAYSIZ    = 2,            ///< 数组单元个数
   parameter int       EXTDBITW  = 7,              ///< 扩展的非数组数据位宽
   parameter int       DEPTH     = 10,             ///< FIFO深度
   parameter bit       SHOWAHEAD = 1'b0            ///< 输出数据提前显示模式（又称为读通知模式）使能标志，1'b1:使能，1'b0:禁用（默认）。
                                                   ///< \details
                                                   ///< - 输出数据提前显示模式下，FIFO输出端的数据在 #rdreq 信号置位前置位并保持于输出端，#rdreq 信号
                                                   ///< 的高电平触发FIFO在下一个时钟输出下一个可输出数据于输出端，并保持到下一个 #rdreq 信号的高电平。
                                                   ///< - 非输出数据提前显示模式时，FIFO仅在检测到 #rdreq 信号的高电平后下一个时钟才输出数据于输出端，
                                                   ///< 并保持直到下一个 #rdreq 信号的高电平。
) (clk, aclr, sclr, wrreq, rdreq, d, de, q, qe, qlk, qp, qpe, usedw, empty, full, undrflow, overflow);
   input  bit                 clk;                          ///< 驱动时钟
   input  wire                aclr, sclr;                   ///< aclr:异步复位信号，sclr:同步复位信号，高电平(1)有效
   input  wire                wrreq, rdreq;                 ///< wrreq:写入请求信号，rdreq:读出请求信号，高电平(1)有效
   input  wire [UNITBITW-1:0] d[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< FIFO输入数据
   input  wire [EXTDBITW-1:0] de;                           ///< FIFO输入扩展数据
   output wire [UNITBITW-1:0] q[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< FIFO输出数据
   output wire [EXTDBITW-1:0] qe;                           ///< FIFO输出扩展数据
   output wire                qlk;                          ///< 读泄漏信号，高电平(1)有效。
                                                            ///< 由于双口RAM的读写特性限制，基于双口RAM实现的SHOWHEAD模式FIFO在空状态下，若写入数据后需要在下一拍立即读出，在FIFO的输出端将无法得到有效的数据。
                                                            ///< 为补偿该情况，用户应在 #qlk 信号为高电平(1)时用 #qp 端口的数据替换 #q 端口的数据
   output logic[UNITBITW-1:0] qp[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< 读泄漏输出补偿数据信号，仅 #qlk 为高电平时有效
   output wire [EXTDBITW-1:0] qpe;                          ///< FIFO输出扩展数据
   localparam int depBitw = miscs::minbitw_of_integer(DEPTH, 31);
   output wire [depBitw -1:0] usedw;                        ///< FIFO已使用深度
   output wire                empty, full;                  ///< empty:FIFO空标志，full:FIFO满标志，高电平(1)有效
                                                            ///< \attention #empty 信号会比 #usedw 信号从 0 变为 非0 时刻延迟一拍清零
   output wire                undrflow, overflow;           ///< undrflow:下溢出标志，overflow:上溢出标志，高电平(1)有效，本信号置位后须复位FIFO才能清零

   wire[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:0]dd, qq, qqp;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in (d                                 ),
      .out(dd[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   assign dd[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ] = de;
   fifo_1clk #(
      .UNITBITW   (UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW),
      .DEPTH      (DEPTH                              ),
      .SHOWAHEAD  (SHOWAHEAD                          )
   ) scfifopai(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .rdreq   (rdreq   ),
      .wrreq   (wrreq   ),
      .d       (dd      ),
      .q       (qq      ),
      .qlk     (qlk     ),
      .qp      (qqp     ),
      .usedw   (usedw   ),
      .empty   (empty   ),
      .full    (full    ),
      .undrflow(undrflow),
      .overflow(overflow)
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in (qq[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]),
      .out(q                                 )
   );
   assign qe = qq[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(UNITBITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) p2a(
      .in (qqp[UNITBITW*AUNITSIZ*ARRAYSIZ-1:0]  ),
      .out(qp                                   )
   );
   assign qpe = qqp[UNITBITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:UNITBITW*AUNITSIZ*ARRAYSIZ];
endmodule

