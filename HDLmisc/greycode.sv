/*!
 * \license SPDX-License-Identifier: MIT
 * \file greycode.sv
 * \brief 格雷码的编码、解码、连续性判断
 * \author JohnYork <johnyork@yeah.net>
 */
/*! \brief 格雷码编码 */
module greycode_encode #(
   parameter int BITW = 2   ///< 待编码数据位宽
) (
   input  wire[BITW-1:0]i,
   output wire[BITW-1:0]o
);
   assign o[BITW-1] = i[BITW-1];
   generate
      if (BITW > 1) assign o[BITW-2:0] = i[BITW-2:0]^i[BITW-1:1];
   endgenerate
endmodule
/*! \brief 格雷码解码 */
module greycode_decode #(
   parameter int BITW = 2  ///< 待解码数据位宽
) (
   input  wire[BITW-1:0]i,
   output wire[BITW-1:0]o
);
   assign o[BITW-1] = i[BITW-1];
   generate
      if (BITW > 1) assign o[BITW-2:0] = i[BITW-2:0]^o[BITW-1:1];
   endgenerate
endmodule
/*! \brief 格雷码连续性判断 */
module greycode_continuouschk #(
   parameter int BITW = 2  ///< 连续格雷码数据位宽
) (
   input  wire[1:0][BITW-1:0] greys,
   output wire                valid
);
   /* 二进制码转格雷码：
    * grey = {bin[BITW-1], bin[BITW-2:0]^bin[BITW-1:1]}
    * 格雷码转二进制码
    * bin = {grey[BITW-1], grey[BITW-2:0]^bin[BITW-1:1]}
    */
   /* 输入格雷码是否连续的判断算法：
    * 特性1.数值连续的格雷码之间仅变化一个比特位。
    * 基于上述特性，可对输入格雷码连续寄存两拍，并对寄存结果做异或运算，结果中存在1个比特1，则说明格雷码连续，存在0个比特1，则说明格雷码未变化，
    * 若存在1个以上的比特1，则说明格雷码不连续。
    * 判断二进制数是否存在一个以上比特1的算法：
    * 特性2.二进制数的特性：当需要消除二进制数 n 的最低的比特1时，不需要知道最低比特1的位置，只需要做运算 n&(n-1) 。
    * 基于上述特性，可对上一步骤的计算结果做运算 n&(n-1) ，并判断运算结果是否为0，不为0则说明存在一个以上比特1，否则说明最多存在一个比特1.
    */
   wire[BITW-1:0] grey_xor = greys[0]^greys[1];
   assign valid = (grey_xor&(grey_xor - (BITW)'(1))) == (BITW)'(0) ? 1'b1 : 1'b0;
endmodule
