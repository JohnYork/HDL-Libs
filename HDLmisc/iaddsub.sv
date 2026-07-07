/*!
 * \license SPDX-License-Identifier: MIT
 * \file iaddsub.sv
 * \brief 有符号整型加/减法运算器，用于替换Altera(IntelFPGA)的lpm_addsub核
 * \author JohnYork <johnyork@yeah.net>
 * \depends pipedelay
 */
module iaddsub #(
   parameter int BITW     = 8,                     ///< 数据位宽
   parameter int INSTMODE = 0,                     ///< 例化模式：<0-仅例化减法，0-同时例化加法和减法，>0-仅例化加法
   parameter bit SIGNED   = 1'b0,                  ///< 有符号运算标志，1'b0-无符号运算，1'b1-有符号运算
   parameter bit DEFTCIN  = 1'b1,                  ///< 忽略 #cin 端口的信号，使用进位信号的默认值
   parameter int PIPELINE = 0                      ///< 流水延迟输出时钟数
) (
   input  bit           clk,                       ///< 驱动时钟
   input  wire          aclr,                      ///< 异步复位信号，高电平(1)有效
   input  wire          clken,                     ///< 时钟使能信号，高电平(1)有效
   input  wire          add_sub,                   ///< 运算选择信号，高电平(1):加法运算，低电平(0):减法运算
   input  wire[BITW-1:0]dataa,                     ///< 运算左参数
   input  wire[BITW-1:0]datab,                     ///< 运算右参数
   input  wire          cin,                       ///< 进位/借位信号输入：
                                                   ///< add_sub = 1'b0(减法)，cin = 1'b0 表示有借位； cin = 1'b1 表示无借位
                                                   ///< add_sub = 1'b1(加法)，cin = 1'b0 表示无进位； cin = 1'b1 表示有进位
   output wire[BITW-1:0]result,                    ///< 运算结果
   output wire          cout,                      ///< 进位/借位信号输出
   output wire          overflow                   ///< 溢出，高电平(1)有效
);
   wire cabr, c2o, of, addsub2use;
   wire[BITW-1:0] b2use, p, g, cp, r2o;
   genvar ibit, incbits_oflvl, ig, ic; generate
   if      (INSTMODE < 0) assign addsub2use = 1'b0, b2use = ~datab;
   else if (INSTMODE > 0) assign addsub2use = 1'b1, b2use = datab;
   else                   assign addsub2use = add_sub, b2use = addsub2use ? datab : ~datab;
   if (DEFTCIN)assign cabr = ~addsub2use;
   else        assign cabr = cin;
   assign p = dataa^b2use;
   assign g = dataa&b2use;
   localparam int bitwof_ppgg = (BITW + 3)/4;
   wire[bitwof_ppgg-1:0]pp, gg;
   for (ibit = 0; ibit < bitwof_ppgg; ibit ++) begin: PG
      localparam int ibitbtn = ibit*4;
      localparam int ibittop = ((ibit+1)*4 > BITW ? BITW : (ibit+1)*4) - 1;
      assign pp[ibit] = &p[ibittop:ibitbtn];
//    for (ig = ibitbtn + 1; ig <= ibittop; ig++) begin: G
//       wire ggi, ggo;
//       if (ig == ibitbtn + 1) assign ggi = g[ibitbtn];
//       else                   assign ggi = G[ig-1].ggo;
//       assign ggo = g[ig]|(p[ig]&ggi);
//    end
      if (ibittop > ibitbtn) begin
         wire[ibittop:ibitbtn+1] ggg, ggg2u;
         if (ibittop > ibitbtn + 1) assign ggg2u = {ggg[ibittop-1:ibitbtn+1], g[ibitbtn]};
         else                       assign ggg2u = g[ibitbtn];
         assign ggg = g[ibittop:ibitbtn+1]|(p[ibittop:ibitbtn+1]&ggg2u);
         assign gg[ibit] = ggg[ibittop];//G[ibittop].ggo;
      end else assign gg[ibit] = g[ibitbtn];
//    for (ic = ibitbtn; ic < ibittop; ic++) begin: C
//       if (ic == 0)assign cp[ic] = g[ic]|(p[ic]&cabr);
//       else        assign cp[ic] = g[ic]|(p[ic]&cp[ic-1]);
//    end
      if (ibittop > ibitbtn) begin
         wire[ibittop-1:ibitbtn] cp2u;
         if (ibitbtn > 0) assign cp2u = cp[ibittop-2:ibitbtn-1];
         else             assign cp2u = {cp[ibittop-2:ibitbtn], cabr};
         assign cp[ibittop-1:ibitbtn] = g[ibittop-1:ibitbtn]|(p[ibittop-1:ibitbtn]&cp2u);
      end
      if (ibittop - ibitbtn + 1 == 4 || ibittop == BITW-1) begin
         if (ibit == 0) assign cp[ibittop] = gg[ibit]|(pp[ibit]&cabr);
         else           assign cp[ibittop] = gg[ibit]|(pp[ibit]&cp[ibit*4-1]);
      end
   end
   assign c2o = cp[BITW-1];
   assign r2o = p^{cp[BITW-2:0], cabr};
   if      (SIGNED)       assign of = (addsub2use ^ (dataa[BITW-1] ^ datab[BITW-1])) & (dataa[BITW-1] ^ r2o[BITW-1]);
   else if (INSTMODE < 0) assign of = ~cp[BITW-1];
   else if (INSTMODE > 0) assign of = cp[BITW-1];
   else                   assign of = addsub2use ? cp[BITW-1] : ~cp[BITW-1];
   endgenerate
   pipedelay_taps #(
      .DATABITW(BITW+2),.DELAYTAPS(PIPELINE)
   ) pipe_res(
      .clk(clk),  .aclr(aclr),.sclr(1'b0),.clken(clken),.x({of, c2o, r2o}),  .pipe_x({overflow, cout, result})
   );
endmodule

