/*!
 * \license SPDX-License-Identifier: MIT
 * \file convdb.sv
 * \brief 将数值转换为dB
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, mux, rams, lmbd, lcshift, pipedelay
 */
`include "miscs.svh"
`include "mux.svh"
`include "lmbd.svh"
`include "clshift.svh"
`include "rams.svh"
`define __INC_FROM_CONVDB__
`include "convdb.svh"
/*! \brief dB查询表 */
module __convdb_lut #(
   parameter bit                                                     DUALCHNL    = 1'b0,           ///< 双通道数据输入输出标志，1'b1-双通道数据查表，1'b0-单通道数据查表
   parameter int                                                     IVALBITW    = 16,             ///< 用于查表的数值位宽
   parameter int                                                     SCALDB      = 1,              ///< dB数据的量化值，真实dB = 输出dB / SCALDB
   parameter int                                                     Q15DBLUTSIZ = 0,              ///< Q.15数表示的dB查找表初始化参数深度
   parameter bit                                                     Q15DBSCALED = 1'b0,           ///< Q.15数表示的dB查找表初始化参数经过 SCALDB 量化标志，1'b1-已量化，1'b0-未量化
   parameter bit[(Q15DBLUTSIZ>0?Q15DBLUTSIZ:1)-1:0][$bits(int)-1:0]  Q15DBLUT    = {(Q15DBLUTSIZ>0?Q15DBLUTSIZ:1){{($bits(int)){1'b0}}}}, ///< Q.15数表示的dB数值查找表初始化参数
   parameter int signed                                              DBFIX       = 0,              ///< 输出dB值的修正量，注意其量化值应为 #SCALDB
   parameter int                                                     DBBITW      = 8               ///< 输出dB值的位宽
) (
   input  bit                             clk,     ///< 驱动时钟
   input  wire                            clken,   ///< 时序逻辑翻转使能信号，高电平(1)有效
   input  wire [DUALCHNL:0][IVALBITW-1:0] ival,    ///< 输入待查询的数值
   output logic[DUALCHNL:0][DBBITW-1:0]   odb      ///< 输出数值对应的dB值
);
   localparam ramstyle_use = rams_pkg::recommend_ramstyle(2**IVALBITW, DBBITW) == 0 ? rams_pkg::ramstyle_logic : rams_pkg::ramstyle_ram;
   (* ram_style = ramstyle_use *)
   reg signed[DBBITW-1:0]rom[2**IVALBITW-1:0];
   initial begin
      automatic longint pp;
      automatic int i;
      automatic int signed db, db1;
      if (SCALDB == 0) $error("convdb/__convdb_lut: SCALDB(%0d) of zero is illegal!", SCALDB);
      db1 = convdb_pkg::mindbbitw_wantedbydblut(
                           .scaldb  (SCALDB  ),
                           .ivalbitw(IVALBITW));
      if (DBBITW < db1) $error("convdb/__convdb_lut: DBBITW(%0d) could not hold all the bits of DB value with IVALBITW(%0d), at least %0d bits is required!", DBBITW, IVALBITW, db1); 
      rom[0] = DBFIX;
      for (i = 1; i < 2**IVALBITW; i++) begin
         if (i < Q15DBLUTSIZ) begin
            db = Q15DBLUT[i];
            if (Q15DBSCALED == 1'b0) db = db*SCALDB;
            db = (db>>14);
         end
         else begin
            pp = i;
            pp = (pp << 30);
            db = ((miscs::q15ilog10ofq30(pp)*SCALDB*5)>>13); // ((miscs::q15ilog10ofq30(pp)*10)>>15)
         end
         db = (db>>1) + (db&1);
         rom[i] = db + DBFIX;
      end
   end
   genvar i; generate for (i = 0; i <= int'(DUALCHNL); i++) begin
      always @(posedge clk) begin
         odb[i] <= clken ? rom[ival[i]] : odb;
      end
   end endgenerate
endmodule
/*! \brief 左移位位数对应dB值查找表 */
module __convdb_bslut #(
   parameter bit        DUALCHNL = 1'b0,           ///< 双通道数据输入输出标志，1'b1-双通道数据查表，1'b0-单通道数据查表
   parameter int        MAXBITS2LSH = 15,          ///< 最大左移位数
   parameter int        SCALDB      = 1,           ///< dB数据的量化值，真实dB = 输出dB / SCALDB
   parameter int signed DBFIX       = 0,           ///< 输出dB值的修正量，注意其量化值应为 #SCALDB
   parameter int        DBBITW      = 8            ///< 输出dB值的位宽
) (clk, clken, lshbits, odb);
   input  bit                                   clk;     ///< 驱动时钟
   input  wire                                  clken;   ///< 时序逻辑翻转使能信号，高电平(1)有效
   localparam int bitwof_lshbits = miscs::minbitw_of_integer(MAXBITS2LSH, 32);
   input  wire [DUALCHNL:0][bitwof_lshbits-1:0] lshbits; ///< 左移位数
   output logic[DUALCHNL:0][DBBITW-1:0]         odb;     ///< 左移位数对应的dB值

   localparam ramstyle_use = rams_pkg::recommend_ramstyle(MAXBITS2LSH, DBBITW) == 0 ? rams_pkg::ramstyle_logic : rams_pkg::ramstyle_ram;
   (* ram_style = ramstyle_use *)
   reg signed[DBBITW-1:0] rom[MAXBITS2LSH:0];
   initial begin
      automatic longint pp, q15log10_2;
      automatic int i;
      automatic int signed db, db1;
      if (SCALDB == 0) $error("convdb/__convdb_bslut: SCALDB(%0d) of zero is illegal!", SCALDB);
      q15log10_2 = miscs::q15ilog10ofq30(2<<30);
      pp = q15log10_2*MAXBITS2LSH;
      pp = ((pp*SCALDB*5)>>14);
      db1 = miscs::minbitw_of_longint(pp, 64);
      if (DBBITW < db1) $error("convdb/__convdb_bslut: DBBITW(%0d) could not hold all the bits of DB value with MAXBITS2LSH(%0d), at least %0d bits is required", DBBITW, MAXBITS2LSH, db1);
      rom[0] = 0 + DBFIX;
      for (i = 1; i <= MAXBITS2LSH; i++) begin
         rom[i] = ((q15log10_2*i*SCALDB*5)>>14) + DBFIX;
      end
   end
   genvar i; generate for (i = 0; i <= int'(DUALCHNL); i++) begin
      always @(posedge clk) begin
         odb[i] <= clken ? rom[lshbits[i]] : odb;
      end
   end endgenerate
endmodule
/*! \brief dB数值转换器 */
module convdb_lshfix #(
   parameter int                                                     CHNLCNT     = 1,              ///< 数据通道数
   parameter int                                                     IVALBITW    = 16,             ///< 待转换的数值位宽
   parameter int                                                     SCALDB      = 1,              ///< dB数据的量化值，真实dB = 输出dB / SCALDB ，取 0 表示不输出 dB值
   parameter int                                                     Q15DBLUTSIZ = 0,              ///< Q.15数表示的dB查找表初始化参数深度
   parameter bit                                                     Q15DBSCALED = 1'b0,           ///< Q.15数表示的dB查找表初始化参数经过 SCALDB 量化标志，1'b1-已量化，1'b0-未量化
   parameter bit[(Q15DBLUTSIZ>0?Q15DBLUTSIZ:1)-1:0][$bits(int)-1:0]  Q15DBLUT    = {(Q15DBLUTSIZ>0?Q15DBLUTSIZ:1){{($bits(int)){1'b0}}}}, ///< Q.15数表示的dB数值查找表初始化参数
   parameter int                                                     MAXPRELSH   = 0,              ///< 最大可预置的输入数据左移位数
   parameter int signed                                              DBFIX       = 0,              ///< 输出dB值的修正量，注意其量化值应为 #SCALDB
   parameter int                                                     DBBITW      = 8               ///< 输出dB值的位宽
) (clk, aclr, sclr, clken, ival, prelsh, odb);
   input  bit                             clk;     ///< 驱动时钟
   input  wire                            aclr;    ///< 异步复位信号，高电平(1)有效
   input  wire                            sclr;    ///< 同步复位信号，高电平(1)有效
   input  wire                            clken;   ///< 时序逻辑电路翻转使能信号，高电平(1)有效
   input  wire [CHNLCNT-1:0][IVALBITW-1:0]ival;    ///< 输入等待转换的数值，无符号数
   localparam int prelshbw = miscs::minbitw_of_integer(
                                       .value   (MAXPRELSH        ),
                                       .maxbitw ($bits(MAXPRELSH) ));
   input  wire [CHNLCNT-1:0][prelshbw-1:0]prelsh;
   output logic[CHNLCNT-1:0][DBBITW  -1:0]odb;     ///< 输出的dB值

   genvar i; generate
   if (SCALDB != 0) begin: GDB
      localparam int bitwof_ival2db = convdb_pkg::ival2db_bitw;
      localparam int bitwof_pos = miscs::minbitw_of_integer(
                                             .value   (IVALBITW         ),
                                             .maxbitw ($bits(IVALBITW)  )
                                          );
      localparam int delaytaps_lmbd = lmbd_pkg::delaytaps_recommend(IVALBITW);
      logic [CHNLCNT-1:0][bitwof_ival2db-1:0]ival_clsho2db;
      localparam int max_lshbits = convdb_pkg::max_lshbits4convdb(.ivalbitw(IVALBITW+MAXPRELSH));
      localparam int bitwof_lshbits = miscs::minbitw_of_integer(
                                                .value   (max_lshbits),
                                                .maxbitw ($bits(int) )
                                             );
      logic [CHNLCNT-1:0][bitwof_lshbits-1:0]bits2rsh_clsho2db;
      wire  [CHNLCNT-1:0][DBBITW        -1:0]db0, db1, db2o;
      localparam int shbw = IVALBITW + ((MAXPRELSH > 0)
                                        ? prelshbw
                                        : 0);
      wire[CHNLCNT-1:0][shbw-1:0]pipei, pipeo;
      shiftfixtaps_packedarray #(
         .DATABITW   (shbw             ),
         .ARRAYSIZ   (CHNLCNT          ),
         .TAP_DIST   (delaytaps_lmbd+1 ),
         .SCLR_ONRAM (1'b0             ),
         .IMPLBYLOGIC(1'b0             )
      ) pipe_ival(
         .clk     (clk  ),
         .aclr    (aclr ),
         .sclr    (sclr ),
         .clken   (clken),
         .shiftin (pipei),
         .shiftout(pipeo),
         .reseting(     )
      );
      for (i = 0; i < CHNLCNT; i++) begin
         wire[bitwof_pos-1:0] ipos_msb;
         lmbd #(
            .DATABITW   (IVALBITW      ),
            .POSBITW    (bitwof_pos    ),
            .IDXFRMLSB  (1'b0          ),
            .DELAYTAPS  (delaytaps_lmbd),
            .PIPELINE   (1'b0          ),
            .PIPEINPUT  (1'b0          )
         ) lmbd_ival(
            .clk     (clk     ),
            .aclr    (aclr    ),
            .sclr    (sclr    ),
            .clken   (clken   ),
            .x       (ival[i] ),
            .bit2s   (1'b1    ),
            .ipos    (ipos_msb),
            .pipe_x  (        )
         );
         /* ipos_msb(from MSB)      bits2rsh
            IVALBITW                   0
            IVALBITW-1              IVALBITW-bitw2db
            IVALBITW-2              IVALBITW-bitw2db-1
              ...                      ...
               0                    IVALBITW-bitw2db-IVALBITW+1
            即： bits2rsh = IVALBITW-bitw2db - ipos_msb;
            当 IVALBITW-bitw2db > ipos_msb 时， bits2rsh = IVALBITW-bitw2db - ipos_msb
            否则                                bits2rsh = 0
          */
         logic[bitwof_pos-1:0]bits2rsh;
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr) bits2rsh <= '0;
            else if (sclr) bits2rsh <= '0;
            else if (clken)bits2rsh <= ipos_msb < (bitwof_pos)'(IVALBITW-bitwof_ival2db) ? (bitwof_pos)'(IVALBITW-bitwof_ival2db) - ipos_msb : (bitwof_pos)'(0);
            else           bits2rsh <= bits2rsh;
         end
         wire[IVALBITW-1:0]ival_clshi, ival_clsho;
         assign pipei[i][IVALBITW-1:0] = ival [i],
                ival_clshi             = pipeo[i][IVALBITW-1:0];
         if (MAXPRELSH > 0) assign pipei[i][shbw-1:shbw-prelshbw] = prelsh[i];
         localparam int delaytaps_clshft = clshift_pkg::delaytaps_recommend(IVALBITW);
         wire[bitwof_pos-1:0] bits2rsh_clsho;
         clshift #(
            .BITWIDTH      (IVALBITW         ),
            .DIRECTION     (1'b1             ),
            .ARITHMATIC    (1'b0             ),
            .DELAYTAPS     (delaytaps_clshft ),
            .PIPELINE      (1'b1             ),
            .PIPEINPUT     (1'b0             ),
            .PIPEDISTANCE  (1'b1             )
         ) clsh_ival(
            .clk           (clk           ),
            .aclr          (aclr          ),
            .sclr          (sclr          ),
            .clken         (clken         ),
            .x             (ival_clshi    ),
            .distance      (bits2rsh      ),
            .result        (ival_clsho    ),
            .pipe_x        (              ),
            .pipe_distance (bits2rsh_clsho)
         );
         if (MAXPRELSH > 0) begin
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if      (aclr) ival_clsho2db[i] <= {(bitwof_lshbits){1'b0}};
               else if (sclr) ival_clsho2db[i] <= {(bitwof_lshbits){1'b0}};
               else           ival_clsho2db[i] <= clken
                                                      ? ival_clsho[bitwof_ival2db-1:0]
                                                      : ival_clsho2db[i];
            end
            always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
               if      (aclr) bits2rsh_clsho2db[i] <= {(bitwof_lshbits){1'b0}};
               else if (sclr) bits2rsh_clsho2db[i] <= {(bitwof_lshbits){1'b0}};
               else           bits2rsh_clsho2db[i] <= clken
                                                      ? (bitwof_lshbits)'(bits2rsh_clsho) + (bitwof_lshbits)'(pipeo[i][shbw-1:shbw-prelshbw])
                                                      : bits2rsh_clsho2db[i];
            end
         end
         else assign ival_clsho2db    [i] = ival_clsho[bitwof_ival2db-1:0],
                     bits2rsh_clsho2db[i] = bits2rsh_clsho[bitwof_lshbits-1:0];
         assign db2o[i] = db0[i] + db1[i];
         if ((i%2) == 0) begin: LUT
            localparam bit duch = (i + 1 < CHNLCNT)
                                  ? 1'b1
                                  : 1'b0;
            __convdb_lut #(
               .DUALCHNL   (duch          ),
               .IVALBITW   (bitwof_ival2db),
               .SCALDB     (SCALDB        ),
               .Q15DBLUTSIZ(Q15DBLUTSIZ   ),
               .Q15DBSCALED(Q15DBSCALED   ),
               .Q15DBLUT   (Q15DBLUT      ),
               .DBFIX      (DBFIX         ),
               .DBBITW     (DBBITW        )
            ) dbluti(
               .clk  (clk                             ),
               .clken(clken                           ),
               .ival (ival_clsho2db[i+(int'(duch)):i] ),
               .odb  (db0          [i+(int'(duch)):i] )
            );
            __convdb_bslut #(
               .DUALCHNL   (duch       ),
               .MAXBITS2LSH(max_lshbits),
               .SCALDB     (SCALDB     ),
               .DBFIX      (0          ),
               .DBBITW     (DBBITW     )
            ) bsdbluti(
               .clk     (clk                                ),
               .clken   (clken                              ),
               .lshbits (bits2rsh_clsho2db[i+(int'(duch)):i]),
               .odb     (db1              [i+(int'(duch)):i])
            );
         end
      end
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) odb <= '0;
         else if (sclr) odb <= '0;
         else           odb <= clken ? db2o : odb;
      end
   end else assign odb = '0;
   endgenerate
endmodule
module convdb #(
   parameter int                                                     CHNLCNT     = 1,              ///< 数据通道数
   parameter int                                                     IVALBITW    = 16,             ///< 待转换的数值位宽
   parameter int                                                     SCALDB      = 1,              ///< dB数据的量化值，真实dB = 输出dB / SCALDB ，取 0 表示不输出 dB值
   parameter int                                                     Q15DBLUTSIZ = 0,              ///< Q.15数表示的dB查找表初始化参数深度
   parameter bit                                                     Q15DBSCALED = 1'b0,           ///< Q.15数表示的dB查找表初始化参数经过 SCALDB 量化标志，1'b1-已量化，1'b0-未量化
   parameter bit[(Q15DBLUTSIZ>0?Q15DBLUTSIZ:1)-1:0][$bits(int)-1:0]  Q15DBLUT    = {(Q15DBLUTSIZ>0?Q15DBLUTSIZ:1){{($bits(int)){1'b0}}}}, ///< Q.15数表示的dB数值查找表初始化参数
   parameter int signed                                              DBFIX       = 0,              ///< 输出dB值的修正量，注意其量化值应为 #SCALDB
   parameter int                                                     DBBITW      = 8               ///< 输出dB值的位宽
) (clk, aclr, sclr, clken, ival, odb);
   input  bit                             clk;     ///< 驱动时钟
   input  wire                            aclr;    ///< 异步复位信号，高电平(1)有效
   input  wire                            sclr;    ///< 同步复位信号，高电平(1)有效
   input  wire                            clken;   ///< 时序逻辑电路翻转使能信号，高电平(1)有效
   input  wire [CHNLCNT-1:0][IVALBITW-1:0]ival;    ///< 输入等待转换的数值，无符号数
   output logic[CHNLCNT-1:0][DBBITW  -1:0]odb;     ///< 输出的dB值

   convdb_lshfix #(
      .CHNLCNT    (CHNLCNT    ),
      .IVALBITW   (IVALBITW   ),
      .SCALDB     (SCALDB     ),
      .Q15DBLUTSIZ(Q15DBLUTSIZ),
      .Q15DBSCALED(Q15DBSCALED),
      .Q15DBLUT   (Q15DBLUT   ),
      .MAXPRELSH  (0          ),
      .DBFIX      (DBFIX      ),
      .DBBITW     (DBBITW     )
   ) convdbi(
      .clk     (clk              ),
      .aclr    (aclr             ),
      .sclr    (sclr             ),
      .clken   (clken            ),
      .ival    (ival             ),
      .prelsh  ({(CHNLCNT){1'b0}}),
      .odb     (odb              )
   );
endmodule
