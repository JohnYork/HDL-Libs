/*!
 * \license SPDX-License-Identifier: MIT
 * \file miscs.sv
 * \brief 部分通用工具类函数
 * \author JohnYork <johnyork@yeah.net>
 */
`define __INC_FROM_MISCS__
`include "miscs.svh"

module miscs_macrodef_verify #(
   parameter bit COMPILER = 1'b1,
   parameter bit BLKRAM   = 1'b1,
   parameter bit SHIFTTAPS = 1'b1,
   parameter bit ALLBITS2RAM = 1'b1,
   parameter bit MUX    = 1'b1
) ();
   initial begin
      if (COMPILER) begin
         `ifdef COMPILER_VIVADO
         $display("miscs : macro `COMPILER_VIVADO specified.");
         `elsif COMPILER_QUARTUS
         $display("miscs : macro `COMPILER_QUARTUS specified.");
         `else
         $warning("MISCS : NO macro for compiler identification specified.");
         `endif
         $display("logic ram will be identified by \"%s\"", miscs::miscs_ramstyle_logic);
      end
      if (BLKRAM) begin
         `ifndef BLKRAM_RAMBITS
         $warning("miscs : macro `BLKRAM_RAMBITS not defined, use default value(%0d) for count of bit per block ram", miscs::blkram_rambits);
         `else
         $display("miscs : count of bit per block ram is specified to %0d by macro `BLKRAM_RAMBITS", miscs::blkram_rambits);
         `endif
         `ifndef BLKRAM_MAXBITW4SDP
         $warning("miscs : macro `BLKRAM_MAXBITW4SDP not defined, use default value(%0d) for max bitwidth per block ram in SDP mode", miscs::blkram_maxbitw4sdp);
         `else
         $display("miscs : max bitwidth per block ram in SDP mode is specified to %0d by macro `BLKRAM_MAXBITW4SDP", miscs::blkram_maxbitw4sdp);
         `endif
         `ifndef BLKRAM_MAXBITW4TDP
         $warning("miscs : macro `BLKRAM_MAXBITW4TDP not defined, use default value(%0d) for max bitwidth per block ram in TDP mode", miscs::blkram_maxbitw4tdp);
         `else
         $display("miscs : max bitwidth per block ram in TDP mode is specified to %0d by macro `BLKRAM_MAXBITW4TDP", miscs::blkram_maxbitw4tdp);
         `endif
         `ifndef  BLKRAM_MINBITW4NORSV
         $warning("miscs : macro `BLKRAM_MINBITW4NORSV not defined, use default value(%0d) for min bitwidth with which no dummy bitwidth will produced in block ram", miscs::blkram_minbitw4norsv);
         `else
         $display("miscs : min bitwidth with which no dummy bitwidth will produced in block ram is specified to %0d by macro `BLKRAM_MINBITW4NORSV", miscs::blkram_minbitw4norsv);
         `endif
      end
      if (ALLBITS2RAM) begin
         `ifndef  ALLBITS2RAM_GATE
         $warning("miscs : macro `ALLBITS2RAM_GATE not defined, use default value(%0d) for bitsgate of implimenting instance with RAM", miscs::allbits2ram);
         `else
         $display("miscs : bitsgate of implimenting instance with RAM is specified to %0d by macro `ALLBITS2RAM_GATE", miscs::allbits2ram);
         `endif
      end
      if (SHIFTTAPS) begin
         `ifndef  SHIFTTAPS_TAPS2RAM
         $warning("miscs : macro `SHIFTTAPS_TAPS2RAM not defined, use default value(%0d) for tapsgate of implimenting instance with RAM", miscs::taps2ram);
         `else
         $display("miscs : tapsgate of implimenting instance with RAM is specified to %0d by macro `SHIFTTAPS_TAPS2RAM", miscs::taps2ram);
         `endif
      end
   end
endmodule