/*!
 * \license SPDX-License-Identifier: MIT
 * \file mux.svh
 * \brief 多路复用选择器的头文件
 * \author JohnYork <johnyork@yeah.net>
 */
`include "miscs.svh"

`ifdef  __INC_FROM_MUX__
 `ifdef  __PKG_INC_ONCE_THRGH_PRJ__ // 该宏仅适配 Quartus 编译器，用于避免Quartus编译器产生多个同样类型实例的问题
  `define __PKG_INC_ONCE_THRGH_PRJ_BANNED__
  `undef  __PKG_INC_ONCE_THRGH_PRJ__
 `endif//__PKG_INC_ONCE_THRGH_PRJ__
`else
 `define __ITF_BANNED__
`endif//__INC_FROM_MUX__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ__
 `define __PKG_BANNED__
`endif

`ifndef  __PKG_BANNED__

 `ifndef __MUX_PKG__
 `define __MUX_PKG__
package mux_pkg;
   /*! \brief 多路复用选择器输入端个数对应选通索引位宽 */
   function automatic int idxbitw_ofmux(int inputcnt);
      if (inputcnt <= 0) return 1;
      return miscs::minbitw_of_integer(inputcnt - 1, 31);
   endfunction
   /*! \brief 器件的基本多路复用器最大输入路数 */
   localparam int maxinputs_ofbasicmux = 
   `ifdef   MAXINPUTS_OFBASICMUX
      `MAXINPUTS_OFBASICMUX
   `else
      4
   `endif
   ;
   /*! \brief 多路复用器每拍最多允许的二选一复用级数 */
   localparam int mux_maxstage_pertap = idxbitw_ofmux(maxinputs_ofbasicmux);
   /*! \brief 计算多路复用选择器选通需要的最少延迟拍数 */
   function automatic int delaytaps4mux_minimum(int inputcnt);
      return idxbitw_ofmux(inputcnt)/mux_maxstage_pertap;
   endfunction
   /*! \brief 计算多路复用选择器作2选1选通推荐使用的延迟拍数 */
   function automatic int delaytaps4mux_recommend(int inputcnt);
      if (inputcnt <= 1) return 0;
      return (idxbitw_ofmux(inputcnt) + mux_maxstage_pertap - 1)/mux_maxstage_pertap;
   endfunction
endpackage: mux_pkg
 `endif//__MUX_PKG__

`else
 `undef  __PKG_BANNED__
`endif// __PKG_BANNED__

`ifdef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `undef  __PKG_INC_ONCE_THRGH_PRJ_BANNED__
 `define __PKG_INC_ONCE_THRGH_PRJ__
`endif//__PKG_INC_ONCE_THRGH_PRJ_BANNED__

`ifndef  __ITF_BANNED__
`else
 `undef  __ITF_BANNED__
`endif

