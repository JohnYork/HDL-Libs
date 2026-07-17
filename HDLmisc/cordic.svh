/*!
 * \license SPDX-License-Identifier: MIT
 * \file cordic.svh
 * \brief CORDIC算法模块头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`include "miscs.svh"
`include "lmbd.svh"
`include "clshift.svh"

`ifdef  __INC_FROM_CORDIC__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_CORDIC__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __CORDIC_PKG__
 `define __CORDIC_PKG__
package cordic_pkg;
   /*! \brief CORDIC旋转坐标系 */
   typedef enum {
      cdcrs_circular   = 0,   ///< 圆坐标旋转
      cdcrs_linear     = 1,   ///< 线性坐标旋转
      cdcrs_hyperbolic = 2    ///< 双曲坐标旋转
   } cdcrs_t;
   /*! \brief CORDIC驱动模式 */
   typedef enum bit {
      cdcdm_vec = 1'b0,       ///< 矢量驱动模式——驱动 y 值归零
      cdcdm_ang = 1'b1        ///< 角度驱动模式——驱动 z 值归零
   } cdcdm_t;
   /*!
    * \brief 根据角度值的小数位宽计算角度值的总位宽
    * \param qscale         半周数值量化值，即半周角度（半圆角度，180度）对应的量化数值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定。
    *                       例如：弧度的半周量化值是 pi ，以度为单位的角度半周量化值是 180
    * \param qfbits         定点参数 #qscale 的小数位宽
    * \param angle_fracbits 角度的小数位宽
    * \return int型，角度值（有符号数）的总位宽
    */
   function automatic int bitwof_angle_frm_fracbits(
      longint qscale,
      int     qfbits,
      int     angle_fracbits
   );
      longint cmprval;
      int qsbw, qsibw;
      qsbw = miscs::bits_of_longint(
         .value   (qscale        ),
         .maxbits ($bits(longint)));
      cmprval = 1;
      cmprval <<= (qsbw-1);
      qsibw = qsbw - qfbits;
      if (cmprval >= qscale)
         qsibw --;
      return angle_fracbits + qsibw/*有效整数位宽*/ + 1/* 符号位 */;
   endfunction
   /*!
    * \brief 根据给定量化值量化的角度值的总位宽计算该量化值量化的角度值的小数位宽
    * \param qscale     半周数值量化值，即半周角度（半圆角度，180度）对应的量化数值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定。
    *                   例如：弧度的半周量化值是 pi ，以度为单位的角度半周量化值是 180
    * \param qfbits     定点参数 #qscale 的小数位宽
    * \param angle_bitw 用给定量化值量化的角度（弧度）的总位宽
    * \return int型，角度值（有符号数）的小数位宽
    */
   function automatic int fracbits_of_angle_bitw(
      longint qscale,
      int     qfbits,
      int     angle_bitw
   );
      longint cmprval;
      int qsbw, qsibw;
      qsbw = miscs::bits_of_longint(
         .value   (qscale        ),
         .maxbits ($bits(longint)));
      cmprval = 1;
      cmprval <<= (qsbw-1);
      qsibw = qsbw - qfbits;
      if (cmprval >= qscale)
         qsibw --;
      return angle_bitw - qsibw/*有效整数位宽*/ - 1/* 符号位 */;
   endfunction
   /*!
    * \brief 根据归一化二维矢量分量的小数位宽计算归一化二维矢量分量的总位宽
    * \param vp_fracbits 二维矢量分量的小数位宽
    * \return int型，二维矢量分量的总位宽（有符号数）
    */
   function automatic int bitwof_vecpart_frm_fracbits(int vp_fracbits);
      return vp_fracbits + 1/* 最多表示 1.0 */ + 1/* 符号位 */;
   endfunction
   /*!
    * \brief 根据归一化二维矢量分量的总位宽计算其小数位宽
    * \param vp_bitw 二维矢量分量的总位宽
    * \return int型，二维矢量分量的小数位宽
    */
   function automatic int fracbits_of_vecpart_bitw(int vp_bitw);
      return vp_bitw - 1/* 最多表示 1.0 */ - 1/* 符号位 */;
   endfunction
   /*!
    * \brief 根据角度值（弧度）的小数位宽计算圆坐标模式下推荐的二维矢量分量位宽（包含符号位）
    * \param rotsys         旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param angle_qscale   对圆坐标模式：本参数表示半周数值量化值，即半周角度（半圆角度，180度）对应的量化数值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定；
    *                       对线性坐标模式：本参数不具备任何意义，函数也仅返回本参数与 #angle_qfbits #angle_fracbits 一起表示的数值的最小位宽；
    *                       对双曲坐标模式：本参数表示反双曲正切函数值域极值的两倍数值的量化值，即双曲角度“2”对应的量化数值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定；
    *                       例如：圆坐标模式中，弧度的半周量化值是 pi ，以度为单位的角度半周量化值是 180
    * \param angle_qfbits   定点参数 #angle_qscale 的小数位宽
    * \param angle_fracbits 角度（弧度）的小数位宽
    * \return int型，推荐的二维矢量分量位宽（包含符号位）
    */
   function automatic int recommend_vecpartbitw_by_anglefracbits(
      cdcrs_t rotsys,
      longint angle_qscale,
      int     angle_qfbits,
      int     angle_fracbits
   );
      if (rotsys == cdcrs_linear) return bitwof_angle_frm_fracbits(  .qscale(angle_qscale),  .qfbits(angle_qfbits),  .angle_fracbits(angle_fracbits));
      else begin
         miscs::sfpt sfp_angle, sfp_max_vecpart, sfp_angscal;
         // 最小角度值转换为单位为弧度的角度值
         sfp_angle = miscs::sfp_div(miscs::sfp_makesfp_byqp(1, angle_fracbits), miscs::sfp_makesfp_byqp(angle_qscale, angle_qfbits));
         if (rotsys == cdcrs_circular) sfp_angscal = miscs::sfp_pi;
         else                          sfp_angscal = miscs::sfp_two;
         sfp_angle = miscs::sfp_mul(sfp_angle, sfp_angscal);
         if (rotsys == cdcrs_circular) begin
            // x/y = cotan(sfp_angle), y 取1，则x便是矢量分类最大值
            sfp_max_vecpart = miscs::sfp_div(miscs::sfp_cos(sfp_angle), miscs::sfp_sin(sfp_angle));
         end else begin
            // x/y = cotanh(sfp_angle) = cosh(sfp_angle)/sinh(sfp_angle)，y 取1，则x便是矢量分类最大值
            sfp_max_vecpart = miscs::sfp_div(miscs::sfp_cosh(sfp_angle), miscs::sfp_sinh(sfp_angle));
         end
         return sfp_max_vecpart.expn;
      end
   endfunction
   /*!
    * \brief 根据输入二维矢量分量的位宽计算推荐的旋转角度小数位宽
    * \param rotsys         旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param angle_qscale   对圆坐标模式：本参数表示半周数值量化值，即半周角度（半圆角度，180度）对应的量化数值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定；
    *                       对线性坐标模式：本参数不具备任何意义，函数也仅返回本参数与 #angle_qfbits #angle_fracbits 一起表示的数值的最小位宽；
    *                       对双曲坐标模式：本参数表示反双曲正切函数值域极值的两倍数值的量化值，即双曲角度“2”对应的量化数值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定；
    *                       例如：圆坐标模式中，弧度的半周量化值是 pi ，以度为单位的角度半周量化值是 180
    * \param angle_qfbits   定点参数 #angle_qscale 的小数位宽
    * \param vp_bitw        输入二维矢量分量的位宽
    * \return int型，推荐的旋转角度小数位宽
    */
   function automatic int recommend_angle_fracbits_byvecpartbitw(
      cdcrs_t rotsys,
      longint angle_qscale,
      int     angle_qfbits,
      int     vp_bitw
   );
      if (rotsys == cdcrs_linear) return fracbits_of_angle_bitw(  .qscale(angle_qscale),  .qfbits(angle_qfbits),.angle_bitw(vp_bitw));
      else begin
         longint min_angle;
         miscs::sfpt sfp_min_angle, sfp_angscal;
         // 计算位宽为 #vp_bitw 的矢量可表示的最小角度弧度值
         if (rotsys == cdcrs_circular) begin
            min_angle = miscs::q61atan2i2q(1, (longint'(2))**(vp_bitw-1+1)-1);
            sfp_angscal = miscs::sfp_pi;
         end else begin
            min_angle = miscs::q61atanh2i2q(1, (longint'(2))**(vp_bitw-1+1)-1);
            sfp_angscal = miscs::sfp_two;
         end
         // 最小角度弧度值转换为 #miscs::sfpt 型的半周值
         sfp_min_angle = miscs::sfp_div(miscs::sfp_makesfp_byqp(min_angle, 61), sfp_angscal);
         // 乘以角度量化值
         sfp_min_angle = miscs::sfp_mul(sfp_min_angle, miscs::sfp_makesfp_byqp(angle_qscale, angle_qfbits));
         /* 1 < sfp_min_angle.mnts <= 0.5 ， sfp_min_angle.expn 表示的最小角度是 0.5*2^sfp_min_angle.expn ，
         * 要保留的小数位数保证能表示最小的角度 0.5*2^sfp_min_angle.expn ，则正好取小数位数为 -sfp_min_angle.expn 即可。
         */
         return -sfp_min_angle.expn;
      end
   endfunction
   /*! \brief 推荐的cordic运算器迭代数据位宽信息 */
   typedef struct packed {
      int ang_fracbits; ///< 推荐的迭代角度小数位宽
      int vpnex_bitw;   ///< 推荐的未扩展迭代矢量位宽
   } recommend_iterat_bitwinfo_t;
   function automatic int ang_fracbits_of_recommend_iterat_bitwinfo(recommend_iterat_bitwinfo_t ribi);
      return ribi.ang_fracbits;
   endfunction
   function automatic int vpnex_bitw_of_recommend_iterat_bitwinfo(recommend_iterat_bitwinfo_t ribi);
      return ribi.vpnex_bitw;
   endfunction
   /*!
    * \brief 计算cordic运算器推荐的迭代数据位宽信息
    * \param rotsys       旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param oangle_bitw  输出角度数据位宽
    * \param ovp_bitw     输出矢量数据位宽
    * \param angle_qscale 以 Q.x 定点数形式表示的角度量化值
    * \param angle_qfbits #angle_qscale 的小数位数
    * \param fixed_drvmod 固定驱动模式指示标志，-1:不指定固定的驱动模式，int'(cdcdm_vec):固定矢量驱动模式，int'(cdcdm_ang):固定角度驱动模式
    * \return recommend_iterat_bitwinfo_t型，cordic运算器推荐的迭代数据位宽信息
    */
   function automatic recommend_iterat_bitwinfo_t recommend_iterating_bitwinfo(
      cdcrs_t    rotsys,
      int        oangle_bitw,
      int        ovp_bitw,
      longint    angle_qscale,
      int        angle_qfbits,
      int signed fixed_drvmod
   );
      recommend_iterat_bitwinfo_t ribi;
      int oa_fracbits, rvbyoa_vp_bitw, vecdrv_r_vpnex_bitw, vecdrv_ra_fracbits, rabyov_fracbits, angdrv_ra_fracbits, angdrv_r_vpnex_bitw;
      // 输出角度的小数位宽
      oa_fracbits = fracbits_of_angle_bitw(angle_qscale, angle_qfbits, oangle_bitw);
      if (fixed_drvmod != int'(cdcdm_ang)) begin
         // 未指定角度驱动模式，则需要兼容矢量驱动模式。
         // 矢量驱动模式是将输入矢量的幅值和角度输出至输出端矢量分量和角度
         // 输出端矢量分量的精度由 #ovp_bitw 确定，需要保证输出角度的精度

         // 根据输出角度小数位宽估计建议的迭代矢量位宽
         rvbyoa_vp_bitw = recommend_vecpartbitw_by_anglefracbits(rotsys, angle_qscale, angle_qfbits, oa_fracbits);
         // 矢量驱动模式下的迭代矢量位宽——根据输出角度小数位宽估计的建议迭代矢量位宽 #rvbyoa_vp_bitw 和 输出矢量位宽 #ovp_bitw 之间的最大值
         vecdrv_r_vpnex_bitw = miscs::maxu(rvbyoa_vp_bitw, ovp_bitw);
         // 矢量驱动模式下的迭代角度小数位宽——根据矢量驱动模式下的迭代矢量位宽 #vecdrv_r_vpnex_bitw 计算推荐值
         vecdrv_ra_fracbits = recommend_angle_fracbits_byvecpartbitw(rotsys, angle_qscale, angle_qfbits, vecdrv_r_vpnex_bitw);
      end else begin
         rvbyoa_vp_bitw = 0;
         vecdrv_r_vpnex_bitw = 0;
         vecdrv_ra_fracbits = 0;
      end
      if (fixed_drvmod != int'(cdcdm_vec)) begin
         // 未指定矢量驱动模式，则需要兼容角度驱动模式。
         // 角度驱动模式是将输入矢量根据输入角度旋转后输出至输出端矢量，输出端角度归零。
         // 因输出端角度必然归零，输出角度精度不再被考虑；
         // 输出端矢量分量的精度由 #ovp_bitw 确定，其需要的旋转角度精度低于输入角度精度时，对输入角度保留足够高位位宽即可，需要的旋转角度精度高于输入角度精度时，对输入角度低位补零。

         // 根据输出矢量位宽估计建议的迭代角度小数位宽
         rabyov_fracbits = recommend_angle_fracbits_byvecpartbitw(rotsys, angle_qscale, angle_qfbits, ovp_bitw);
         // 角度驱动模式下的迭代角度小数位宽——根据输出矢量位宽估计的建议迭代角度小数位宽 #rabyov_fracbits 和 输出角度小数位宽 #oa_fracbits 之间的最大值
         angdrv_ra_fracbits = miscs::maxu(rabyov_fracbits, oa_fracbits);
         // 角度驱动模式下的迭代矢量位宽——根据角度驱动模式下的迭代角度小数位宽 #angdrv_ra_fracbits 计算推荐值
         angdrv_r_vpnex_bitw = recommend_vecpartbitw_by_anglefracbits(rotsys, angle_qscale, angle_qfbits, angdrv_ra_fracbits);
      end else begin
         rabyov_fracbits = 0;
         angdrv_r_vpnex_bitw = 0;
         angdrv_ra_fracbits = 0;
      end
      if (fixed_drvmod == int'(cdcdm_ang)) begin
         ribi.ang_fracbits = angdrv_ra_fracbits;
         ribi.vpnex_bitw = angdrv_r_vpnex_bitw;
      end else if (fixed_drvmod == int'(cdcdm_vec)) begin
         ribi.ang_fracbits = vecdrv_ra_fracbits;
         ribi.vpnex_bitw = vecdrv_r_vpnex_bitw;
      end else begin
         ribi.ang_fracbits = miscs::maxu(angdrv_ra_fracbits, vecdrv_ra_fracbits);
         ribi.vpnex_bitw = miscs::maxu(angdrv_r_vpnex_bitw, vecdrv_r_vpnex_bitw);
      end
      return ribi;
   endfunction
   /*!
    * \brief 角度驱动模式下的建议迭代次数
    * \attention 要求输入的旋转角度范围在 [-pi/2, pi/2] 之间。
    * \param rotsys         旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param angle_qscale   对圆坐标模式：本参数表示半周数值量化值，即半周角度（半圆角度，180度）对应的量化数值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定；
    *                       对线性坐标模式：本参数不具备任何意义，函数也仅返回本参数与 #angle_qfbits #angle_fracbits 一起表示的数值的最小位宽；
    *                       对双曲坐标模式：本参数表示反双曲正切函数值域极值的两倍数值的量化值，即双曲角度“2”对应的量化数值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定；
    *                       例如：圆坐标模式中，弧度的半周量化值是 pi ，以度为单位的角度半周量化值是 180
    * \param angle_qfbits   定点参数 #angle_qscale 的小数位宽
    * \param angle_fracbits 输入旋转角度值的小数位数。
    * \return int型，建议的迭代次数
    */
   function automatic int recommend_iterating_times_driven_byangle(
      cdcrs_t rotsys,
      longint angle_qscale,
      int     angle_qfbits,
      int     angle_fracbits
   );
      if (rotsys == cdcrs_linear) return bitwof_angle_frm_fracbits(  .qscale(angle_qscale),  .qfbits(angle_qfbits),  .angle_fracbits(angle_fracbits));
      else begin
         longint atan_res, ax, ress, prev_ress;
         miscs::sfpt min_angle, sfp_angscal, tan_min_angle;
         // 求 miscs::sfpt 型的最小角度值对应的弧度值
         min_angle = miscs::sfp_makesfp_byqp(1, angle_fracbits);                                      // 最小角度数值（圆坐标）
         min_angle = miscs::sfp_div(min_angle, miscs::sfp_makesfp_byqp(angle_qscale, angle_qfbits));  // 最小角度量化系数由 angle_qscale 转为 半周 （圆坐标）
         if (rotsys == cdcrs_circular) sfp_angscal = miscs::sfp_pi;
         else                          sfp_angscal = miscs::sfp_two;
         min_angle = miscs::sfp_mul(min_angle, sfp_angscal);                                          // 最小角度量化系数由 半周 转为 弧度 （圆坐标）
         /* 查找最小角度对应的最大迭代次数——超过该迭代次数的迭代运算使得迭代的角度增量为零
          * 令最大迭代次数为 i ，则应有 atan(1/2^i) < min_angle
          * 即 1/2^i < tan(min_angle) ,
          *    2^i > cotan(min_angle) = cos(min_angle)/sin(min_angle)
          */
         tan_min_angle = miscs::sfp_div(miscs::sfp_cos(min_angle), miscs::sfp_sin(min_angle));
         return tan_min_angle.expn;
      end
   endfunction
   /*!
    * \brief 矢量驱动模式下的建议迭代次数
    * \attention 
    * #- 矢量模式下的建议迭代次数与二维向量分量的有效位宽一致
    * #- 矢量模式下必须对二维向量分量分别取绝对值后再参与迭代，否则迭代将会发散
    * #- 矢量模式下必须选绝对值较大的分量来作为乘以2^-i的量，以加快收敛速度
    */
   function automatic int recommend_iterating_times_driven_byvector(
      int vecbitw
   );
      return vecbitw;
   endfunction
   /*!
    * \brief 根据迭代数据位宽信息计算cordic运算器的建议迭代次数
    * \param rotsys       旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param r_fracbits   迭代角度小数位宽
    * \param r_vpnex_bitw 未扩展整数位的迭代矢量位宽
    * \param angle_qscale 以 Q.x 定点数形式表示的角度量化值
    * \param angle_qfbits #angle_qscale 的小数位数
    * \param fixed_drvmod 固定驱动模式指示标志
    * \return int型，根据迭代数据位宽信息计算出的建议迭代次数
    */
   function automatic int recommend_iterating_times_by_iterating_bitws(
      cdcrs_t    rotsys,
      int        r_fracbits,
      int        r_vpnex_bitw,
      longint    angle_qscale,
      int        angle_qfbits,
      int signed fixed_drvmod
   );
      int r_vp_bitw, r_it_times;
      r_vp_bitw = r_vpnex_bitw;
      if (rotsys == cdcrs_hyperbolic) r_vp_bitw = r_vp_bitw + 1;
      if      (fixed_drvmod == cdcdm_ang) r_it_times = recommend_iterating_times_driven_byangle(rotsys, angle_qscale, angle_qfbits, r_fracbits);
      else if (fixed_drvmod == cdcdm_vec) r_it_times = recommend_iterating_times_driven_byvector(r_vp_bitw);
      else                                r_it_times = miscs::maxu(
                                             recommend_iterating_times_driven_byangle(rotsys, angle_qscale, angle_qfbits, r_fracbits),
                                             recommend_iterating_times_driven_byvector(r_vp_bitw)
                                          );
      return r_it_times;
   endfunction
   /*!
    * \brief 计算cordic运算器推荐的迭代次数
    * \param rotsys       旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param oangle_bitw  输出角度数据位宽
    * \param ovp_bitw     输出矢量数据位宽
    * \param angle_qscale 以 Q.x 定点数形式表示的角度量化值
    * \param angle_qfbits #angle_qscale 的小数位数
    * \param fixed_drvmod 固定驱动模式指示标志
    */
   function automatic int recommend_iterating_times(
      cdcrs_t    rotsys,
      int        oangle_bitw,
      int        ovp_bitw,
      longint    angle_qscale,
      int        angle_qfbits,
      int signed fixed_drvmod
   );
      recommend_iterat_bitwinfo_t ribi;
      ribi = recommend_iterating_bitwinfo(rotsys, oangle_bitw, ovp_bitw, angle_qscale, angle_qfbits, fixed_drvmod);
      return recommend_iterating_times_by_iterating_bitws(rotsys, ang_fracbits_of_recommend_iterat_bitwinfo(ribi), vpnex_bitw_of_recommend_iterat_bitwinfo(ribi), angle_qscale, angle_qfbits, fixed_drvmod);
   endfunction
   /*!
    * \brief 根据cordic运算器的迭代次数计算运算时延
    * \param rotsys       旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param iterat_count 给定的运算器迭代次数
    * \return int型，cordic运算器的运算时延拍数
    */
   function automatic int cordic_delaytaps_of_iterating_times(
      cdcrs_t rotsys,
      int     iterat_count
   );
      int r_it_times;
      r_it_times = iterat_count;
      if (rotsys == cdcrs_hyperbolic) begin
         // 双曲模式下需要重复迭代的步骤的个数：
         // 参考——知乎网站上——《硬件算法笔记22——CORDIC算法》，广义CORDIC算法，双曲坐标旋转的收敛问题
         // 对 i = 4, 13, 40, 121, ..., j, 3j+1, ... 的迭代，重复进行一次以促进收敛...
         // i =      4,          13,               40,                       121,               ...
         //   = 3^1 + 3^0, 3^2 + 3^1 + 3^0, 3^3 + 3^2 + 3^1 + 3^0, 3^4 + 3^3 + 3^2 + 3^1 + 3^0, ...
         // n =      1,          2,                3,                         4,                ...
         // 上面的序列中，n是需要重复的迭代步骤编号。
         // 可见，需要重复迭代的步骤编号是基为3的等比数列的前n项部分和，即：
         //               n
         // idx_it2rep =  ∑ (3^i) = 4*(1-3^n)/(1-3) = 2*(3^n - 1)
         //              i=1
         // 则对总共k次迭代，需要重复的迭代步骤个数n为：
         // 2*(3^n - 1) = k => n = int(log3(int(k/2) + 1))
         r_it_times = r_it_times - 1/*双曲坐标旋转迭代从索引1开始*/ + (miscs::q15mul(miscs::q15ilogofq30(longint'((r_it_times/2) + 1)<<<30), int'((0.91023922662683739361424016573611/*1/loge3*/+0.0000152587890625)*2**15))>>15);
      end
      return 1/*abs(input)*/ + r_it_times + 1/*mult fact_cosine*/;
   endfunction
   /*!
    * \brief 计算cordic运算器运算时延
    * \param rotsys       旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param oangle_bitw  输出角度数据位宽
    * \param ovp_bitw     输出矢量数据位宽
    * \param angle_qscale 以 Q.x 定点数形式表示的角度量化值
    * \param angle_qfbits #angle_qscale 的小数位数
    * \param iterat_count 用户指定的迭代次数，0表示由程序自动计算保证最高输出精度的迭代次数
    * \param fixed_drvmod 固定驱动模式指示标志
    * \return int型，cordic运算器的运算时延拍数
    */
   function automatic int cordic_delaytaps(
      cdcrs_t    rotsys,
      int        oangle_bitw,
      int        ovp_bitw,
      longint    angle_qscale,
      int        angle_qfbits,
      int        iterat_count,
      int signed fixed_drvmod
   );
      int r_it_times;
      if (iterat_count == 0)
         r_it_times = recommend_iterating_times(rotsys, oangle_bitw, ovp_bitw, angle_qscale, angle_qfbits, fixed_drvmod);
      else
         r_it_times = iterat_count;
      return cordic_delaytaps_of_iterating_times(rotsys, r_it_times);
   endfunction
   /*!
    * \brief Q.61角度转换为给定量化值的定点角度值
    * \param rotsys         旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param ang            待转换的角度值，对圆坐标旋转，其单位是弧度；对线性坐标旋转，无单位；对双曲坐标旋转，单位不确定（因双曲坐标旋转是伪旋转，其几何意义并不直观）
    * \param angle_qscale   单位角度量化值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定。
    *                       对圆坐标旋转：半周数值量化值，即半周角度（半圆角度，180度）对应的量化数值；
    *                       对线性坐标旋转：无意义，不使用该参数，可默认填0；
    *                       对双曲坐标旋转：数值“2”的量化值。
    *                       例如：对圆坐标旋转来说，弧度的半周量化值是 pi ，以度为单位的角度半周量化值是 180
    * \param angle_qfbits   定点参数 #angle_qscale 的小数位宽
    * \param angle_fracbits 输出角度值的小数位数。
    */
   function automatic longint signed q61angle2scale(
      cdcrs_t        rotsys,
      longint signed ang,
      longint        angle_qscale,
      int            angle_qfbits,
      int            angle_fracbits
   );
      miscs::sfpt sfp_angle, ang_scal;
      int signed rshbits;
      if (rotsys == cdcrs_circular) ang_scal = miscs::sfp_pi;
      else                          ang_scal = miscs::sfp_one;
      /* \attention 这里的 #ang_scal 在双曲坐标时要用不同于 #cordic_pkg::#recommend_vecpartbitw_by_anglefracbits 、 #cordic_pkg::#recommend_angle_fracbits_byvecpartbitw 、 
       * #cordic_pkg::#recommend_iterating_times_driven_byangle 使用的 #miscs::#sfp_two 的 #miscs::#sfp_one ，原因是：
       * 圆坐标旋转时，输入坐标在内部是被 #pi 值归一化，则当输入坐标以 #pi 为倍数时即可正常转换；
       * 而双曲坐标旋转时，输入坐标在内部是被 #2 值归一化，则输入坐标也应该是以 #2 为倍数才能正确转换，这与我们习惯使用的以 #1 为倍数不符，当输入坐标按 #1 为倍数输入时，这里的转换
       * 仍然按 #2 为倍数转换的话，则实际转换出的角度将会是期望值的一半，与习惯期望值不符。
       * 为改正该问题，特将这里的 #ang_scal 设置为 #miscs::sfp_one 来匹配习惯用法。
       */
      sfp_angle = miscs::sfp_div(miscs::sfp_makesfp_byqp(ang, 61), ang_scal);
      sfp_angle = miscs::sfp_mul(sfp_angle, miscs::sfp_makesfp_byqp(angle_qscale, angle_qfbits));
      rshbits = 61 - angle_fracbits - sfp_angle.expn;
      if (rshbits >= 0) return (sfp_angle.mnts>>>(+rshbits));
      else              return (sfp_angle.mnts<<<(-rshbits));
   endfunction
   /*!
    * \brief 按给定量化值量化的整数角度值转换为给定量化值的定点角度值
    * \param qsang    按给定量化值量化的整数角度值
    * \param qscale   单位角度量化值，以Q.X定点数表示，定点数小数位宽由 #qbits 指定。
    *                 对圆坐标旋转：半周数值量化值，即半周角度（半圆角度，180度）对应的量化数值；
    *                 对线性坐标旋转：无意义，不使用该参数，可默认填0；
    *                 对双曲坐标旋转：数值“2”的量化值。
    *                 例如：对圆坐标旋转来说，弧度的半周量化值是 pi ，以度为单位的角度半周量化值是 180
    * \param qfbits   定点参数 #angle_qscale 的小数位宽
    * \param fracbits 输出角度值的小数位数。
    */
   function automatic longint signed qsangle2scale(
      longint signed qsang,
      longint        qscale,
      int            qfbits,
      int            fracbits
   );
      int signed rshbits;
      miscs::sfpt sfp_angle = miscs::sfp_div(miscs::sfp_makesfp_byqp(qsang, qfbits), miscs::sfp_makesfp_byqp(qscale, qfbits));
      rshbits = 61 - fracbits - sfp_angle.expn;
      if (rshbits >= 0) return (sfp_angle.mnts>>>(+rshbits));
      else              return (sfp_angle.mnts<<<(-rshbits));
   endfunction
   /*!
    * \brief Q.61角度迭代差值
    * \attention 当设计中有多个 CORDIC 实例时，可以用本函数预先产生角度迭代差值数组，并作为例化参数传递给实例，避免多个 CORDIC 实例例化时重复计算迭代差值，影响编译速度
    * \param rotsys     旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param idx_iterat 迭代索引，当 rotsys == cordic_pkg::cdcrs_hyperbolic 时从 1 开始计，其他值则从 0 开始计
    * \return Q.61数表示的角度迭代差值
    */
   function automatic longint signed q61dzofiteration(
      cdcrs_t        rotsys,
      int            idx_iterat
   );
      if      (rotsys == cdcrs_linear)   return (64'd1<<(61-idx_iterat));
      else if (rotsys == cdcrs_circular) return miscs::q61atan2i2q(1, (64'd2)**idx_iterat);
      else if (idx_iterat > 0)           return miscs::q61atanh2i2q(1, (64'd2)**idx_iterat);
      else                               return 64'd0;
   endfunction
   /*!
    * \brief 矢量幅度归一化运算时延
    * \param rotsys     旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param ivp_bitw   输入矢量数据有效位宽，不包含符号位，实际位宽是 ivp_bitw + 1
    * \return int型，矢量幅度归一化运算时延对应时钟拍数
    */
   function automatic int magnorm_delaytaps(
      cdcrs_t    rotsys,
      int        ivp_bitw
   );
      int vpbw2sh;
      vpbw2sh = ivp_bitw + 1;
      if (rotsys == cdcrs_hyperbolic) vpbw2sh = vpbw2sh + 1;
      return lmbd_pkg::delaytaps_recommend(.databitw(vpbw2sh)) +
             1 +
             clshift_pkg::delaytaps_recommend(.databitw(vpbw2sh));
   endfunction
   /*!
    * \brief 矢量幅度归一化分量左移位数的位宽推荐值
    * \param ivp_bitw   输入矢量数据有效位宽，不包含符号位，实际位宽是 ivp_bitw + 1
    * \return int型，矢量幅度归一化分量左移位数的位宽推荐值，最小返回 1 。
    */
   function automatic int magnorm_recommend_bitwof_lshbsbw(
      int ivp_bitw
   );
      return miscs::minbitw_of_integer(
                     .value  (ivp_bitw    ),
                     .maxbitw($bits(int)  )
                  );
   endfunction
   /*!
    * \brief 矢量幅度归一化恢复运算时延
    * \param rotsys     旋转坐标模式——cordic_pkg::cdcrs_circular ， cordic_pkg::cdcrs_linear ， cordic_pkg::cdcrs_hyperbolic
    * \param ovp_bitw   输出的归一化恢复后矢量数据有效位宽，不包含符号位，实际位宽是 ovp_bitw + 1
    * \return int型，矢量幅度归一化运算时延对应时钟拍数
    */
   function automatic int magnorm_restr_delaytaps(
      cdcrs_t    rotsys,
      int        ovp_bitw
   );
      int vpbw2sh;
      vpbw2sh = ovp_bitw + 1;
      if (rotsys == cdcrs_hyperbolic) vpbw2sh = vpbw2sh + 1;
      return clshift_pkg::delaytaps_recommend(.databitw(vpbw2sh));
   endfunction
endpackage
 `endif  //__CORDIC_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__INC_INTERFACE__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__
`else
 `undef  __ITF_BANNED__
`endif

