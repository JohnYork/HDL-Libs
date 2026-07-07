/*!
 * \license SPDX-License-Identifier: MIT
 * \file icmultconst.sv
 * \brief 整型复数常数乘法器
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, multconst, pipedelay
 */
`include "miscs.svh"
`define __INC_FROM_ICMULTCONST__
`include "icmultconst.svh"
/*!
 * \brief 整型复数常数乘法器
 * \attention
 * # 当参数 #VAR_PARTBITW 和 #CONST_PARTBITW 都大于0时，结果的实部、虚部位宽将按 #VAR_PARTBITW + #CONST_PARTBITW + 1 为基准执行截位操作；
 * # 否则按计算出的最佳位宽为基准执行截位操作
 */
module icmultconst #(
   parameter int signed MINOF_VARPART  = 6'h01, ///< 输入变量的实部、虚部分量在定义域范围内的最小值
   parameter int signed MAXOF_VARPART  = 6'h30, ///< 输入变量的实部、虚部分量在定义域范围内的最大值
   parameter int signed CONST_REALPART = 3,     ///< 常量复数的实数部分值
   parameter int signed CONST_IMAGPART = 0,     ///< 常量复数的虚数部分值
   parameter int        VAR_PARTBITW   = 0,     ///< 输入变量复数的实部、虚部分量位宽， = 0 时表示自动计算最佳位宽
   parameter int        CONST_PARTBITW = 0,     ///< 常量复数的实部虚部、分量位宽， = 0 时表示自动计算最佳位宽
   parameter int        RES_PARTBITW   = 0,     ///< 指定结果复数实部、虚部分量位宽， = 0 时表示自动计算最佳位宽， > 0 表示计算结果按高位对齐， < 0 表示计算结果按低位对齐
   parameter bit        USE3MULTP      = 1'b0,  ///< 使用三乘法器实现，1'b1-以增加加法器和延迟拍数为代价减少乘法器资源的消耗，1'b0-以增加乘法器资源消耗为代价减少计算延迟拍数
   parameter bit        USEHRDCOR      = 1'b0,  ///< 使用硬件核例化常数乘法器标志，1'b0-使用逻辑元件例化常数乘法器，1'b1-使用硬件乘法器核例化常数乘法器
   parameter bit        RNDRESLSB      = 1'b1,  ///< 结果最低位做四舍五入处理标志，1'b1-对结果最低位四舍五入，1'b0-不对结果最低位四舍五入
   parameter int        DELAYTAPS      = 0      ///< 延迟输出拍数，可选值：0,1,2,3,4
) (clk, aclr, sclr, clken, var_arg, var_valid, res, res_valid);
   input  bit                          clk;           ///< 驱动时钟
   input  wire                         aclr;          ///< 异步复位信号，高电平(1)有效
   input  wire                         sclr;          ///< 同步复位信号，高电平(1)有效
   input  wire                         clken;         ///< 时序逻辑更新使能标志，高电平(1)使能，低电平(0)禁止
   localparam int var_bitw = multconst_pkg::bitwOfSignedVar(.minOfVar(MINOF_VARPART),  .maxOfVar(MAXOF_VARPART));
   initial if (VAR_PARTBITW > 0 && var_bitw > VAR_PARTBITW) $error("icmultconst : specified VAR_PARTBITW(%0d) could not hold all bits of variable between MINOF_VAR(%0d) and MAXOF_VAR(%0d)", VAR_PARTBITW, MINOF_VARPART, MAXOF_VARPART);
   localparam int varbitwbyinput = VAR_PARTBITW > 0 ? VAR_PARTBITW : var_bitw;
   input  wire[1:0][varbitwbyinput-1:0]var_arg;       ///< 输入的复数变量被乘数
   input  wire                         var_valid;     ///< 输入的复数变量有效标志，本标志除了可用作同步外，还被用于在仿真时模块内部对 #var_arg 做值域检查的使能控制
   localparam int minResBitwFrmInput = VAR_PARTBITW + CONST_PARTBITW + 1;
   localparam int minResBitwFrmParam = icmultconst_pkg::bitwOfCplxResPart(.real_minVar(MINOF_VARPART), .real_maxVar(MAXOF_VARPART),  .const_real(CONST_REALPART),  .imag_minVar(MINOF_VARPART),  .imag_maxVar(MAXOF_VARPART),  .const_imag(CONST_IMAGPART));
   localparam int minResBitwNoCut = (VAR_PARTBITW > 0 && CONST_PARTBITW > 0) ? minResBitwFrmInput : minResBitwFrmParam;
   localparam int res_bitw = (RES_PARTBITW == 0) ? minResBitwNoCut : (RES_PARTBITW > 0 ? RES_PARTBITW : -RES_PARTBITW);
   output wire[1:0][res_bitw-1:0]      res;           ///< 乘法结果
   output wire                         res_valid;     ///< 输出结果有效标志

   localparam int stgcnt_entry    = 1;
   localparam int stgcnt_preadd   = int'(USE3MULTP);
   localparam int stgcnt_multiply = USEHRDCOR ? 1 : 3;
   localparam int stgcnt_postadd  = 1;
   localparam int total_stages  = stgcnt_entry + stgcnt_preadd + stgcnt_multiply + stgcnt_postadd;
   localparam int istg_entry    = 0;
   localparam int istg_preadd   = istg_entry + stgcnt_entry;
   localparam int istg_multiply = istg_preadd + stgcnt_preadd;
   localparam int istgend_multiply = istg_multiply + stgcnt_multiply - 1;
   localparam int istg_postadd  = istg_multiply + stgcnt_multiply;
   wire signed[1:0][varbitwbyinput-1:0]var2c;
   wire                                var_valid2c;
   pipedelay_taps #(
      .DATABITW(varbitwbyinput*2+1),.DELAYTAPS(miscs::delaytaps4stage(.stagecnt(total_stages), .istage(istg_entry), .totaltaps(DELAYTAPS),.top_first(1'b0)))
   ) entry_delay(
      .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),.x({var_valid, var_arg[1], var_arg[0]}),  .pipe_x({var_valid2c, var2c[1], var2c[0]})
   );
   localparam int bitwof_muladdres = (VAR_PARTBITW > 0 && CONST_PARTBITW > 0 && RES_PARTBITW > 0) ? res_bitw : minResBitwNoCut;
   /* VAR_PARTBITW > 0 且 CONST_PARTBITW > 0 且 RES_PARTBITW > 0 时，输出结果才高位对齐；
    * VAR_PARTBITW > 0 且 CONST_PARTBITW > 0 不满足时，结果位宽自动匹配最佳位宽，输出结果设置低位对齐也不影响。
    */
   localparam bit mulres_alignlsb = (VAR_PARTBITW > 0 && CONST_PARTBITW > 0 && RES_PARTBITW > 0) ? 1'b0 : 1'b1;
   localparam int bitwof_vmr = multconst_pkg::bitwOfSignedMultRes_constSigned(.minOfVar(MINOF_VARPART),  .maxOfVar(MAXOF_VARPART),  .signedVar(1'b1), .constArg(CONST_REALPART));
   localparam int bitwof_vmi = multconst_pkg::bitwOfSignedMultRes_constSigned(.minOfVar(MINOF_VARPART),  .maxOfVar(MAXOF_VARPART),  .signedVar(1'b1), .constArg(CONST_IMAGPART));
   localparam int bitwof_partmulres = (bitwof_vmr > bitwof_vmi) ? bitwof_vmr : bitwof_vmi;
   localparam int bitwof_mulres = mulres_alignlsb ? (USE3MULTP ? minResBitwNoCut : bitwof_partmulres) : (USE3MULTP ? res_bitw : res_bitw-1);
   localparam int bitwof_resbfrcut = mulres_alignlsb ? minResBitwNoCut : res_bitw;
   wire signed[bitwof_resbfrcut-1:0]rrnc, rinc;
   wire                             rnc_valid;
   localparam int partbitw_r_2p = (res_bitw > minResBitwNoCut) ? minResBitwNoCut : res_bitw;
   generate if (USE3MULTP) begin: CPLX_3MULTP
      /* 节省一个乘法器的算法：
       *   (ar + j*ai)*(br + j*bi)
       * = ar*br - ai*bi + (ar*bi + br*ai)*j
       * = ar*br - ar*bi + ar*bi - ai*bi + (ar*bi - ai*bi + ai*bi + br*ai)*j
       * = ar*(br - bi) + (ar - ai)*bi + [(ar - ai)*bi + ai*(br + bi)]*j
       */
      localparam int signed br_sub_bi = CONST_REALPART - CONST_IMAGPART;
      localparam int signed br_add_bi = CONST_REALPART + CONST_IMAGPART;
      wire signed[varbitwbyinput:0] ar_sub_ai, ar_sub_ai_p;
      wire                          valid_preadd;
      assign ar_sub_ai = {var2c[0][varbitwbyinput-1], var2c[0]} - {var2c[1][varbitwbyinput-1], var2c[1]};
      wire signed[1:0][varbitwbyinput-1:0]var2c_p;
      pipedelay_taps #(
         .DATABITW(1+varbitwbyinput+1+varbitwbyinput*2), .DELAYTAPS(miscs::delaytaps4stage(.stagecnt(total_stages), .istage(istg_preadd), .totaltaps(DELAYTAPS),.top_first(1'b0)))
      ) pre_add_delay(
         .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),
         .x({var_valid2c, ar_sub_ai, var2c[0], var2c[1]}),
         .pipe_x({valid_preadd, ar_sub_ai_p, var2c_p[0], var2c_p[1]})
      );
      localparam int bitwof_ar_mul_br_sub_bi = bitwof_mulres;
      wire signed [bitwof_ar_mul_br_sub_bi-1:0] ar_mul_br_sub_bi;
      imultconst #(
         .MINOF_VAR(MINOF_VARPART), .MAXOF_VAR(MAXOF_VARPART), .SIGNED_VAR(1'b1),.CONSTARG(br_sub_bi),.VARBITW(VAR_PARTBITW),
         .CONSTBITW(CONST_PARTBITW>0 ? CONST_PARTBITW+1 : 0),  .RESBITW(mulres_alignlsb ? -bitwof_ar_mul_br_sub_bi : bitwof_ar_mul_br_sub_bi),  .USEHRDCOR(USEHRDCOR),  .RNDRESLSB(1'b0),
         .DELAYTAPS(miscs::delaytaps4stagerange(.stagecnt(total_stages),.ibgnstage(istg_multiply),.iendstage(istgend_multiply),.totaltaps(DELAYTAPS),.top_first(1'b0)))
      ) ar_mul_br_sub_bi_mpy(
         .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken), .var_arg(var2c_p[0]),.var_valid(valid_preadd),  .res(ar_mul_br_sub_bi), .res_valid(rnc_valid)
      );
      localparam int bitwof_ai_mul_br_add_bi = bitwof_mulres;
      wire signed [bitwof_ai_mul_br_add_bi-1:0] ai_mul_br_add_bi;
      imultconst #(
         .MINOF_VAR(MINOF_VARPART), .MAXOF_VAR(MAXOF_VARPART), .SIGNED_VAR(1'b1),.CONSTARG(br_add_bi),.VARBITW(VAR_PARTBITW),
         .CONSTBITW(CONST_PARTBITW>0 ? CONST_PARTBITW+1 : 0),  .RESBITW(mulres_alignlsb ? -bitwof_ai_mul_br_add_bi : bitwof_ai_mul_br_add_bi),  .USEHRDCOR(USEHRDCOR),  .RNDRESLSB(1'b0),
         .DELAYTAPS(miscs::delaytaps4stagerange(.stagecnt(total_stages),.ibgnstage(istg_multiply),.iendstage(istgend_multiply),.totaltaps(DELAYTAPS),.top_first(1'b0)))
      ) ai_mul_br_add_bi_mpy(
         .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken), .var_arg(var2c_p[1]),.var_valid(valid_preadd),  .res(ai_mul_br_add_bi), .res_valid()
      );
      localparam int signed max_int = {($bits(int)-1){1'b1}};
      localparam int MAXOF_VARPART_DBL = (MAXOF_VARPART < -max_int/2) ? -max_int : ((MAXOF_VARPART > max_int/2) ? max_int : MAXOF_VARPART*2);
      localparam int MINOF_VARPART_DBL = (MINOF_VARPART < -max_int/2) ? -max_int : ((MINOF_VARPART > max_int/2) ? max_int : MINOF_VARPART*2);
      localparam int bitwof_ar_sub_ai_mul_bi = bitwof_mulres;
      wire signed [bitwof_ar_sub_ai_mul_bi-1:0] ar_sub_ai_mul_bi;
      imultconst #(
         .MINOF_VAR(MINOF_VARPART_DBL),.MAXOF_VAR(MAXOF_VARPART_DBL),.SIGNED_VAR(1'b1),.CONSTARG(CONST_IMAGPART),       .VARBITW(VAR_PARTBITW>0 ? VAR_PARTBITW+1 : 0),
         .CONSTBITW(CONST_PARTBITW),   .RESBITW(mulres_alignlsb ? -bitwof_ar_sub_ai_mul_bi : bitwof_ar_sub_ai_mul_bi),  .USEHRDCOR(USEHRDCOR),  .RNDRESLSB(1'b0),
         .DELAYTAPS(miscs::delaytaps4stagerange(.stagecnt(total_stages),.ibgnstage(istg_multiply),.iendstage(istgend_multiply),.totaltaps(DELAYTAPS),.top_first(1'b0)))
      ) ar_sub_ai_mul_bi_mpy(
         .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken), .var_arg(ar_sub_ai_p),  .var_valid(valid_preadd),  .res(ar_sub_ai_mul_bi), .res_valid()
      );
      if (bitwof_resbfrcut > bitwof_mulres) begin
         assign rrnc = {{(bitwof_resbfrcut-bitwof_ar_mul_br_sub_bi){ar_mul_br_sub_bi[bitwof_ar_mul_br_sub_bi-1]}}, ar_mul_br_sub_bi} + {{(bitwof_resbfrcut-bitwof_ar_sub_ai_mul_bi){ar_sub_ai_mul_bi[bitwof_ar_sub_ai_mul_bi-1]}}, ar_sub_ai_mul_bi};
         assign rinc = {{(bitwof_resbfrcut-bitwof_ar_sub_ai_mul_bi){ar_sub_ai_mul_bi[bitwof_ar_sub_ai_mul_bi-1]}}, ar_sub_ai_mul_bi} + {{(bitwof_resbfrcut-bitwof_ai_mul_br_add_bi){ai_mul_br_add_bi[bitwof_ai_mul_br_add_bi-1]}}, ai_mul_br_add_bi};
      end else begin
         assign rrnc = ar_mul_br_sub_bi + ar_sub_ai_mul_bi;
         assign rinc = ar_sub_ai_mul_bi + ai_mul_br_add_bi;
      end
   end else begin: CPLX_4MULTP
      /* 标准算法
       *   (ar + j*ai)*(br + j*bi)
       * = ar*br - ai*bi + (ar*bi + br*ai)*j
       */
      localparam int bitwof_ar_mul_br = bitwof_mulres;
      initial assert(bitwof_ar_mul_br <= minResBitwNoCut);
      wire signed[bitwof_ar_mul_br-1:0]ar_mul_br;
      imultconst #(
         .MINOF_VAR(MINOF_VARPART), .MAXOF_VAR(MAXOF_VARPART), .SIGNED_VAR(1'b1),.CONSTARG(CONST_REALPART), .VARBITW(VAR_PARTBITW),
         .CONSTBITW(CONST_PARTBITW > 0 ? CONST_PARTBITW : 0),  .RESBITW(mulres_alignlsb ? -bitwof_ar_mul_br : bitwof_ar_mul_br), .USEHRDCOR(USEHRDCOR),  .RNDRESLSB(1'b0),
         .DELAYTAPS(miscs::delaytaps4stagerange(.stagecnt(total_stages),.ibgnstage(istg_multiply),.iendstage(istgend_multiply),.totaltaps(DELAYTAPS),.top_first(1'b0)))
      ) ar_mul_br_mpy(
         .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken), .var_arg(var2c[0]),  .var_valid(var_valid2c),.res(ar_mul_br),  .res_valid(rnc_valid)
      );
      localparam int bitwof_ai_mul_bi = bitwof_mulres;
      initial assert(bitwof_ai_mul_bi <= minResBitwNoCut);
      wire signed[bitwof_ai_mul_bi-1:0]ai_mul_bi;
      imultconst #(
         .MINOF_VAR(MINOF_VARPART), .MAXOF_VAR(MAXOF_VARPART), .SIGNED_VAR(1'b1),.CONSTARG(CONST_IMAGPART), .VARBITW(VAR_PARTBITW),
         .CONSTBITW(CONST_PARTBITW > 0 ? CONST_PARTBITW : 0),  .RESBITW(mulres_alignlsb ? -bitwof_ai_mul_bi : bitwof_ai_mul_bi), .USEHRDCOR(USEHRDCOR),  .RNDRESLSB(1'b0),
         .DELAYTAPS(miscs::delaytaps4stagerange(.stagecnt(total_stages),.ibgnstage(istg_multiply),.iendstage(istgend_multiply),.totaltaps(DELAYTAPS),.top_first(1'b0)))
      ) ai_mul_bi_mpy(
         .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken), .var_arg(var2c[1]),  .var_valid(var_valid2c),.res(ai_mul_bi),  .res_valid()
      );
      localparam int bitwof_ar_mul_bi = bitwof_mulres;
      initial assert(bitwof_ar_mul_bi <= minResBitwNoCut);
      wire signed[bitwof_ar_mul_bi-1:0]ar_mul_bi;
      imultconst #(
         .MINOF_VAR(MINOF_VARPART), .MAXOF_VAR(MAXOF_VARPART), .SIGNED_VAR(1'b1),.CONSTARG(CONST_IMAGPART), .VARBITW(VAR_PARTBITW),
         .CONSTBITW(CONST_PARTBITW > 0 ? CONST_PARTBITW : 0),  .RESBITW(mulres_alignlsb ? -bitwof_ar_mul_bi : bitwof_ar_mul_bi),    .USEHRDCOR(USEHRDCOR),  .RNDRESLSB(1'b0),
         .DELAYTAPS(miscs::delaytaps4stagerange(.stagecnt(total_stages),.ibgnstage(istg_multiply),.iendstage(istgend_multiply),.totaltaps(DELAYTAPS),.top_first(1'b0)))
      ) ar_mul_bi_mpy(
         .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken), .var_arg(var2c[0]),  .var_valid(var_valid2c),.res(ar_mul_bi),  .res_valid()
      );
      localparam int bitwof_ai_mul_br = bitwof_mulres;
      initial assert(bitwof_ai_mul_br <= minResBitwNoCut);
      wire signed[bitwof_ai_mul_br-1:0]ai_mul_br;
      imultconst #(
         .MINOF_VAR(MINOF_VARPART), .MAXOF_VAR(MAXOF_VARPART), .SIGNED_VAR(1'b1),.CONSTARG(CONST_REALPART), .VARBITW(VAR_PARTBITW),
         .CONSTBITW(CONST_PARTBITW > 0 ? CONST_PARTBITW : 0),  .RESBITW(mulres_alignlsb ? -bitwof_ai_mul_br : bitwof_ai_mul_br), .USEHRDCOR(USEHRDCOR),  .RNDRESLSB(1'b0),
         .DELAYTAPS(miscs::delaytaps4stagerange(.stagecnt(total_stages),.ibgnstage(istg_multiply),.iendstage(istgend_multiply),.totaltaps(DELAYTAPS),.top_first(1'b0)))
      ) ai_mul_br_mpy(
         .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken), .var_arg(var2c[1]),  .var_valid(var_valid2c),.res(ai_mul_br),  .res_valid()
      );
      if (bitwof_resbfrcut > bitwof_mulres) begin
         assign rrnc = {{(bitwof_resbfrcut-bitwof_ar_mul_br){ar_mul_br[bitwof_ar_mul_br-1]}}, ar_mul_br} - {{(bitwof_resbfrcut-bitwof_ai_mul_bi){ai_mul_bi[bitwof_ai_mul_bi-1]}}, ai_mul_bi};
         assign rinc = {{(bitwof_resbfrcut-bitwof_ar_mul_bi){ar_mul_bi[bitwof_ar_mul_bi-1]}}, ar_mul_bi} + {{(bitwof_resbfrcut-bitwof_ai_mul_br){ai_mul_br[bitwof_ai_mul_br-1]}}, ai_mul_br};
      end else begin
         assign rrnc = ar_mul_br - ai_mul_bi;
         assign rinc = ar_mul_bi + ai_mul_br;
      end
   end
   wire signed[partbitw_r_2p-1:0]rrc, ric;
   if (RES_PARTBITW > 0) begin: ALIGN_MSB
      assign rrc = rrnc[bitwof_resbfrcut-1-:partbitw_r_2p];
      assign ric = rinc[bitwof_resbfrcut-1-:partbitw_r_2p];
   end else begin: ALIGN_LSB
      assign rrc = rrnc[partbitw_r_2p-1:0];
      assign ric = rinc[partbitw_r_2p-1:0];
   end
   wire signed[partbitw_r_2p-1:0]rrp, rip;
   pipedelay_taps #(
      .DATABITW(partbitw_r_2p*2+1), .DELAYTAPS(miscs::delaytaps4stage(.stagecnt(total_stages),.istage(istg_postadd),.totaltaps(DELAYTAPS),.top_first(1'b0)))
   ) post_add_delay(
      .clk(clk),  .aclr(aclr),.sclr(sclr),.clken(clken),.x({rnc_valid, ric, rrc}), .pipe_x({res_valid, rip, rrp})
   );
   if (RES_PARTBITW > 0) begin
      assign res[0][res_bitw-1:res_bitw-partbitw_r_2p] = rrp;
      if (partbitw_r_2p < res_bitw) assign res[0][res_bitw-partbitw_r_2p-1:0] = '0;
      assign res[1][res_bitw-1:res_bitw-partbitw_r_2p] = rip;
      if (partbitw_r_2p < res_bitw) assign res[1][res_bitw-partbitw_r_2p-1:0] = '0;
   end else begin
      assign res[0][partbitw_r_2p-1:0] = rrp;
      if (partbitw_r_2p < res_bitw) assign res[0][res_bitw-1:partbitw_r_2p] = {(res_bitw-partbitw_r_2p){rrp[partbitw_r_2p-1]}};
      assign res[1][partbitw_r_2p-1:0] = rip;
      if (partbitw_r_2p < res_bitw) assign res[1][res_bitw-1:partbitw_r_2p] = {(res_bitw-partbitw_r_2p){rip[partbitw_r_2p-1]}};
   end
   endgenerate
endmodule

