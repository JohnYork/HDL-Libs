/*!
 * \license SPDX-License-Identifier: MIT
 * \file convdb.svh
 * \brief dB数值转换模块头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`include "mux.svh"
`include "lmbd.svh"
`include "clshift.svh"
`ifdef  __INC_FROM_CONVDB__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_CONVDB__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __CONVDB_PKG__
 `define __CONVDB_PKG__
package convdb_pkg;
   /*! \brief 计算dB数值转换模块的输出时延 */
   function automatic int delaytaps_lshfix(
      int ivalbitw,
      int maxprelsh
   );
      return lmbd_pkg::delaytaps_recommend(ivalbitw) +
            1/*移位位数*/ +
            clshift_pkg::delaytaps_recommend(ivalbitw) +
            ((maxprelsh > 0) ? 1 : 0)/*fix lsh*/ +
            1/*db0,db1*/ +
            1/*db0+db1*/;
   endfunction
   function automatic int delaytaps(
      int ivalbitw
   );
      return delaytaps_lshfix(
                  .ivalbitw   (ivalbitw),
                  .maxprelsh  (0       )
               );
   endfunction
   /*! \brief 直接查表的数据位宽 */
   localparam int ival2db_bitw = 8;
   /*!
    * \brief 数值转换dB值的直接查找表深度
    * \param ivalbitw 待转换数值的位宽，0 表示根据默认的 #ival2db_bitw 计算
    * \return int型，查找表深度
    */
   function automatic int val2db_lutsiz(
      int ivalbitw
   );
      if (ivalbitw == 0)return 2**ival2db_bitw;
      else              return 2**ivalbitw;
   endfunction
   /*!
    * \brief 计算数值转换dB值的查找表中存储dB值所需的最小位宽
    * \param scaldb   dB量化值
    * \param ivalbitw 待转换数值的位宽，0 表示根据默认的 #ival2db_bitw 计算
    * \return int型，存储dB值所需的最小位宽
    */
   function automatic int mindbbitw_wantedbydblut(
      int scaldb,
      int ivalbitw
   );
      longint pp;
      int signed db;
      if (ivalbitw == 0)pp = 2**ival2db_bitw - 1;
      else              pp = 2**ivalbitw - 1;
      pp = (pp << 30);
      db = ((miscs::q15ilog10ofq30(pp)*scaldb*5)>>14);
      return miscs::minbitw_of_integer(db, 32);
   endfunction
   /*!
    * \brief 数值转换dB值
    * \param ival2cnv 待转换的数值
    * \param scaldb   dB数值量化值
    * \param q15dbfix Q.15数表示的dB值修正量
    * \return Q.15数表示的经过量化的dB值
    */
   function automatic int signed convdb_val2db(
      longint    ival2lut,
      int        scaldb,
      int signed q15dbfix
   );
      longint    pp;
      int signed db;
      if (ival2lut == 0) return int'(signed'({1'b1, {($bits(int)-1){1'b0}}}));
      pp = (ival2lut << 30);
      db = miscs::q15ilog10ofq30(pp)*scaldb*10;
      return db + q15dbfix;
   endfunction
   /*!
    * \brief 信号位宽中根据移位位数转换dB值的最大左移位数
    * \param ivalbitw 信号数据位宽
    * \return int型，最大左移位数
    */
   function automatic int max_lshbits4convdb(
      int ivalbitw
   );
      return ivalbitw - ival2db_bitw + 1;
   endfunction
   /*!
    * \brief 计算移位转换dB值查找表中存储dB值所需的最小位数
    * \param maxlshbits 最大左移位数
    * \param scaldb     dB数值量化值
    * \return int型，存储dB值需要的最小位数
    */
   function automatic int mindbbitw_wantedbybslut(
      int maxlshbits,
      int scaldb
   );
      longint pp, q15log10_2;
      int signed db;
      q15log10_2 = miscs::q15ilog10ofq30(2<<30);
      pp = q15log10_2*maxlshbits;
      pp = ((pp*scaldb*5)>>14);
      return miscs::minbitw_of_longint(pp, 64);
   endfunction
   /*!
    * \brief 左移移位位数转换dB值
    * \param lshbits  待转换的左移位数
    * \param scaldb   dB数值量化值
    * \param q15dbfix Q.15数表示的dB值修正量
    */
   function automatic int signed convdb_bs2db(
      int        lshbits,
      int        scaldb,
      int signed q15dbfix
   );
      return miscs::q15ilog10ofq30(2<<30)*lshbits*scaldb*10 + q15dbfix;
   endfunction
endpackage
 `endif//__CONVDB_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef __CONVDB_ITF__
 `define __CONVDB_ITF__

 `endif//__CONVDB_ITF__

`else
 `undef  __ITF_BANNED__
`endif
