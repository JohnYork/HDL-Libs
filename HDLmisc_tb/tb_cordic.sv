`timescale 1ps/1ps
`include "cordic.svh"
module tb_cordic;
   // import cordic_pkg::*;
   import __lcordic_pkg::*;
   import miscs::*;
   /*!
    * \brief 根据输入二维矢量分量的有效位宽（不包含符号位）计算推荐的转换结果角度值的小数位宽最大值
    * \details 推荐的最大转换结果角度值小数位宽所表示的角度值可以保证对任意输入二维矢量的分量值的最小变化量产生反应
    * \param vp_bitw 输入二维矢量分量的有效位宽（不包含符号位）
    * \return int型，推荐的转换结果角度值的小数位宽最大值
    */
// function automatic int recommend_maxfracbits_of_angle_frm_vecpartbitw(int vp_bitw);
//    longint min_angle;
//    min_angle = q61atan2i2q(64'd2**vp_bitw-1, 1) - q61atan2i2q(64'd2**vp_bitw-2, 1);
//    return 61 - bits_of_longint(min_angle, 63) + 1;
// endfunction
   function automatic int recommend_angle_fracbits_byvecpartbitw(longint angle_qscale, int angle_qscfbits, int vp_bitw);
      longint min_angle;
      miscs::sfpt sfp_min_angle;
      // 计算位宽为 #vp_bitw 的矢量可表示的最小角度弧度值
      min_angle = miscs::q61atan2i2q(1, (longint'(2))**(vp_bitw-1+1)-1);
      // 最小角度弧度值转换为 #miscs::sfpt 型的半周值
      sfp_min_angle = miscs::sfp_div(miscs::sfp_makesfp_byqp(min_angle, 61), miscs::sfp_pi);
      // 乘以角度量化值
      sfp_min_angle = miscs::sfp_mul(sfp_min_angle, miscs::sfp_makesfp_byqp(angle_qscale, angle_qscfbits));
      /* 1 < sfp_min_angle.mnts <= 0.5 ， sfp_min_angle.expn 表示的最小角度是 0.5*2^sfp_min_angle.expn ，
       * 要保留的小数位数保证能表示最小的角度 0.5*2^sfp_min_angle.expn ，则正好取小数位数为 -sfp_min_angle.expn 即可。
       */
      return -sfp_min_angle.expn;
   endfunction
   function automatic int recommend_vecpartbitw_by_anglefracbits(longint angle_qscale, int angle_qfbits, int angle_fracbits);
      miscs::sfpt sfp_angle, sfp_max_vecpart;
      // 最小角度值转换为单位为弧度的角度值
      sfp_angle = miscs::sfp_div(miscs::sfp_makesfp_byqp(1, angle_fracbits), miscs::sfp_makesfp_byqp(angle_qscale, angle_qfbits));
      sfp_angle = miscs::sfp_mul(sfp_angle, miscs::sfp_pi);
      // x/y = cotan(sfp_angle), y 取1，则x便是矢量分类最大值
      sfp_max_vecpart = miscs::sfp_div(miscs::sfp_cos(sfp_angle), miscs::sfp_sin(sfp_angle));
      return sfp_max_vecpart.expn;
   endfunction
   function automatic int recommend_iterating_times_of_rotation(longint angle_qscale, int angle_qfbits, int angle_fracbits);
      longint atan_res, ress;
      miscs::sfpt min_angle;
      int i, shftbits;
      // 求 miscs::sfpt 型的最小角度值对应的弧度值
      min_angle = miscs::sfp_makesfp_byqp(1, angle_fracbits);
      min_angle = miscs::sfp_div(min_angle, miscs::sfp_makesfp_byqp(angle_qscale, angle_qfbits));
      min_angle = miscs::sfp_mul(min_angle, miscs::sfp_pi);
      // Q.61型弧度值的右移位数
      shftbits = 61 + min_angle.expn;
      i = -1;
      do begin
         i = i + 1;
         atan_res = miscs::q61atan2i2q(1, (longint'(2))**i);
         ress = (atan_res>>shftbits) + ((atan_res>>(shftbits - 1))&1);
      end while(ress > 0);
      return i;
   endfunction
   function automatic int recommend_iterating_times_driven_byangle(longint angle_qscale, int angle_qfbits, int angle_fracbits);
      longint atan_res, ress;
      miscs::sfpt min_angle, tan_min_angle;
      int i, shftbits;
      // 求 miscs::sfpt 型的最小角度值对应的弧度值
      min_angle = miscs::sfp_makesfp_byqp(1, angle_fracbits);
      min_angle = miscs::sfp_div(min_angle, miscs::sfp_makesfp_byqp(angle_qscale, angle_qfbits));
      min_angle = miscs::sfp_mul(min_angle, miscs::sfp_pi);
      /* 查找最小角度对应的最大迭代次数——超过该迭代次数的迭代运算使得迭代的角度增量为零
       * 令最大迭代次数为 i ，则应有 atan(1/2^i) < min_angle
       * 即 1/2^i < tan(min_angle) ,
       *    2^i > cotan(min_angle) = cos(min_angle)/sin(min_angle)
       */
      tan_min_angle = miscs::sfp_div(miscs::sfp_cos(min_angle), miscs::sfp_sin(min_angle));
      
      return tan_min_angle.expn;
   endfunction
   function automatic longint signed q61rad2scale(longint signed rad, longint angle_qscale, int angle_qfbits, int angle_fracbits);
      miscs::sfpt sfp_angle;
      int signed rshbits;
      sfp_angle = miscs::sfp_div(miscs::sfp_makesfp_byqp(rad, 61), miscs::sfp_pi);
      sfp_angle = miscs::sfp_mul(sfp_angle, miscs::sfp_makesfp_byqp(angle_qscale, angle_qfbits));
      rshbits = 61 - angle_fracbits - sfp_angle.expn;
      if (rshbits >= 0) return (sfp_angle.mnts>>>rshbits);
      else              return (sfp_angle.mnts<<<rshbits);
   endfunction
   initial begin
      automatic longint test, res, cntr, res2;
      automatic longint tt;
      // for (tt = 1; tt < 63; tt++) begin
      //    $display("miscs::q61atan2i2q(1, 2**%0d-1) = %0d", tt, miscs::q61atan2i2q(1, 64'd2**tt-1));
      // end
      // test = 10;
      // tt = 2**62;
      // res = isqrt(tt + 16*16);
      // $display("isqrt(%0d) = %0d", tt, res);
      // res = factorial_secant(100, 30);
      // $display("factorial_secant(100, 30) = %0d", res);
      // res = factorial_cosine(100, 30);
      // $display("factorial_cosine(100, 30) = %0d", res);
      // test = 8;
      // res = recommend_iterating_times_of_rotation(test);
      // $display("recommend_iterating_times_of_rotation(%0d) = %0d", test, res);
      test = 32;
      res = recommend_angle_fracbits_byvecpartbitw(miscs::q61_pi, 61, test);
      $display("recommend_angle_fracbits_byvecpartbitw(..., %0d) = %0d", test, res);
      test = 32;
      res = recommend_vecpartbitw_by_anglefracbits(miscs::q61_pi, 61, test);
      $display("recommend_vecpartbitw_by_anglefracbits(..., %0d) = %0d", test, res);
      test = 32;
      res = recommend_iterating_times_of_rotation(miscs::q61_pi, 61, test);
      $display("recommend_iterating_times_of_rotation(..., %0d) = %0d", test, res);
      res = recommend_iterating_times_driven_byangle(miscs::q61_pi, 61, test);
      $display("recommend_iterating_times_driven_byangle(..., %0d) = %0d", test, res);
      test = miscs::q61_pi;
      res = q61rad2scale(test, miscs::q61_pi, 61, 61);
      $display("q61rad2scale(%0d, miscs::q61_pi, 61, 61) = %0d", test, res);
      res = q61rad2scale(test, 180, 0, 1);
      $display("q61rad2scale(%0d, 180, 0, 1) = %0d", test, res);
      // res = recommend_vecpartbitw_by_anglefracbits(test);
      // $display("recommend_vecpartbitw_by_anglefracbits(%0d) = %0d", test, res);
      // test = 32;
      // res = q61atan2i2q((64'd2)**test-1, 1);
      // $display("q61atan2i2q(2**%0d-1, 1) = %0d", test, res);
      // res2 = q61atan2i2q((64'd2)**test-2, 1);
      // $display("q61atan2i2q(2**%0d-2, 1) = %0d", test, res2);
      // res = q61atan2i2q(1, (64'd2)**test-1);
      // $display("q61atan2i2q(1, 2**%0d-1) = %0d", test, res);
      // res = recommend_angle_fracbits_byvecpartbitw(test);
      // $display("recommend_angle_fracbits_byvecpartbitw(%0d) = %0d", test, res);
      // test = res;
      // res = recommend_iterating_times_of_rotation(test);
      // $display("recommend_iterating_times_of_rotation(%0d) = %0d", test, res);
   end

   reg clk;
   initial begin
      clk = 0;
   end
   always # 1 clk = ~clk;
   reg mdl_rst, sclr, test_sig;
   initial begin
      mdl_rst = 0;
      test_sig = 0;
      # 1 mdl_rst = 1;
      # 4 mdl_rst = 0;
      # 10 test_sig = 1;
   end
   always_ff @(posedge clk) sclr <= mdl_rst;

   localparam int vp_bitw = 31;
   localparam longint angle_qscale = miscs::q61_pi;//1800;//miscs::q61_pi
   localparam int angle_qfbits = 61;//0;//61
   localparam int angl_fracbits = cordic_pkg::recommend_angle_fracbits_byvecpartbitw(cordic_pkg::cdcrs_circular, angle_qscale, angle_qfbits, vp_bitw);
   localparam int angle_bitw = cordic_pkg::bitwof_angle_frm_fracbits(angle_qscale, angle_qfbits, angl_fracbits);
   reg[vp_bitw-1:0]xi2u,yi2u;
   reg[angle_bitw-1:0]zi2u;
   localparam int hangl_fracbits = cordic_pkg::recommend_angle_fracbits_byvecpartbitw(cordic_pkg::cdcrs_hyperbolic, (64'sd1<<61), 61, vp_bitw);
   localparam int hangle_bitw = cordic_pkg::bitwof_angle_frm_fracbits((64'sd1<<61), 61, hangl_fracbits);
   reg[hangle_bitw-1:0]hzi2u;
   initial begin
      xi2u = 0; yi2u = 0; zi2u = 0;
      # 5
      xi2u = (vp_bitw)'('h635);
      yi2u = (vp_bitw)'('h635);
      zi2u = (angle_bitw)'((q61_pi/4)>>>(61-angl_fracbits));    // pi/4 , 45 °
      hzi2u = (hangle_bitw)'(((64'sd1<<<61)/4)>>>(61-hangl_fracbits));// 1/4
      # 2
      zi2u = (angle_bitw)'((q61_pi/2)>>>(61-angl_fracbits));    // pi/2
      hzi2u = (hangle_bitw)'(((64'sd1<<<61)/2)>>>(61-hangl_fracbits));// 1/2
      # 2
      zi2u = (angle_bitw)'((q61_pi/3)>>>(61-angl_fracbits));    // pi/3
      hzi2u = (hangle_bitw)'(((64'sd1<<<61)/3)>>>(61-hangl_fracbits));// 1/3
      # 2
      zi2u = (angle_bitw)'((q61_pi/3)>>>(61-angl_fracbits-1));  //2*pi/3
      hzi2u = (hangle_bitw)'(((64'sd1<<<62)/3)>>>(61-hangl_fracbits));// 2/3
      # 2
      zi2u = (angle_bitw)'((-q61_pi/4)>>>(61-angl_fracbits));    // -pi/4
      hzi2u = (hangle_bitw)'(((-64'sd1<<<61)/4)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/2)>>>(61-angl_fracbits));    // -pi/2
      hzi2u = (hangle_bitw)'(((-64'sd1<<<61)/2)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/3)>>>(61-angl_fracbits));    // -pi/3
      hzi2u = (hangle_bitw)'(((-64'sd1<<<61)/3)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/3)>>>(61-angl_fracbits-1));  //-2*pi/3
      hzi2u = (hangle_bitw)'(((-64'sd1<<<62)/3)>>>(61-hangl_fracbits));
      # 2
      xi2u = (vp_bitw)'('h634);
      yi2u = (vp_bitw)'('h635);
      zi2u = (angle_bitw)'((q61_pi/4)>>>(61-angl_fracbits));    // pi/4
      hzi2u = (hangle_bitw)'(((64'sd1<<<61)/4)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((q61_pi/2)>>>(61-angl_fracbits));    // pi/2
      hzi2u = (hangle_bitw)'(((64'sd1<<<61)/2)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((q61_pi/3)>>>(61-angl_fracbits));    // pi/3
      hzi2u = (hangle_bitw)'(((64'sd1<<<61)/3)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((q61_pi/3)>>>(61-angl_fracbits-1));  //2*pi/3
      hzi2u = (hangle_bitw)'(((64'sd1<<<62)/3)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/4)>>>(61-angl_fracbits));    // -pi/4
      hzi2u = (hangle_bitw)'(((-64'sd1<<<61)/4)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/2)>>>(61-angl_fracbits));    // -pi/2
      hzi2u = (hangle_bitw)'(((-64'sd1<<<61)/2)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/3)>>>(61-angl_fracbits));    // -pi/3
      hzi2u = (hangle_bitw)'(((-64'sd1<<<61)/3)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/3)>>>(61-angl_fracbits-1));  //-2*pi/3
      hzi2u = (hangle_bitw)'(((-64'sd1<<<62)/3)>>>(61-hangl_fracbits));
      # 2
      xi2u = (vp_bitw)'('h636);
      yi2u = (vp_bitw)'('h635);
      zi2u = (angle_bitw)'((q61_pi/4)>>>(61-angl_fracbits));    // pi/4
      hzi2u = (hangle_bitw)'(((64'sd1<<<61)/4)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((q61_pi/2)>>>(61-angl_fracbits));    // pi/2
      hzi2u = (hangle_bitw)'(((64'sd1<<<61)/2)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((q61_pi/3)>>>(61-angl_fracbits));    // pi/3
      hzi2u = (hangle_bitw)'(((64'sd1<<<61)/3)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((q61_pi/3)>>>(61-angl_fracbits-1));  //2*pi/3)
      hzi2u = (hangle_bitw)'(((64'sd1<<<62)/3)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/4)>>>(61-angl_fracbits));    // -pi/4
      hzi2u = (hangle_bitw)'(((-64'sd1<<<61)/4)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/2)>>>(61-angl_fracbits));    // -pi/2
      hzi2u = (hangle_bitw)'(((-64'sd1<<<61)/2)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/3)>>>(61-angl_fracbits));    // -pi/3
      hzi2u = (hangle_bitw)'(((-64'sd1<<<61)/3)>>>(61-hangl_fracbits));
      # 2
      zi2u = (angle_bitw)'((-q61_pi/3)>>>(61-angl_fracbits-1));  //-2*pi/3
      hzi2u = (hangle_bitw)'(((-64'sd1<<<62)/3)>>>(61-hangl_fracbits));
      # 2
      xi2u = (vp_bitw)'('h635);  yi2u = (vp_bitw)'('h635);
      # 2
      xi2u = (vp_bitw)'(-'h635);  yi2u = (vp_bitw)'('h635);
      # 2
      xi2u = (vp_bitw)'('h635);  yi2u = (vp_bitw)'(-'h635);
      # 2
      xi2u = (vp_bitw)'(-'h635);  yi2u = (vp_bitw)'(-'h635);
      # 2
      xi2u = (vp_bitw)'('h634);  yi2u = (vp_bitw)'('h635);
      # 2
      xi2u = (vp_bitw)'(-'h634);  yi2u = (vp_bitw)'('h635);
      # 2
      xi2u = (vp_bitw)'('h634);  yi2u = (vp_bitw)'(-'h635);
      # 2
      xi2u = (vp_bitw)'(-'h634);  yi2u = (vp_bitw)'(-'h635);
      # 2
      xi2u = (vp_bitw)'('h636);  yi2u = (vp_bitw)'('h635);
      # 2
      xi2u = (vp_bitw)'(-'h636);  yi2u = (vp_bitw)'('h635);
      # 2
      xi2u = (vp_bitw)'('h636);  yi2u = (vp_bitw)'(-'h635);
      # 2
      xi2u = (vp_bitw)'(-'h636);  yi2u = (vp_bitw)'(-'h635);
      # 2
      xi2u = (vp_bitw)'('h635);  yi2u = (vp_bitw)'('h635<<<1);
      # 2
      xi2u = (vp_bitw)'('h635<<<1);  yi2u = (vp_bitw)'('h635);
      # 2
      xi2u = (vp_bitw)'('d1944); yi2u = (vp_bitw)'('d40);
   end
   genvar i; generate
   localparam int chnlcnt = 2;
   reg[chnlcnt-1:0][vp_bitw-0:0]xii, yii;
   reg[chnlcnt-1:0][angle_bitw-1:0]zii;
   always_ff @(posedge clk) xii[0] <= xi2u;
   always_ff @(posedge clk) yii[0] <= yi2u;
   always_ff @(posedge clk) zii[0] <= zi2u;
   for (i = chnlcnt-1; i > 0; i--) begin
      always_ff @(posedge clk) xii[i] <= (xii[i-1]<<<1);
      always_ff @(posedge clk) yii[i] <= (yii[i-1]<<<1);
      always_ff @(posedge clk) zii[i] <= (zii[i-1]<<<1);
   end
   endgenerate
   reg[6:0][20:0] tx, ty, txi, tyi;
   initial begin
      tx = 0;
      ty = 0;
      # 7
         tx[0] = 272896; ty[0] = 273408;
         tx[1] = 386560; ty[1] = 383488;
         tx[2] = 21'h7FFFF; ty[2] = 21'h7FFFF;
         tx[3] = 274944; ty[3] = 273820;
         tx[4] = 280192; ty[4] = 280960;
         tx[5] = 386560; ty[5] = 383488;
         tx[6] = 480512; ty[6] = 480512;
   end
   always_ff @(posedge clk) txi <= tx;
   always_ff @(posedge clk) tyi <= ty;
   cordic #(
      .IVP_BITW(20),
      .IANGLE_BITW(23),
      .OVP_BITW(20),
      .OANGLE_BITW(23),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .ANGLE_QSCALE(1800),
      .ANGLE_QFBITS(0),
      .ANGLE_EINTBITS(0),
      .CHNLCNT(7),
      .ITERAT_COUNT(20),
      .FIXED_DRVMOD(0),
      .DRVBYCHNL0(1'b0),
      .HRDCOR_MC(1'b1)
   ) tvec0(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr(sclr),
      .clken(1'b1),
      .xi(txi),
      .yi(tyi),
      .zi('0),
      .drvmod(cordic_pkg::cdcdm_vec),
      .xo(),
      .yo(),
      .zo()
   );
   cordic_g #(
      .IVP_BITW(20),
      .IANGLE_BITW(23),
      .OVP_BITW(20),
      .OANGLE_BITW(23),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .ANGLE_QSCALE(1800),
      .ANGLE_QFBITS(0),
      .ANGLE_EINTBITS(0),
      .CHNLCNT(7),
      .ITERAT_COUNT(20),
      .FIXED_DRVMOD(0),
      .DRVBYCHNL0(1'b0),
      .HRDCOR_MC(1'b1)
   ) tvecg(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr(sclr),
      .clken(1'b1),
      .xi(txi),
      .yi(tyi),
      .zi('0),
      .drvmod(cordic_pkg::cdcdm_vec),
      .xo(),
      .yo(),
      .zo()
   );
   localparam int ovpbw = 8;
   localparam int lshbsbw = cordic_pkg::magnorm_recommend_bitwof_lshbsbw(vp_bitw);
   initial $display("cdc_magnorm: delaytaps = %0d", cordic_pkg::magnorm_delaytaps(cordic_pkg::cdcrs_circular,vp_bitw));
   wire[chnlcnt-1:0][ovpbw-0:0]xni, yni;
   wire[chnlcnt-1:0][lshbsbw-1:0]lshbs;
   cdc_magnorm #(
      .IVP_BITW(vp_bitw                   ),
      .OVP_BITW(ovpbw                     ),
      .CPLXVEC (1'b1                      ),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .LSHBSBW (lshbsbw                   ),
      .CHNLCNT (chnlcnt                   )
   ) cdcmni(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr(sclr),
      .clken(1'b1),
      .xi({yii, xii}),
      .xo({yni, xni}),
      .lshbs(lshbs)
   );
   initial $display("cdc_magnorm_restr: delaytaps = %0d", cordic_pkg::magnorm_restr_delaytaps(cordic_pkg::cdcrs_circular,vp_bitw));
   cdc_magnorm_restr #(
      .IVP_BITW(ovpbw                     ),
      .OVP_BITW(vp_bitw                   ),
      .CPLXVEC (1'b1                      ),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .LSHBSBW (lshbsbw                   ),
      .PIPLSHBS(1'b1                      ),
      .CHNLCNT (chnlcnt                   )
   ) cdcmnri(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr(sclr),
      .clken(1'b1),
      .xi({yii, xii}),
      .lshbs(lshbs),
      .xo(),
      .lshbso()
   );
   cordic #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(angle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(angle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .ANGLE_QSCALE(miscs::q61_pi),
      .ANGLE_QFBITS(61),
      .CHNLCNT(chnlcnt),
      .ITERAT_COUNT(0),
      .DRVBYCHNL0(1'b0),
      .HRDCOR_MC(1'b1)
   ) ca0(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .xi(xii),.yi(yii),.zi({(chnlcnt){{(angle_bitw){1'b0}}}}),.drvmod(cordic_pkg::cdcdm_ang),.xo(),.yo(),.zo()
   );
   cordic #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(angle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(angle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .ANGLE_QSCALE(miscs::q61_pi),
      .ANGLE_QFBITS(61),
      .CHNLCNT(chnlcnt),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) ca(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .xi(xii),.yi(yii),.zi(zii),.drvmod(cordic_pkg::cdcdm_ang),.xo(),.yo(),.zo()
   );
   cordic_g #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(angle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(angle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .ANGLE_QSCALE(miscs::q61_pi),
      .ANGLE_QFBITS(61),
      .CHNLCNT(chnlcnt),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) ca2(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      // .xi(xii[1]),.yi(yii[1]),.zi(zii[1]),.drvmod(cordic_pkg::cdcdm_ang),.xo(),.yo(),.zo()
      .xi(xii),.yi(yii),.zi(zii),.drvmod(cordic_pkg::cdcdm_ang),.xo(),.yo(),.zo()
   );
   wire[chnlcnt-1:0][angle_bitw-1:0]cv_ango, cv2_ango;
   logic[chnlcnt-1:0][11:0]cv_angdeg, cv2_angdeg;
   always_comb foreach(cv_angdeg[i,]) cv_angdeg[i] = cv_ango[i][angle_bitw-1:angle_bitw-12];
   always_comb foreach(cv2_angdeg[i,]) cv2_angdeg[i] = cv2_ango[i][angle_bitw-1:angle_bitw-12];
   cordic #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(angle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(angle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .ANGLE_QSCALE(1800),
      .ANGLE_QFBITS(0),
      .CHNLCNT(chnlcnt),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cv(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .xi(xii),.yi(yii),.zi('0), .drvmod(cordic_pkg::cdcdm_vec),.xo(),.yo(),.zo(cv_ango)
   );
   cordic_g #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(angle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(angle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .ANGLE_QSCALE(1800),
      .ANGLE_QFBITS(0),
      .CHNLCNT(chnlcnt),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cv2(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .xi(xii),.yi(yii),.zi('0), .drvmod(cordic_pkg::cdcdm_vec),.xo(),.yo(),.zo(cv2_ango)
   );
   reg signed[vp_bitw-1:0] sc_xi;
   always_ff @(posedge clk) sc_xi <= 2**(vp_bitw-1)-1;
   reg signed[angle_bitw-1:0] sc_zi;
   localparam longint angle_inc = 64'd300<<23;//angle_bitw < 12 ? 1 : (64'd1<<(angle_bitw - 12));
   always_ff @(posedge clk) begin
      if (mdl_rst|sclr)sc_zi <= '0;
      else        sc_zi <= sc_zi < (64'd14400<<23) ? sc_zi + angle_inc : -14400;//(sc_zi < (q61_pi>>(61-angl_fracbits))) ? sc_zi + (angle_bitw)'(angle_inc) : -(q61_pi>>(61-angl_fracbits));
   end
   cordic #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(angle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(angle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .ANGLE_QSCALE(/*miscs::q61_pi*/1800),
      .ANGLE_QFBITS(/*61*/0),
      .CHNLCNT    (1),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cc_sincos2(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr(sclr),
      .clken(1'b1),
      .xi({sc_xi[vp_bitw-1], sc_xi}),
      .yi('0),
      .drvmod(cordic_pkg::cdcdm_ang),
      .zi(sc_zi),
      .xo(),
      .yo(),
      .zo()
   );
   cordic #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(angle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(angle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .ANGLE_QSCALE(/*miscs::q61_pi*/1800),
      .ANGLE_QFBITS(/*61*/0),
      .CHNLCNT    (1),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cc_sincos21(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr(sclr),
      .clken(1'b1),
      .xi({sc_xi[vp_bitw-1], sc_xi}),
      .yi('0),
      .drvmod(cordic_pkg::cdcdm_ang),
      .zi('0),
      .xo(),
      .yo(),
      .zo()
   );
   cordic_g #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(angle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(angle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_circular),
      .ANGLE_QSCALE(/*miscs::q61_pi*/1800),
      .ANGLE_QFBITS(/*61*/0),
      .CHNLCNT    (1),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cc_sincos22(
      .clk(clk),
      .aclr(mdl_rst),
      .sclr(sclr),
      .clken(1'b1),
      .xi({sc_xi[vp_bitw-1], sc_xi}),
      .yi('0),
      .drvmod(cordic_pkg::cdcdm_ang),
      .zi(sc_zi),
      .xo(),
      .yo(),
      .zo()
   );
   cordic #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(vp_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(vp_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_linear),
      .ANGLE_QSCALE(64'sd1<<(vp_bitw-1)),
      .ANGLE_QFBITS(vp_bitw-1),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cc_muladd(
      .clk(clk),  .aclr(mdl_rst),.sclr(1'b0),.clken(1'b1),
      .xi(xii[0]),   .yi(yii[0]),      .zi(zii[0][angle_bitw-1-:vp_bitw]), .drvmod(cordic_pkg::cdcdm_ang), .xo(),.yo(),.zo()
   );
   cordic_g #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(vp_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(vp_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_linear),
      .ANGLE_QSCALE(64'sd1<<(vp_bitw-1)),
      .ANGLE_QFBITS(vp_bitw-1),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cc_muladd2(
      .clk(clk),  .aclr(mdl_rst),.sclr(1'b0),.clken(1'b1),
      .xi(xii[0]),   .yi(yii[0]),      .zi(zii[0][angle_bitw-1-:vp_bitw]), .drvmod(cordic_pkg::cdcdm_ang), .xo(),.yo(),.zo()
   );
   localparam int vp_fracbits = cordic_pkg::fracbits_of_vecpart_bitw(.vp_bitw(vp_bitw));
   cordic #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(vp_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(vp_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_linear),
      .ANGLE_QSCALE(64'sd1<<<vp_fracbits),
      .ANGLE_QFBITS(vp_fracbits),
      .ANGLE_EINTBITS(vp_bitw-1),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cc_divadd(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .xi(xii[0]),   .yi(yii[0]),      .zi('0/*zii[angle_bitw-1-:vp_bitw]*/), .drvmod(cordic_pkg::cdcdm_vec),.xo(),.yo(),.zo()
   );
   cordic_g #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(vp_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(vp_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_linear),
      .ANGLE_QSCALE(64'sd1<<<vp_fracbits),
      .ANGLE_QFBITS(vp_fracbits),
      .ANGLE_EINTBITS(vp_bitw-1),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cc_divadd2(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .xi(xii[0]),   .yi(yii[0]),      .zi('0/*zii[angle_bitw-1-:vp_bitw]*/), .drvmod(cordic_pkg::cdcdm_vec),.xo(),.yo(),.zo()
   );
   reg[hangle_bitw-1:0]hzii;
   always_ff @(posedge clk) hzii <= hzi2u;
   cordic #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(hangle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(hangle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_hyperbolic),
      .ANGLE_QSCALE(64'sd1<<hangl_fracbits),
      .ANGLE_QFBITS(hangl_fracbits),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cah(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .xi({xii[0][vp_bitw-1], xii[0]}),.yi({yii[0][vp_bitw-1], yii[0]}),
      .zi(hzii),  .drvmod(cordic_pkg::cdcdm_ang),
      .xo(),.yo(),.zo()
   );
   cordic_g #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(hangle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(hangle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_hyperbolic),
      .ANGLE_QSCALE(64'sd1<<hangl_fracbits),
      .ANGLE_QFBITS(hangl_fracbits),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cah2(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .xi({xii[0][vp_bitw-1], xii[0]}),.yi({yii[0][vp_bitw-1], yii[0]}),
      .zi(hzii),  .drvmod(cordic_pkg::cdcdm_ang),
      .xo(),.yo(),.zo()
   );
   reg[vp_bitw-0:0]hxiu, hyiu, hziu, hxi, hyi, hzi;
   initial begin
      hxiu = 0; hyiu = 0; hziu = 0;
      # 5
      hxiu = (vp_bitw)'('h633);
      hyiu = (vp_bitw)'('h635);
      hziu = (hangle_bitw)'(((64'sd1<<<61)/4)>>>(61-hangl_fracbits));
      # 5
      hxiu = (vp_bitw)'('h634);
      hyiu = (vp_bitw)'('h635);
   end
   always @(clk) hxi <= hxiu;
   always @(clk) hyi <= hyiu;
   always @(clk) hzi <= hziu;
   
   cordic #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(hangle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(hangle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_hyperbolic),
      .ANGLE_QSCALE(64'sd1<<hangl_fracbits),
      .ANGLE_QFBITS(hangl_fracbits),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cvh(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .xi({hxi[vp_bitw-1], hxi}),.yi({hyi[vp_bitw-1], hyi}),
      .zi(/*hzii*/'0),  .drvmod(cordic_pkg::cdcdm_vec),
      .xo(),.yo(),.zo()
   );
   cordic_g #(
      .IVP_BITW(vp_bitw),
      .IANGLE_BITW(hangle_bitw),
      .OVP_BITW(vp_bitw),
      .OANGLE_BITW(hangle_bitw),
      .ROTATSYS(cordic_pkg::cdcrs_hyperbolic),
      .ANGLE_QSCALE(64'sd1<<hangl_fracbits),
      .ANGLE_QFBITS(hangl_fracbits),
      .ITERAT_COUNT(0),
      .HRDCOR_MC(1'b1)
   ) cvh2(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .xi({hxi[vp_bitw-1], hxi}),.yi({hyi[vp_bitw-1], hyi}),
      .zi(/*hzii*/'0),  .drvmod(cordic_pkg::cdcdm_vec),
      .xo(),.yo(),.zo()
   );
   logic[1:0][11:0] angi, angi2o, angrf, angrf2o;
   initial begin
      angi = 0;
      angrf = 0;
      # 5
         angi[0] = -379;
         angrf[0] = 378;
         angi[1] = 1757;
         angrf[1] = 649;
      # 10
         angi[0] = -225;
         angrf[0] = 378;
         angi[1] = -1766;
         angrf[1] = 649;
      # 10
         angrf[0] = 0;
         angrf[1] = 0;
         angi[0] = 1797;
         angi[1] = 1795;
      # 10
         angi[0] = -999;
         angi[1] = -998;
   end
   always_ff @(posedge clk) angi2o <= angi;
   always_ff @(posedge clk) angrf2o <= angrf;
   cdc_phscyclmod_byref #(
      .ANGBITW    (12   ),
      .ANGEIBW    (0    ),
      .PHSQSCALE  (1800 ),
      .PHSQFBITS  (0    ),
      .RFSBWEQIN  (1'b1 ),
      .CHNLCNT    (2    ),
      .DELAYTAPS  (1    )
   ) cpcbri(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .angi(angi2o),
      .angrf(angrf2o),
      .ango()
   );
   logic[2:0][11:0] cpfcm_angi, cpfcm_angi2o;
   initial begin
      cpfcm_angi = 0;
      # 5
         cpfcm_angi[0] = 100;
         cpfcm_angi[1] = 1493;
         cpfcm_angi[2] = 1434;
   end
   always_ff @(posedge clk) cpfcm_angi2o <= cpfcm_angi;
   cdc_phsfix_cyclmod #(
      .ANGBITW    (12   ),
      .ANGEIBW    (0    ),
      .PHSQSCALE  (1800 ),
      .PHSQFBITS  (0    ),
      .ADDSUBSEL  (0    ),
      .FXASLOP    (1'b0 ),
      .CHNLCNT    (6    ),
      .DELAYTAPS  (1    )
   ) cpfcmi(
      .clk(clk),  .aclr(mdl_rst),.sclr(sclr),.clken(1'b1),
      .angi({cpfcm_angi2o, cpfcm_angi2o}),
      .angfx('0),
      .ango()
   );
endmodule
