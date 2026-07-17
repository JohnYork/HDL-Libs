/*!
 * \license SPDX-License-Identifier: MIT
 * \file cordic.sv
 * \brief CORDIC算法实现
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, pipedelay, multconst
 */
`include "miscs.svh"
`define __INC_FROM_CORDIC__
`include "cordic.svh"
package __lcordic_pkg;
   /*!
    * \brief 迭代过程中的正割值阶乘结果
    * \param it_times 迭代次数
    * \param mag_bitw 幅度位宽
    * \return longint unsigned型，小数位数为 mag_bitw 的定点数值，有效位数为 mag_bitw+1
    */
   function automatic longint unsigned factorial_secant(int it_times, int mag_bitw);
      // tan(theta) = 2^-i
      // sec(theta) = sqrt(1 + tan(theta)^2)
      longint unsigned tan_theta, sqrt_1_add_sqr_tan, fac_sec, res;
      int unsigned i;
      tan_theta = (longint'(2))**61; fac_sec = (longint'(2))**61;
      for (i = 0; i < it_times; i++) begin
         sqrt_1_add_sqr_tan = miscs::q61sqrt2(((longint'(2))**61), tan_theta, 1'b0);
         fac_sec = miscs::q61mult(fac_sec, sqrt_1_add_sqr_tan);
         tan_theta = tan_theta/2;
      end
      res = longint'(fac_sec);
      if (mag_bitw>=61) return (res<<(mag_bitw-61));
      else              return (res>>(61-mag_bitw))+((res>>(61-mag_bitw-1))&1);
   endfunction
   /*!
    * \brief 迭代过程中的余弦值阶乘结果
    * \param it_times 迭代次数
    * \param mag_bitw 幅度位宽，不包含符号位
    * \return longint unsigned型，小数位数为 mag_bitw 的定点数值，有效位数为 mag_bitw+1
    */
   function automatic longint unsigned factorial_cosine(int it_times, int mag_bitw);
      // tan(theta) = 2^-i
      // sec(theta) = sqrt(1 + tan(theta)^2)
      // cos(theta) = rsqrt(1 + tan(theta)^2)
      longint unsigned tan_theta, sqrt_1_add_sqr_tan, fac_sec, res;
      int unsigned i;
      tan_theta = (longint'(2))**61; fac_sec = (longint'(2))**61;
      for (i = 0; i < it_times; i++) begin
         sqrt_1_add_sqr_tan = miscs::q61rsqrt2(((longint'(2))**61), tan_theta, 1'b0);
         fac_sec = miscs::q61mult(fac_sec, sqrt_1_add_sqr_tan);
         tan_theta = tan_theta/2;
      end
      res = fac_sec;
      if (mag_bitw>=61) return (res<<(mag_bitw-61));
      else              return (res>>(61-mag_bitw))+((res>>(61-mag_bitw-1))&1);
   endfunction
   /*!
    * \brief 迭代过程中的双曲正割值阶乘结果
    * \param it_times 迭代次数
    * \param mag_bitw 幅度位宽
    * \return longint unsigned型，小数位数为 mag_bitw 的定点数值，有效位数为 mag_bitw+1
    */
   function automatic longint unsigned factorial_hyperbolic_secant(int it_times, int mag_bitw);
      /* ——知乎网站——硬件算法笔记22——CORDIC算法——双曲CORDIC
       * 双曲旋转中，伪旋转“角度”定义为与双曲扇形面积相关的量；向量长度定义为 R = sqrt(x^2 - y^2)；
       * 伪旋转在每次迭代中引入的偏差系数为 sqrt(1-tanh(a[i])^2) = 1/cosh(a[i])
       */
      // tanh(theta) = 2^-i
      // sech(theta) = sqrt(1 - tanh(theta)^2)
      longint unsigned tanh_theta, sqrt_1_sub_sqr_tanh, fac_sech, res;
      int unsigned i, j;
      tanh_theta = (longint'(2))**(61-1/*双曲坐标旋转的迭代索引从1开始*/); fac_sech = (longint'(2))**61; j = 4;
      for (i = 1; i < it_times; i++) begin
         sqrt_1_sub_sqr_tanh = miscs::q61sqrt2(((longint'(2))**61), tanh_theta, 1'b1);
         fac_sech = miscs::q61mult(fac_sech, sqrt_1_sub_sqr_tanh);
         if (i == j) begin
            fac_sech = miscs::q61mult(fac_sech, sqrt_1_sub_sqr_tanh);
            j = 3*j + 1;
         end
         tanh_theta = tanh_theta/2;
      end
      res = longint'(fac_sech);
      if (mag_bitw>=61) return (res<<(mag_bitw-61));
      else              return (res>>(61-mag_bitw))+((res>>(61-mag_bitw-1))&1);
   endfunction
   /*!
    * \brief 迭代过程中的双曲余弦值阶乘结果
    * \param it_times 迭代次数
    * \param mag_bitw 幅度位宽，不包含符号位
    * \return longint unsigned型，小数位数为 mag_bitw 的定点数值，有效位数为 mag_bitw+1
    */
   function automatic longint unsigned factorial_hyperbolic_cosine(int it_times, int mag_bitw);
      /* ——知乎网站——硬件算法笔记22——CORDIC算法——双曲CORDIC
       * 双曲旋转中，伪旋转“角度”定义为与双曲扇形面积相关的量；向量长度定义为 R = sqrt(x^2 - y^2)；
       * 伪旋转在每次迭代中引入的偏差系数为 sqrt(1-tanh(a[i])^2) = 1/cosh(a[i])
       */
      // tanh(theta) = 2^-i
      // sech(theta) = sqrt(1 - tanh(theta)^2)
      // cosh(theta) = rsqrt(1 - tanh(theta)^2)
      longint unsigned tanh_theta, sqrt_1_sub_sqr_tanh, fac_sech, res;
      int unsigned i, j;
      tanh_theta = (longint'(2))**(61-1/*双曲坐标旋转的迭代索引从1开始*/); fac_sech = (longint'(2))**61; j = 4;
      for (i = 1; i < it_times; i++) begin
         sqrt_1_sub_sqr_tanh = miscs::q61rsqrt2(((longint'(2))**61), tanh_theta, 1'b1);
         fac_sech = miscs::q61mult(fac_sech, sqrt_1_sub_sqr_tanh);
         if (i == j) begin
            fac_sech = miscs::q61mult(fac_sech, sqrt_1_sub_sqr_tanh);
            j = 3*j + 1;
         end
         tanh_theta = tanh_theta/2;
      end
      res = longint'(fac_sech);
      if (mag_bitw>=61) return (res<<(mag_bitw-61));
      else              return (res>>(61-mag_bitw))+((res>>(61-mag_bitw-1))&1);
   endfunction
   /*!
    * \brief Q.61弧度值角度转换为给定量化值的定点角度值
    * \param rad            待转换的弧度值角度
    * \param angle_qscale   半周数值量化值，即半周角度（半圆角度，180度）对应的量化数值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定。
    *                       例如：弧度的半周量化值是 pi ，以度为单位的角度半周量化值是 180
    * \param angle_qfbits   定点参数 #angle_qscale 的小数位宽
    * \param angle_fracbits 输输出角度值的小数位数。
    */
   function automatic longint signed q61rad2scale(longint signed rad, longint angle_qscale, int angle_qfbits, int angle_fracbits);
      miscs::sfpt sfp_angle;
      int signed rshbits;
      sfp_angle = miscs::sfp_div(miscs::sfp_makesfp_byqp(rad, 61), miscs::sfp_pi);
      sfp_angle = miscs::sfp_mul(sfp_angle, miscs::sfp_makesfp_byqp(angle_qscale, angle_qfbits));
      rshbits = 61 - angle_fracbits - sfp_angle.expn;
      if (rshbits >= 0) return (sfp_angle.mnts>>>rshbits);
      else              return (sfp_angle.mnts<<<rshbits);
   endfunction
endpackage
/*!
 * \brief CORDIC 运算核模块
 * \details CORDIC 运算各种旋转模式下可实现的功能：
 * cordic_pkg::cdcrs_circular : 
 *            cordic_pkg::cdcdm_ang ： 实现向量旋转给定角度，旋转的角度由 #zi 指定；
 *                                     特别的，当 #yi 置零时，可将由 #xi 表示幅值、 #zi 表示角度的极坐标转换为 #xo 、 #yo 表示的复数；
 *                                     特别的，当 #yi 置零、 #xi 置单位一的值时， #xo 、 #yo 则分别输出角度 #zi 的余弦、正弦值
 *            cordic_pkg::cdcdm_vec ： 将 (#yi , #xi) 表示的复数矢量的幅值输出到 #xo ，复数角度累加到 #zi 上，
 *                                     特别的，当 #zi置零，将 (#yi , #xi) 表示的复数转换为 #xo 表示幅值、 #zo 表示角度的极坐标，即计算矢量的模和反正切值（atan(#yi/#xi) 、 actan(#xi/#yi) ）
 *                                     特别的，当 #xi 置单位 1 的值， #zi 置零时，输出的 #xo 为 sqrt(1 + #yi^2) ， #zo 为 atan(#yi)
 * cordic_pkg::cdcrs_linear :
 *            cordic_pkg::cdcdm_ang ： 实现乘加运算，                        #zo = 0， #xo = #xi ， #yo = #yi + #xi*#zi ；
 *                                     特别的，当 #yi 置零时，可实现乘法运算， #zo = 0， #xo = #xi ， #yo = #xi*#zi ；
 *            cordic_pkg::cdcdm_vec ： 实现除加运算，                        #yo = 0， #xo = #xi ， #zo = #zi + #yi/#xi ；
 *                                     特别的，当 #zi 置零时，可实现除法运算， #yo = 0， #xo = #xi ， #zo = #yi/#xi 
 * cordic_pkg::cdcrs_hyperbolic :
 *            cordic_pkg::cdcdm_ang ： 实现矢量的双曲角度旋转，               #zo = 0， #xo = #xi*cosh(#zi) + #yi*sinh(#zi) ， #yo = #yi*cosh(#zi) + #xi*sinh(#zi)
 *                                     收敛条件 —— abs(zi) < 1.1181 ，用户可通过观察输出的 #zo 的绝对值是否小于用户自主设定的门限来判断是否满足收敛精度。
 *                                     特别的，当 #yi 置零、 #xi 置单位一时， #zo = 0， #xo = #cosh(#zi) ，                    #yo = #sinh(#zi)
 *            cordic_pkg::cdcdm_vec ： 实现平方差的平方根运算及双曲角度累加，  #yo = 0， #xo = sqrt(#xi^2 - #yi^2) ，           #zo = #zi + atanh(#yi/#xi)
 *                                     收敛条件 —— abs(#yi)/abs(#xi) < 0.8069 ，用户可通过观察输出的 #yo 的绝对值是否小于用户自主设定的门限来判断是否满足收敛精度。
 *                                     特别的，当 #zi 置零时，               #yo = 0， #xo = sqrt(#xi^2 - #yi^2) ，           #zo = atanh(#yi/#xi)
 *            \attention 双曲坐标旋转模式下输入矢量分量的整数位宽扩展为1位，输出矢量分量的整数位宽扩展为2位。
 */
module cordic #(
   parameter int                                                   IVP_BITW       = 32,                                    ///< 输入二维矢量分量有效位宽，不包含符号位，小数位宽由 #cordic_pkg::#fracbits_of_vecpart_bitw( #IVP_BITW + 1 ) 计算。
                                                                                                                           ///< \attention 这里给出的矢量分量位宽是两个分量同时取最大值 2**(IVP_BITW-1) 时的位宽；
                                                                                                                           ///< 但实际上经过角度旋转后，单个分量的最大值将达到 sqrt(2)*2**(IVP_BITW-1) ，此时另一个分量的值将归零。
                                                                                                                           ///< 为兼容这种情况，输入矢量分量位宽被实际设置为 #IVP_BITW+1 ，以容纳 sqrt(2)*2**(IVP_BITW-1) 的值域范围
   parameter int                                                   IANGLE_BITW    = 33,                                    ///< 输入角度（信号 #zi ）位宽，包含符号位；
                                                                                                                           ///< \attention 信号 #zi 的小数位宽由本例化参数和例化参数 #ANGLE_QSCALE 、 #ANGLE_QFBITS 共同决定，
                                                                                                                           ///< 可由常数函数 #cordic_pkg::#fracbits_of_angle_bitw 计算。
   parameter int                                                   OVP_BITW       = 32,                                    ///< 输出二维矢量分量有效位宽，不包含符号位，小数位宽由 #cordic_pkg::#fracbits_of_vecpart_bitw( #OVP_BITW + 1 ) 计算。
                                                                                                                           ///< \attention 这里给出的矢量分量位宽是两个分量同时取最大值 2**(OVP_BITW-1) 时的位宽；
                                                                                                                           ///< 但实际上经过角度旋转后，单个分量的最大值将达到 sqrt(2)*2**(OVP_BITW-1) ，此时另一个分量的值将归零。
                                                                                                                           ///< 为兼容这种情况，输出矢量分量位宽被实际设置为 #OVP_BITW+1 ，以容纳 sqrt(2)*2**(OVP_BITW-1) 的值域范围
   parameter int                                                   OANGLE_BITW    = 33,                                    ///< 输出角度（信号 #zo ）位宽，包含符号位；
                                                                                                                           ///< \attention 信号 #zo 的小数位宽由本例化参数和例化参数 #ANGLE_QSCALE 、 #ANGLE_QFBITS 共同决定，
                                                                                                                           ///< 可由常数函数 #cordic_pkg::#fracbits_of_angle_bitw 计算。
   parameter cordic_pkg::cdcrs_t                                   ROTATSYS       = cordic_pkg::cdcrs_circular,            ///< 旋转坐标系模式：
                                                                                                                           ///< cordic_pkg::cdcrs_circular  -圆坐标旋转模式；
                                                                                                                           ///< cordic_pkg::cdcrs_linear    -线性坐标旋转模式；
                                                                                                                           ///< cordic_pkg::cdcrs_hyperbolic-双曲坐标旋转模式
   parameter longint                                               ANGLE_QSCALE   = 1,                                     ///< 以 Q.x 定点数形式表示的角度量化值，定点数小数位数由 #ANGLE_QFBITS 定义，必须 > 0。
                                                                                                                           ///< 角度值的基准单位为“半周”，对应的角度为 180 度或者 pi ，在该基准单位上乘以不同的量化系数可得到不同单位的角度，
                                                                                                                           ///< 例如： #ANGLE_QSCALE = 1.0 ，对应输入、输出的角度单位为“半周”；
                                                                                                                           ///<        #ANGLE_QSCALE = pi ，对应角度单位为“rad”；
                                                                                                                           ///<        #ANGLE_QSCALE = 180 ，对应角度单位为“度”...
   parameter int                                                   ANGLE_QFBITS   = 0,                                     ///< 参数 #ANGLE_QSCALE 的小数位数
   parameter int                                                   ANGLE_EINTBITS = 0,                                     ///< 角度分量整数部分扩展位宽，用于避免线性坐标旋转（cordic_pkg::cdcrs_linear）矢量驱动模式下除法计算结果溢出，
                                                                                                                           ///< 对双曲坐标旋转（cordic_pkg::cdcrs_hyperbolic），本参数应设置1以避免角度结果溢出；
                                                                                                                           ///< 对圆坐标旋转（cordic_pkg::cdcrs_circular）或者线性坐标旋转的角度驱动模式，本参数可置0.
   parameter int                                                   Q61DZASIZ      = 0,                                     ///< 角度迭代差值数组大小，为 0 表示自主生成角度迭代差值，非 0 表示使用传入的预先生成的角度迭代差值参数
   parameter bit[(Q61DZASIZ>0?Q61DZASIZ:1)-1:0][$bits(longint)-1:0]Q61DZARRAY     ={(Q61DZASIZ>0?Q61DZASIZ:1){{($bits(longint)){1'b0}}}},///< 角度迭代差值数组
   parameter int                                                   CHNLCNT        = 1,                                     ///< 计算数据通道数
   parameter int                                                   ITERAT_COUNT   = 0,                                     ///< 迭代循环次数，次数越多运算精度越高，消耗资源也越多。0-由程序自动选择保持精度的迭代次数，>0-用户指定迭代次数。
   parameter int signed                                            FIXED_DRVMOD   = -1,                                    ///< 固定驱动模式指示标志——
                                                                                                                           ///< -1：驱动模式在运行时由入口信号 #drvmod 选择；
                                                                                                                           ///<  int'(cordic_pkg::cdcdm_vec)：驱动模式固定为矢量驱动，入口信号 #drvmod 被忽略；
                                                                                                                           ///<  int'(cordic_pkg::cdcdm_ang)：驱动模式固定为角度驱动，入口信号 #drvmod 被忽略；
   parameter bit                                                   DRVBYCHNL0     = 1'b0,                                  ///< 仅用第一个通道的驱动参数驱动所有通道的旋转标志。矢量驱动模式下的驱动参数是 #yi ，角度驱动模式下的驱动参数是 #zi 。
                                                                                                                           ///< 1'b0-每个通道使用各自的驱动参数驱动旋转
                                                                                                                           ///< 1'b1-每个通道均使用第一个通道的驱动参数驱动旋转
   parameter bit                                                   HRDCOR_MC      = 1'b0                                   ///< 用硬件核实现常数乘法器标志，1'b1-用硬件核实现常数乘法器，1'b0-用逻辑电路实现常数乘法器
) (clk, aclr, sclr, clken, xi, yi, zi, drvmod, xo, yo, zo);
   input  bit                                               clk;     ///< 时钟信号
   input  wire                                              aclr;    ///< 异步复位信号，高电平(1)有效
   input  wire                                              sclr;    ///< 同步复位信号，高电平(1)有效
   input  wire                                              clken;   ///< 时钟使能信号，高电平(1)有效
   localparam int vectr_exint = (ROTATSYS == cordic_pkg::cdcrs_hyperbolic) ? 1 : 0;
   input  wire [CHNLCNT-1:0][vectr_exint   +IVP_BITW   -0:0]xi;      ///< 待旋转矢量x分量，MSB是符号位
   localparam int ychcnt = (FIXED_DRVMOD == cordic_pkg::cdcdm_vec && DRVBYCHNL0 == 1'b1) ? 1 : CHNLCNT;
   input  wire [ychcnt -1:0][vectr_exint   +IVP_BITW   -0:0]yi;      ///< 待旋转矢量y分量，MSB是符号位
   localparam int zchcnt = (FIXED_DRVMOD == cordic_pkg::cdcdm_ang && DRVBYCHNL0 == 1'b1) ? 1 : CHNLCNT;
   input  wire [zchcnt -1:0][ANGLE_EINTBITS+IANGLE_BITW-1:0]zi;      ///< 待旋转角度，MSB是符号位，有效输入：
                                                                     ///< 对 cordic_pkg::cdcrs_circular , -180° ~ +180°
                                                                     ///< 对 cordic_pkg::cdcrs_linear , -1 ~ +1
                                                                     ///< 对 cordic_pkg::cdcrs_hyperbolic , -2 ~ +2
   input  cordic_pkg::cdcdm_t                               drvmod;  ///< 驱动模式控制信号。
                                                                     ///< 当例化参数 #FIXED_DRVMOD < 0 时，可选的有：
                                                                     ///< cordic_pkg::cdcdm_vec : 矢量驱动模式——驱动 y 值归零；
                                                                     ///< cordic_pkg::cdcdm_ang : 角度驱动模式——驱动 z 值归零；
                                                                     ///< 当例化参数 #FIXED_DRVMOD >= 0 时，本信号被忽略
   output logic[CHNLCNT-1:0][vectr_exint*2 +OVP_BITW   -0:0]xo;      ///< 旋转结果矢量x分量，MSB是符号位
   output logic[ychcnt -1:0][vectr_exint*2 +OVP_BITW   -0:0]yo;      ///< 旋转结果矢量y分量，MSB是符号位
   output logic[zchcnt -1:0][ANGLE_EINTBITS+OANGLE_BITW-1:0]zo;      ///< 旋转结果角度，MSB是符号位
   /*
    * 矢量驱动模式——驱动 y 值归零，则 y 位宽大小影响 z 的精度，那么：
    * -                           x/y 的迭代位宽应由 z 的输出位宽计算推荐值(recommend_vecpartbitw_by_anglefracbits)，并与 x/y 的输出位宽比较取最大值；
    * -                           z 的迭代位宽由 x/y 的迭代位宽计算推荐值(recommend_angle_fracbits_byvecpartbitw)。
    * 角度驱动模式——驱动 z 值归零，则 z 位宽大小影响 x/y 的精度，那么：
    *                             z 的迭代位宽应由 x/y 的输出位宽计算(recommend_angle_fracbits_byvecpartbitw)，并与 z 的输出位宽比较取最大值。
    *                             x/y 的迭代位宽由 z 的迭代位宽计算推荐值(recommend_vecpartbitw_by_anglefracbits)
    */
   // 输入角度的小数位宽
   localparam int ia_fracbits = cordic_pkg::fracbits_of_angle_bitw(
                                             .qscale     (ANGLE_QSCALE  ),
                                             .qfbits     (ANGLE_QFBITS  ),
                                             .angle_bitw (IANGLE_BITW   )
                                          );
   // 推荐的迭代数据位宽信息：包含推荐的迭代角度小数位宽、未扩展迭代矢量位宽
   localparam cordic_pkg::recommend_iterat_bitwinfo_t ribi = cordic_pkg::recommend_iterating_bitwinfo(
                                                                           .rotsys        (ROTATSYS      ),
                                                                           .oangle_bitw   (OANGLE_BITW   ),
                                                                           .ovp_bitw      (OVP_BITW      ),
                                                                           .angle_qscale  (ANGLE_QSCALE  ),
                                                                           .angle_qfbits  (ANGLE_QFBITS  ),
                                                                           .fixed_drvmod  (FIXED_DRVMOD  )
                                                                        );

   // 迭代计算使用的角度小数位宽
   localparam int r_fracbits = cordic_pkg::ang_fracbits_of_recommend_iterat_bitwinfo(ribi);
   localparam int r_anglnex_bitw = cordic_pkg::bitwof_angle_frm_fracbits(
                                                .qscale        (ANGLE_QSCALE  ),
                                                .qfbits        (ANGLE_QFBITS  ),
                                                .angle_fracbits(r_fracbits    )
                                             );
   localparam int r_anglbitw = ANGLE_EINTBITS + r_anglnex_bitw;
   // 迭代计算使用的矢量位宽
   localparam int r_vpnex_bitw = cordic_pkg::vpnex_bitw_of_recommend_iterat_bitwinfo(ribi);
   localparam int r_vp_bitw = r_vpnex_bitw + vectr_exint;
   // 迭代计算次数
   localparam int r_it_times = (ITERAT_COUNT > 0)
                               ? ITERAT_COUNT
                               : cordic_pkg::recommend_iterating_times_by_iterating_bitws(
                                                .rotsys        (ROTATSYS      ),
                                                .r_fracbits    (r_fracbits    ),
                                                .r_vpnex_bitw  (r_vpnex_bitw  ),
                                                .angle_qscale  (ANGLE_QSCALE  ),
                                                .angle_qfbits  (ANGLE_QFBITS  ),
                                                .fixed_drvmod  (FIXED_DRVMOD  )
                                             );
   localparam int total_delaytaps = cordic_pkg::cordic_delaytaps_of_iterating_times(
                                                   .rotsys        (ROTATSYS   ),
                                                   .iterat_count  (r_it_times )
                                                );
   initial $display("cordic: implement %0d taps for cordic calculation.", total_delaytaps);
   logic signed[CHNLCNT-1:0][vectr_exint      +IVP_BITW-0:0]xii, xiiu;
   logic signed[ychcnt -1:0][vectr_exint      +IVP_BITW-0:0]yii, yiiu;
   logic signed[zchcnt -1:0][ANGLE_EINTBITS+IANGLE_BITW-1:0]zii, ziiu;
   logic       [CHNLCNT-1:0][       1       :       0      ]nfiu, nfii;          // 0- negx, 1- negy
   cordic_pkg::cdcdm_t           drvmodii;
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) zii <= '0;
      else if (sclr) zii <= '0;
      else           zii <= clken ? ziiu : zii;
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) xii <= '0;
      else if (sclr) xii <= '0;
      else           xii <= clken ? xiiu : xii;
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) yii <= '0;
      else if (sclr) yii <= '0;
      else           yii <= clken ? yiiu : yii;
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) nfii <= '0;
      else if (sclr) nfii <= '0;
      else           nfii <= clken ? nfiu : nfii;
   end
   generate
      if (FIXED_DRVMOD <  0) begin
         always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
            if      (aclr) drvmodii <= cordic_pkg::cdcdm_ang;
            else if (sclr) drvmodii <= cordic_pkg::cdcdm_ang;
            else           drvmodii <= clken ? drvmod : drvmodii;
         end
      end
      else if (FIXED_DRVMOD == int'(cordic_pkg::cdcdm_vec)) assign drvmodii = cordic_pkg::cdcdm_vec;
      else if (FIXED_DRVMOD == int'(cordic_pkg::cdcdm_ang)) assign drvmodii = cordic_pkg::cdcdm_ang;
      else initial $error("cordic: unrecognized value is set to parameter FIXED_DRVMOD(%0d), only -1/0/1 is supported.", FIXED_DRVMOD);
   endgenerate
   localparam longint signed angle_unitval  = (ROTATSYS == cordic_pkg::cdcrs_circular)
                                              ? miscs::q61_pi
                                              : 2*(64'sd2**61);
   localparam bit            periodic_angle = (ROTATSYS == cordic_pkg::cdcrs_circular)
                                              ? 1'b1
                                              : 1'b0;
   localparam bit signed[ANGLE_EINTBITS+IANGLE_BITW-1:0] ang_unit4zi = cordic_pkg::q61angle2scale(
                                                                                    .rotsys        (ROTATSYS      ),
                                                                                    .ang           (angle_unitval ),
                                                                                    .angle_qscale  (ANGLE_QSCALE  ),
                                                                                    .angle_qfbits  (ANGLE_QFBITS  ),
                                                                                    .angle_fracbits(ia_fracbits   )
                                                                                 );
   localparam bit signed[ANGLE_EINTBITS+IANGLE_BITW-1:0] ang_hfunit4zi = cordic_pkg::q61angle2scale(
                                                                                       .rotsys        (ROTATSYS         ),
                                                                                       .ang           (angle_unitval/2  ),
                                                                                       .angle_qscale  (ANGLE_QSCALE     ),
                                                                                       .angle_qfbits  (ANGLE_QFBITS     ),
                                                                                       .angle_fracbits(ia_fracbits      )
                                                                                    );
   localparam bit signed[r_anglbitw:0] pi_zi_p = (ROTATSYS == cordic_pkg::cdcrs_circular) ? cordic_pkg::q61angle2scale(
                                                                                                .rotsys        (ROTATSYS      ),
                                                                                                .ang           (miscs::q61_pi ),
                                                                                                .angle_qscale  (ANGLE_QSCALE  ),
                                                                                                .angle_qfbits  (ANGLE_QFBITS  ),
                                                                                                .angle_fracbits(r_fracbits    )
                                                                                             ) : 0;
   /*!
    * \brief 检查双曲坐标旋转中迭代步骤是否需要重复
    * \param idxiterat 待检查的迭代步骤编号
    * \return bit 型， 1'b1-编号对应迭代步骤需要重复， 1'b0-编号对应迭代步骤不需要重复
    */
   function automatic bit iteration_should_repeat_for_hyperbolic(int idxiterat);
      int i;
      for (i = 4; i < idxiterat; i = 3*i+1);
      return (i == idxiterat) ? 1'b1 : 1'b0;
   endfunction
   genvar i, j, k; generate
   wire angle_drv_use;
   if      (FIXED_DRVMOD <  0                          ) assign angle_drv_use = (drvmod == cordic_pkg::cdcdm_ang) ? 1'b1 : 1'b0;
   else if (FIXED_DRVMOD == int'(cordic_pkg::cdcdm_vec)) assign angle_drv_use = 1'b0;
   else if (FIXED_DRVMOD == int'(cordic_pkg::cdcdm_ang)) assign angle_drv_use = 1'b1;
   wire[CHNLCNT-1:0]negx;
   wire[ychcnt -1:0]negy;
   wire[CHNLCNT-1:0]zi_ge_p90, zi_s_n90;
   for (j = 0; j < CHNLCNT; j++) begin: CHINIT
                     assign negx[j] = xi[j][vectr_exint+IVP_BITW-1];
      if (j < ychcnt)assign negy[j] = yi[j][vectr_exint+IVP_BITW-1];
      if (j < zchcnt)assign zi_ge_p90[j] = (signed'(zi[j]) >= +ang_hfunit4zi)
                                           ? periodic_angle
                                           : 1'b0,// 用 __lcordic_pkg::q61rad2scale 转换
                            zi_s_n90 [j] = (signed'(zi[j]) <  -ang_hfunit4zi)
                                           ? periodic_angle
                                           : 1'b0;
      else           assign zi_ge_p90[j] = zi_ge_p90[0],
                            zi_s_n90[j]  = zi_s_n90 [0];
      assign nfiu[j] = (angle_drv_use&periodic_angle)
                       ? {(zi_ge_p90[j]|zi_s_n90[j]), (zi_ge_p90[j]|zi_s_n90[j])}
                       : { negy[j],                    negx[j]                  };
      if (j < zchcnt)assign ziiu[j] = (angle_drv_use&periodic_angle)
                                      ? (zi_ge_p90[j]
                                         ? (signed'(zi[j]) - ang_unit4zi)
                                         : (zi_s_n90[j]
                                            ? (signed'(zi[j]) + ang_unit4zi)
                                            : zi[j]))
                                      : zi[j];
      if (j < ychcnt)assign yiiu[j] = angle_drv_use
                                      ? yi[j]
                                      : (negy[j]
                                         ? -(signed'(yi[j]))
                                         :           yi[j]);
                     assign xiiu[j] = angle_drv_use
                                      ? xi[j]
                                      : (negx[j]
                                         ? -(signed'(xi[j]))
                                         :           xi[j]);
   end
   localparam int i_it_bgn = (ROTATSYS == cordic_pkg::cdcrs_hyperbolic)
                             ? 1
                             : 0;/* 双曲坐标旋转下，迭代索引从0开始时，计算 #dz 的atanh函数将会得到无穷大值，因此此时迭代索引应从1开始 */
   function automatic int total_iterate_times();
      int i, rep4hyp;
      rep4hyp = 0;
      for (i = 0; i < r_it_times && ROTATSYS == cordic_pkg::cdcrs_hyperbolic; i++) begin
         rep4hyp = rep4hyp + (int'(iteration_should_repeat_for_hyperbolic(i)));
      end
      return rep4hyp + r_it_times;
   endfunction
   localparam int total_ittms = total_iterate_times();
   logic signed[i_it_bgn:total_ittms-1][CHNLCNT-1:0][r_vp_bitw+1:0]xsi, xso;//, xs2o;
   logic signed[i_it_bgn:total_ittms-1][ychcnt -1:0][r_vp_bitw+1:0]ysi, yso;//, ys2o;
   logic signed[i_it_bgn:total_ittms-1][zchcnt -1:0][r_anglbitw :0]zsi, zso;//, zs2o;
   cordic_pkg::cdcdm_t[i_it_bgn:total_ittms-1]                     drvmodi, drvmodo;
   logic       [i_it_bgn:total_ittms-1][CHNLCNT-1:0][     1     :0]negfi, negfo;

   logic       [i_it_bgn:total_ittms-1][CHNLCNT-1:0]               rotate_dir;
   logic signed[i_it_bgn:total_ittms-1][zchcnt -1:0][r_anglbitw :0]zs, zsou;
   logic signed[i_it_bgn:total_ittms-1][CHNLCNT-1:0][r_vp_bitw+1:0]xs, xsou;
   logic signed[i_it_bgn:total_ittms-1][ychcnt -1:0][r_vp_bitw+1:0]ys, ysou;
   // 输入级，输入信号连接
   initial if (r_anglbitw - r_fracbits < IANGLE_BITW - ia_fracbits)
      $fatal("cordic: algorithm of fraction bitwidth calculated from angle bitwidth and scale factor is bad!");
   assign drvmodi[i_it_bgn] = drvmodii,
          negfi  [i_it_bgn] = nfii;
   for (j = 0; j < CHNLCNT; j++) begin: CH
         if (r_vp_bitw <= IVP_BITW) assign xsi[i_it_bgn][j] = {{(r_vp_bitw-r_vpnex_bitw+1){xii[j][IVP_BITW]}}, xii[j][IVP_BITW:IVP_BITW-r_vpnex_bitw]};
         else                       assign xsi[i_it_bgn][j] = {{(r_vp_bitw-r_vpnex_bitw+1){xii[j][IVP_BITW]}}, xii[j], {(r_vpnex_bitw-IVP_BITW){1'b0}}};
      if (j < ychcnt) begin
         if (r_vp_bitw <= IVP_BITW) assign ysi[i_it_bgn][j] = {{(r_vp_bitw-r_vpnex_bitw+1){yii[j][IVP_BITW]}}, yii[j][IVP_BITW:IVP_BITW-r_vpnex_bitw]};
         else                       assign ysi[i_it_bgn][j] = {{(r_vp_bitw-r_vpnex_bitw+1){yii[j][IVP_BITW]}}, yii[j], {(r_vpnex_bitw-IVP_BITW){1'b0}}};
      end
      if (j < zchcnt) begin
         if (r_fracbits > 0) begin
            if      (r_fracbits <= ia_fracbits) assign zsi[i_it_bgn][j][r_fracbits-1:0] =  zii[j][ia_fracbits-1:ia_fracbits-r_fracbits];
            else if (ia_fracbits > 0)           assign zsi[i_it_bgn][j][r_fracbits-1:0] = {zii[j][ia_fracbits-1:0], {(r_fracbits-ia_fracbits){1'b0}}};
            else                                assign zsi[i_it_bgn][j][r_fracbits-1:0] = {(r_fracbits){1'b0}};
         end
         if (r_anglbitw - r_fracbits == ANGLE_EINTBITS + IANGLE_BITW - ia_fracbits)
            assign zsi[i_it_bgn][j][r_anglbitw:r_fracbits] = {zii[j][ANGLE_EINTBITS+IANGLE_BITW-1], zii[j][ANGLE_EINTBITS+IANGLE_BITW-1:ia_fracbits]};
         else
            assign zsi[i_it_bgn][j][r_anglbitw:r_fracbits] = {{((r_anglbitw-r_fracbits)-(ANGLE_EINTBITS+IANGLE_BITW-ia_fracbits)){zii[j][ANGLE_EINTBITS+IANGLE_BITW-1]}}, zii[j][ANGLE_EINTBITS+IANGLE_BITW-1:ia_fracbits]};
      end
   end
   // 迭代级输入信号连接
   assign drvmodi[i_it_bgn+1:total_ittms-1] = drvmodo[i_it_bgn:total_ittms-2],
          negfi  [i_it_bgn+1:total_ittms-1] = negfo  [i_it_bgn:total_ittms-2],
          xsi    [i_it_bgn+1:total_ittms-1] = xso    [i_it_bgn:total_ittms-2],
          ysi    [i_it_bgn+1:total_ittms-1] = yso    [i_it_bgn:total_ittms-2],
          zsi    [i_it_bgn+1:total_ittms-1] = zso    [i_it_bgn:total_ittms-2];
   // 迭代阵列
   function automatic bit[i_it_bgn:total_ittms-1][r_anglbitw-0:0] gen_dz();
      bit[i_it_bgn:total_ittms-1][r_anglbitw-0:0] ret;
      longint signed                              q61dz_use;
      bit                        [r_anglbitw-0:0] zz;
      int                                         it, itrepc;
      for (it = i_it_bgn, itrepc = 0; it < r_it_times; it++) begin
         if (it < Q61DZASIZ) q61dz_use = longint'(signed'(Q61DZARRAY[it]));
         else                q61dz_use = cordic_pkg::q61dzofiteration(
                                                      .rotsys     (ROTATSYS),
                                                      .idx_iterat (it      )
                                                   );
         zz = cordic_pkg::q61angle2scale(
                           .rotsys        (ROTATSYS      ),
                           .ang           (q61dz_use     ),
                           .angle_qscale  (ANGLE_QSCALE  ),
                           .angle_qfbits  (ANGLE_QFBITS  ),
                           .angle_fracbits(r_fracbits    )
                        );
         ret[it+itrepc] = zz;
         if (ROTATSYS == cordic_pkg::cdcrs_hyperbolic && iteration_should_repeat_for_hyperbolic(it) == 1'b1) begin
            itrepc = itrepc + 1;
            ret[it+itrepc] = zz;
         end
      end
      return ret;
   endfunction
   localparam bit[i_it_bgn:total_ittms-1][r_anglbitw-0:0] dz = gen_dz();
   initial if (FIXED_DRVMOD >= 0 && FIXED_DRVMOD != int'(cordic_pkg::cdcdm_vec) && FIXED_DRVMOD != int'(cordic_pkg::cdcdm_ang))
      $error("cordic: unrecognized value is set to parameter FIXED_DRVMOD(%0d), only -1/0/1 is supported.", FIXED_DRVMOD);
   always_comb foreach(rotate_dir[i, j]) begin: ROT
      if (j == 0 || (DRVBYCHNL0 == 1'b0 && j < zchcnt && j < ychcnt)) begin: ZS_DRVCH
         if      (FIXED_DRVMOD == int'(cordic_pkg::cdcdm_vec)) rotate_dir[i][j] = ~ysi[i][j][r_vp_bitw+1];
         else if (FIXED_DRVMOD == int'(cordic_pkg::cdcdm_ang)) rotate_dir[i][j] =  zsi[i][j][r_anglbitw ];
         else                                                  rotate_dir[i][j] = (drvmodi[i] == cordic_pkg::cdcdm_vec)
                                                                                  ? ~ysi[i][j][r_vp_bitw+1]
                                                                                  :  zsi[i][j][r_anglbitw ];
      end
      else begin: ZS_DRVBY0
         if      (FIXED_DRVMOD == int'(cordic_pkg::cdcdm_vec)) rotate_dir[i][j] = ~ysi[i][0][r_vp_bitw+1];
         else if (FIXED_DRVMOD == int'(cordic_pkg::cdcdm_ang)) rotate_dir[i][j] =  zsi[i][0][r_anglbitw ];
         else                                                  rotate_dir[i][j] = (drvmodi[i] == cordic_pkg::cdcdm_vec)
                                                                                  ? ~ysi[i][0][r_vp_bitw+1]
                                                                                  :  zsi[i][0][r_anglbitw ];
      end
      if (j < zchcnt) begin: ZS
         if (rotate_dir[i][j]) zs[i][j] =  (signed'(dz[i]));
         else                  zs[i][j] = -(signed'(dz[i]));
         zsou[i][j] = zsi[i][j] + zs[i][j];
      end
      if (rotate_dir[i][j]) xs[i][j] = -((signed'(xsi[i][j]))>>>i);
      else                  xs[i][j] =  ((signed'(xsi[i][j]))>>>i);
      if (j < ychcnt) begin: YS
         if (rotate_dir[i][j]) ys[i][j] = -((signed'(ysi[i][j]))>>>i);
         else                  ys[i][j] =  ((signed'(ysi[i][j]))>>>i);
         ysou[i][j] = ysi[i][j] + xs[i][j];
      end
      if (ROTATSYS == cordic_pkg::cdcrs_linear) xsou[i][j] = xsi[i][j];                          // 参考——知乎网站上——《硬件算法笔记22——CORDIC算法》，广义CORDIC算法，线性坐标旋转
      else begin
         automatic bit signed[r_vp_bitw+1:0]ys2use;
         if      (DRVBYCHNL0 == 1'b0 || (FIXED_DRVMOD == int'(cordic_pkg::cdcdm_ang) && j < ychcnt)) begin: YSCHI
            ys2use = ys[i][j];
         end
         else if (/* DRVBYCHNL0 == 1'b1 && */FIXED_DRVMOD == int'(cordic_pkg::cdcdm_vec)) begin: YSCH0
            ys2use = ys[i][0];
         end
         else/*if (DRVBYCHNL0 == 1'b1 && (FIXED_DRVMOD < 0 || (FIXED_DRVMOD == cordic_pkg::cdcdm_ang && j >= ychcnt))*/ begin: YSCHSEL
            ys2use = (drvmodi[i] == cordic_pkg::cdcdm_vec) ? ys[i][0] : ys[i][j];
         end
         if      (ROTATSYS == cordic_pkg::cdcrs_hyperbolic) xsou[i][j] = xsi[i][j] + ys2use;  // 参考——知乎网站上——《硬件算法笔记22——CORDIC算法》，广义CORDIC算法，双曲坐标旋转
         else if (ROTATSYS == cordic_pkg::cdcrs_circular)   xsou[i][j] = xsi[i][j] - ys2use;  // 普通圆坐标旋转
      end
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) negfo[i_it_bgn:total_ittms-2] <= {(total_ittms-i_it_bgn-1){{(CHNLCNT){2'b0}}}};
      else if (sclr) negfo[i_it_bgn:total_ittms-2] <= {(total_ittms-i_it_bgn-1){{(CHNLCNT){2'b0}}}};
      else           negfo[i_it_bgn:total_ittms-2] <= clken
                                                      ? negfi[i_it_bgn:total_ittms-2]
                                                      : negfo[i_it_bgn:total_ittms-2];
   end
   assign negfo[total_ittms-1] = negfi[total_ittms-1];
   if (FIXED_DRVMOD < 0) always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) drvmodo[i_it_bgn:total_ittms-2] <= {(total_ittms-i_it_bgn-1){{($bits(cordic_pkg::cdcdm_t)){1'b0}}}};
      else if (sclr) drvmodo[i_it_bgn:total_ittms-2] <= {(total_ittms-i_it_bgn-1){{($bits(cordic_pkg::cdcdm_t)){1'b0}}}};
      else           drvmodo[i_it_bgn:total_ittms-2] <= clken
                                                        ? drvmodi[i_it_bgn:total_ittms-2]
                                                        : drvmodo[i_it_bgn:total_ittms-2];
   end
   else assign drvmodo[i_it_bgn:total_ittms-2] = drvmodi[i_it_bgn:total_ittms-2];
   assign drvmodo[total_ittms-1] = drvmodi[total_ittms-1];
   cordic_pkg::cdcdm_t lsdm;
   assign lsdm = drvmodo[total_ittms-1];
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr)   xso <= {(total_ittms-i_it_bgn){{(CHNLCNT){{(r_vp_bitw+2){1'b0}}}}}};
      else if (sclr)   xso <= {(total_ittms-i_it_bgn){{(CHNLCNT){{(r_vp_bitw+2){1'b0}}}}}};
      else if (~clken) xso <= xso;
      else for (int ii = i_it_bgn; ii < total_ittms; ii++) begin
         for (int jj = 0; jj < CHNLCNT; jj++) begin
            if      (ii< total_ittms - 1)                                       xso[ii][jj] <=           xsou[ii][jj];
            else if (lsdm == cordic_pkg::cdcdm_ang && negfo[ii][jj][0] == 1'b1) xso[ii][jj] <= -(signed'(xsou[ii][jj]));
            else                                                                xso[ii][jj] <=           xsou[ii][jj];
         end
      end
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr)   yso <= {(total_ittms-i_it_bgn){{(ychcnt){{(r_vp_bitw+2){1'b0}}}}}};
      else if (sclr)   yso <= {(total_ittms-i_it_bgn){{(ychcnt){{(r_vp_bitw+2){1'b0}}}}}};
      else if (~clken) yso <= yso;
      else for (int ii = i_it_bgn; ii < total_ittms; ii++) begin
         for (int jj = 0; jj < ychcnt; jj++) begin
            if      (ii < total_ittms - 1)                                      yso[ii][jj] <=           ysou[ii][jj];
            else if (lsdm == cordic_pkg::cdcdm_ang && negfo[ii][jj][1] == 1'b1) yso[ii][jj] <= -(signed'(ysou[ii][jj]));
            else                                                                yso[ii][jj] <=           ysou[ii][jj];
         end
      end
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr)   zso <= {(total_ittms-i_it_bgn){{(zchcnt){{(r_anglbitw+1){1'b0}}}}}};
      else if (sclr)   zso <= {(total_ittms-i_it_bgn){{(zchcnt){{(r_anglbitw+1){1'b0}}}}}};
      else if (~clken) zso <= zso;
      else for (int ii = i_it_bgn; ii < total_ittms; ii++) begin
         for (int jj = 0; jj < zchcnt; jj ++) begin
            if      (ii < total_ittms - 1)                zso[ii][jj] <= zsou[ii][jj];
            else if (ROTATSYS == cordic_pkg::cdcrs_circular) begin
               if      (lsdm == cordic_pkg::cdcdm_ang) zso[ii][jj] <= zsou[ii][jj];
               else if (negfo[ii][jj][0]) begin
                  if (negfo[ii][jj][1]) zso[ii][jj] <= (signed'(zsou[ii][jj])) - pi_zi_p;
                  else                  zso[ii][jj] <= pi_zi_p - (signed'(zsou[ii][jj]));
               end else begin
                  if (negfo[ii][jj][1]) zso[ii][jj] <= -(signed'(zsou[ii][jj]));
                  else                  zso[ii][jj] <=  (signed'(zsou[ii][jj]));
               end
            end
            else if (lsdm == cordic_pkg::cdcrs_circular)   zso[ii][jj] <=           zsou[ii][jj];
            else if (negfo[ii][jj][0] != negfo[ii][jj][1]) zso[ii][jj] <= -(signed'(zsou[ii][jj]));
            else                                           zso[ii][jj] <=  (signed'(zsou[ii][jj]));
         end
      end
   end
   localparam longint signed ft_cosine = (ROTATSYS == cordic_pkg::cdcrs_circular)
                                         ? __lcordic_pkg::factorial_cosine(
                                                            .it_times(r_it_times ),
                                                            .mag_bitw(OVP_BITW   )/*幅度位宽，即归一化后的小数位宽——位宽里所有比特都填1对应无限接近归一化的一*/)
                                         : ((ROTATSYS == cordic_pkg::cdcrs_linear)
                                            ? 1
                                            : __lcordic_pkg::factorial_hyperbolic_cosine(
                                                               .it_times(r_it_times ),
                                                               .mag_bitw(OVP_BITW   )));
   localparam int bitwof_ft_cosine = (ROTATSYS == cordic_pkg::cdcrs_linear)
                                     ?  2
                                     : (vectr_exint+OVP_BITW+1/*符号位*/);
   localparam int o_fracbits = cordic_pkg::fracbits_of_angle_bitw(
                                             .qscale     (ANGLE_QSCALE  ),
                                             .qfbits     (ANGLE_QFBITS  ),
                                             .angle_bitw (OANGLE_BITW   )
                                          );
   wire[zchcnt -1:0][ANGLE_EINTBITS+OANGLE_BITW-1:0]zoo;
   wire[CHNLCNT-1:0][r_vp_bitw                 +1:0]xoo;
   wire[ychcnt -1:0][r_vp_bitw                 +1:0]yoo;
   wire[CHNLCNT-1:0][vectr_exint*2 +OVP_BITW   +1:0]xot;
   wire[ychcnt -1:0][vectr_exint*2 +OVP_BITW   +1:0]yot;
   for (j = 0; j < CHNLCNT; j++) begin: MAGFIX
      assign xoo[j] = xso[total_ittms-1][j][r_vp_bitw+1:0];
      ilmultconst #(
         .MINOF_VAR  (-((64'd2)**(r_vp_bitw+1))   ),
         .MAXOF_VAR  (((64'd2)**(r_vp_bitw+1))-1  ),
         .SIGNED_VAR (1'b1                      ),
         .CONSTARG   (ft_cosine                 ),
         .CONSTBITW  (bitwof_ft_cosine          ),
         .RESBITW    (vectr_exint*2+OVP_BITW+2  ),
         .USEHRDCOR  (HRDCOR_MC                 ),
         .RNDRESLSB  (1'b0                      ),
         .DELAYTAPS  (1                         )
      ) xso_mc(
         .clk        (clk     ),
         .aclr       (aclr    ),
         .sclr       (sclr    ),
         .clken      (clken   ),
         .var_arg    (xoo[j]  ),
         .var_valid  (1'b1    ),
         .res        (xot[j]  ),
         .res_valid  (        )
      );
      assign xo[j] = xot[j][vectr_exint*2 +OVP_BITW:0];
      if (j < ychcnt) begin: YFIX
         assign yoo[j] = yso[total_ittms-1][j][r_vp_bitw+1:0];
         ilmultconst #(
            .MINOF_VAR  (-((64'd2)**(r_vp_bitw+1))   ),
            .MAXOF_VAR  (((64'd2)**(r_vp_bitw+1))-1  ),
            .SIGNED_VAR (1'b1                      ),
            .CONSTARG   (ft_cosine                 ),
            .CONSTBITW  (bitwof_ft_cosine          ),
            .RESBITW    (vectr_exint*2+OVP_BITW+2  ),
            .USEHRDCOR  (HRDCOR_MC                 ),
            .RNDRESLSB  (1'b0                      ),
            .DELAYTAPS  (1                         )
         ) yso_mc(
            .clk        (clk     ),
            .aclr       (aclr    ),
            .sclr       (sclr    ),
            .clken      (clken   ),
            .var_arg    (yoo[j]  ),
            .var_valid  (1'b1    ),
            .res        (yot[j]  ),
            .res_valid  (        )
         );
         assign yo[j] = yot[j][vectr_exint*2 +OVP_BITW:0];
      end
      if (j < zchcnt) begin: ZFIX
         /* 由 #cordic_pkg::#fracbits_of_angle_bitw 计算的小数位宽是在确保整数位宽匹配 #ANGLE_QSCALE 和 #ANGLE_QFBITS 的整数位下的小数位宽，
          * 因此 #r_anglebitw 和 #OANGLE_BITW 中的整数位宽应该相同。                                                                      */
         if (o_fracbits <= r_fracbits) assign zoo[j][o_fracbits-1:0] = zso[total_ittms-1][j][r_fracbits-1:r_fracbits-o_fracbits];
         else                          assign zoo[j][o_fracbits-1:0] = {zso[total_ittms-1][j], {(o_fracbits-r_fracbits){1'b0}}};
         if (ANGLE_EINTBITS+OANGLE_BITW - o_fracbits <= r_anglbitw - r_fracbits)
            assign zoo[j][ANGLE_EINTBITS+OANGLE_BITW-1:o_fracbits] = zso[total_ittms-1][j][ANGLE_EINTBITS+OANGLE_BITW-1-o_fracbits+r_fracbits:r_fracbits];
         else
            assign zoo[j][ANGLE_EINTBITS+OANGLE_BITW-1:o_fracbits] = {{((ANGLE_EINTBITS+OANGLE_BITW-o_fracbits)-(r_anglbitw-r_fracbits)){zso[total_ittms-1][j][r_anglbitw-1]}}, zso[total_ittms-1][j][r_anglbitw-1:r_fracbits]};
      end
   end
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) zo <= '0;
      else if (sclr) zo <= '0;
      else           zo <= clken ? zoo : zo;
   end
   endgenerate
endmodule
/*!
 * \brief 矢量幅度归一化
 * 令 - 表示冗余位， + 表示有效位。
 * 当 IVP_BITW < OVP_BITW 时：
 *    - 归一化
 *       xi : |---|++++++|
 *       xo : |++++++|---|-----|
 *    - 归一化恢复
 *       xo : |++++++|---|-----|
 *       xi : |---|++++++|
 *    - 可见有效的移位范围与 xi 一致
 * 当 IVP_BITW >= OVP_BITW 时：
 *    - 归一化
 *       xi : |---|+++++++++++++|
 *       xo : |++++++++++|
 *    - 归一化恢复
 *       xo : |++++++++++|
 *       xi : |---|++++++++++|--|
 *    - 可见有效的移位范围也与 xi 一致
 * 因此，移位器的比特位作用范围只需要对齐 xi 即可。
 */
module cdc_magnorm #(
   parameter int                 IVP_BITW = 32,                         ///< 输入矢量分量有效位宽，不包含符号位
   parameter int                 OVP_BITW = 16,                         ///< 输出矢量分量有效位宽，不包含符号位
   parameter bit                 CPLXVEC  = 1'b0,                       ///< 输入输出矢量是复数矢量的标志，1'b0-实数矢量，1'b1-复数矢量
   parameter cordic_pkg::cdcrs_t ROTATSYS = cordic_pkg::cdcrs_circular, ///< 旋转坐标系模式：
                                                                        ///< cordic_pkg::cdcrs_circular  -圆坐标旋转模式；
                                                                        ///< cordic_pkg::cdcrs_linear    -线性坐标旋转模式；
                                                                        ///< cordic_pkg::cdcrs_hyperbolic-双曲坐标旋转模式
   parameter int                 LSHBSBW  = 0,                          ///< 归一化左移位数的位宽， = 0 表示自动计算左移位数的位宽
   parameter int                 CHNLCNT  = 1                           ///< 数据通道数
) (clk, aclr, sclr, clken, xi, xo, lshbs);
   input  bit                                                     clk;  ///< 时钟信号
   input  wire                                                    aclr; ///< 异步复位信号，高电平(1)有效
   input  wire                                                    sclr; ///< 同步复位信号，高电平(1)有效
   input  wire                                                    clken;///< 时钟使能信号，高电平(1)有效
   localparam int vectr_exint = (ROTATSYS == cordic_pkg::cdcrs_hyperbolic) ? 1 : 0;
   input  wire [CPLXVEC:0][CHNLCNT-1:0][vectr_exint+IVP_BITW-0:0] xi;   ///< 输入矢量阵列，各矢量分量MSB是符号位
   output wire [CPLXVEC:0][CHNLCNT-1:0][vectr_exint+OVP_BITW-0:0] xo;   ///< 输出矢量阵列，各矢量分量MSB是符号位
   localparam int lshbsbwe = cordic_pkg::magnorm_recommend_bitwof_lshbsbw(.ivp_bitw(IVP_BITW));
   initial if (LSHBSBW > 0 && LSHBSBW < lshbsbwe)
      $error("cdc_magnorm: bitwidth of signal 'lshbs' specified by LSHBSBW(%0d) is too little to hold all shift bit count, at least %0d is required!", LSHBSBW, lshbsbwe);
   localparam int bwoflshbs = (LSHBSBW > 0)
                              ? LSHBSBW
                              : lshbsbwe;
   output logic           [CHNLCNT-1:0][bwoflshbs           -1:0] lshbs;///< 输出的归一化分量相对原分量的左移位数

   localparam int dlytaps_lmbd = lmbd_pkg::delaytaps_recommend(.databitw(vectr_exint+IVP_BITW+1));
   localparam int lmbd_ipbw    = lmbd_pkg::iposbw_recommend(.databitw(vectr_exint+IVP_BITW+1));
   localparam int dlytaps_clsh = clshift_pkg::delaytaps_recommend(.databitw(vectr_exint+IVP_BITW+1));
   localparam int clsh_dsbw    = clshift_pkg::distanceBitwOfDataBitw(.databitw(vectr_exint+IVP_BITW+1));
   logic     [CPLXVEC:0][CHNLCNT-1:0][lmbd_ipbw           -1:0]xshbs;
   logic                [CHNLCNT-1:0][lmbd_ipbw           -1:0]shbso;
   logic[1:0][CPLXVEC:0][CHNLCNT-1:0][vectr_exint+IVP_BITW-0:0]pp;
   logic     [CPLXVEC:0][CHNLCNT-1:0][vectr_exint+IVP_BITW-0:0]xt, yt;
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) pp[1] <= {(2){{(int'(CPLXVEC)+1){{(CHNLCNT){{(vectr_exint+IVP_BITW+1){1'b0}}}}}}}};
      else if (sclr) pp[1] <= {(2){{(int'(CPLXVEC)+1){{(CHNLCNT){{(vectr_exint+IVP_BITW+1){1'b0}}}}}}}};
      else           pp[1] <= clken ? pp[0] : pp[1];
   end
   genvar i, j; generate
   for (i = 0; i < CHNLCNT; i++) begin: CH
      wire[CPLXVEC:0]               xs2s;
      wire[CPLXVEC:0][lmbd_ipbw-1:0]xshbs2u;
      wire           [lmbd_ipbw-1:0]shbs2u;
      if (CPLXVEC) assign shbs2u = (xshbs[0][i] > xshbs[1][i])
                                   ? xshbs2u[1]
                                   : xshbs2u[0];
      else         assign shbs2u = xshbs2u[0];
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
         if      (aclr) shbso[i] <= {(lmbd_ipbw){1'b0}};
         else if (sclr) shbso[i] <= {(lmbd_ipbw){1'b0}};
         else           shbso[i] <= clken
                                    ? shbs2u
                                    : shbso[i];
      end
      wire[clsh_dsbw-1:0]dssh;
      assign dssh[lmbd_ipbw-1:0] = shbso[i];
      if (clsh_dsbw > lmbd_ipbw) assign dssh[clsh_dsbw-1:lmbd_ipbw] = {(clsh_dsbw-lmbd_ipbw){1'b0}};
      
      for (j = 0; j <= int'(CPLXVEC); j++) begin: CPLX
         assign xs2s[j] = ~xi[j][i][vectr_exint+IVP_BITW-0];
         lmbd #(
            .DATABITW   (vectr_exint+IVP_BITW+1 ),
            .POSBITW    (lmbd_ipbw              ),
            .IDXFRMLSB  (1'b0                   ),
            .DELAYTAPS  (dlytaps_lmbd           ),
            .PIPELINE   (1'b1                   ),
            .PIPEINPUT  (1'b1                   )
         ) lmbdxi(
            .clk     (clk        ),
            .aclr    (aclr       ),
            .sclr    (sclr       ),
            .clken   (clken      ),
            .x       (xi[j][i]   ),
            .bit2s   (xs2s[j]    ),
            .ipos    (xshbs[j][i]),
            .pipe_x  (pp[0][j][i])
         );
         assign xshbs2u[j] = (xshbs[j][i] > (lmbd_ipbw)'(vectr_exint+1/*符号位*/+1/*扩位*/))
                             ? (xshbs[j][i] - (lmbd_ipbw)'(vectr_exint+1/*符号位*/+1/*扩位*/))
                             : {(lmbd_ipbw){1'b0}};
         wire[clsh_dsbw-1:0]dsshp;
         clshift #(
            .BITWIDTH      (vectr_exint+IVP_BITW+1 ),
            .DIRECTION     (1'b0                   ), // 左移
            .ARITHMATIC    (1'b0                   ), // 不带符号的逻辑移位
            .DELAYTAPS     (dlytaps_clsh           ),
            .PIPELINE      (1'b1                   ),
            .PIPEINPUT     (1'b0                   ),
            .PIPEDISTANCE  ((j == 0) ? 1'b1 : 1'b0 )
         ) clshxi(
            .clk           (clk        ),
            .aclr          (aclr       ),
            .sclr          (sclr       ),
            .clken         (clken      ),
            .x             (pp[1][j][i]),
            .distance      (dssh       ),
            .result        (xt[j][i]   ),
            .pipe_x        (           ),
            .pipe_distance (dsshp      )
         );
         if (j == 0) assign lshbs[i] = dsshp[bwoflshbs-1:0];
         assign xo[j][i] = xt[j][i][vectr_exint+IVP_BITW+0:vectr_exint+IVP_BITW+1-(OVP_BITW+1)];
      end
   end
   endgenerate
endmodule
/*!
 * \brief 矢量幅度归一化恢复
 */
module cdc_magnorm_restr  #(
   parameter int                 IVP_BITW = 32,                         ///< 输入矢量分量有效位宽，不包含符号位
   parameter int                 OVP_BITW = 16,                         ///< 输出矢量分量有效位宽，不包含符号位
   parameter bit                 CPLXVEC  = 1'b0,                       ///< 输入输出矢量是复数矢量的标志，1'b0-实数矢量，1'b1-复数矢量
   parameter cordic_pkg::cdcrs_t ROTATSYS = cordic_pkg::cdcrs_circular, ///< 旋转坐标系模式：
                                                                        ///< cordic_pkg::cdcrs_circular  -圆坐标旋转模式；
                                                                        ///< cordic_pkg::cdcrs_linear    -线性坐标旋转模式；
                                                                        ///< cordic_pkg::cdcrs_hyperbolic-双曲坐标旋转模式
   parameter int                 LSHBSBW  = 0,                          ///< 归一化左移位数的位宽， = 0 表示自动计算左移位数的位宽
   parameter bit                 PIPLSHBS = 1'b0,                       ///< 是否同步输出输入的归一化左移位数，1'b0-不同步输出以节省资源，1'b1-从 #lshbso 同步输出
   parameter int                 CHNLCNT  = 1                           ///< 数据通道数
) (clk, aclr, sclr, clken, xi, lshbs, xo, lshbso);
   input  bit                                                     clk;     ///< 时钟信号
   input  wire                                                    aclr;    ///< 异步复位信号，高电平(1)有效
   input  wire                                                    sclr;    ///< 同步复位信号，高电平(1)有效
   input  wire                                                    clken;   ///< 时钟使能信号，高电平(1)有效
   localparam int vectr_exint = (ROTATSYS == cordic_pkg::cdcrs_hyperbolic) ? 1 : 0;
   input  wire [CPLXVEC:0][CHNLCNT-1:0][vectr_exint+IVP_BITW-0:0] xi;      ///< 待恢复的归一化矢量，各分量的MSB是符号位
   localparam int lshbsbwe = cordic_pkg::magnorm_recommend_bitwof_lshbsbw(.ivp_bitw(OVP_BITW));
   initial if (LSHBSBW > 0 && LSHBSBW < lshbsbwe)
      $error("cdc_magnorm: bitwidth of signal 'lshbs' specified by LSHBSBW(%0d) is too little to hold all shift bit count, at least %0d is required!", LSHBSBW, lshbsbwe);
   localparam int bwoflshbs = (LSHBSBW > 0)
                              ? LSHBSBW
                              : lshbsbwe;
   input  logic           [CHNLCNT-1:0][bwoflshbs           -1:0] lshbs;   ///< 输入的归一化分量相对原分量的左移位数
   output logic[CPLXVEC:0][CHNLCNT-1:0][vectr_exint+OVP_BITW-0:0] xo;      ///< 归一化恢复后的矢量，各分量MSB是符号位
   output logic           [CHNLCNT-1:0][bwoflshbs           -1:0] lshbso;  ///< 同步输出的归一化分量相对原分量的左移位数

   localparam int xsbw = vectr_exint + OVP_BITW + 1;
   localparam int dlytaps_crsh = clshift_pkg::delaytaps_recommend(.databitw(xsbw));
   localparam int clsh_dsbw    = clshift_pkg::distanceBitwOfDataBitw(.databitw(xsbw));
   genvar i, j; generate
   wire[CPLXVEC:0][CHNLCNT-1:0][xsbw-1:0]xs;
   localparam int bw2cp = (IVP_BITW < OVP_BITW)
                          ? (IVP_BITW + vectr_exint + 1)
                          : (OVP_BITW + vectr_exint + 1);
   for (i = 0; i < CHNLCNT; i++) begin: CH
      wire[1:0][clsh_dsbw-1:0]lshbs2cs;
      assign lshbs2cs[0] = (clsh_dsbw)'(lshbs[i]);
      for (j = 0; j <= int'(CPLXVEC); j++) begin: CPLX
         assign xs[j][i][xsbw-1:xsbw-bw2cp] = xi[j][i][vectr_exint+IVP_BITW-0:vectr_exint+IVP_BITW-bw2cp+1];
         if (xsbw > bw2cp) assign xs[j][i][xsbw-bw2cp-1:0] = {(xsbw-bw2cp){1'b0}};
         wire[clsh_dsbw-1:0] lshbs2csp;
         clshift #(
            .BITWIDTH      (xsbw          ),
            .DIRECTION     (1'b1          ), // 右移
            .ARITHMATIC    (1'b1          ), // 带符号的算术移位
            .DELAYTAPS     (dlytaps_crsh  ),
            .PIPELINE      (1'b1          ),
            .PIPEINPUT     (1'b0          ),
            .PIPEDISTANCE  (PIPLSHBS      )
         ) crshxi(
            .clk           (clk        ),
            .aclr          (aclr       ),
            .sclr          (sclr       ),
            .clken         (clken      ),
            .x             (xs[j][i]   ),
            .distance      (lshbs2cs[0]),
            .result        (xo[j][i]   ),
            .pipe_x        (           ),
            .pipe_distance (lshbs2csp  )
         );
         if (j == 0) assign lshbs2cs[1] = lshbs2csp;
      end
      assign lshbso[i] = lshbs2cs[1][bwoflshbs-1:0];
   end
   endgenerate
endmodule
/*!
 * \brief 相位值整周修正
 * \details 若输入的相位值处于正负半周之外，则将其折算至正负半周之内输出，否则直接输出原值
 */
module cdc_phsfix_cyclmod #(
   parameter int     ANGBITW   = 32,   ///< 相位角度值位宽
   parameter int     ANGEIBW   = 0,    ///< 相位角度值整数扩展位宽
   parameter longint PHSQSCALE = 16,   ///< 相位半周对应的量化值，Q.x型定点数，小数位数由 #PHSQFBITS 指定
   parameter int     PHSQFBITS = 0,    ///< 参数 #PHSQSCALE 的小数位数
   parameter int     ADDSUBSEL = 0,    ///< 对输入的相位修正量的修正算法选择，0:不修正，>0:以加法修正，<0:以减法修正
   parameter bit     FXASLOP   = 1'b0, ///< 用输入相位Y作为修正加减法的左操作数标志，1'b0- #angiy 作为右操作数，计算 x - y ， 1'b1- #angiy 作为左操作数，计算 y - x
   parameter int     CHNLCNT   = 1,    ///< 数据通道数
   parameter int     DELAYTAPS = 0     ///< 延迟输出拍数。
) (
   input  bit                                            clk,    ///< 同步时钟
   input  wire                                           aclr,   ///< 异步复位信号，高电平(1)有效
   input  wire                                           sclr,   ///< 同步复位信号，高电平(1)有效
   input  wire                                           clken,  ///< 时序逻辑使能信号，高电平(1)有效
   input  wire  signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-1:0] angi,   ///< 待修正相位值
   input  wire  signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-1:0] angfx,  ///< 相位修正量
   output logic signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-1:0] ango    ///< 修正后的相位值
);
   localparam int agfcbitw = cordic_pkg::fracbits_of_angle_bitw(
                                             .qscale     (PHSQSCALE  ), // 预留可以表示 -180° ~ +180° 角度范围的整数部分位宽
                                             .qfbits     (PHSQFBITS  ),
                                             .angle_bitw (ANGBITW    )
                                          );
   localparam bit signed[ANGEIBW+ANGBITW-0:0]halfcycle_angles = (PHSQFBITS > agfcbitw) ? (PHSQSCALE>>(PHSQFBITS-agfcbitw-0)) : (PHSQSCALE<<(agfcbitw-PHSQFBITS+0));
   localparam bit signed[ANGEIBW+ANGBITW-0:0]wholcycle_angles = (PHSQFBITS > agfcbitw) ? (PHSQSCALE>>(PHSQFBITS-agfcbitw-1)) : (PHSQSCALE<<(agfcbitw-PHSQFBITS+1));
   logic signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-0:0] ang2fx, ang_subwholecycle, ang_addwholecycle;
   logic signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-1:0] ang2o;
   genvar i; generate
      for (i = 0; i < CHNLCNT; i++) begin
         if (FXASLOP) begin
            if      (ADDSUBSEL > 0) assign ang2fx[i] = (signed'({{(1){angfx[i][ANGEIBW+ANGBITW-1]}}, angfx[i]})) + (signed'({{(1){angi[i][ANGEIBW+ANGBITW-1]}}, angi[i]}));
            else if (ADDSUBSEL < 0) assign ang2fx[i] = (signed'({{(1){angfx[i][ANGEIBW+ANGBITW-1]}}, angfx[i]})) - (signed'({{(1){angi[i][ANGEIBW+ANGBITW-1]}}, angi[i]}));
            else                    assign ang2fx[i] = (signed'({{(1){angi [i][ANGEIBW+ANGBITW-1]}}, angi [i]}));
         end
         else begin
            if      (ADDSUBSEL > 0) assign ang2fx[i] = (signed'({{(1){angi[i][ANGEIBW+ANGBITW-1]}}, angi[i]})) + (signed'({{(1){angfx[i][ANGEIBW+ANGBITW-1]}}, angfx[i]}));
            else if (ADDSUBSEL < 0) assign ang2fx[i] = (signed'({{(1){angi[i][ANGEIBW+ANGBITW-1]}}, angi[i]})) - (signed'({{(1){angfx[i][ANGEIBW+ANGBITW-1]}}, angfx[i]}));
            else                    assign ang2fx[i] = (signed'({{(1){angi[i][ANGEIBW+ANGBITW-1]}}, angi[i]}));
         end
         assign ang_subwholecycle[i] = ang2fx[i] - wholcycle_angles;
         assign ang_addwholecycle[i] = ang2fx[i] + wholcycle_angles;
         assign ang2o[i] = ((signed'(ang2fx[i])) >= (signed'(halfcycle_angles))) ? ang_subwholecycle[i][ANGEIBW+ANGBITW-1:0]
                                                                                 : (((signed'(ang2fx[i])) < (-signed'(halfcycle_angles))) ? ang_addwholecycle[i][ANGEIBW+ANGBITW-1:0]
                                                                                                                                          : ang2fx[i][ANGEIBW+ANGBITW-1:0]);
      end
      pipedelay_taps_packedarray #(
         .DATABITW   (ANGEIBW + ANGBITW),
         .ARRAYSIZ   (CHNLCNT          ),
         .DELAYTAPS  (DELAYTAPS        )
      ) pipe2o(
         .clk     (clk  ),
         .aclr    (aclr ),
         .sclr    (sclr ),
         .clken   (clken),
         .x       (ang2o),
         .pipe_x  (ango )
      );
   endgenerate
endmodule
/*!
 * \brief 相位值相对参考相位整周修正
 * \details 若输入的相位值相对参考相位的差值处于正负半周之外，则将其折算至与参考相位的差值处于正负半周之内后输出，否则直接输出原值
 */
module cdc_phscyclmod_byref #(
   parameter int     ANGBITW   = 32,   ///< 相位角度值位宽
   parameter int     ANGEIBW   = 0,    ///< 相位角度值整数扩展位宽
   parameter longint PHSQSCALE = 16,   ///< 相位半周对应的量化值，Q.x型定点数，小数位数由 #PHSQFBITS 指定
   parameter int     PHSQFBITS = 0,    ///< 参数 #PHSQSCALE 的小数位数
   parameter bit     RFSBWEQIN = 1'b1, ///< 参考相位位宽与输入相位位宽相同标志，1'b0-参考相位比输入相位多一位符号位扩展，1'b1-参考相位与输入相位位宽相同
   parameter int     CHNLCNT   = 1,    ///< 数据通道数
   parameter int     DELAYTAPS = 0     ///< 延迟输出拍数。
                                       ///< 模块的运算共分两层：
                                       ///< -# 第一层在输入相位值的基础上加上输入的相位修正量；
                                       ///< -# 第二层用加上相位修正量的相位值与输入的参考相位值做差，并根据差值决定加上相位修正量的相位值的象限修正值。
                                       ///< \attention 信号 #angrf 的建立时间应与第二层运算的启动时间一致，否则将产生运算时序错误。
) (
   input  bit                                                     clk,  ///< 同步时钟
   input  wire                                                    aclr, ///< 异步复位信号，高电平(1)有效
   input  wire                                                    sclr, ///< 同步复位信号，高电平(1)有效
   input  wire                                                    clken,///< 时序逻辑使能信号，高电平(1)有效
   input  wire  signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-        1:0]  angi, ///< 待修正相位值
   input  wire  signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-RFSBWEQIN:0]  angrf,///< 参考相位值
   output logic signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-        0:0]  ango  ///< 修正后的相位值
);
   localparam int agfcbitw = cordic_pkg::fracbits_of_angle_bitw(
                                             .qscale     (PHSQSCALE  ), // 预留可以表示 -180° ~ +180° 角度范围的整数部分位宽
                                             .qfbits     (PHSQFBITS  ),
                                             .angle_bitw (ANGBITW    )
                                          );
   localparam bit signed[ANGEIBW+ANGBITW-RFSBWEQIN:0]onesixthcycl_angles = (PHSQFBITS > agfcbitw) ? ((PHSQSCALE/3)>>(PHSQFBITS-agfcbitw-0)) : ((PHSQSCALE/3)<<(agfcbitw-PHSQFBITS+0));
   localparam bit signed[ANGEIBW+ANGBITW-0:0]qurtcycle_angles = (agfcbitw > PHSQFBITS) ? (PHSQSCALE<<(agfcbitw-PHSQFBITS-1)) : (PHSQSCALE>>(PHSQFBITS-agfcbitw+1));
   localparam bit signed[ANGEIBW+ANGBITW-0:0]halfcycle_angles = (PHSQFBITS > agfcbitw) ? (PHSQSCALE>>(PHSQFBITS-agfcbitw-0)) : (PHSQSCALE<<(agfcbitw-PHSQFBITS+0));
   localparam bit signed[ANGEIBW+ANGBITW-0:0]wholcycle_angles = (PHSQFBITS > agfcbitw) ? (PHSQSCALE>>(PHSQFBITS-agfcbitw-1)) : (PHSQSCALE<<(agfcbitw-PHSQFBITS+1));
   logic signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-0:0] angsubrf, ang_subwholecycle, ang_addwholecycle;
   logic signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-0:0] ang2o;
   genvar i; generate
      for (i = 0; i < CHNLCNT; i++) begin
         assign ang_subwholecycle[i] = {angi[i][ANGEIBW+ANGBITW-1], angi[i]} - wholcycle_angles,
                ang_addwholecycle[i] = {angi[i][ANGEIBW+ANGBITW-1], angi[i]} + wholcycle_angles;
         assign angsubrf[i] = {angi[i][ANGEIBW+ANGBITW-(int'(RFSBWEQIN))], angi[i]} - ((signed'(angrf[i]) < -signed'(onesixthcycl_angles))
                                                                                       ? (-qurtcycle_angles)
                                                                                       : ((signed'(angrf[i]) >= signed'(onesixthcycl_angles))
                                                                                          ? qurtcycle_angles
                                                                                          : (signed'(angrf[i]))));
         assign ang2o[i] = (signed'(angsubrf[i]) >= signed'(halfcycle_angles)) ? ang_subwholecycle[i]
                                                                               : ((signed'(angsubrf[i]) < -signed'(halfcycle_angles)) ? ang_addwholecycle[i]
                                                                                                                                      : {angi[i][ANGBITW-1], angi[i]});
      end
      pipedelay_taps_packedarray #(
         .DATABITW   (ANGEIBW+ANGBITW+1),
         .ARRAYSIZ   (CHNLCNT          ),
         .DELAYTAPS  (DELAYTAPS        )
      ) pipe2o(
         .clk     (clk  ),
         .aclr    (aclr ),
         .sclr    (sclr ),
         .clken   (clken),
         .x       (ang2o),
         .pipe_x  (ango )
      );
   endgenerate
endmodule
/*!
 * \brief 相位值相对前一输出相位整周修正
 * \details 若输入的相位值相对参考相位的差值处于正负半周之外，则将其折算至与参考相位的差值处于正负半周之内后输出，否则直接输出原值
 */
module cdc_phscyclmod_byprev #(
   parameter int     ANGBITW   = 32,   ///< 相位角度值位宽
   parameter int     ANGEIBW   = 0,    ///< 相位角度值整数扩展位宽
   parameter longint PHSQSCALE = 16,   ///< 相位半周对应的量化值，Q.x型定点数，小数位数由 #PHSQFBITS 指定
   parameter int     PHSQFBITS = 0,    ///< 参数 #PHSQSCALE 的小数位数
   parameter int     CHNLCNT   = 1,    ///< 数据通道数
   parameter int     DELAYTAPS = 0     ///< 延迟输出拍数。
                                       ///< 模块的运算共分两层：
                                       ///< -# 第一层在输入相位值的基础上加上输入的相位修正量；
                                       ///< -# 第二层用加上相位修正量的相位值与输入的参考相位值做差，并根据差值决定加上相位修正量的相位值的象限修正值。
                                       ///< \attention 信号 #angrf 的建立时间应与第二层运算的启动时间一致，否则将产生运算时序错误。
) (
   input  bit                                            clk,  ///< 同步时钟
   input  wire                                           aclr, ///< 异步复位信号，高电平(1)有效
   input  wire                                           sclr, ///< 同步复位信号，高电平(1)有效
   input  wire                                           clken,///< 时序逻辑使能信号，高电平(1)有效
   input  wire  signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-1:0] angi, ///< 待修正相位值
   output logic signed[CHNLCNT-1:0][ANGEIBW+ANGBITW-0:0] ango  ///< 修正后的相位值
);
   logic signed[CHNLCNT-1:0][ANGBITW-0:0] angrf, ang2o;
   cdc_phscyclmod_byref #(
      .ANGBITW    (ANGBITW    ),
      .PHSQSCALE  (PHSQSCALE  ),
      .PHSQFBITS  (PHSQFBITS  ),
      .RFSBWEQIN  (1'b0       ),
      .CHNLCNT    (CHNLCNT    ),
      .DELAYTAPS  (0          )
   ) phscyclmod_byrefi(
      .clk  (clk  ),
      .aclr (aclr ),
      .sclr (sclr ),
      .clken(clken),
      .angi (angi ),
      .angrf(angrf),
      .ango (ang2o)
   );
   always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk, aclr)) begin
      if      (aclr) angrf <= {(CHNLCNT){{(ANGEIBW+ANGBITW+1){1'b0}}}};
      else if (sclr) angrf <= {(CHNLCNT){{(ANGEIBW+ANGBITW+1){1'b0}}}};
      else           angrf <= clken ? ang2o : angrf;
   end
   generate if (DELAYTAPS > 0) begin
      pipedelay_taps_packedarray #(
         .DATABITW   (ANGEIBW+ANGBITW+1),
         .ARRAYSIZ   (CHNLCNT          ),
         .DELAYTAPS  (DELAYTAPS-1      )
      ) pipeo(
         .clk     (clk  ),
         .aclr    (aclr ),
         .sclr    (sclr ),
         .clken   (clken),
         .x       (angrf),
         .pipe_x  (ango )
      );
   end
   else assign ango = ang2o;
   endgenerate
endmodule
