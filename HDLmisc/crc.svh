/*!
 * \license SPDX-License-Identifier: MIT
 * \file crc.svh
 * \brief 循环冗余码校验
 * \author JohnYork <johnyork@yeah.net>
 */

`ifdef  __INC_FROM_CRC__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_CRC__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __CRC_PKG__
 `define __CRC_PKG__
package crc_pkg;
   /*! \brief 最大校验和位数 */
   localparam int maxbits = 64;
   /*! \brief CRC校验和配置 */
   typedef struct packed {
      int               csbits;  ///< 校验和位宽
      bit[maxbits-1:0]  poly;    ///< 校验和生成多项式
      bit[maxbits-1:0]  initval; ///< 寄存器初始值
      bit[maxbits-1:0]  endxorv; ///< 校验结束输出前的异或值
      bit               ibitrev; ///< 输入按位反转标志
      bit               obitrev; ///< 输出按位反转标志
   } crcCfg;
   function automatic int csbits_ofcrcCfg(crcCfg cc);
      return cc.csbits;
   endfunction
   function automatic bit[maxbits-1:0] poly_ofcrcCfg(crcCfg cc);
      return cc.poly;
   endfunction
   function automatic bit[maxbits-1:0] initval_ofcrcCfg(crcCfg cc);
      return cc.initval;
   endfunction
   function automatic bit[maxbits-1:0] endxorv_ofcrcCfg(crcCfg cc);
      return cc.endxorv;
   endfunction
   function automatic bit ibitrev_ofcrcCfg(crcCfg cc);
      return cc.ibitrev;
   endfunction
   function automatic bit obitrev_ofcrcCfg(crcCfg cc);
      return cc.obitrev;
   endfunction
   /*!
    * \brief 生成CRC校验和配置参数
    * \attention
    * -# CRC标准中输入和输出按位反转没有统一的规定，但二者不同的标准使用较少。
    * -# 输入、输出按位反转多用于处理字节流的系统（如以太网、存储），与LSB优先处理方式匹配
    * -# 输入、输出不按位反转多用于处理比特流的系统（如某些通信协议），与MSB优先处理方式匹配
    */
   function automatic crcCfg make_crcCfg(
      int               csbits,  ///< 校验和位宽
      bit[maxbits-1:0]  poly,    ///< 生成多项式
      bit[maxbits-1:0]  initval, ///< 寄存器初始值
      bit[maxbits-1:0]  endxorv, ///< 校验结束输出前的异或值
      bit               ibitrev, ///< 输入按位反转标志
      bit               obitrev  ///< 输出按位反转标志
   );
      crcCfg cc;
      int i;
      cc.csbits  = csbits;
      if (ibitrev) begin
         for (i = 0; i < csbits; i++)
            cc.poly[i] = poly[csbits-1-i];
      end
      else cc.poly = poly;
      cc.initval = initval;
      cc.endxorv = endxorv;
      cc.ibitrev = ibitrev;
      cc.obitrev = obitrev;
      return cc;
   endfunction
   /*! \brief 常见CRC标准的参数配置 */
   localparam crcCfg crc8             = make_crcCfg(.csbits( 8),.poly(64'h07              ),.initval(64'hFF              ),.endxorv(64'h00              ),.ibitrev(1'b0),.obitrev(1'b0));
   localparam crcCfg crc12            = make_crcCfg(.csbits(12),.poly(64'h80F             ),.initval(64'h000             ),.endxorv(64'h000             ),.ibitrev(1'b0),.obitrev(1'b0));
   localparam crcCfg crc16modbus      = make_crcCfg(.csbits(16),.poly(64'h8005            ),.initval(64'hFFFF            ),.endxorv(64'h0000            ),.ibitrev(1'b1),.obitrev(1'b1));
   localparam crcCfg crc16ccittx25    = make_crcCfg(.csbits(16),.poly(64'h1021            ),.initval(64'hFFFF            ),.endxorv(64'h0000            ),.ibitrev(1'b1),.obitrev(1'b1));
   localparam crcCfg crc16ccittfalse  = make_crcCfg(.csbits(16),.poly(64'h1021            ),.initval(64'hFFFF            ),.endxorv(64'h0000            ),.ibitrev(1'b0),.obitrev(1'b0));
   localparam crcCfg crc16ccittxmodem = make_crcCfg(.csbits(16),.poly(64'h1021            ),.initval(64'h0000            ),.endxorv(64'h0000            ),.ibitrev(1'b0),.obitrev(1'b0));
   localparam crcCfg crc32            = make_crcCfg(.csbits(32),.poly(64'h04C11DB7        ),.initval(64'hFFFFFFFF        ),.endxorv(64'hFFFFFFFF        ),.ibitrev(1'b1),.obitrev(1'b1));
   localparam crcCfg crc32c           = make_crcCfg(.csbits(32),.poly(64'h1EDC6F41        ),.initval(64'hFFFFFFFF        ),.endxorv(64'hFFFFFFFF        ),.ibitrev(1'b1),.obitrev(1'b1));
   localparam crcCfg crc64iso         = make_crcCfg(.csbits(64),.poly(64'h000000000000001B),.initval(64'h0000000000000000),.endxorv(64'h0000000000000000),.ibitrev(1'b0),.obitrev(1'b0));
   /*! \brief #scrc 运算延迟 */
   function automatic int dlytaps_scrc(
      int bw2c ///< 待校验数据位宽
   );
      return bw2c;
   endfunction
   /*! \brief #pcrc 运算延迟 */
   function automatic int dlytaps_pcrc(
      int bw2c,///< 待校验数据位宽
      int pcbw ///< 并行校验的数据位宽
   );
      return 3*bw2c/pcbw;
   endfunction
endpackage
 `endif//__CRC_PKG__

`else
 `undef  __PKG_BANNED__
`endif//__PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__

 `ifndef __CRC_ITF__
 `define __CRC_ITF__

 `endif//__CRC_ITF__

`else
 `undef  __ITF_BANNED__
`endif
