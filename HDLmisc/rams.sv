/*!
 * \license SPDX-License-Identifier: MIT
 * \file rams.sv
 * \brief RAM、RAM数组、RAM数组合并非数组元素位宽RAM
 * \author JohnYork <johnyork@yeah.net>
 * \depends miscs, packconv
 */
`include "miscs.svh"
`define __INC_FROM_RAMS__
`include "rams.svh"

package _l_rams_pkg;
   // 块RAM资源的可分配位宽种类数
   localparam int bitwtyp_cnt = miscs::minbitw_of_integer(miscs::blkram_maxbitw4sdp > miscs::blkram_maxbitw4tdp ? miscs::blkram_maxbitw4sdp : miscs::blkram_maxbitw4tdp, 32) + (miscs::blkram_minbitw4norsv&1);
   localparam int bitwtyp_cnt_sdp = miscs::minbitw_of_integer(miscs::blkram_maxbitw4sdp, 32) + (miscs::blkram_minbitw4norsv&1);
   localparam int bitwtyp_cnt_tdp = miscs::minbitw_of_integer(miscs::blkram_maxbitw4tdp, 32) + (miscs::blkram_minbitw4norsv&1);
   // 块RAM资源各类位宽分配数据类型
   typedef int bitwtyp_alloc_t[bitwtyp_cnt-1:0];
   /*! \brief 产生空的块RAM资源分配数据类型 */
   function automatic bitwtyp_alloc_t make_null_bta();
      bitwtyp_alloc_t bta;
      for (int i = 0; i < bitwtyp_cnt; i++)
         bta[i] = 0;
      return bta;
   endfunction
   /*!
    * \brief 计算块RAM资源分配数据中给定索引的分配数据对应的RAM块数据位宽
    * \param maxbitw_pblkram 待分配的单位块RAM资源可产生的最宽数据位宽
    * \param minbitw4norsv   最小无冗余比特的块RAM配置位宽
    * \param imaxbitwtp      最大可分配位宽的块RAM资源数目在 #bitwtyp_alloc_t 数组中的索引
    * \param ibt             待检验的索引
    * \return int型，索引 #ibt 对应的RAM块数据位宽
    */
   function automatic int signed bitwof_ibt_in_bta(int maxbitw_pblkram, int minbitw4norsv, int imaxbitwtp, int ibt);
      int bitwof_ibt;
      if (imaxbitwtp < ibt) return -1;
      bitwof_ibt = (maxbitw_pblkram>>(imaxbitwtp - ibt));
      if (bitwof_ibt < minbitw4norsv) bitwof_ibt = (1<<ibt);
      return signed'(bitwof_ibt);
   endfunction
   /*!
    * \brief 计算块RAM资源分配数据中给定索引的分配数据对应的RAM块可提供的地址深度
    * \param rambits_ofblk   每单位块RAM资源的存储资源位数
    * \param maxbitw_pblkram 待分配的单位块RAM资源可产生的最宽数据位宽
    * \param minbitw4norsv   最小无冗余比特的块RAM配置位宽
    * \param imaxbitwtp      最大可分配位宽的块RAM资源数目在 #bitwtyp_alloc_t 数组中的索引
    * \param ibt             待检验的索引
    * \return int型，索引 #ibt 对应的的RAM块可提供的地址深度
    */
   function automatic int signed addrdepth_perblkram_of_ibt_in_bta(int rambits_ofblk, int maxbitw_pblkram, int minbitw4norsv, int imaxbitwtp, int ibt);
      int bitwof_ibt, bitsof_minbitw4norsv, addrdepth_ofminbitw4norsv, addrdepth_ofblk;
      bitwof_ibt = bitwof_ibt_in_bta(maxbitw_pblkram,minbitw4norsv,imaxbitwtp, ibt);
      bitsof_minbitw4norsv = miscs::minbitw_of_integer(minbitw4norsv, 32);
      addrdepth_ofminbitw4norsv = rambits_ofblk/minbitw4norsv;
      if (bitwof_ibt >= minbitw4norsv)
         addrdepth_ofblk = rambits_ofblk/bitwof_ibt;
      else
         addrdepth_ofblk = addrdepth_ofminbitw4norsv<<(bitsof_minbitw4norsv - ibt - 1);
//    $display("addrdepth_perblkram_of_ibt_in_bta(0): bitwof_ibt = %0d, bitsof_minbitw4norsv = %0d, addrdepth_ofminbitw4norsv = %0d, addrdepth_ofblk = %0d", bitwof_ibt, bitsof_minbitw4norsv, addrdepth_ofminbitw4norsv, addrdepth_ofblk);
      return addrdepth_ofblk;
   endfunction
   /*!
    * \brief 统计块RAM资源分配数据中给定索引之间的分配数据已分配的数据位宽
    * \param maxbitw_pblkram 待分配的单位块RAM资源可产生的最宽数据位宽
    * \param minbitw4norsv   最小无冗余比特的块RAM配置位宽
    * \param bta             输入待枚举的块RAM资源各类位宽分配数据
    * \param imaxbitwtp      最大可分配位宽的块RAM资源数目在 #bitwtyp_alloc_t 数组中的索引
    * \param ibt2bgn         起始统计索引
    * \param ibt_aftr_end    结束统计索引(不含)
    * \return int型，给定索引之间已分配的数据位宽
    */
   function automatic int count_allcated_bitw_ofbta(int maxbitw_pblkram, int minbitw4norsv, bitwtyp_alloc_t bta, int imaxbitwtp, int ibt2bgn, int ibt2end);
      int d_ibt, ibt, bitw_allocated, ibit2end;
      int signed bitwof_ibt;
      ibit2end = ibt2end;
      if (ibt2bgn < ibit2end)
         ibt = ibt2bgn;
      else begin
         ibt = ibit2end;
         ibit2end = ibt2bgn;
      end
      for (bitw_allocated = 0; ibt <= ibit2end; ibt ++) begin
         bitwof_ibt = bitwof_ibt_in_bta(maxbitw_pblkram, minbitw4norsv, imaxbitwtp, ibt);
         if (bitwof_ibt > 0) bitw_allocated += bitwof_ibt*bta[ibt];
      end
      return bitw_allocated;
   endfunction
   /*!
    * \brief 枚举匹配待例化RAM数据位宽的块RAM资源分配方案
    * \param maxbitw_pblkram 待分配的单位块RAM资源可产生的最宽数据位宽
    * \param minbitw4norsv   最小无冗余比特的块RAM配置位宽
    * \param bitw2alloc      待例化RAM的数据位宽
    * \param bta             输入待枚举的块RAM资源各类位宽分配数据
    * \param imaxbitwtp      最大可分配位宽的块RAM资源数目在 #bitwtyp_alloc_t 数组中的索引
    * \return #bitwtyp_alloc_t型，在 #bta 基础上枚举的块RAM资源各类位宽分配数据
    */
   function automatic bitwtyp_alloc_t enum_alloc_scheme(int maxbitw_pblkram, int minbitw4norsv, int bitw2alloc, bitwtyp_alloc_t bta, int imaxbitwtp);
      int ibt, ibt_unalloc, bitw_allocated, bitwof_ibt;
      // 统计已分配的块类型及位宽：跳过位宽为1的分配块数，从最小位宽开始向大搜索，搜到的第一个分配块数不为0的位宽类型及其之后的位宽类型均视为已分配类型
      for (ibt = 1, ibt_unalloc = -1, bitw_allocated = 0; ibt <= imaxbitwtp; ibt++) begin
         if (ibt_unalloc < 0) begin
            if (bta[ibt] == 0) continue;
            ibt_unalloc = ibt - 1;
         end
         bitw_allocated += bitwof_ibt_in_bta(maxbitw_pblkram,minbitw4norsv,imaxbitwtp,ibt)*bta[ibt];
      end
      if (bitw_allocated == 0) ibt_unalloc = imaxbitwtp;
//    $display("0--bitw2alloc = %0d, imaxbitwtp = %0d, ibt_unalloc = %0d, bitw_allocated = %0d", bitw2alloc, imaxbitwtp, ibt_unalloc, bitw_allocated);
      if (ibt_unalloc < imaxbitwtp) begin
         // 第一个分配块数为0的位宽类型之前已有位宽类型被分配了，则递减前一块位宽类型的分配数，并重新计算 #ibt_unalloc 类型位宽的分配数
         bta[ibt_unalloc+1]--;
         bitw_allocated -= bitwof_ibt_in_bta(maxbitw_pblkram,minbitw4norsv,imaxbitwtp,ibt_unalloc+1);
      end
//    $display("1--ibt_unalloc = %0d, bitw_allocated = %0d", ibt_unalloc, bitw_allocated);
      bitwof_ibt = bitwof_ibt_in_bta(maxbitw_pblkram,minbitw4norsv,imaxbitwtp,ibt_unalloc);
//    $display("2--bitwof_ibt = %0d", bitwof_ibt);
      bta[ibt_unalloc] = ((bitw2alloc - bitw_allocated) + bitwof_ibt - 1)/bitwof_ibt;
      for (ibt = ibt_unalloc - 1; ibt >= 0; ibt--) begin
         bta[ibt] = 0;
      end
      return bta;
   endfunction
   function automatic void print_bitwtyp_alloc(bitwtyp_alloc_t bta, bit tdpram);
      automatic int maxbta, ibitwtypbgn, maxbitw_pblkram, minbw4norsv_blkram;
       maxbta = 8;
      maxbitw_pblkram = tdpram ? miscs::blkram_maxbitw4tdp : miscs::blkram_maxbitw4sdp;
      minbw4norsv_blkram = miscs::blkram_minbitw4norsv;
      ibitwtypbgn = miscs::minbitw_of_integer(maxbitw_pblkram, 32) - ((minbw4norsv_blkram <= 0) ? 1 : 0);
     if (bitwtyp_cnt == 8)
         $display("%0d-%0d, %0d-%0d, %0d-%0d, %0d-%0d, %0d-%0d, %0d-%0d, %0d-%0d, %0d-%0d",
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (7                   )
            ),bta[7],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (6                   )
            ),bta[6],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (5                   )
            ),bta[5],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (4                   )
            ),bta[4],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (3                   )
            ),bta[3],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (2                   )
            ),bta[2],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (1                   )
            ),bta[1],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (0                   )
            ),bta[0]);
      else if (bitwtyp_cnt == 7)
         $display("%0d-%0d, %0d-%0d, %0d-%0d, %0d-%0d, %0d-%0d, %0d-%0d, %0d-%0d",
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (6                   )
            ),bta[6],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (5                   )
            ),bta[5],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (4                   )
            ),bta[4],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (3                   )
            ),bta[3],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (2                   )
            ),bta[2],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (1                   )
            ),bta[1],
            bitwof_ibt_in_bta(
               .maxbitw_pblkram  (maxbitw_pblkram     ),
               .minbitw4norsv    (minbw4norsv_blkram  ),
               .imaxbitwtp       (ibitwtypbgn         ),
               .ibt              (0                   )
            ),bta[0]);
      else $error("unsupported bitwtyp_alloc_t!");
   endfunction
   /*!
    * \brief 搜索产生RAM实例的最经济（不使用的块RAM位数最少）的块RAM资源分配方案
    * \param rambits_ofblk   每单位块RAM资源的存储资源位数
    * \param maxbitw_pblkram 待分配的单位块RAM资源可产生的最宽数据位宽
    * \param minbitw4norsv   最小无冗余比特的块RAM配置位宽
    * \param bitw2alloc      待例化RAM的数据位宽
    * \param depth           待例化RAM的地址深度
    * \return bitwtyp_alloc_t型，块RAM资源各类位宽分配数据
    */
   function automatic bitwtyp_alloc_t search_economic_alloc_scheme(int rambits_ofblk, int maxbitw_pblkram, int minbitw4norsv, int bitw2alloc, int depth);
      bitwtyp_alloc_t bta, bta_min_rsvd;
      int ibitwtypbgn, ityp, bitw_allocated, chk_typcnt, bitwof_ibt, addrdepth_ofblk, bits_rsvd, min_bits_rsvd;
      int bitsof_minbitw4norsv, addrdepth_ofminbitw4norsv, maxbitw2raise_rsv_blk, rsvbits_ofblk, blkcnt_ofdepth;
      int itcnt;
      ibitwtypbgn = miscs::minbitw_of_integer(maxbitw_pblkram, 32) - 1;
      if (minbitw4norsv > 0) ibitwtypbgn ++;
      bta = make_null_bta();
      min_bits_rsvd = -1;
      // 计算RAM块配置位宽小于最低不产生冗余比特的位宽时会产生的冗余比特数
      bitsof_minbitw4norsv = miscs::minbitw_of_integer(minbitw4norsv, 32);
      maxbitw2raise_rsv_blk = 1<<(bitsof_minbitw4norsv - 1);
      addrdepth_ofminbitw4norsv = rambits_ofblk/minbitw4norsv;
      rsvbits_ofblk = (minbitw4norsv - maxbitw2raise_rsv_blk)*addrdepth_ofminbitw4norsv;
//    $display("0::: minbitw4norsv = %0d, bitsof_minbitw4norsv = %0d, maxbitw2raise_rsv_blk = %0d, addrdepth_ofminbitw4norsv = %0d, rsvbits_ofblk = %0d", minbitw4norsv, bitsof_minbitw4norsv, maxbitw2raise_rsv_blk, addrdepth_ofminbitw4norsv, rsvbits_ofblk);
      chk_typcnt = 1;
      itcnt = 100000;
      while(chk_typcnt > 0 && itcnt > 0) begin
         bta = enum_alloc_scheme(maxbitw_pblkram, minbitw4norsv, bitw2alloc, bta, ibitwtypbgn);
         for (bitw_allocated = 0, bits_rsvd = 0, ityp = ibitwtypbgn; ityp >= 0; ityp--) begin
            bitwof_ibt = maxbitw_pblkram>>(ibitwtypbgn - ityp);
            if (bitwof_ibt < minbitw4norsv) begin
               bitwof_ibt = 1<<ityp;
               addrdepth_ofblk = addrdepth_ofminbitw4norsv<<(bitsof_minbitw4norsv - ityp - 1);
            end else
               addrdepth_ofblk = rambits_ofblk/bitwof_ibt;
            // 统计因为地址深度冗余产生的保留比特位数
            bits_rsvd += ((addrdepth_ofblk - (depth%addrdepth_ofblk))*bitwof_ibt)*bta[ityp];
            // 统计因为数据位宽冗余产生的保留比特位数，比如：Xilinx的FPGA中，M36K存储块，在数据位宽为8、4、2、1时将产生 36k - 32k = 4k 的冗余
            blkcnt_ofdepth = (depth + addrdepth_ofblk - 1)/addrdepth_ofblk;
            bits_rsvd += (rambits_ofblk - bitwof_ibt*addrdepth_ofblk)*bta[ityp]*blkcnt_ofdepth;
            bitw_allocated += bitwof_ibt*bta[ityp];
//          $display("1::: ityp = %0d, bitwof_ibt = %0d, addrdepth_ofblk = %0d, bits_rsvd = %0d", ityp, bitwof_ibt, addrdepth_ofblk, bits_rsvd);
         end
         if (bitw_allocated > bitw2alloc) bits_rsvd += (bitw_allocated - bitw2alloc)*depth;
//       print_bitwtyp_alloc(bta);
         // 记录冗余比特数最小的块资源分配数据
         if (min_bits_rsvd < 0 || min_bits_rsvd > bits_rsvd) begin
            min_bits_rsvd = bits_rsvd;
            bta_min_rsvd = bta;
//          $display("2---::: min_bits_rsvd = %0d", min_bits_rsvd);
         end
         // 统计循环结束条件：当除 ityp == 0 的RAM块分配数外所有分配数都为0时，循环枚举结束
         for (chk_typcnt = 0, ityp = ibitwtypbgn; ityp > 0; ityp--)
            chk_typcnt += bta[ityp];
//       $display("2::: bits_rsvd = %0d, itcnt = %0d, chk_typcnt = %0d", bits_rsvd, itcnt, chk_typcnt);
         itcnt --;
      end
//    $display("Result: bitw2alloc = %0d, depth = %0d, min_bits_rsvd = %0d", bitw2alloc, depth, min_bits_rsvd);
//    print_bitwtyp_alloc(bta_min_rsvd);
      return bta_min_rsvd;
   endfunction
   function automatic int redntbits_of_ibta(int rambits_ofblk, int maxbitw_pblkram, int minbitw4norsv, int imaxbitwtp, int depth_want, int bitw_want, int ibt, int blkcnt_on_width);
      int bitwof_ibt, addrdepth_ofblk, redntbits;
      bitwof_ibt = bitwof_ibt_in_bta(maxbitw_pblkram,minbitw4norsv,imaxbitwtp, ibt);
      addrdepth_ofblk = addrdepth_perblkram_of_ibt_in_bta(rambits_ofblk, maxbitw_pblkram, minbitw4norsv, imaxbitwtp, ibt);
      // 地址冗余产生的冗余比特
      redntbits = bitwof_ibt*blkcnt_on_width*(addrdepth_ofblk - (depth_want%addrdepth_ofblk));
//    $display("redntbits_of_ibta(1): redntbits = %0d, bitwof_ibt = %0d, blkcnt_on_width = %0d, depth_want = %0d, addrdepth_ofblk = %0d", redntbits, bitwof_ibt, blkcnt_on_width, depth_want, addrdepth_ofblk);
      // RAM块内无法分配的冗余比特
      redntbits += (rambits_ofblk - bitwof_ibt*addrdepth_ofblk)*blkcnt_on_width*((depth_want + addrdepth_ofblk - 1)/addrdepth_ofblk);
//    $display("redntbits_of_ibta(2): redntbits = %0d, bitwof_ibt = %0d, blkcnt_on_width = %0d, depth_want = %0d, addrdepth_ofblk = %0d", redntbits, bitwof_ibt, blkcnt_on_width, depth_want, addrdepth_ofblk);
      // 分配的RAM块数无法产生足够的位宽时，反相符号以提示位宽不足
      if (blkcnt_on_width*bitwof_ibt < bitw_want) redntbits = -redntbits;
      // 位宽上分配的RAM块产生的冗余比特
      if (blkcnt_on_width > 0) redntbits += (blkcnt_on_width*bitwof_ibt - bitw_want)*depth_want;
//    $display("redntbits_of_ibta(3): redntbits = %0d, bitwof_ibt = %0d, blkcnt_on_width = %0d, depth_want = %0d, bitw_want = %0d", redntbits, bitwof_ibt, blkcnt_on_width, depth_want, bitw_want);
      return redntbits;
   endfunction
   function automatic int count_redntbits_of_ibta_rng(int rambits_ofblk, int maxbitw_pblkram, int minbitw4norsv, int imaxbitwtp, int depth_want, int ibitw_want, bitwtyp_alloc_t bta, int ibt_bgn, int ibt_end);
      int ibt, redntbits, bitw_allocated, bitw_want;
      bitw_want = ibitw_want;
      if (ibt_bgn < ibt_end)
         ibt = ibt_end;
      else begin
         ibt = ibt_bgn;
         ibt_bgn = ibt_end;
      end
      for (bitw_allocated = 0, redntbits = 0; ibt >= ibt_bgn; ibt--) begin
         int signed bitwof_ibt, bitw_want_on_ibt;
         bitwof_ibt = bitwof_ibt_in_bta(maxbitw_pblkram,minbitw4norsv,imaxbitwtp,ibt);
         bitw_want_on_ibt = bitw_want < bitwof_ibt ? bitw_want : bitwof_ibt;
         redntbits += redntbits_of_ibta(rambits_ofblk,maxbitw_pblkram,minbitw4norsv,imaxbitwtp,depth_want,bitw_want_on_ibt,ibt,bta[ibt]);
         // $display("dbg1: bta[%0d] = %0d, bitw_want = %0d, bitwof_ibt = %0d, bitw_want_on_ibt = %0d, redntbits = %0d", ibt, bta[ibt], bitw_want, bitwof_ibt, bitw_want_on_ibt, redntbits);
         bitw_want -= bitw_want_on_ibt*bta[ibt];
      end
      return redntbits;
   endfunction
   function automatic bitwtyp_alloc_t generate_economic_alloc_scheme(int rambits_ofblk, int maxbitw_pblkram, int minbitw4norsv, int bitw2alloc, int depth);
      bitwtyp_alloc_t bta, bta_min_rsvd;
      int ibitwtypbgn, ityp, bitw_allocated, bitwof_ibt, addrdepth_ofblk, redntbits_ofibt, min_bits_rsvd;
      int bitsof_minbitw4norsv, addrdepth_ofminbitw4norsv, bitw_left, maxbitw2raise_rsv_blk, rsvbits_ofblk, blkcnt_ofdepth;
      int itcnt;
      ibitwtypbgn = miscs::minbitw_of_integer(maxbitw_pblkram, 32) - 1;
      if (minbitw4norsv > 0) ibitwtypbgn ++;
      bta = make_null_bta();
      // 计算不产生冗余比特位宽条件下的块RAM地址深度
      bitsof_minbitw4norsv = miscs::minbitw_of_integer(minbitw4norsv, 32);
      maxbitw2raise_rsv_blk = 1<<(bitsof_minbitw4norsv - 1);
      addrdepth_ofminbitw4norsv = rambits_ofblk/minbitw4norsv;
      min_bits_rsvd = -1;
      // 先按最小位宽冗余原则计算块RAM分配方案
      for (bitw_allocated = 0,ityp = ibitwtypbgn; ityp >= 0; ityp--) begin
         bitwof_ibt = bitwof_ibt_in_bta(maxbitw_pblkram,minbitw4norsv,ibitwtypbgn, ityp);
         if (bitwof_ibt >= minbitw4norsv)
            addrdepth_ofblk = rambits_ofblk/bitwof_ibt;
         else
            addrdepth_ofblk = addrdepth_ofminbitw4norsv<<(bitsof_minbitw4norsv - ityp - 1);
         bitw_left = bitw2alloc - bitw_allocated;
         bta[ityp] = bitw_left/bitwof_ibt;
         bitw_allocated += bitwof_ibt*bta[ityp];
      end
      // $display(" ------ Before recyle for depth = %0d, iibitwtypbgn = %0d ------ ", depth, ibitwtypbgn);
      // print_bitwtyp_alloc(.bta(bta), .tdpram(1'b1));
      // 假定：冗余位宽仅产生于块数非0的RAM块类型中位宽最小的一类RAM块
      // 则只需检查从被轮询RAM块类型到位宽最小的RAM块类型之间的RAM块是否可以回收至被轮询RAM块中，
      // 若回收后的冗余比特少于回收前，则执行回收。
      // 再从最大位宽的块RAM块数开始尝试，轮询将小于它的块RAM块数回收至本级后产生的冗余比特数，
      // 取冗余比特最小的回收方案执行回收
      // 解释：考虑 i,j,k 三级块RAM块数，i > j > k ；
      // 本方案可行的条件是不会出现从 k 级开始依次检查过 k ,j 级后，将 j 级向上回收至 i 级后再发现
      // k 级也可以向上回收至 i 级的情况（因为这意味着必须重新轮询一次 k 级到 j 级，多产生一次轮询循环）。
      // 分析：无论 k 级直接被回收至 i 级，还是先被回收至 j 级再被回收至 i 级，k 级的冗余比特数与 k 级被
      // 回收至 i 级产生的冗余比特数之差都是一定的，所以上面的情况不可能出现。
      for (ityp = ibitwtypbgn; ityp > 0; ityp--) begin
         int bitw_left, bitwof_ityp2zero, blkcnt_inc, redntbits_aftr_inc, redntbits_befr_inc;
         // 位宽类型索引从 0 到 ityp - 1 之间已分配的位宽
         bitw_left = count_allcated_bitw_ofbta(maxbitw_pblkram,minbitw4norsv,bta,ibitwtypbgn,0,ityp-1);
         // 当前 ityp 的位宽
         bitwof_ibt = bitwof_ibt_in_bta(maxbitw_pblkram,minbitw4norsv,ibitwtypbgn, ityp);
         if (bitwof_ibt < bitw_left*2) begin
            bitwof_ityp2zero = bitwof_ibt*bta[ityp] + bitw_left;
            blkcnt_inc = (bitw_left + bitwof_ibt - 1)/bitwof_ibt;
            redntbits_aftr_inc = redntbits_of_ibta(rambits_ofblk,maxbitw_pblkram,minbitw4norsv,ibitwtypbgn,depth,bitwof_ityp2zero,ityp,bta[ityp] + blkcnt_inc);
            if (redntbits_aftr_inc < 0) redntbits_aftr_inc = -redntbits_aftr_inc;
            redntbits_befr_inc = count_redntbits_of_ibta_rng(rambits_ofblk,maxbitw_pblkram,minbitw4norsv,ibitwtypbgn,depth,bitwof_ityp2zero,bta,0,ityp);
            if (redntbits_befr_inc < 0) redntbits_befr_inc = -redntbits_befr_inc;
            // $display("ityp = %0d, bitw_left = %0d, bitwof_ibt = %0d, bta[ityp] = %0d, bitwof_ityp2zero = %0d, blkcnt_inc = %0d, redntbits_aftr_inc = %0d, redntbits_befr_inc = %0d", ityp, bitw_left, bitwof_ibt, bta[ityp], bitwof_ityp2zero, blkcnt_inc, redntbits_aftr_inc, redntbits_befr_inc);
            if (redntbits_aftr_inc <= redntbits_befr_inc) begin
               int jtyp;
               bta[ityp] += blkcnt_inc;
               for (jtyp = 0; jtyp < ityp; jtyp++) bta[jtyp] = 0;
               break;
            end
         end
      end
      return bta;
   endfunction
   /*!
    * \brief 根据RAM块索引计算块索引的各比特位对应RAM序列的深度
    * \param ibitof_rowidx RAM块索引的比特位索引
    * \param addrLen       RAM映射地址长度
    * \param ramblk_depth  单位RAM块地址深度
    */
   function automatic int addrlen_ofstage_frmrowidx(int ibitof_rowidx, int addrLen, int ramblk_depth);
//    if (ibitof_rowidx == 0) return addrLen % ramblk_depth;
      if (ibitof_rowidx < 2) begin
         int addrLen_last2stage, allocated_addrlen;
         addrLen_last2stage = addrLen % (2*ramblk_depth);
         allocated_addrlen  = ibitof_rowidx * ramblk_depth;
         if (addrLen_last2stage > allocated_addrlen + ramblk_depth)
            return ramblk_depth;
         else if (addrLen_last2stage > allocated_addrlen)
            return addrLen_last2stage - allocated_addrlen;
         else
            return 0;
      end else if ((addrLen % ((2**ibitof_rowidx)*ramblk_depth)) >= ((2**(ibitof_rowidx-1))*ramblk_depth))
         return ((2**(ibitof_rowidx-1))*ramblk_depth);
      else return 0;
   endfunction
   /*!
    * \brief 枚举用于分配的地址深度
    * \param rambits_ofblk   每单位块RAM资源的存储资源位数
    * \param maxbitw_pblkram 待分配的单位块RAM资源可产生的最宽数据位宽
    * \param minbitw4norsv   最小无冗余比特的块RAM配置位宽
    * \param imaxbitwtp      最大可分配位宽的块RAM资源数目在 #bitwtyp_alloc_t 数组中的索引
    * \param depth_want      总共要求分配的地址深度
    * \param ienum           枚举次数索引
    * \return int型，给定枚举次数索引 #ienum 对应的用于分配的地址深度
    */
   function automatic int signed enum_addrdepth_4alloc(int rambits_ofblk, int maxbitw_pblkram, int minbitw4norsv, int imaxbitwtp, int depth_want, int ienum);
      int i, idepth2alloc, idpa, depth_waitalloc, depth2alloc;
      // 略过已分配的地址深度范围
      idepth2alloc = 0;
      depth2alloc = 0;
      depth_waitalloc = depth_want;
      for (i = 0; i < ienum; i++) begin
         for (idpa = idepth2alloc; idpa <= imaxbitwtp; idpa++) begin
            depth2alloc = addrdepth_perblkram_of_ibt_in_bta(rambits_ofblk, maxbitw_pblkram, minbitw4norsv, imaxbitwtp, idpa);
            // $display("dbg1: imaxbitwtp = %0d, depth_want = %0d, ienum = %0d, i = %0d, idpa = %0d, depth_waitalloc = %0d, depth2alloc = %0d", imaxbitwtp, depth_want, ienum, i, idpa, depth_waitalloc, depth2alloc);
            if (depth2alloc <= depth_waitalloc) begin
               depth_waitalloc = depth_waitalloc - depth2alloc;
               break;
            end
         end
         if (idpa > imaxbitwtp) begin
            // 最短的地址深度已经被枚举略过了，此时 0 <= depth_waitalloc < depth2alloc 
            // ，此时待略过的枚举索引 i < ienum ，表明略过次数还不足
            if (depth_waitalloc > 0)depth_waitalloc = 0; // 再分配一次深度则应将所有的待分配地址深度分配完毕
            else                    return -1;            // 若此时没有待分配地址深度了，则属于未考虑到的异常现象
         end
         idepth2alloc = idpa;
      end
      // $display("dbg2: idepth2alloc = %0d, depth_waitalloc = %0d", idepth2alloc, depth_waitalloc);
      if (depth_waitalloc <= 0) return 0; // 若略过已分配的地址深度范围后没有地址深度可分配了，则应停止分配地址深度
      for (idpa = idepth2alloc; idpa <= imaxbitwtp; idpa++) begin
         depth2alloc = addrdepth_perblkram_of_ibt_in_bta(rambits_ofblk, maxbitw_pblkram, minbitw4norsv, imaxbitwtp, idpa);
         // $display("dbg3: imaxbitwtp = %0d, depth_want = %0d, ienum = %0d, i = %0d, idpa = %0d, depth_waitalloc = %0d, depth2alloc = %0d", imaxbitwtp, depth_want, ienum, i, idpa, depth_waitalloc, depth2alloc);
         if (depth2alloc <= depth_waitalloc) break;
      end
      // $display("dbg4: idpa = %0d, depth2alloc = %0d, depth_waitalloc = %0d", idpa, depth2alloc, depth_waitalloc);
      return (depth_waitalloc > depth2alloc) ? depth2alloc : depth_waitalloc;
   endfunction
   /*!
    * \brief 统计地址深度分配枚举次数
    */
   function automatic int count_enum_times_of_addrdepth2alloc(int rambits_ofblk, int maxbitw_pblkram, int minbitw4norsv, int imaxbitwtp, int depth_want);
      int cnt, idepth2alloc, idpa, depth_waitalloc, depth2alloc;
      // 略过已分配的地址深度范围
      idepth2alloc = 0;
      depth2alloc = 0;
      cnt = 0;
      depth_waitalloc = depth_want;
      while (depth_waitalloc > 0) begin
         for (idpa = idepth2alloc; idpa <= imaxbitwtp; idpa++) begin
            depth2alloc = addrdepth_perblkram_of_ibt_in_bta(rambits_ofblk, maxbitw_pblkram, minbitw4norsv, imaxbitwtp, idpa);
            if (depth2alloc <= depth_waitalloc) begin
               depth_waitalloc = depth_waitalloc - depth2alloc;
               cnt = cnt + 1;
               break;
            end
         end
         if (idpa > imaxbitwtp) begin
            if (depth_waitalloc > 0 && depth2alloc > 0) begin
               depth_waitalloc = 0;
               cnt = cnt + 1;
            end
         end
         idepth2alloc = idpa;
      end
      return cnt;
   endfunction
endpackage

/*! \brief Basic Simple Dual Port RAM */
module basic_sdpram_2clk #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter     RAMSTYLE = rams_pkg::ramstyle_auto///< RAM例化特征
) (clk_w, we, clken_w, addr_w, data_w, clk_q, clken_q, addr_q, data_q);
   input  bit                 clk_w;               ///< RAM写端口驱动时钟
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                we;                  ///< RAM写信号，高电平(1)有效
   input  wire                clken_w;             ///< RAM写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_w;              ///< RAM写地址
   input  wire [DATABITW-1:0] data_w;              ///< RAM待写数据
   input  bit                 clk_q;               ///< RAM读端口驱动时钟
   input  wire                clken_q;             ///< RAM读使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_q;              ///< RAM读地址
   output logic[DATABITW-1:0] data_q;              ///< RAM读数据输出

   (* ram_style = RAMSTYLE *)
   reg[DATABITW-1:0] ram[ADDRLEN-1:0];
   initial begin
      for (int i = 0; i < ADDRLEN; i++) ram[i] = '0;
      data_q = '0;
   end
   always @(posedge clk_w) if (clken_w & we) ram[addr_w] <= data_w;
   always @(posedge clk_q) if (clken_q) data_q <= ram[addr_q];
endmodule
module basic_sdpram #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ADDRLEN  = 5                      ///< 地址长度
) (clk, we, clken_w, addr_w, data_w, clken_q, addr_q, data_q);
   input  bit                 clk;                 ///< RAM驱动时钟
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                we;                  ///< RAM写信号，高电平(1)有效
   input  wire                clken_w;             ///< RAM写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_w;              ///< RAM写地址
   input  wire [DATABITW-1:0] data_w;              ///< RAM待写数据
   input  wire                clken_q;             ///< RAM读使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_q;              ///< RAM读地址
   output logic[DATABITW-1:0] data_q;              ///< RAM读数据输出

   basic_sdpram_2clk #(
      .DATABITW(DATABITW               ),
      .ADDRLEN (ADDRLEN                ),
      .RAMSTYLE(rams_pkg::ramstyle_auto)
   )rami(
      .we      (we      ),
      .clk_w   (clk     ),
      .clken_w (clken_w ),
      .addr_w  (addr_w  ),
      .data_w  (data_w  ),
      .clk_q   (clk     ),
      .clken_q (clken_q ),
      .addr_q  (addr_q  ),
      .data_q  (data_q  )
   );
endmodule
/*! \brief Simple Dual Port RAM */
module sdpram_2clk #(
   parameter int DATABITW = 32,                    ///< RAM数据位宽
   parameter int ADDRLEN  = 4,                     ///< RAM地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, clk_q, clken_q, addr_q, data_q);
   input  bit                 clk_w;               ///< RAM写端口驱动时钟
   input  wire                aclr;                ///< 输出端寄存器异步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                we;                  ///< RAM写信号，高电平(1)有效
   input  wire                clken_w;             ///< RAM写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_w;              ///< RAM写地址
   input  wire [DATABITW-1:0] data_w;              ///< RAM待写数据
   input  bit                 clk_q;               ///< RAM读端口驱动时钟
   input  wire                sclr_q;              ///< 输出端寄存器同步复位信号，高电平(1)有效
   input  wire                clken_q;             ///< RAM读使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_q;              ///< RAM读地址
   output logic[DATABITW-1:0] data_q;              ///< RAM读数据输出

   initial if (IMPLMOD > 2) $error("sdpram_2clk: illegal parameter IMPLMOD(%0d) specified, only 2,1,0 is allowed!", IMPLMOD);
   wire[DATABITW-1:0]data2q;
   genvar i, j; generate if (IMPLMOD == 2) begin: MINAREA
      localparam _l_rams_pkg::bitwtyp_alloc_t bta = _l_rams_pkg::generate_economic_alloc_scheme(
                                                                  .rambits_ofblk    (miscs::blkram_rambits        ),
                                                                  .maxbitw_pblkram  (miscs::blkram_maxbitw4sdp    ),
                                                                  .minbitw4norsv    (miscs::blkram_minbitw4norsv  ),
                                                                  .bitw2alloc       (DATABITW                     ),
                                                                  .depth            (ADDRLEN                      )
                                                               );
//    initial _l_rams_pkg::print_bitwtyp_alloc(bta, 1'b0);
      localparam int ibitwtypbgn = miscs::minbitw_of_integer(miscs::blkram_maxbitw4sdp, 32) -
                                   ((miscs::blkram_minbitw4norsv <= 0)
                                    ? 1
                                    : 0);
      for (i = 0; i < _l_rams_pkg::bitwtyp_cnt_sdp; i++) begin: BTA
         localparam int ibitw_bgn = (i == 0)
                                    ? 0
                                    : _l_rams_pkg::count_allcated_bitw_ofbta(
                                                      .maxbitw_pblkram  (miscs::blkram_maxbitw4sdp    ),
                                                      .minbitw4norsv    (miscs::blkram_minbitw4norsv  ),
                                                      .bta              (bta                          ),
                                                      .imaxbitwtp       (ibitwtypbgn                  ),
                                                      .ibt2bgn          (0                            ),
                                                      .ibt2end          (i - 1                        )
                                                   );
         localparam int bitwof_ibt = _l_rams_pkg::bitwof_ibt_in_bta(
                                                   .maxbitw_pblkram  (miscs::blkram_maxbitw4sdp    ),
                                                   .minbitw4norsv    (miscs::blkram_minbitw4norsv  ),
                                                   .imaxbitwtp       (ibitwtypbgn                  ),
                                                   .ibt              (i                            )
                                                );
         for (j = 0; j < bta[i]; j++) begin: E
            if (bta[i] > 0) begin
               localparam int imsb_ofdata_inbta = ((ibitw_bgn+bitwof_ibt*(j+1) > DATABITW)
                                                   ? DATABITW
                                                   : ibitw_bgn+bitwof_ibt*(j+1)) - 1;
               localparam int imsb_ofbta = ibitw_bgn+bitwof_ibt*(j+1) - 1;
               localparam int ilsb_ofbta = ibitw_bgn+bitwof_ibt*j;
//             initial $display("ibitwtypbgn = %0d, ibitw_bgn = %0d, i = %0d, j = %0d, bitwof_ibt = %0d, imsb_ofdata_inbta = %0d, imsb_ofbta = %0d", ibitwtypbgn, ibitw_bgn, i, j, bitwof_ibt, imsb_ofdata_inbta, imsb_ofbta);
               localparam int bitw_ofrai = bitwof_ibt - (imsb_ofbta - imsb_ofdata_inbta);
               wire[bitw_ofrai-1:0] rami_w, rami_q;
               assign rami_w = data_w[imsb_ofdata_inbta:ilsb_ofbta];
               basic_sdpram_2clk #(
                  .DATABITW(bitw_ofrai             ),
                  .ADDRLEN (ADDRLEN                ),
                  .RAMSTYLE(rams_pkg::ramstyle_ram )
               ) rami(  
                  .clk_w   (clk_w         ),
                  .clken_w (clken_w       ),
                  .we      (we            ),
                  .addr_w  (addr_w        ),
                  .data_w  (rami_w        ),
                  .clk_q   (clk_q         ),
                  .clken_q (clken_q|sclr_q),
                  .addr_q  (addr_q        ),
                  .data_q  (rami_q        )
               );
               assign data2q[imsb_ofdata_inbta:ilsb_ofbta] = rami_q[imsb_ofdata_inbta - ilsb_ofbta:0];
            end
         end
      end
   end else if (IMPLMOD == 0) begin: MAPREG
      basic_sdpram_2clk #(
         .DATABITW(DATABITW                  ),
         .ADDRLEN (ADDRLEN                   ),
         .RAMSTYLE(rams_pkg::ramstyle_logic  )
      ) rami(
         .clk_w   (clk_w         ),
         .clken_w (clken_w       ),
         .we      (we            ),
         .addr_w  (addr_w        ),
         .data_w  (data_w        ),
         .clk_q   (clk_q         ),
         .clken_q (clken_q|sclr_q),
         .addr_q  (addr_q        ),
         .data_q  (data2q        )
      );
   end else begin: NORMMOD
      basic_sdpram_2clk #(
         .DATABITW(DATABITW               ),
         .ADDRLEN (ADDRLEN                ),
         .RAMSTYLE(rams_pkg::ramstyle_auto)
      ) rami(
         .clk_w   (clk_w         ),
         .clken_w (clken_w       ),
         .we      (we            ),
         .addr_w  (addr_w        ),
         .data_w  (data_w        ),
         .clk_q   (clk_q         ),
         .clken_q (clken_q|sclr_q),
         .addr_q  (addr_q        ),
         .data_q  (data2q        )
      );
   end
   if (REGOUTP) always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clk_q, aclr)) begin
      if     (aclr)  data_q <= '0;
      else if(sclr_q)data_q <= '0;
      else           data_q <= clken_q ? data2q : data_q;
   end else assign data_q = data2q;
   endgenerate
endmodule
module sdpram #(
   parameter int DATABITW = 32,                    ///< RAM数据位宽
   parameter int ADDRLEN  = 4,                     ///< RAM地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, we, clken_w, addr_w, data_w, clken_q, addr_q, data_q);
   input  bit                 clk;                 ///< RAM驱动时钟
   input  wire                aclr;                ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                we;                  ///< RAM写信号，高电平(1)有效
   input  wire                clken_w;             ///< RAM写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_w;              ///< RAM写地址
   input  wire [DATABITW-1:0] data_w;              ///< RAM待写数据
   input  wire                clken_q;             ///< RAM读使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_q;              ///< RAM读地址
   output logic[DATABITW-1:0] data_q;              ///< RAM读数据输出

   sdpram_2clk #(
      .DATABITW(DATABITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) sdprami(
      .aclr    (aclr    ),
      .clk_w   (clk     ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (data_w  ),
      .clk_q   (clk     ),
      .clken_q (clken_q ),
      .sclr_q  (sclr    ),
      .addr_q  (addr_q  ),
      .data_q  (data_q  )
   );
endmodule
module sdpram2clk4if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_2clk_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram2clk4if: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($bits(p.data_w) != DATABITW || $bits(p.data_q) != DATABITW)
      $error("sdpram2clk4if: DATABITW(%0d) does not match the bitwidth of p.data_w(%0d) or .p.data_q(%0d)", DATABITW, $bits(p.data_w), $bits(p.data_q));
   sdpram_2clk #(
      .DATABITW(DATABITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr     ),
      .clk_w   (p.clk_w    ),
      .clken_w (p.clken_w  ),
      .we      (p.we       ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .clk_q   (p.clk_q    ),
      .clken_q (p.clken_q  ),
      .sclr_q  (p.sclr_q   ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   )
   );
endmodule
module sdpram4if #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram4if: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($bits(p.data_w) != DATABITW || $bits(p.data_q) != DATABITW)
      $error("sdpram4if: DATABITW(%0d) does not match the bitwidth of p.data_w(%0d) or .p.data_q(%0d)", DATABITW, $bits(p.data_w), $bits(p.data_q));
   sdpram #(
      .DATABITW(DATABITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk      ),
      .we      (p.we       ),
      .aclr    (p.aclr     ),
      .sclr    (p.sclr     ),
      .clken_w (p.clken_w  ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .clken_q (p.clken_q  ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   )
   );
endmodule
/*! \brief Simple Dual Port RAM for packed-array */
module sdpram_2clk_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, clk_q, clken_q, addr_q, data_q);
   input  bit                             clk_w;   ///< RAM写端驱动时钟
   input  wire                            aclr;    ///< 输出端寄存器异步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            we;      ///< RAM写信号，高电平(1)有效
   input  wire                            clken_w; ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_w;  ///< RAM写地址
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]data_w;  ///< RAM待写数据
   input  bit                             clk_q;   ///< RAM读端驱动时钟
   input  wire                            sclr_q;  ///< 输出端寄存器同步复位信号，高电平(1)有效
   input  wire                            clken_q; ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_q;  ///< RAM读地址
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]data_q;  ///< RAM读数据输出

   initial if (longint'(DATABITW) > longint'((2**31/ARRAYSIZ)*2))$error("sdpram_2clk_packedarray: total data bitwidth(%0d) for DATABITW(%0d) and ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*ARRAYSIZ, DATABITW, ARRAYSIZ);
   localparam int totalbitw = DATABITW*ARRAYSIZ;
   wire [totalbitw-1:0] d, q;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in   (data_w  ),
      .out  (d       )
   );
   sdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk_w   ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (d       ),
      .clk_q   (clk_q   ),
      .clken_q (clken_q ),
      .sclr_q  (sclr_q  ),
      .addr_q  (addr_q  ),
      .data_q  (q       )
   );
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in   (q       ),
      .out  (data_q  )
   );
endmodule
module sdpram_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, we, clken_w, addr_w, data_w, clken_q, addr_q, data_q);
   input  bit                             clk;     ///< 驱动时钟
   input  wire                            aclr;    ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclr;    ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            we;      ///< RAM写信号，高电平(1)有效
   input  wire                            clken_w; ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_w;  ///< RAM写地址
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]data_w;  ///< RAM待写数据
   input  wire                            clken_q; ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_q;  ///< RAM读地址
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]data_q;  ///< RAM读数据输出

   sdpram_2clk_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk     ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (data_w  ),
      .clk_q   (clk     ),
      .clken_q (clken_q ),
      .sclr_q  (sclr    ),
      .addr_q  (addr_q  ),
      .data_q  (data_q  )
   );
endmodule
module sdpram2clk4if_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_2clk_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram2clk4if_packedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 2) != DATABITW || $size(p.data_q, 2) != DATABITW)
      $error("sdpram2clk4if_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram2clk4if_packedarray: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));

   sdpram_2clk_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr     ),
      .clk_w   (p.clk_w    ),
      .clken_w (p.clken_w  ),
      .we      (p.we       ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .clk_q   (p.clk_q    ),
      .clken_q (p.clken_q  ),
      .sclr_q  (p.sclr_q   ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   )
   );
endmodule
module sdpram4if_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram4if_packedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 2) != DATABITW || $size(p.data_q, 2) != DATABITW)
      $error("sdpram4if_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram4if_packedarray: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));

   sdpram_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk      ),
      .we      (p.we       ),
      .aclr    (p.aclr     ),
      .sclr    (p.sclr     ),
      .clken_w (p.clken_w  ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .clken_q (p.clken_q  ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   )
   );
endmodule
/*! \brief Simple Dual Port RAM for packed-array with extra data */
module sdpram_2clk_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, extd_w, clk_q, clken_q, addr_q, data_q, extd_q);
   input  bit                             clk_w;   ///< RAM写端驱动时钟
   input  wire                            aclr;    ///< 输出端寄存器异步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            we;      ///< RAM写信号，高电平(1)有效
   input  wire                            clken_w; ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_w;  ///< RAM写地址
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]data_w;  ///< RAM待写数组数据
   input  wire[EXTDBITW-1:0]              extd_w;  ///< RAM待写扩展数据
   input  bit                             clk_q;   ///< RAM读端驱动时钟
   input  wire                            sclr_q;  ///< 输出端寄存器同步复位信号，高电平(1)有效
   input  wire                            clken_q; ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_q;  ///< RAM读地址
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]data_q;  ///< RAM读数组数据输出
   output wire[EXTDBITW-1:0]              extd_q;  ///< RAM读扩展数据输出

   initial if (DATABITW > ((2**31-EXTDBITW/2-(EXTDBITW&1))/ARRAYSIZ)*ARRAYSIZ)
      $error("sdpram_2clk_packedarray_extd: total data bitwidth(%0d) for DATABITW(%0d) , ARRAYSIZ(%0d) and EXTDBITW(%0d) should not be greator than 2**32", DATABITW*ARRAYSIZ+EXTDBITW, DATABITW, ARRAYSIZ, EXTDBITW);
   localparam int totalbitw = DATABITW*ARRAYSIZ + EXTDBITW;
   wire [totalbitw-1:0] d, q;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in   (data_w                    ),
      .out  (d[DATABITW*ARRAYSIZ-1:0]  )
   );
   assign d[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ] = extd_w;
   sdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk_w   ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (d       ),
      .clk_q   (clk_q   ),
      .clken_q (clken_q ),
      .sclr_q  (sclr_q  ),
      .addr_q  (addr_q  ),
      .data_q  (q       )
   );
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in   (q[DATABITW*ARRAYSIZ-1:0]  ),
      .out  (data_q                    )
   );
   assign extd_q = q[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ];
endmodule
module sdpram_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q, data_q, extd_q);
   input  bit                             clk;     ///< 驱动时钟
   input  wire                            aclr;    ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclr;    ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            we;      ///< RAM写信号，高电平(1)有效
   input  wire                            clken_w; ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_w;  ///< RAM写地址
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]data_w;  ///< RAM待写数组数据
   input  wire[EXTDBITW-1:0]              extd_w;  ///< RAM待写扩展数据
   input  wire                            clken_q; ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_q;  ///< RAM读地址
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]data_q;  ///< RAM读数组数据输出
   output wire[EXTDBITW-1:0]              extd_q;  ///< RAM读扩展数据输出

   sdpram_2clk_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk     ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (data_w  ),
      .extd_w  (extd_w  ),
      .clk_q   (clk     ),
      .clken_q (clken_q ),
      .sclr_q  (sclr    ),
      .addr_q  (addr_q  ),
      .data_q  (data_q  ),
      .extd_q  (extd_q  )
   );
endmodule
module sdpram2clk4if_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_2clk_packedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram42clkif_packedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 2) != DATABITW || $size(p.data_q, 2) != DATABITW)
      $error("sdpram2clk4if_packedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram2clk4if_packedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));
   initial if ($bits(p.extd_w) != EXTDBITW || $bits(p.extd_q) != EXTDBITW)
      $error("sdpram2clk4if_packedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.extd_w(%0d) or p.extd_q(%0d)", EXTDBITW, $bits(p.extd_w), $bits(p.extd_q));

   sdpram_2clk_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr     ),
      .clk_w   (p.clk_w    ),
      .clken_w (p.clken_w  ),
      .we      (p.we       ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .extd_w  (p.extd_w   ),
      .clk_q   (p.clk_q    ),
      .clken_q (p.clken_q  ),
      .sclr_q  (p.sclr_q   ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   ),
      .extd_q  (p.extd_q   )
   );
endmodule
module sdpram4if_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_packedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram4if_packedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 2) != DATABITW || $size(p.data_q, 2) != DATABITW)
      $error("sdpram4if_packedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram4if_packedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));
   initial if ($bits(p.extd_w) != EXTDBITW || $bits(p.extd_q) != EXTDBITW)
      $error("sdpram4if_packedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.extd_w(%0d) or p.extd_q(%0d)", EXTDBITW, $bits(p.extd_w), $bits(p.extd_q));

   sdpram_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk      ),
      .aclr    (p.aclr     ),
      .sclr    (p.sclr     ),
      .we      (p.we       ),
      .clken_w (p.clken_w  ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .extd_w  (p.extd_w   ),
      .clken_q (p.clken_q  ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   ),
      .extd_q  (p.extd_q   )
   );
endmodule
/*! \brief Simple Dual Port RAM for unpacked-array */
module sdpram_2clk_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, clk_q, clken_q, addr_q, data_q);
   input  bit                 clk_w;               ///< RAM写端口驱动时钟
   input  wire                aclr;                ///< 输出端寄存器异步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                we;                  ///< RAM写信号，高电平(1)有效
   input  wire                clken_w;             ///< RAM写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_w;              ///< RAM写地址
   input  wire [DATABITW-1:0] data_w[ARRAYSIZ-1:0];///< RAM待写数据
   input  bit                 clk_q;               ///< RAM读端口驱动时钟
   input  wire                sclr_q;              ///< 输出端寄存器同步复位信号，高电平(1)有效
   input  wire                clken_q;             ///< RAM读使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_q;              ///< RAM读地址
   output wire [DATABITW-1:0] data_q[ARRAYSIZ-1:0];///< RAM读数据输出

   wire[ARRAYSIZ-1:0][DATABITW-1:0] d, q;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aci(
      .in   (data_w  ),
      .out  (d       )
   );
   sdpram_2clk_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) sdpram_pai(
      .aclr    (aclr    ),
      .clk_w   (clk_w   ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (d       ),
      .clk_q   (clk_q   ),
      .clken_q (clken_q ),
      .sclr_q  (sclr_q  ),
      .addr_q  (addr_q  ),
      .data_q  (q       )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aco(
      .in   (q       ),
      .out  (data_q  )
   );
endmodule
module sdpram_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, we, clken_w, addr_w, data_w, clken_q, addr_q, data_q);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr;                ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                we;                  ///< RAM写信号，高电平(1)有效
   input  wire                clken_w;             ///< RAM写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_w;              ///< RAM写地址
   input  wire [DATABITW-1:0] data_w[ARRAYSIZ-1:0];///< RAM待写数据
   input  wire                clken_q;             ///< RAM读使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_q;              ///< RAM读地址
   output wire [DATABITW-1:0] data_q[ARRAYSIZ-1:0];///< RAM读数据输出

   wire[ARRAYSIZ-1:0][DATABITW-1:0] d, q;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aci(
      .in   (data_w  ),
      .out  (d       )
   );
   sdpram_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) sdpram_pai(
      .clk     (clk     ),
      .we      (we      ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .clken_w (clken_w ),
      .addr_w  (addr_w  ),
      .data_w  (d       ),
      .clken_q (clken_q ),
      .addr_q  (addr_q  ),
      .data_q  (q       )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   )aco(
      .in   (q       ),
      .out  (data_q  )
   );
endmodule
module sdpram2clk4if_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_2clk_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram2clk4if_unpackedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 2) != DATABITW || $size(p.data_q, 2) != DATABITW)
      $error("sdpram2clk4if_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram2clk4if_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));

   sdpram_2clk_unpackedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr     ),
      .clk_w   (p.clk_w    ),
      .clken_w (p.clken_w  ),
      .we      (p.we       ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .clk_q   (p.clk_q    ),
      .clken_q (p.clken_q  ),
      .sclr_q  (p.sclr_q   ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   )
   );
endmodule
module sdpram4if_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram4if_unpackedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 2) != DATABITW || $size(p.data_q, 2) != DATABITW)
      $error("sdpram4if_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram4if_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));

   sdpram_unpackedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk      ),
      .we      (p.we       ),
      .aclr    (p.aclr     ),
      .sclr    (p.sclr     ),
      .clken_w (p.clken_w  ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .clken_q (p.clken_q  ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   )
   );
endmodule
/*! \brief Simple Dual Port RAM for unpacked-array with extra data */
module sdpram_2clk_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, extd_w, clk_q, clken_q, addr_q, data_q, extd_q);
   input  bit                 clk_w;               ///< RAM写端驱动时钟
   input  wire                aclr;                ///< 输出端寄存器异步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                we;                  ///< RAM写信号，高电平(1)有效
   input  wire                clken_w;             ///< RAM写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_w;              ///< RAM写地址
   input  wire [DATABITW-1:0] data_w[ARRAYSIZ-1:0];///< RAM待写数组数据
   input  wire [EXTDBITW-1:0] extd_w;              ///< RAM待写扩展数据
   input  bit                 clk_q;               ///< RAM读端驱动时钟
   input  wire                sclr_q;              ///< 输出端寄存器同步复位信号，高电平(1)有效
   input  wire                clken_q;             ///< RAM读使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_q;              ///< RAM读地址
   output wire [DATABITW-1:0] data_q[ARRAYSIZ-1:0];///< RAM读数组数据输出
   output wire [EXTDBITW-1:0] extd_q;              ///< RAM读扩展数据输出

   wire[ARRAYSIZ-1:0][DATABITW-1:0] d, q;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aci(
      .in   (data_w  ),
      .out  (d       )
   );
   sdpram_2clk_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) sdprupaei(
      .aclr    (aclr    ),
      .clk_w   (clk_w   ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (d       ),
      .extd_w  (extd_w  ),
      .clk_q   (clk_q   ),
      .clken_q (clken_q ),
      .sclr_q  (sclr_q  ),
      .addr_q  (addr_q  ),
      .data_q  (q       ),
      .extd_q  (extd_q  )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aco(
      .in   (q       ),
      .out  (data_q  )
   );
endmodule
module sdpram_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q, data_q, extd_q);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr;                ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                we;                  ///< RAM写信号，高电平(1)有效
   input  wire                clken_w;             ///< RAM写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_w;              ///< RAM写地址
   input  wire [DATABITW-1:0] data_w[ARRAYSIZ-1:0];///< RAM待写数组数据
   input  wire [EXTDBITW-1:0] extd_w;              ///< RAM待写扩展数据
   input  wire                clken_q;             ///< RAM读使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addr_q;              ///< RAM读地址
   output wire [DATABITW-1:0] data_q[ARRAYSIZ-1:0];///< RAM读数组数据输出
   output wire [EXTDBITW-1:0] extd_q;              ///< RAM读扩展数据输出

   wire[ARRAYSIZ-1:0][DATABITW-1:0] d, q;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aci(
      .in   (data_w  ),
      .out  (d       )
   );
   sdpram_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) sdprupaei(
      .clk     (clk     ),
      .we      (we      ),
      .aclr    (aclr    ),
      .sclr    (sclr    ), 
      .clken_w (clken_w ),
      .addr_w  (addr_w  ),
      .data_w  (d       ),
      .extd_w  (extd_w  ),
      .clken_q (clken_q ),
      .addr_q  (addr_q  ),
      .data_q  (q       ),
      .extd_q  (extd_q  )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) aco(
      .in   (q       ),
      .out  (data_q  )
   );
endmodule
module sdpram2clk4if_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_2clk_unpackedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram2clk4if_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 2) != DATABITW || $size(p.data_q, 2) != DATABITW)
      $error("sdpram2clk4if_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram2clk4if_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));
   initial if ($bits(p.extd_w) != EXTDBITW || $bits(p.extd_q) != EXTDBITW)
      $error("sdpram2clk4if_unpackedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.extd_w(%0d) or p.extd_q(%0d)", EXTDBITW, $bits(p.extd_w), $bits(p.extd_q));

   sdpram_2clk_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr     ),
      .clk_w   (p.clk_w    ),
      .clken_w (p.clken_w  ),
      .we      (p.we       ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .extd_w  (p.extd_w   ),
      .clk_q   (p.clk_q    ),
      .clken_q (p.clken_q  ),
      .sclr_q  (p.sclr_q   ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   ),
      .extd_q  (p.extd_q   )
   );
endmodule
module sdpram4if_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_unpackedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram4if_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 2) != DATABITW || $size(p.data_q, 2) != DATABITW)
      $error("sdpram4if_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram4if_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));
   initial if ($bits(p.extd_w) != EXTDBITW || $bits(p.extd_q) != EXTDBITW)
      $error("sdpram4if_unpackedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.extd_w(%0d) or p.extd_q(%0d)", EXTDBITW, $bits(p.extd_w), $bits(p.extd_q));

   sdpram_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk      ),
      .we      (p.we       ),
      .aclr    (p.aclr     ),
      .sclr    (p.sclr     ), 
      .clken_w (p.clken_w  ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .extd_w  (p.extd_w   ),
      .clken_q (p.clken_q  ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   ),
      .extd_q  (p.extd_q   )
   );
endmodule
/*! \brief Simple Dual Port RAM for packed-unit-packed-array */
module sdpram_2clk_packedunit_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, clk_q, clken_q, addr_q, data_q);
   input  bit                                            clk_w;   ///< RAM写端驱动时钟
   input  wire                                           aclr;    ///< 输出端寄存器异步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                                           we;      ///< RAM写信号，高电平(1)有效
   input  wire                                           clken_w; ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addr_w;  ///< RAM写地址
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_w;  ///< RAM待写数据
   input  bit                                            clk_q;   ///< RAM读端驱动时钟
   input  wire                                           sclr_q;  ///< 输出端寄存器同步复位信号，高电平(1)有效
   input  wire                                           clken_q; ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addr_q;  ///< RAM读地址
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_q;  ///< RAM读数据输出

   initial if (longint'(DATABITW) > longint'((2**31/(ARRAYSIZ*AUNITSIZ))*2))
      $error("sdpram_2clk_packedunit_packedarray: total data bitwidth(%0d) for DATABITW(%0d) and AUNITSIZ(%0d) ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*AUNITSIZ*ARRAYSIZ, DATABITW, AUNITSIZ, ARRAYSIZ);
   localparam int totalbitw = DATABITW*AUNITSIZ*ARRAYSIZ;
   wire [totalbitw-1:0] d, q;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in   (data_w  ),
      .out  (d       )
   );
   sdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk_w   ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (d       ),
      .clk_q   (clk_q   ),
      .clken_q (clken_q ),
      .sclr_q  (sclr_q  ),
      .addr_q  (addr_q  ),
      .data_q  (q       )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in   (q       ),
      .out  (data_q  )
   );
endmodule
module sdpram_packedunit_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, we, clken_w, addr_w, data_w, clken_q, addr_q, data_q);
   input  bit                                            clk;     ///< 驱动时钟
   input  wire                                           aclr;    ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                                           sclr;    ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                                           we;      ///< RAM写信号，高电平(1)有效
   input  wire                                           clken_w; ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addr_w;  ///< RAM写地址
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_w;  ///< RAM待写数据
   input  wire                                           clken_q; ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addr_q;  ///< RAM读地址
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_q;  ///< RAM读数据输出

   sdpram_2clk_packedunit_packedarray #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk     ),
      .clken_w (clken_w ),
      .we      (we      ),      
      .addr_w  (addr_w  ),
      .data_w  (data_w  ),
      .clk_q   (clk     ),
      .clken_q (clken_q ),
      .sclr_q  (sclr    ),
      .addr_q  (addr_q  ),
      .data_q  (data_q  )
   );
endmodule
module sdpram2clk4if_packedunit_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_2clk_packedunit_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram2clk4if_packedunit_packedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 3) != DATABITW || $size(p.data_q, 3) != DATABITW)
      $error("sdpram2clk4if_packedunit_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 2) != AUNITSIZ || $size(p.data_q, 2) != AUNITSIZ)
      $error("sdpram2clk4if_packedunit_packedarray: AUNITSIZ(%0d) does not match the unit size of array p.data_w(%0d) or p.data_q(%0d)", AUNITSIZ, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram2clk4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));

   sdpram_2clk_ppackedunit_packedarray #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr     ),
      .clk_w   (p.clk_w    ),
      .clken_w (p.clken_w  ),
      .we      (p.we       ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .clk_q   (p.clk_q    ),
      .clken_q (p.clken_q  ),
      .sclr_q  (p.sclr_q   ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   )
   );
endmodule
module sdpram4if_packedunit_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_packedunit_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram4if_packedunit_packedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 3) != DATABITW || $size(p.data_q, 3) != DATABITW)
      $error("sdpram4if_packedunit_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 3), $size(p.data_q, 3));
   initial if ($size(p.data_w, 2) != AUNITSIZ || $size(p.data_q, 2) != AUNITSIZ)
      $error("sdpram4if_packedunit_packedarray: AUNITSIZ(%0d) does not match the unit size of array p.data_w(%0d) or p.data_q(%0d)", AUNITSIZ, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));

   sdpram_packedunit_packedarray #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk      ),
      .we      (p.we       ),
      .aclr    (p.aclr     ),
      .sclr    (p.sclr     ),
      .clken_w (p.clken_w  ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .clken_q (p.clken_q  ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   )
   );
endmodule
/*! \brief Simple Dual Port RAM for packed-unit-packed-array with extra data */
module sdpram_2clk_packedunit_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, extd_w, clk_q, clken_q, addr_q, data_q, extd_q);
   input  bit                                            clk_w;   ///< RAM写端驱动时钟
   input  wire                                           aclr;    ///< 输出端寄存器异步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                                           we;      ///< RAM写信号，高电平(1)有效
   input  wire                                           clken_w; ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addr_w;  ///< RAM写地址
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_w;  ///< RAM待写数据
   input  wire[EXTDBITW-1:0]                             extd_w;  ///< RAM待写扩展数据
   input  bit                                            clk_q;   ///< RAM读端驱动时钟
   input  wire                                           sclr_q;  ///< 输出端寄存器同步复位信号，高电平(1)有效
   input  wire                                           clken_q; ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addr_q;  ///< RAM读地址
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_q;  ///< RAM读数据输出
   output wire[EXTDBITW-1:0]                             extd_q;  ///< RAM读扩展数据输出

   initial if (longint'(DATABITW) > longint'((2**31/(ARRAYSIZ*AUNITSIZ))*2))
      $error("sdpram_2clk_packedunit_packedarray_extd: total data bitwidth(%0d) for DATABITW(%0d) and AUNITSIZ(%0d) ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*AUNITSIZ*ARRAYSIZ, DATABITW, AUNITSIZ, ARRAYSIZ);
   localparam int totalbitw = DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW;
   wire [totalbitw-1:0] d, q;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in   (data_w                             ),
      .out  (d[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]  )
   );
   assign d[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ] = extd_w;
   sdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk_w   ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (d       ),
      .clk_q   (clk_q   ),
      .clken_q (clken_q ),
      .sclr_q  (sclr_q  ),
      .addr_q  (addr_q  ),
      .data_q  (q       )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in   (q[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]  ),
      .out  (data_q                             )
   );
   assign extd_q = q[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ];
endmodule
module sdpram_packedunit_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q, data_q, extd_q);
   input  bit                                            clk;     ///< 驱动时钟
   input  wire                                           aclr;    ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                                           sclr;    ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                                           we;      ///< RAM写信号，高电平(1)有效
   input  wire                                           clken_w; ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addr_w;  ///< RAM写地址
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_w;  ///< RAM待写数据
   input  wire[EXTDBITW-1:0]                             extd_w;  ///< RAM待写扩展数据
   input  wire                                           clken_q; ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addr_q;  ///< RAM读地址
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] data_q;  ///< RAM读数据输出
   output wire[EXTDBITW-1:0]                             extd_q;  ///< RAM读扩展数据输出

   sdpram_2clk_packedunit_packedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk     ),
      .clken_w (clken_w ),
      .we      (we      ),      
      .addr_w  (addr_w  ),
      .data_w  (data_w  ),
      .extd_w  (extd_w  ),
      .clk_q   (clk     ),
      .clken_q (clken_q ),
      .sclr_q  (sclr    ),
      .addr_q  (addr_q  ),
      .data_q  (data_q  ),
      .extd_q  (extd_q  )
   );
endmodule
module sdpram2clk4if_packedunit_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_2clk_packedunit_packedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram2clk4if_packedunit_packedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 3) != DATABITW || $size(p.data_q, 3) != DATABITW)
      $error("sdpram2clk4if_packedunit_packedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 2) != AUNITSIZ || $size(p.data_q, 2) != AUNITSIZ)
      $error("sdpram2clk4if_packedunit_packedarray_extd: AUNITSIZ(%0d) does not match the unit size of array p.data_w(%0d) or p.data_q(%0d)", AUNITSIZ, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram2clk4if_packedunit_packedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));
   initial if ($bits(p.extd_w) != EXTDBITW || $bits(p.extd_q) != EXTDBITW)
      $error("sdpram2clk4if_packedunit_packedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.extd_w(%0d) or p.extd_q(%0d)", EXTDBITW, $bits(p.extd_w), $bits(p.extd_q));

   sdpram_2clk_packedunit_packedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr     ),
      .clk_w   (p.clk_w    ),
      .clken_w (p.clken_w  ),
      .we      (p.we       ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .extd_w  (p.extd_w   ),
      .clk_q   (p.clk_q    ),
      .clken_q (p.clken_q  ),
      .sclr_q  (p.sclr_q   ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   ),
      .extd_q  (p.extd_q   )
   );
endmodule
module sdpram4if_packedunit_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_packedunit_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram4if_packedunit_packedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 3) != DATABITW || $size(p.data_q, 3) != DATABITW)
      $error("sdpram4if_packedunit_packedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 3), $size(p.data_q, 3));
   initial if ($size(p.data_w, 2) != AUNITSIZ || $size(p.data_q, 2) != AUNITSIZ)
      $error("sdpram4if_packedunit_packedarray_extd: AUNITSIZ(%0d) does not match the unit size of array p.data_w(%0d) or p.data_q(%0d)", AUNITSIZ, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram4if_packedunit_packedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));
   initial if ($bits(p.extd_w) != EXTDBITW || $bits(p.extd_q) != EXTDBITW)
      $error("sdpram4if_packedunit_packedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.extd_w(%0d) or p.extd_q(%0d)", EXTDBITW, $bits(p.extd_w), $bits(p.extd_q));

   sdpram_packedunit_packedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk      ),
      .we      (p.we       ),
      .aclr    (p.aclr     ),
      .sclr    (p.sclr     ),
      .clken_w (p.clken_w  ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .extd_w  (p.extd_w   ),
      .clken_q (p.clken_q  ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   ),
      .extd_q  (p.extd_q   )
   );
endmodule
/*! \brief Simple Dual Port RAM for packed-unit-unpacked-array with extra data */
module sdpram_2clk_packedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, extd_w, clk_q, clken_q, addr_q, data_q, extd_q);
   input  bit                             clk_w;               ///< RAM写端驱动时钟
   input  wire                            aclr;                ///< 输出端寄存器异步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            we;                  ///< RAM写信号，高电平(1)有效
   input  wire                            clken_w;             ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_w;              ///< RAM写地址
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]data_w[ARRAYSIZ-1:0];///< RAM待写数据
   input  wire[EXTDBITW-1:0]              extd_w;              ///< RAM待写扩展数据
   input  bit                             clk_q;               ///< RAM读端驱动时钟
   input  wire                            sclr_q;              ///< 输出端寄存器同步复位信号，高电平(1)有效
   input  wire                            clken_q;             ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_q;              ///< RAM读地址
   output wire[AUNITSIZ-1:0][DATABITW-1:0]data_q[ARRAYSIZ-1:0];///< RAM读数据输出
   output wire[EXTDBITW-1:0]              extd_q;              ///< RAM读扩展数据输出

   initial if (longint'(DATABITW) > longint'((2**31/(ARRAYSIZ*AUNITSIZ))*2))
      $error("sdpram_2clk_packedunit_unpackedarray_extd: total data bitwidth(%0d) for DATABITW(%0d) and AUNITSIZ(%0d) ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*AUNITSIZ*ARRAYSIZ, DATABITW, AUNITSIZ, ARRAYSIZ);
   localparam int totalbitw = DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW;
   wire [totalbitw-1:0] d, q;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in   (data_w                             ),
      .out  (d[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]  )
   );
   assign d[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ] = extd_w;
   sdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk_w   ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (d       ),
      .clk_q   (clk_q   ),
      .clken_q (clken_q ),
      .sclr_q  (sclr_q  ),
      .addr_q  (addr_q  ),
      .data_q  (q       )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in   (q[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]  ),
      .out  (data_q                             )
   );
   assign extd_q = q[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ];
endmodule
module sdpram_packedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q, data_q, extd_q);
   input  bit                             clk;                 ///< 驱动时钟
   input  wire                            aclr;                ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclr;                ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            we;                  ///< RAM写信号，高电平(1)有效
   input  wire                            clken_w;             ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_w;              ///< RAM写地址
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]data_w[ARRAYSIZ-1:0];///< RAM待写数据
   input  wire[EXTDBITW-1:0]              extd_w;              ///< RAM待写扩展数据
   input  wire                            clken_q;             ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addr_q;              ///< RAM读地址
   output wire[AUNITSIZ-1:0][DATABITW-1:0]data_q[ARRAYSIZ-1:0];///< RAM读数据输出
   output wire[EXTDBITW-1:0]              extd_q;              ///< RAM读扩展数据输出

   sdpram_2clk_packedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk     ),
      .clken_w (clken_w ),
      .we      (we      ),      
      .addr_w  (addr_w  ),
      .data_w  (data_w  ),
      .extd_w  (extd_w  ),
      .clk_q   (clk     ),
      .clken_q (clken_q ),
      .sclr_q  (sclr    ),
      .addr_q  (addr_q  ),
      .data_q  (data_q  ),
      .extd_q  (extd_q  )
   );
endmodule
module sdpram2clk4if_packedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_2clk_packedunit_unpackedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram2clk4if_packedunit_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 3) != DATABITW || $size(p.data_q, 3) != DATABITW)
      $error("sdpram2clk4if_packedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 3), $size(p.data_q, 3));
   initial if ($size(p.data_w, 2) != AUNITSIZ || $size(p.data_q, 2) != AUNITSIZ)
      $error("sdpram2clk4if_packedunit_unpackedarray_extd: AUNITSIZ(%0d) does not match the unit size of array p.data_w(%0d) or p.data_q(%0d)", AUNITSIZ, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram2clk4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));
   initial if ($bits(p.extd_w) != EXTDBITW || $bits(p.extd_q) != EXTDBITW)
      $error("sdpram2clk4if_packedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.extd_w(%0d) or p.extd_q(%0d)", EXTDBITW, $bits(p.extd_w), $bits(p.extd_q));

   sdpram_2clk_packedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr     ),
      .clk_w   (p.clk_w    ),
      .clken_w (p.clken_w  ),
      .we      (p.we       ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .extd_w  (p.extd_w   ),
      .clk_q   (p.clk_q    ),
      .clken_q (p.clken_q  ),
      .sclr_q  (p.sclr_q   ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   ),
      .extd_q  (p.extd_q   )
   );
endmodule
module sdpram4if_packedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_packedunit_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram4if_packedunit_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 3) != DATABITW || $size(p.data_q, 3) != DATABITW)
      $error("sdpram4if_packedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 3), $size(p.data_q, 3));
   initial if ($size(p.data_w, 2) != AUNITSIZ || $size(p.data_q, 2) != AUNITSIZ)
      $error("sdpram4if_packedunit_unpackedarray_extd: AUNITSIZ(%0d) does not match the unit size of array p.data_w(%0d) or p.data_q(%0d)", AUNITSIZ, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));
   initial if ($bits(p.extd_w) != EXTDBITW || $bits(p.extd_q) != EXTDBITW)
      $error("sdpram4if_packedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.extd_w(%0d) or p.extd_q(%0d)", EXTDBITW, $bits(p.extd_w), $bits(p.extd_q));

   sdpram_packedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk      ),
      .we      (p.we       ),
      .aclr    (p.aclr     ),
      .sclr    (p.sclr     ),
      .clken_w (p.clken_w  ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .extd_w  (p.extd_w   ),
      .clken_q (p.clken_q  ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   ),
      .extd_q  (p.extd_q   )
   );
endmodule
/*! \brief Simple Dual Port RAM for unpacked-unit-unpacked-array with extra data */
module sdpram_2clk_unpackedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk_w, aclr, sclr_q, we, clken_w, addr_w, data_w, extd_w, clk_q, clken_q, addr_q, data_q, extd_q);
   input  bit                 clk_w;                             ///< RAM写端驱动时钟
   input  wire                aclr;                              ///< 输出端寄存器异步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                we;                                ///< RAM写信号，高电平(1)有效
   input  wire                clken_w;                           ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]  addr_w;                            ///< RAM写地址
   input  wire[DATABITW-1:0]  data_w[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< RAM待写数据
   input  wire[EXTDBITW-1:0]  extd_w;                            ///< RAM待写扩展数据
   input  bit                 clk_q;                             ///< RAM读端驱动时钟
   input  wire                sclr_q;                            ///< 输出端寄存器同步复位信号，高电平(1)有效
   input  wire                clken_q;                           ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]  addr_q;                            ///< RAM读地址
   output wire[DATABITW-1:0]  data_q[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< RAM读数据输出
   output wire[EXTDBITW-1:0]  extd_q;                            ///< RAM读扩展数据输出

   initial if (longint'(DATABITW) > longint'((2**31/(ARRAYSIZ*AUNITSIZ))*2))
      $error("sdpram_2clk_unpackedunit_unpackedarray_extd: total data bitwidth(%0d) for DATABITW(%0d) and AUNITSIZ(%0d) ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*AUNITSIZ*ARRAYSIZ, DATABITW, AUNITSIZ, ARRAYSIZ);
   localparam int totalbitw = DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW;
   wire [totalbitw-1:0] d, q;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2u(
      .in   (data_w                             ),
      .out  (d[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]  )
   );
   assign d[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ] = extd_w;
   sdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk_w   ),
      .clken_w (clken_w ),
      .we      (we      ),
      .addr_w  (addr_w  ),
      .data_w  (d       ),
      .clk_q   (clk_q   ),
      .clken_q (clken_q ),
      .sclr_q  (sclr_q  ),
      .addr_q  (addr_q  ),
      .data_q  (q       )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2a(
      .in   (q[DATABITW*AUNITSIZ*ARRAYSIZ-1:0]  ),
      .out  (data_q                             )
   );
   assign extd_q = q[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ];
endmodule
module sdpram_unpackedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, we, clken_w, addr_w, data_w, extd_w, clken_q, addr_q, data_q, extd_q);
   input  bit                 clk;                               ///< 驱动时钟
   input  wire                aclr;                              ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                sclr;                              ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                we;                                ///< RAM写信号，高电平(1)有效
   input  wire                clken_w;                           ///< RAM写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]  addr_w;                            ///< RAM写地址
   input  wire[DATABITW-1:0]  data_w[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< RAM待写数据
   input  wire[EXTDBITW-1:0]  extd_w;                            ///< RAM待写扩展数据
   input  wire                clken_q;                           ///< RAM读使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]  addr_q;                            ///< RAM读地址
   output wire[DATABITW-1:0]  data_q[ARRAYSIZ-1:0][AUNITSIZ-1:0];///< RAM读数据输出
   output wire[EXTDBITW-1:0]  extd_q;                            ///< RAM读扩展数据输出

   sdpram_2clk_packedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clk_w   (clk     ),
      .clken_w (clken_w ),
      .we      (we      ),      
      .addr_w  (addr_w  ),
      .data_w  (data_w  ),
      .extd_w  (extd_w  ),
      .clk_q   (clk     ),
      .clken_q (clken_q ),
      .sclr_q  (sclr    ),
      .addr_q  (addr_q  ),
      .data_q  (data_q  ),
      .extd_q  (extd_q  )
   );
endmodule
module sdpram2clk4if_unpackedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_2clk_packedunit_unpackedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram2clk4if_unpackedunit_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 3) != DATABITW || $size(p.data_q, 3) != DATABITW)
      $error("sdpram2clk4if_unpackedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 3), $size(p.data_q, 3));
   initial if ($size(p.data_w, 2) != AUNITSIZ || $size(p.data_q, 2) != AUNITSIZ)
      $error("sdpram2clk4if_unpackedunit_unpackedarray_extd: AUNITSIZ(%0d) does not match the unit size of array p.data_w(%0d) or p.data_q(%0d)", AUNITSIZ, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram2clk4if_unpackedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));
   initial if ($bits(p.extd_w) != EXTDBITW || $bits(p.extd_q) != EXTDBITW)
      $error("sdpram2clk4if_unpackedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.extd_w(%0d) or p.extd_q(%0d)", EXTDBITW, $bits(p.extd_w), $bits(p.extd_q));

   sdpram_2clk_unpackedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr     ),
      .clk_w   (p.clk_w    ),
      .clken_w (p.clken_w  ),
      .we      (p.we       ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .extd_w  (p.extd_w   ),
      .clk_q   (p.clk_q    ),
      .clken_q (p.clken_q  ),
      .sclr_q  (p.sclr_q   ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   ),
      .extd_q  (p.extd_q   )
   );
endmodule
module sdpram4if_unpackedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (sdpram_packedunit_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addr_w) != addrBitw || $bits(p.addr_q) != addrBitw)
      $error("sdpram4if_unpackedunit_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addr_w(%0d) or p.addr_q(%0d)", addrBitw, ADDRLEN, $bits(p.addr_w), $bits(p.addr_q));
   initial if ($size(p.data_w, 3) != DATABITW || $size(p.data_q, 3) != DATABITW)
      $error("sdpram4if_unpackedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.data_w(%0d) or p.data_q(%0d)", DATABITW, $size(p.data_w, 3), $size(p.data_q, 3));
   initial if ($size(p.data_w, 2) != AUNITSIZ || $size(p.data_q, 2) != AUNITSIZ)
      $error("sdpram4if_unpackedunit_unpackedarray_extd: AUNITSIZ(%0d) does not match the unit size of array p.data_w(%0d) or p.data_q(%0d)", AUNITSIZ, $size(p.data_w, 2), $size(p.data_q, 2));
   initial if ($size(p.data_w, 1) != ARRAYSIZ || $size(p.data_q, 1) != ARRAYSIZ)
      $error("sdpram4if_unpackedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.data_w(%0d) or p.data_q(%0d)", ARRAYSIZ, $size(p.data_w, 1), $size(p.data_q, 1));
   initial if ($bits(p.extd_w) != EXTDBITW || $bits(p.extd_q) != EXTDBITW)
      $error("sdpram4if_unpackedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.extd_w(%0d) or p.extd_q(%0d)", EXTDBITW, $bits(p.extd_w), $bits(p.extd_q));

   sdpram_unpackedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk      ),
      .we      (p.we       ),
      .aclr    (p.aclr     ),
      .sclr    (p.sclr     ),
      .clken_w (p.clken_w  ),
      .addr_w  (p.addr_w   ),
      .data_w  (p.data_w   ),
      .extd_w  (p.extd_w   ),
      .clken_q (p.clken_q  ),
      .addr_q  (p.addr_q   ),
      .data_q  (p.data_q   ),
      .extd_q  (p.extd_q   )
   );
endmodule
/*! \brief Basic True Dual Port RAM */
module basic_tdpram_2clk #(
   parameter int DATABITW = 34,                    ///< 数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter     RAMSTYLE = rams_pkg::ramstyle_auto///< RAM例化特征标识
) (clka, wea, clkena, addra, da, qa, clkb, web, clkenb, addrb, db, qb);
   input  bit                 clka, clkb;          ///< 驱动时钟
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                wea, web;            ///< RAM端口写信号，高电平(1)有效
   input  wire                clkena, clkenb;      ///< RAM端口读写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addra, addrb;        ///< RAM端口读写地址
   input  wire [DATABITW-1:0] da, db;              ///< RAM端口输入信号
   output logic[DATABITW-1:0] qa, qb;              ///< RAM端口输出信号

   initial if (RAMMODE < 0 || RAMMODE > 2) $error("basic_tdpram_2clk: parameter RAMMODE(%0d) is illegal, only one of (0,1,2) is allowed", RAMMODE);
   (* ram_style = RAMSTYLE *)
   reg[DATABITW-1:0] ram[ADDRLEN-1:0];
   initial for (int i = 0; i < ADDRLEN; i++) ram[i] = '0;
   generate
   if (RAMMODE == 2) begin: WRITEFIRST
      always @(posedge clka) begin
         if (clkena) begin
            if (wea) begin
               ram[addra] <= da;
               qa <= da;
            end else qa <= ram[addra];
         end
      end
      always @(posedge clkb) begin
         if (clkenb) begin
            if (web) begin
               ram[addrb] <= db;
               qb <= db;
            end else qb <= ram[addrb];
         end
      end
   end
   else if (RAMMODE == 1) begin: READFIRST
      always @(posedge clka) begin
         if (clkena) begin
            if (wea) ram[addra] <= da;
            qa <= ram[addra];
         end
      end
      always @(posedge clkb) begin
         if (clkenb) begin
            if (web) ram[addrb] <= db;
            qb <= ram[addrb];
         end
      end
   end
   else begin: NOCHANGE
      always @(posedge clka) begin
         if (clkena) begin
            if (wea) ram[addra] <= da;
            else     qa <= ram[addra];
         end
      end
      always @(posedge clkb) begin
         if (clkenb) begin
            if (web) ram[addrb] <= db;
            else     qb <= ram[addrb];
         end
      end
   end
   endgenerate
endmodule
module basic_tdpram #(
   parameter int DATABITW = 34,                    ///< 数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0                      ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
) (clk, wea, clkena, addra, da, qa, web, clkenb, addrb, db, qb);
   input  bit                 clk;                 ///< 驱动时钟
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                wea, web;            ///< RAM端口写信号，高电平(1)有效
   input  wire                clkena, clkenb;      ///< RAM端口读写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addra, addrb;        ///< RAM端口读写地址
   input  wire [DATABITW-1:0] da, db;              ///< RAM端口输入信号
   output logic[DATABITW-1:0] qa, qb;              ///< RAM端口输出信号

   basic_tdpram_2clk #(
      .DATABITW(DATABITW               ),
      .ADDRLEN (ADDRLEN                ),
      .RAMMODE (RAMMODE                ),
      .RAMSTYLE(rams_pkg::ramstyle_auto)
   ) tdprami(
      .clka    (clk     ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (da      ),
      .qa      (qa      ),
      .clkb    (clk     ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (db      ),
      .qb      (qb      )
   );
endmodule
/*! \brief True Dual Port RAM */
module tdpram_2clk #(
   parameter int DATABITW = 34,                    ///< RAM数据位宽
   parameter int ADDRLEN  = 5,                     ///< RAM地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clka, aclr, sclra, wea, clkena, addra, da, qa, clkb, sclrb, web, clkenb, addrb, db, qb);
   input  bit                 clka, clkb;          ///< 驱动时钟
   input  wire                aclr;                ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                sclra, sclrb;        ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                wea, web;            ///< RAM端口写信号，高电平(1)有效
   input  wire                clkena, clkenb;      ///< RAM端口读写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addra, addrb;        ///< RAM端口读写地址
   input  wire [DATABITW-1:0] da, db;              ///< RAM端口输入信号
   output logic[DATABITW-1:0] qa, qb;              ///< RAM端口输出信号

   initial if (IMPLMOD > 2) $error("sdpram_2clk: illegal parameter IMPLMOD(%0d) specified, only 2,1,0 is allowed!", IMPLMOD);
   wire[DATABITW-1:0]a2q, b2q;
   genvar i, j; generate if (IMPLMOD == 2) begin: MINAREA
      localparam _l_rams_pkg::bitwtyp_alloc_t bta = /*_l_rams_pkg::make_null_bta();*/_l_rams_pkg::generate_economic_alloc_scheme(
                                                                                                   .rambits_ofblk    (miscs::blkram_rambits        ),
                                                                                                   .maxbitw_pblkram  (miscs::blkram_maxbitw4tdp    ),
                                                                                                   .minbitw4norsv    (miscs::blkram_minbitw4norsv  ),
                                                                                                   .bitw2alloc       (DATABITW                     ),
                                                                                                   .depth            (ADDRLEN                      )
                                                                                                );
      localparam int ibitwtypbgn = miscs::minbitw_of_integer(miscs::blkram_maxbitw4tdp, 32) - ((miscs::blkram_minbitw4norsv <= 0) ? 1 : 0);
      for (i = 0; i < _l_rams_pkg::bitwtyp_cnt_tdp; i++) begin: BTA
         localparam int ibitw_bgn = i == 0 ? 0 : _l_rams_pkg::count_allcated_bitw_ofbta(
                                                               .maxbitw_pblkram  (miscs::blkram_maxbitw4tdp    ),
                                                               .minbitw4norsv    (miscs::blkram_minbitw4norsv  ),
                                                               .bta              (bta                          ),
                                                               .imaxbitwtp       (ibitwtypbgn                  ),
                                                               .ibt2bgn          (0                            ),
                                                               .ibt2end          (i-1                          )
                                                            );
         localparam int bitwof_ibt = _l_rams_pkg::bitwof_ibt_in_bta(
                                                   .maxbitw_pblkram  (miscs::blkram_maxbitw4tdp    ),
                                                   .minbitw4norsv    (miscs::blkram_minbitw4norsv  ),
                                                   .imaxbitwtp       (ibitwtypbgn                  ),
                                                   .ibt              (i                            )
                                                );
         for (j = 0; j < bta[i]; j++) begin: E
            localparam int imsb_ofdata_inbta = (ibitw_bgn+bitwof_ibt*(j+1) > DATABITW ? DATABITW : ibitw_bgn+bitwof_ibt*(j+1)) - 1;
            localparam int imsb_ofbta = ibitw_bgn+bitwof_ibt*(j+1) - 1;
            localparam int ilsb_ofbta = ibitw_bgn+bitwof_ibt*j;
            localparam int bitw_ofrai = bitwof_ibt - (imsb_ofbta - imsb_ofdata_inbta);
            wire[bitw_ofrai-1:0] rami_da, rami_db, rami_qa, rami_qb;
            assign rami_da[bitwof_ibt - (imsb_ofbta - imsb_ofdata_inbta) - 1:0] = da[imsb_ofdata_inbta:ilsb_ofbta];
            assign rami_db[bitwof_ibt - (imsb_ofbta - imsb_ofdata_inbta) - 1:0] = db[imsb_ofdata_inbta:ilsb_ofbta];
            basic_tdpram_2clk #(
               .DATABITW(bitw_ofrai             ),
               .ADDRLEN (ADDRLEN                ),
               .RAMMODE (RAMMODE                ),
               .RAMSTYLE(rams_pkg::ramstyle_ram )
            ) rami(
               .clka    (clka          ),
               .wea     (wea           ),
               .clkena  (clkena|sclra  ),
               .addra   (addra         ),
               .da      (rami_da       ),
               .qa      (rami_qa       ),
               .clkb    (clkb          ),
               .web     (web           ),
               .clkenb  (clkenb|sclrb  ),
               .addrb   (addrb         ),
               .db      (rami_db       ),
               .qb      (rami_qb       )
            );
            assign a2q[imsb_ofdata_inbta:ibitw_bgn+bitwof_ibt*j] = rami_qa[imsb_ofdata_inbta - (ibitw_bgn+bitwof_ibt*j):0];
            assign b2q[imsb_ofdata_inbta:ibitw_bgn+bitwof_ibt*j] = rami_qb[imsb_ofdata_inbta - (ibitw_bgn+bitwof_ibt*j):0];
         end
      end
   end else if (IMPLMOD == 0) begin: MAPREG
      basic_tdpram_2clk #(
         .DATABITW(DATABITW                  ),
         .ADDRLEN (ADDRLEN                   ),
         .RAMMODE (RAMMODE                   ),
         .RAMSTYLE(rams_pkg::ramstyle_logic  )
      ) rami(
         .clka    (clka          ),
         .wea     (wea           ),
         .clkena  (clkena|sclra  ),
         .addra   (addra         ),
         .da      (da            ),
         .qa      (a2q           ),
         .clkb    (clkb          ),
         .web     (web           ),
         .clkenb  (clkenb|sclrb  ),
         .addrb   (addrb         ),
         .db      (db            ),
         .qb      (b2q           )
      );
   end else begin: NORMMOD
      basic_tdpram_2clk #(
         .DATABITW(DATABITW               ),
         .ADDRLEN (ADDRLEN                ),
         .RAMMODE (RAMMODE                ),
         .RAMSTYLE(rams_pkg::ramstyle_auto)
      ) rami(
         .clka    (clka          ),
         .wea     (wea           ),
         .clkena  (clkena|sclra  ),
         .addra   (addra         ),
         .da      (da            ),
         .qa      (a2q           ),
         .clkb    (clkb          ),
         .web     (web           ),
         .clkenb  (clkenb|sclrb  ),
         .addrb   (addrb         ),
         .db      (db            ),
         .qb      (b2q           )
      );
   end
   if (REGOUTP) begin
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clka, aclr)) begin
         if      (aclr) qa <= '0;
         else if (sclra)qa <= '0;
         else           qa <= clkena ? a2q : qa;
      end
      always_ff @(`CLKTABLE_POSEDGE_ASYNC_CLR(clkb, aclr)) begin
         if      (aclr) qb <= '0;
         else if (sclrb)qb <= '0;
         else           qb <= clkenb ? b2q : qb;
      end
   end else assign qa = a2q, qb = b2q;
   endgenerate
endmodule
module tdpram #(
   parameter int DATABITW = 34,                    ///< RAM数据位宽
   parameter int ADDRLEN  = 5,                     ///< RAM地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, wea, clkena, addra, da, qa, web, clkenb, addrb, db, qb);
   input  bit                 clk;                 ///< 驱动时钟
   input  wire                aclr;                ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                sclr;                ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                wea, web;            ///< RAM端口写信号，高电平(1)有效
   input  wire                clkena, clkenb;      ///< RAM端口读写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addra, addrb;        ///< RAM端口读写地址
   input  wire [DATABITW-1:0] da, db;              ///< RAM端口输入信号
   output logic[DATABITW-1:0] qa, qb;              ///< RAM端口输出信号

   tdpram_2clk #(
      .DATABITW(DATABITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clk     ),
      .sclra   (sclr    ),
      .clkena  (clkena  ),
      .wea     (wea     ),
      .addra   (addra   ),
      .da      (da      ),
      .qa      (qa      ),
      .clkb    (clk     ),
      .sclrb   (sclr    ),
      .clkenb  (clkenb  ),
      .web     (web     ),
      .addrb   (addrb   ),
      .db      (db      ),
      .qb      (qb      )
   );
endmodule
module tdpram2clk4if #(
   parameter int DATABITW = 34,                    ///< 数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($bits(p.da) != DATABITW || $bits(p.db) != DATABITW)
      $error("tdpram2clk4if: DATABITW(%0d) does not match the bitwidth of p.da(%0d) or .p.db(%0d)", DATABITW, $bits(p.da), $bits(p.db));
   initial if ($bits(p.qa) != DATABITW || $bits(p.qb) != DATABITW)
      $error("tdpram2clk4if: DATABITW(%0d) does not match the bitwidth of p.qa(%0d) or .p.qb(%0d)", DATABITW, $bits(p.qa), $bits(p.qb));
   tdpram_2clk #(
      .DATABITW(DATABITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclr  ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
module tdpram4if #(
   parameter int DATABITW = 34,                    ///< 数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($bits(p.da) != DATABITW || $bits(p.db) != DATABITW)
      $error("tdpram4if: DATABITW(%0d) does not match the bitwidth of p.da(%0d) or .p.db(%0d)", DATABITW, $bits(p.da), $bits(p.db));
   initial if ($bits(p.qa) != DATABITW || $bits(p.qb) != DATABITW)
      $error("tdpram4if: DATABITW(%0d) does not match the bitwidth of p.qa(%0d) or .p.qb(%0d)", DATABITW, $bits(p.qa), $bits(p.qb));
   tdpram #(
      .DATABITW(DATABITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
/*! \brief True Dual Port RAM for packed-array */
module tdpram_2clk_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clka, aclr, sclra, wea, clkena, addra, da, qa, clkb, sclrb, web, clkenb, addrb, db, qb);
   input  bit                             clka, clkb;    ///< 驱动时钟
   input  wire                            aclr;          ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclra, sclrb;  ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            wea, web;      ///< RAM端口写信号，高电平(1)有效
   input  wire                            clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addra, addrb;  ///< RAM端口读写地址
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]da, db;        ///< RAM端口输入信号
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]qa, qb;        ///< RAM端口输出信号

   initial if (longint'(DATABITW) > longint'((2**31/ARRAYSIZ)*2))$error("tdpram_2clk_packedarray: total data bitwidth(%0d) for DATABITW(%0d) and ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*ARRAYSIZ, DATABITW, ARRAYSIZ);
   localparam int totalbitw = DATABITW*ARRAYSIZ;
   wire [totalbitw-1:0] pda, pdb, pqa, pqb;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ua(
      .in   (da   ),
      .out  (pda  )
   );
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ub(
      .in   (db   ),
      .out  (pdb  )
   );
   tdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .RAMMODE (RAMMODE    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clka    ),
      .sclra   (sclra   ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .qa      (pqa     ),
      .clkb    (clkb    ),
      .sclrb   (sclrb   ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .qb      (pqb     )
   );
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2aa(
      .in   (pqa  ),
      .out  (qa   )
   );
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2ab(
      .in   (pqb  ),
      .out  (qb   )
   );
endmodule
module tdpram_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, clkena, wea, addra, da, qa, clkenb, web, addrb, db, qb);
   input  bit                             clk;           ///< 驱动时钟
   input  wire                            aclr;          ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclr;          ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            wea, web;      ///< RAM端口写信号，高电平(1)有效
   input  wire                            clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addra, addrb;  ///< RAM端口读写地址
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]da, db;        ///< RAM端口输入信号
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]qa, qb;        ///< RAM端口输出信号

   tdpram_2clk_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clk     ),
      .sclra   (sclr    ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (da      ),
      .qa      (qa      ),
      .clkb    (clk     ),
      .sclrb   (sclr    ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (db      ),
      .qb      (qb      )
   );
endmodule
module tdpram2clk4if_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if_packedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 2) != DATABITW || $size(p.db, 2) != DATABITW)
      $error("tdpram2clk4if_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 2) != DATABITW || $size(p.qb, 2) != DATABITW)
      $error("tdpram2clk4if_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_2clk_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclra ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclrb ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
module tdpram4if_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if_packedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 2) != DATABITW || $size(p.db, 2) != DATABITW)
      $error("tdpram4if_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("sdpram4if_packedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 2) != DATABITW || $size(p.qb, 2) != DATABITW)
      $error("tdpram4if_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("sdpram4if_packedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
/*! \brief True Dual Port RAM for packed-array with extra data */
module tdpram_2clk_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (aclr, clka, sclra, wea, clkena, addra, da, dea, qa, qea, clkb, sclrb, web, clkenb, addrb, db, deb, qb, qeb);
   input  bit                             clka, clkb;    ///< 驱动时钟
   input  wire                            aclr;          ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclra, sclrb;  ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            wea, web;      ///< RAM端口写信号，高电平(1)有效
   input  wire                            clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addra, addrb;  ///< RAM端口读写地址
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]da, db;        ///< RAM端口输入信号
   input  wire[EXTDBITW-1:0]              dea, deb;      ///< RAM端口扩展非数组数据输入信号
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]qa, qb;        ///< RAM端口输出信号
   output wire[EXTDBITW-1:0]              qea, qeb;      ///< RAM端口扩展非数组数据输出信号

   initial if (DATABITW > ((2**31-EXTDBITW/2-(EXTDBITW&1))/ARRAYSIZ)*2)$error("tdpram_2clk_packedarray_extd: total data bitwidth(%0d) for DATABITW(%0d) , ARRAYSIZ(%0d) and EXTDBITW(%0d) should not be greator than 2**32", DATABITW*ARRAYSIZ+EXTDBITW, DATABITW, ARRAYSIZ, EXTDBITW);
   localparam int totalbitw = DATABITW*ARRAYSIZ + EXTDBITW;
   wire [totalbitw-1:0] pda, pdb, pqa, pqb;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ua(
      .in   (da                        ),
      .out  (pda[DATABITW*ARRAYSIZ-1:0])
   );
   assign pda[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ] = dea;
   packedarray_combine2unit #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ub(
      .in   (db                        ),
      .out  (pdb[DATABITW*ARRAYSIZ-1:0])
   );
   assign pdb[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ] = deb;
   tdpram_2clk #(
      .DATABITW(DATABITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clka    ),
      .sclra   (sclra   ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .qa      (pqa     ),
      .clkb    (clkb    ),
      .sclrb   (sclrb   ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .qb      (pqb     )
   );
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2aa(
      .in   (pqa[DATABITW*ARRAYSIZ-1:0]),
      .out  (qa                        )
   );
   assign qea = pqa[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ];
   unit_split2packedarray #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2ab(
      .in   (pqb[DATABITW*ARRAYSIZ-1:0]),
      .out  (qb                        )
   );
   assign qeb = pqb[DATABITW*ARRAYSIZ+EXTDBITW-1:DATABITW*ARRAYSIZ];
endmodule
module tdpram_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, wea, clkena, addra, da, dea, qa, qea, web, clkenb, addrb, db, deb, qb, qeb);
   input  bit                             clk;           ///< 驱动时钟
   input  wire                            aclr;          ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclr;          ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            wea, web;      ///< RAM端口写信号，高电平(1)有效
   input  wire                            clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addra, addrb;  ///< RAM端口读写地址
   input  wire[ARRAYSIZ-1:0][DATABITW-1:0]da, db;        ///< RAM端口输入信号
   input  wire[EXTDBITW-1:0]              dea, deb;      ///< RAM端口扩展非数组数据输入信号
   output wire[ARRAYSIZ-1:0][DATABITW-1:0]qa, qb;        ///< RAM端口输出信号
   output wire[EXTDBITW-1:0]              qea, qeb;      ///< RAM端口扩展非数组数据输出信号

   tdpram_2clk_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),   
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clk     ),
      .sclra   (sclr    ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (da      ),
      .dea     (dea     ),
      .qa      (qa      ),
      .qea     (qea     ),
      .clkb    (clk     ),
      .sclrb   (sclr    ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (db      ),
      .deb     (deb     ),
      .qb      (qb      ),
      .qeb     (qeb     )
   );
endmodule
module tdpram2clk4if_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if_packedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 2) != DATABITW || $size(p.db, 2) != DATABITW)
      $error("tdpram2clk4if_packedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.dea, 1) != EXTDBITW || $size(p.deb, 1) != EXTDBITW)
      $error("tdpram2clk4if_packedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.dea(%0d) or p.deb(%0d)", EXTDBITW, $size(p.dea, 1), $size(p.deb, 1));
   initial if ($size(p.qa, 2) != DATABITW || $size(p.qb, 2) != DATABITW)
      $error("tdpram2clk4if_packedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));
   initial if ($size(p.qea, 1) != EXTDBITW || $size(p.qeb, 1) != EXTDBITW)
      $error("tdpram2clk4if_packedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.qea(%0d) or p.qeb(%0d)", EXTDBITW, $size(p.qea, 1), $size(p.qeb, 1));

   tdpram_2clk_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),   
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclra ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .dea     (p.dea   ),
      .qa      (p.qa    ),
      .qea     (p.qea   ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclrb ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .deb     (p.deb   ),
      .qb      (p.qb    ),
      .qeb     (p.qeb   )
   );
endmodule
module tdpram4if_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if_packedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 2) != DATABITW || $size(p.db, 2) != DATABITW)
      $error("tdpram4if_packedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram4if_packedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.dea, 1) != EXTDBITW || $size(p.deb, 1) != EXTDBITW)
      $error("tdpram4if_packedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.dea(%0d) or p.deb(%0d)", EXTDBITW, $size(p.dea, 1), $size(p.deb, 1));
   initial if ($size(p.qa, 2) != DATABITW || $size(p.qb, 2) != DATABITW)
      $error("tdpram4if_packedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram4if_packedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));
   initial if ($size(p.qea, 1) != EXTDBITW || $size(p.qeb, 1) != EXTDBITW)
      $error("tdpram4if_packedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.qea(%0d) or p.qeb(%0d)", EXTDBITW, $size(p.qea, 1), $size(p.qeb, 1));

   tdpram_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),   
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .dea     (p.dea   ),
      .qa      (p.qa    ),
      .qea     (p.qea   ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .deb     (p.deb   ),
      .qb      (p.qb    ),
      .qeb     (p.qeb   )
   );
endmodule
/*! \brief True Dual Port RAM for unpacked-array */
module tdpram_2clk_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clka, aclr, sclra, wea, clkena, addra, da, qa, clkb, sclrb, web, clkenb, addrb, db, qb);
   input  bit                 clka, clkb;                         ///< 驱动时钟
   input  wire                aclr;                               ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                sclra, sclrb;                       ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                wea, web;                           ///< RAM端口写信号，高电平(1)有效
   input  wire                clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addra, addrb;                       ///< RAM端口读写地址
   input  wire [DATABITW-1:0] da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   output wire [DATABITW-1:0] qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号

   wire[ARRAYSIZ-1:0][DATABITW-1:0] pda, pdb, pqa, pqb;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acia(
      .in   (da   ),
      .out  (pda  )
   );
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acib(
      .in   (db   ),
      .out  (pdb  )
   );
   tdpram_2clk_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clka    ),
      .sclra   (sclra   ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .qa      (pqa     ),
      .clkb    (clkb    ),
      .sclrb   (sclrb   ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .qb      (pqb     )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acoa(
      .in   (pqa  ),
      .out  (qa   )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acob(
      .in   (pqb  ),
      .out  (qb   )
   );
endmodule
module tdpram_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, wea, clkena, addra, da, qa, web, clkenb, addrb, db, qb);
   input  bit                 clk;                                ///< 驱动时钟
   input  wire                aclr;                               ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                sclr;                               ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                wea, web;                           ///< RAM端口写信号，高电平(1)有效
   input  wire                clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   input  wire [addrBitw-1:0] addra, addrb;                       ///< RAM端口读写地址
   input  wire [DATABITW-1:0] da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   output wire [DATABITW-1:0] qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号

   wire[ARRAYSIZ-1:0][DATABITW-1:0] pda, pdb, pqa, pqb;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acia(
      .in   (da   ),
      .out  (pda  )
   );
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acib(
      .in   (db   ),
      .out  (pdb  )
   );
   tdpram_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .qa      (pqa     ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .qb      (pqb     )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acoa(
      .in   (pqa  ),
      .out  (qa   )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acob(
      .in   (pqb  ),
      .out  (qb   )
   );
endmodule
module tdpram2clk4if_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if_unpackedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 2) != DATABITW || $size(p.db, 2) != DATABITW)
      $error("tdpram2clk4if_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 2) != DATABITW || $size(p.qb, 2) != DATABITW)
      $error("tdpram2clk4if_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_2clk_unpackedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclra ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclrb ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
module tdpram4if_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if_unpackedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 2) != DATABITW || $size(p.db, 2) != DATABITW)
      $error("tdpram4if_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram4if_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 2) != DATABITW || $size(p.qb, 2) != DATABITW)
      $error("tdpram4if_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram4if_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_unpackedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
/*! \brief True Dual Port RAM for unpacked-array with extra data */
module tdpram_2clk_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (aclr, clka, sclra, wea, clkena, addra, da, dea, qa, qea, clkb, sclrb, web, clkenb, addrb, db, deb, qb, qeb);
   input  bit                 clka, clkb;                         ///< 驱动时钟
   input  wire                aclr;                               ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                sclra, sclrb;                       ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                wea, web;                           ///< RAM端口写信号，高电平(1)有效
   input  wire                clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]  addra, addrb;                       ///< RAM端口读写地址
   input  wire[DATABITW-1:0]  da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   input  wire[EXTDBITW-1:0]  dea, deb;                           ///< RAM端口扩展非数组数据输入信号
   output wire[DATABITW-1:0]  qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号
   output wire[EXTDBITW-1:0]  qea, qeb;                           ///< RAM端口扩展非数组数据输出信号

   wire[ARRAYSIZ-1:0][DATABITW-1:0] pda, pdb, pqa, pqb;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acia(
      .in   (da   ),
      .out  (pda  )
   );
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acib(
      .in   (db   ),
      .out  (pdb  )
   );
   tdpram_2clk_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clka    ),
      .sclra   (sclra   ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .dea     (dea     ),
      .qa      (pqa     ),
      .qea     (qea     ),
      .clkb    (clkb    ),
      .sclrb   (sclrb   ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .deb     (deb     ),
      .qb      (pqb     ),
      .qeb     (qeb     )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acoa(
      .in   (pqa  ),
      .out  (qa   )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acob(
      .in   (pqb  ),
      .out  (qb   )
   );
endmodule
module tdpram_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, wea, clkena, addra, da, dea, qa, qea, web, clkenb, addrb, db, deb, qb, qeb);
   input  bit                 clk;                                ///< 驱动时钟
   input  wire                aclr;                               ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                sclr;                               ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                wea, web;                           ///< RAM端口写信号，高电平(1)有效
   input  wire                clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]  addra, addrb;                       ///< RAM端口读写地址
   input  wire[DATABITW-1:0]  da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   input  wire[EXTDBITW-1:0]  dea, deb;                           ///< RAM端口扩展非数组数据输入信号
   output wire[DATABITW-1:0]  qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号
   output wire[EXTDBITW-1:0]  qea, qeb;                           ///< RAM端口扩展非数组数据输出信号

   wire[ARRAYSIZ-1:0][DATABITW-1:0] pda, pdb, pqa, pqb;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acia(
      .in   (da   ),
      .out  (pda  )
   );
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acib(
      .in   (db   ),
      .out  (pdb  )
   );
   tdpram_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),   
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (clk     ),
      .aclr    (aclr    ),
      .sclr    (sclr    ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .dea     (dea     ),
      .qa      (pqa     ),
      .qea     (qea     ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .deb     (deb     ),
      .qb      (pqb     ),
      .qeb     (qeb     )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acoa(
      .in   (pqa  ),
      .out  (qa   )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acob(
      .in   (pqb  ),
      .out  (qb   )
   );
endmodule
module tdpram2clk4if_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 2) != DATABITW || $size(p.db, 2) != DATABITW)
      $error("tdpram2clk4if_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.dea, 1) != EXTDBITW || $size(p.deb, 1) != EXTDBITW)
      $error("tdpram2clk4if_unpackedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.dea(%0d) or p.deb(%0d)", EXTDBITW, $size(p.dea, 1), $size(p.deb, 1));
   initial if ($size(p.qa, 2) != DATABITW || $size(p.qb, 2) != DATABITW)
      $error("tdpram2clk4if_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));
   initial if ($size(p.qea, 1) != EXTDBITW || $size(p.qeb, 1) != EXTDBITW)
      $error("tdpram2clk4if_unpackedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.qea(%0d) or p.qeb(%0d)", EXTDBITW, $size(p.qea, 1), $size(p.qeb, 1));

   wire[ARRAYSIZ-1:0][DATABITW-1:0] pda, pdb, pqa, pqb;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acia(
      .in   (p.da ),
      .out  (pda  )
   );
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acib(
      .in   (p.db ),
      .out  (pdb  )
   );
   tdpram_2clk_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclra ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (pda     ),
      .dea     (p.dea   ),
      .qa      (pqa     ),
      .qea     (p.qea   ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclrb ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (pdb     ),
      .deb     (p.deb   ),
      .qb      (pqb     ),
      .qeb     (p.qeb   )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acoa(
      .in   (pqa  ),
      .out  (p.qa )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acob(
      .in   (pqb  ),
      .out  (p.qb )
   );
endmodule
module tdpram4if_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 2) != DATABITW || $size(p.db, 2) != DATABITW)
      $error("tdpram4if_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram4if_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.dea, 1) != EXTDBITW || $size(p.deb, 1) != EXTDBITW)
      $error("tdpram4if_unpackedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.dea(%0d) or p.deb(%0d)", EXTDBITW, $size(p.dea, 1), $size(p.deb, 1));
   initial if ($size(p.qa, 2) != DATABITW || $size(p.qb, 2) != DATABITW)
      $error("tdpram4if_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram4if_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));
   initial if ($size(p.qea, 1) != EXTDBITW || $size(p.qeb, 1) != EXTDBITW)
      $error("tdpram4if_unpackedarray_extd: EXTDBITW(%0d) does not match the bitwidth of p.qea(%0d) or p.qeb(%0d)", EXTDBITW, $size(p.qea, 1), $size(p.qeb, 1));

   wire[ARRAYSIZ-1:0][DATABITW-1:0] pda, pdb, pqa, pqb;
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acia(
      .in   (p.da ),
      .out  (pda  )
   );
   array_unpacked2packed #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acib(
      .in   (p.db ),
      .out  (pdb  )
   );
   tdpram_packedarray_extd #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (pda     ),
      .dea     (p.dea   ),
      .qa      (pqa     ),
      .qea     (p.qea   ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (pdb     ),
      .deb     (p.deb   ),
      .qb      (pqb     ),
      .qeb     (p.qeb   )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acoa(
      .in   (pqa  ),
      .out  (p.qa )
   );
   array_packed2unpacked #(
      .UNITBITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ)
   ) acob(
      .in   (pqb  ),
      .out  (p.qb )
   );
endmodule
/*! \brief True Dual Port RAM for packed-unit-packed-array */
module tdpram_2clk_packedunit_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clka, aclr, sclra, wea, clkena, addra, da, qa, clkb, sclrb, web, clkenb, addrb, db, qb);
   input  bit                                            clka, clkb;    ///< 驱动时钟
   input  wire                                           aclr;          ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                                           sclra, sclrb;  ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                                           wea, web;      ///< RAM端口写信号，高电平(1)有效
   input  wire                                           clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addra, addrb;  ///< RAM端口读写地址
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] da, db;        ///< RAM端口输入信号
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] qa, qb;        ///< RAM端口输出信号

   initial if (longint'(DATABITW) > longint'((2**31/(ARRAYSIZ*AUNITSIZ))*2))
      $error("tdpram_2clk_packedunit_packedarray: total data bitwidth(%0d) for DATABITW(%0d) and AUNITSIZ(%0d) ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*AUNITSIZ*ARRAYSIZ, DATABITW, AUNITSIZ, ARRAYSIZ);
   localparam int totalbitw = DATABITW*AUNITSIZ*ARRAYSIZ;
   wire [totalbitw-1:0] pda, pdb, pqa, pqb;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ua(
      .in   (da   ),
      .out  (pda  )
   );
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ub(
      .in   (db   ),
      .out  (pdb  )
   );
   tdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .RAMMODE (RAMMODE    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clka    ),
      .sclra   (sclra   ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .qa      (pqa     ),
      .clkb    (clkb    ),
      .sclrb   (sclrb   ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .qb      (pqb     )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2aa(
      .in   (pqa  ),
      .out  (qa   )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2ab(
      .in   (pqb  ),
      .out  (qb   )
   );
endmodule
module tdpram_packedunit_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, clkena, wea, addra, da, qa, clkenb, web, addrb, db, qb);
   input  bit                                            clk;           ///< 驱动时钟
   input  wire                                           aclr;          ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                                           sclr;          ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                                           wea, web;      ///< RAM端口写信号，高电平(1)有效
   input  wire                                           clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addra, addrb;  ///< RAM端口读写地址
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] da, db;        ///< RAM端口输入信号
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] qa, qb;        ///< RAM端口输出信号

   tdpram_2clk_packedunit_packedarray #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clk     ),
      .sclra   (sclr    ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (da      ),
      .qa      (qa      ),
      .clkb    (clk     ),
      .sclrb   (sclr    ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (db      ),
      .qb      (qb      )
   );
endmodule
module tdpram2clk4if_packedunit_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_packedunit_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if_packedunit_packedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram2clk4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram2clk4if_packedunit_packedarray: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_2clk_packedunit_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclra ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclrb ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
module tdpram4if_packedunit_packedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_packedunit_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if_packedunit_packedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram4if_packedunit_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram4if_packedunit_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram4if_packedunit_packedarray: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_packedarray #(
      .DATABITW(DATABITW),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
/*! \brief True Dual Port RAM for packed-unit-packed-array with extra data */
module tdpram_2clk_packedunit_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clka, aclr, sclra, wea, clkena, addra, da, dea, qa, qea, clkb, sclrb, web, clkenb, addrb, db, deb, qb, qeb);
   input  bit                                            clka, clkb;    ///< 驱动时钟
   input  wire                                           aclr;          ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                                           sclra, sclrb;  ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                                           wea, web;      ///< RAM端口写信号，高电平(1)有效
   input  wire                                           clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addra, addrb;  ///< RAM端口读写地址
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] da, db;        ///< RAM端口输入信号
   input  wire[EXTDBITW-1:0]                             dea, deb;      ///< RAM端口扩展非数组数据输入信号
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] qa, qb;        ///< RAM端口输出信号
   output wire[EXTDBITW-1:0]                             qea, qeb;      ///< RAM端口扩展非数组数据输出信号

   initial if (longint'(DATABITW) > longint'((2**31/(ARRAYSIZ*AUNITSIZ))*2))
      $error("tdpram_2clk_packedunit_packedarray_extd: total data bitwidth(%0d) for DATABITW(%0d) and AUNITSIZ(%0d) ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*AUNITSIZ*ARRAYSIZ, DATABITW, AUNITSIZ, ARRAYSIZ);
   localparam int totalbitw = DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW;
   wire [totalbitw-1:0] pda, pdb, pqa, pqb;
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ua(
      .in   (da                                 ),
      .out  (pda[DATABITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   packedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ub(
      .in   (db                                 ),
      .out  (pdb[DATABITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   assign pda[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ] = dea,
          pdb[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ] = deb;
   tdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .RAMMODE (RAMMODE    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clka    ),
      .sclra   (sclra   ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .qa      (pqa     ),
      .clkb    (clkb    ),
      .sclrb   (sclrb   ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .qb      (pqb     )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2aa(
      .in   (pqa                                ),
      .out  (qa[DATABITW*AUNITSIZ*ARRAYSIZ-1:0] )
   );
   packedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2ab(
      .in   (pqb                                ),
      .out  (qb[DATABITW*AUNITSIZ*ARRAYSIZ-1:0] )
   );
   assign qea = pqa[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ],
          qeb = pqb[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ];
endmodule
module tdpram_packedunit_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, clkena, wea, addra, da, dea, qa, qea, clkenb, web, addrb, db, deb, qb, qeb);
   input  bit                                            clk;           ///< 驱动时钟
   input  wire                                           aclr;          ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                                           sclr;          ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                                           wea, web;      ///< RAM端口写信号，高电平(1)有效
   input  wire                                           clkena, clkenb;///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]                             addra, addrb;  ///< RAM端口读写地址
   input  wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] da, db;        ///< RAM端口输入信号
   input  wire[EXTDBITW-1:0]                             dea, deb;      ///< RAM端口扩展非数组数据输入信号
   output wire[ARRAYSIZ-1:0][AUNITSIZ-1:0][DATABITW-1:0] qa, qb;        ///< RAM端口输出信号
   output wire[EXTDBITW-1:0]                             qea, qeb;      ///< RAM端口扩展非数组数据输出信号

   tdpram_2clk_packedunit_packedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clk     ),
      .sclra   (sclr    ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (da      ),
      .qa      (qa      ),
      .dea     (dea     ),
      .qea     (qea     ),
      .clkb    (clk     ),
      .sclrb   (sclr    ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (db      ),
      .qb      (qb      ),
      .deb     (deb     ),
      .qeb     (qeb     )
   );
endmodule
module tdpram2clk4if_packedunit_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_packedunit_packedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if_packedunit_packedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.dea, 3) != DATABITW || $size(p.deb, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_packedarray: EXTDBITW(%0d) does not match the element bitwidth of array p.dea(%0d) or p.deb(%0d)", EXTDBITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram2clk4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qea, 3) != EXTDBITW || $size(p.qeb, 3) != EXTDBITW)
      $error("tdpram2clk4if_packedunit_packedarray: EXTDBITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", EXTDITW, $size(p.qea, 3), $size(p.qeb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram2clk4if_packedunit_packedarray: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_2clk_packedunit_packedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclra ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .dea     (p.dea   ),
      .qea     (p.qea   ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclrb ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    ),
      .deb     (p.deb   ),
      .qeb     (p.qeb   )
   );
endmodule
module tdpram4if_packedunit_packedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_packedunit_packedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if_packedunit_packedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram4if_packedunit_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram4if_packedunit_packedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram4if_packedunit_packedarray: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram4if_packedunit_packedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_packedunit_packedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .dea     (p.dea   ),
      .qea     (p.qea   ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    ),
      .deb     (p.deb   ),
      .qeb     (p.qeb   )
   );
endmodule
/*! \brief True Dual Port RAM for packed-unit-unpacked-array */
module tdpram_2clk_packedunit_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clka, aclr, sclra, wea, clkena, addra, da, qa, clkb, sclrb, web, clkenb, addrb, db, qb);
   input  bit                             clka, clkb;                         ///< 驱动时钟
   input  wire                            aclr;                               ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclra, sclrb;                       ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            wea, web;                           ///< RAM端口写信号，高电平(1)有效
   input  wire                            clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addra, addrb;                       ///< RAM端口读写地址
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   output wire[AUNITSIZ-1:0][DATABITW-1:0]qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号

   initial if (longint'(DATABITW) > longint'((2**31/(ARRAYSIZ*AUNITSIZ))*2))
      $error("tdpram_2clk_packedunit_unpackedarray: total data bitwidth(%0d) for DATABITW(%0d) and AUNITSIZ(%0d) ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*AUNITSIZ*ARRAYSIZ, DATABITW, AUNITSIZ, ARRAYSIZ);
   localparam int totalbitw = DATABITW*AUNITSIZ*ARRAYSIZ;
   wire [totalbitw-1:0] pda, pdb, pqa, pqb;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ua(
      .in   (da   ),
      .out  (pda  )
   );
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ub(
      .in   (db   ),
      .out  (pdb  )
   );
   tdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .RAMMODE (RAMMODE    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clka    ),
      .sclra   (sclra   ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .qa      (pqa     ),
      .clkb    (clkb    ),
      .sclrb   (sclrb   ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .qb      (pqb     )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2aa(
      .in   (pqa  ),
      .out  (qa   )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2ab(
      .in   (pqb  ),
      .out  (qb   )
   );
endmodule
module tdpram_packedunit_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, clkena, wea, addra, da, qa, clkenb, web, addrb, db, qb);
   input  bit                             clk;                                ///< 驱动时钟
   input  wire                            aclr;                               ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclr;                               ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            wea, web;                           ///< RAM端口写信号，高电平(1)有效
   input  wire                            clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addra, addrb;                       ///< RAM端口读写地址
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   output wire[AUNITSIZ-1:0][DATABITW-1:0]qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号

   tdpram_2clk_packedunit_unpackedarray #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clk     ),
      .sclra   (sclr    ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (da      ),
      .qa      (qa      ),
      .clkb    (clk     ),
      .sclrb   (sclr    ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (db      ),
      .qb      (qb      )
   );
endmodule
module tdpram2clk4if_packedunit_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_packedunit_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if_packedunit_unpackedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_2clk_packedunit_unpackedarray #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclra ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclrb ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
module tdpram4if_packedunit_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_packedunit_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if_packedunit_unpackedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram4if_packedunit_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram4if_packedunit_unpackedarray: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram4if_packedunit_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram4if_packedunit_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram4if_packedunit_unpackedarray: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram4if_packedunit_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_packedunit_unpackedarray #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
/*! \brief True Dual Port RAM for packed-unit-unpacked-array with extra data */
module tdpram_2clk_packedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clka, aclr, sclra, wea, clkena, addra, da, dea, qa, qea, clkb, sclrb, web, clkenb, addrb, db, deb, qb, qeb);
   input  bit                             clka, clkb;                         ///< 驱动时钟
   input  wire                            aclr;                               ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclra, sclrb;                       ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            wea, web;                           ///< RAM端口写信号，高电平(1)有效
   input  wire                            clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addra, addrb;                       ///< RAM端口读写地址
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   input  wire[EXTDBITW-1:0]              dea, deb;                           ///< RAM端口扩展非数组数据输入信号
   output wire[AUNITSIZ-1:0][DATABITW-1:0]qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号
   output wire[EXTDBITW-1:0]              qea, qeb;                           ///< RAM端口扩展非数组数据输出信号

   initial if (longint'(DATABITW) > longint'((2**31/(ARRAYSIZ*AUNITSIZ))*2))
      $error("tdpram_2clk_packedunit_unpackedarray_extd: total data bitwidth(%0d) for DATABITW(%0d) and AUNITSIZ(%0d) ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*AUNITSIZ*ARRAYSIZ, DATABITW, AUNITSIZ, ARRAYSIZ);
   localparam int totalbitw = DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW;
   wire [totalbitw-1:0] pda, pdb, pqa, pqb;
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ua(
      .in   (da                                 ),
      .out  (pda[DATABITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   unpackedarray_packedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ub(
      .in   (db                                 ),
      .out  (pdb[DATABITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   assign pda[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ] = dea,
          pdb[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ] = deb;
   tdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .RAMMODE (RAMMODE    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clka    ),
      .sclra   (sclra   ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .qa      (pqa     ),
      .clkb    (clkb    ),
      .sclrb   (sclrb   ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .qb      (pqb     )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2aa(
      .in   (pqa                                ),
      .out  (qa[DATABITW*AUNITSIZ*ARRAYSIZ-1:0] )
   );
   unpackedarray_unit_split2allpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2ab(
      .in   (pqb                                ),
      .out  (qb[DATABITW*AUNITSIZ*ARRAYSIZ-1:0] )
   );
   assign qea = pqa[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ],
          qeb = pqb[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ];
endmodule
module tdpram_packedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, clkena, wea, addra, da, dea, qa, qea, clkenb, web, addrb, db, deb, qb, qeb);
   input  bit                             clk;                                ///< 驱动时钟
   input  wire                            aclr;                               ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire                            sclr;                               ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire                            wea, web;                           ///< RAM端口写信号，高电平(1)有效
   input  wire                            clkena, clkenb;                     ///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]              addra, addrb;                       ///< RAM端口读写地址
   input  wire[AUNITSIZ-1:0][DATABITW-1:0]da[ARRAYSIZ-1:0], db[ARRAYSIZ-1:0]; ///< RAM端口输入信号
   input  wire[EXTDBITW-1:0]              dea, deb;                           ///< RAM端口扩展非数组数据输入信号
   output wire[AUNITSIZ-1:0][DATABITW-1:0]qa[ARRAYSIZ-1:0], qb[ARRAYSIZ-1:0]; ///< RAM端口输出信号
   output wire[EXTDBITW-1:0]              qea, qeb;                           ///< RAM端口扩展非数组数据输出信号

   tdpram_2clk_packedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clk     ),
      .sclra   (sclr    ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (da      ),
      .qa      (qa      ),
      .dea     (dea     ),
      .qea     (qea     ),
      .clkb    (clk     ),
      .sclrb   (sclr    ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (db      ),
      .qb      (qb      ),
      .deb     (deb     ),
      .qeb     (qeb     )
   );
endmodule
module tdpram2clk4if_packedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_packedunit_unpackedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.dea, 1) != EXTDBITW || $size(p.deb, 1) != EXTDBITW)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the element bitwidth of array p.dea(%0d) or p.deb(%0d)", EXTDBITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qea, 1) != EXTDBITW || $size(p.qeb, 1) != EXTDBITW)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", EXTDITW, $size(p.qea, 3), $size(p.qeb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_2clk_packedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclra ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .dea     (p.dea   ),
      .qea     (p.qea   ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclrb ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    ),
      .deb     (p.deb   ),
      .qeb     (p.qeb   )
   );
endmodule
module tdpram4if_packedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_packedunit_unpackedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if_packedunit_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram4if_packedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.dea, 1) != EXTDBITW || $size(p.deb, 1) != EXTDBITW)
      $error("tdpram4if_packedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the element bitwidth of array p.dea(%0d) or p.deb(%0d)", EXTDBITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram4if_packedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qea, 1) != EXTDBITW || $size(p.qeb, 1) != EXTDBITW)
      $error("tdpram4if_packedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", EXTDITW, $size(p.qea, 3), $size(p.qeb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram4if_packedunit_unpackedarray_extd: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_packedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .dea     (p.dea   ),
      .qea     (p.qea   ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    ),
      .deb     (p.deb   ),
      .qeb     (p.qeb   )
   );
endmodule


/*! \brief True Dual Port RAM for unpacked-unit-unpacked-array */
module tdpram_2clk_unpackedunit_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clka, aclr, sclra, wea, clkena, addra, da, qa, clkb, sclrb, web, clkenb, addrb, db, qb);
   input  bit               clka, clkb;                                                      ///< 驱动时钟
   input  wire              aclr;                                                            ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire              sclra, sclrb;                                                    ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire              wea, web;                                                        ///< RAM端口写信号，高电平(1)有效
   input  wire              clkena, clkenb;                                                  ///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]addra, addrb;                                                    ///< RAM端口读写地址
   input  wire[DATABITW-1:0]da[ARRAYSIZ-1:0][AUNITSIZ-1:0], db[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输入信号
   output wire[DATABITW-1:0]qa[ARRAYSIZ-1:0][AUNITSIZ-1:0], qb[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输出信号

   initial if (longint'(DATABITW) > longint'((2**31/(ARRAYSIZ*AUNITSIZ))*2))
      $error("tdpram_2clk_unpackedunit_unpackedarray: total data bitwidth(%0d) for DATABITW(%0d) and AUNITSIZ(%0d) ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*AUNITSIZ*ARRAYSIZ, DATABITW, AUNITSIZ, ARRAYSIZ);
   localparam int totalbitw = DATABITW*AUNITSIZ*ARRAYSIZ;
   wire [totalbitw-1:0] pda, pdb, pqa, pqb;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ua(
      .in   (da   ),
      .out  (pda  )
   );
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ub(
      .in   (db   ),
      .out  (pdb  )
   );
   tdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .RAMMODE (RAMMODE    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clka    ),
      .sclra   (sclra   ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .qa      (pqa     ),
      .clkb    (clkb    ),
      .sclrb   (sclrb   ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .qb      (pqb     )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2aa(
      .in   (pqa  ),
      .out  (qa   )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2ab(
      .in   (pqb  ),
      .out  (qb   )
   );
endmodule
module tdpram_unpackedunit_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, clkena, wea, addra, da, qa, clkenb, web, addrb, db, qb);
   input  bit               clk;                                                             ///< 驱动时钟
   input  wire              aclr;                                                            ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire              sclr;                                                            ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire              wea, web;                                                        ///< RAM端口写信号，高电平(1)有效
   input  wire              clkena, clkenb;                                                  ///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]addra, addrb;                                                    ///< RAM端口读写地址
   input  wire[DATABITW-1:0]da[ARRAYSIZ-1:0][AUNITSIZ-1:0], db[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输入信号
   output wire[DATABITW-1:0]qa[ARRAYSIZ-1:0][AUNITSIZ-1:0], qb[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输出信号

   tdpram_2clk_unpackedunit_unpackedarray #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clk     ),
      .sclra   (sclr    ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (da      ),
      .qa      (qa      ),
      .clkb    (clk     ),
      .sclrb   (sclr    ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (db      ),
      .qb      (qb      )
   );
endmodule
module tdpram2clk4if_unpackedunit_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_packedunit_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if_unpackedunit_unpackedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram2clk4if_unpackedunit_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram2clk4if_unpackedunit_unpackedarray: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_unpackedunit_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram2clk4if_unpackedunit_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram2clk4if_unpackedunit_unpackedarray: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_unpackedunit_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_2clk_unpackedunit_unpackedarray #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclra ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclrb ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
module tdpram4if_unpackedunit_unpackedarray #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_packedunit_unpackedarray_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if_unpackedunit_unpackedarray: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram4if_unpackedunit_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram4if_unpackedunit_unpackedarray: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram4if_unpackedunit_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram4if_unpackedunit_unpackedarray: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram4if_unpackedunit_unpackedarray: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram4if_unpackedunit_unpackedarray: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_unpackedunit_unpackedarray #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    )
   );
endmodule
/*! \brief True Dual Port RAM for unpacked-unit-unpacked-array with extra data */
module tdpram_2clk_unpackedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据元素位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组单元个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clka, aclr, sclra, wea, clkena, addra, da, dea, qa, qea, clkb, sclrb, web, clkenb, addrb, db, deb, qb, qeb);
   input  bit               clka, clkb;                                                      ///< 驱动时钟
   input  wire              aclr;                                                            ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire              sclra, sclrb;                                                    ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire              wea, web;                                                        ///< RAM端口写信号，高电平(1)有效
   input  wire              clkena, clkenb;                                                  ///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]addra, addrb;                                                    ///< RAM端口读写地址
   input  wire[DATABITW-1:0]da[ARRAYSIZ-1:0][AUNITSIZ-1:0], db[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输入信号
   input  wire[EXTDBITW-1:0]dea, deb;                                                        ///< RAM端口扩展非数组数据输入信号
   output wire[DATABITW-1:0]qa[ARRAYSIZ-1:0][AUNITSIZ-1:0], qb[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输出信号
   output wire[EXTDBITW-1:0]qea, qeb;                                                        ///< RAM端口扩展非数组数据输出信号

   initial if (longint'(DATABITW) > longint'((2**31/(ARRAYSIZ*AUNITSIZ))*2))
      $error("tdpram_2clk_unpackedunit_unpackedarray_extd: total data bitwidth(%0d) for DATABITW(%0d) and AUNITSIZ(%0d) ARRAYSIZ(%0d) should not be greator than 2**32", DATABITW*AUNITSIZ*ARRAYSIZ, DATABITW, AUNITSIZ, ARRAYSIZ);
   localparam int totalbitw = DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW;
   wire [totalbitw-1:0] pda, pdb, pqa, pqb;
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ua(
      .in   (da                                 ),
      .out  (pda[DATABITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   unpackedarray_unpackedunitarray_combineall2unit #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) a2ub(
      .in   (db                                 ),
      .out  (pdb[DATABITW*AUNITSIZ*ARRAYSIZ-1:0])
   );
   assign pda[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ] = dea,
          pdb[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ] = deb;
   tdpram_2clk #(
      .DATABITW(totalbitw  ),
      .ADDRLEN (ADDRLEN    ),
      .RAMMODE (RAMMODE    ),
      .IMPLMOD (IMPLMOD    ),
      .REGOUTP (REGOUTP    )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clka    ),
      .sclra   (sclra   ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (pda     ),
      .qa      (pqa     ),
      .clkb    (clkb    ),
      .sclrb   (sclrb   ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (pdb     ),
      .qb      (pqb     )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2aa(
      .in   (pqa                                ),
      .out  (qa[DATABITW*AUNITSIZ*ARRAYSIZ-1:0] )
   );
   unpackedarray_unit_split2allunpackedunitarray #(
      .UNITBITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ)
   ) u2ab(
      .in   (pqb                                ),
      .out  (qb[DATABITW*AUNITSIZ*ARRAYSIZ-1:0] )
   );
   assign qea = pqa[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ],
          qeb = pqb[DATABITW*AUNITSIZ*ARRAYSIZ+EXTDBITW-1:DATABITW*AUNITSIZ*ARRAYSIZ];
endmodule
module tdpram_unpackedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (clk, aclr, sclr, clkena, wea, addra, da, dea, qa, qea, clkenb, web, addrb, db, deb, qb, qeb);
   input  bit               clk;                                                             ///< 驱动时钟
   input  wire              aclr;                                                            ///< 输出端寄存器异步复位信号，高电平(1)有效
   input  wire              sclr;                                                            ///< 输出端寄存器同步复位信号，高电平(1)有效
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   input  wire              wea, web;                                                        ///< RAM端口写信号，高电平(1)有效
   input  wire              clkena, clkenb;                                                  ///< RAM端口读写使能信号，高电平(1)有效
   input  wire[addrBitw-1:0]addra, addrb;                                                    ///< RAM端口读写地址
   input  wire[DATABITW-1:0]da[ARRAYSIZ-1:0][AUNITSIZ-1:0], db[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输入信号
   input  wire[EXTDBITW-1:0]dea, deb;                                                        ///< RAM端口扩展非数组数据输入信号
   output wire[DATABITW-1:0]qa[ARRAYSIZ-1:0][AUNITSIZ-1:0], qb[ARRAYSIZ-1:0][AUNITSIZ-1:0];  ///< RAM端口输出信号
   output wire[EXTDBITW-1:0]qea, qeb;                                                        ///< RAM端口扩展非数组数据输出信号

   tdpram_2clk_unpackedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (aclr    ),
      .clka    (clk     ),
      .sclra   (sclr    ),
      .wea     (wea     ),
      .clkena  (clkena  ),
      .addra   (addra   ),
      .da      (da      ),
      .qa      (qa      ),
      .dea     (dea     ),
      .qea     (qea     ),
      .clkb    (clk     ),
      .sclrb   (sclr    ),
      .web     (web     ),
      .clkenb  (clkenb  ),
      .addrb   (addrb   ),
      .db      (db      ),
      .qb      (qb      ),
      .deb     (deb     ),
      .qeb     (qeb     )
   );
endmodule
module tdpram2clk4if_unpackedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_2clk_unpackedunit_unpackedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.dea, 1) != EXTDBITW || $size(p.deb, 1) != EXTDBITW)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the element bitwidth of array p.dea(%0d) or p.deb(%0d)", EXTDBITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qea, 1) != EXTDBITW || $size(p.qeb, 1) != EXTDBITW)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", EXTDITW, $size(p.qea, 3), $size(p.qeb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram2clk4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_2clk_unpackedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .aclr    (p.aclr  ),
      .clka    (p.clka  ),
      .sclra   (p.sclra ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .dea     (p.dea   ),
      .qea     (p.qea   ),
      .clkb    (p.clkb  ),
      .sclrb   (p.sclrb ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    ),
      .deb     (p.deb   ),
      .qeb     (p.qeb   )
   );
endmodule
module tdpram4if_unpackedunit_unpackedarray_extd #(
   parameter int DATABITW = 32,                    ///< 数据位宽
   parameter int AUNITSIZ = 1,                     ///< 数组单元元素个数
   parameter int ARRAYSIZ = 2,                     ///< 数组元素个数
   parameter int EXTDBITW = 7,                     ///< 扩展的非数组数据位宽
   parameter int ADDRLEN  = 5,                     ///< 地址长度
   parameter int RAMMODE  = 0,                     ///< RAM工作模式：
                                                   ///< 0-保持(No Change)，端口写使能时输出信号保持不变；
                                                   ///< 1-读优先(Read First)，端口写使能时输出写之前的数据；
                                                   ///< 2-写优先(Write First)，端口写使能时输出写入的数据。
   parameter int IMPLMOD  = 2,                     ///< 实现模式：
                                                   ///< 2-最小化面积模式：以牺牲一定性能为代价最小化面积消耗；
                                                   ///< 1-普通模式：以消耗更多面积为代价提高电路时序性能；
                                                   ///< 0-逻辑资源模式：用逻辑资源实现与RAM类似的电路功能
   parameter bit REGOUTP  = 1'b0                   ///< 寄存读输出数据标志，1'b1-寄存读输出数据以提高时序性能，1'b0-不寄存读输出数据以降低时延
) (tdpram_unpackedunit_unpackedarray_extd_if.ramp p);
   localparam int addrBitw = rams_pkg::addrLen2AddrBitw(ADDRLEN);
   initial if ($bits(p.addra) != addrBitw || $bits(p.addrb) != addrBitw)
      $error("tdpram4if_packedunit_unpackedarray_extd: address bitwidth (%0d) of ADDRLEN(%0d) does not matched the bitwidth of p.addra(%0d) or p.addrb(%0d)", addrBitw, ADDRLEN, $bits(p.addra), $bits(p.addrb));
   initial if ($size(p.da, 3) != DATABITW || $size(p.db, 3) != DATABITW)
      $error("tdpram4if_packedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.da(%0d) or p.db(%0d)", DATABITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.dea, 1) != EXTDBITW || $size(p.deb, 1) != EXTDBITW)
      $error("tdpram4if_packedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the element bitwidth of array p.dea(%0d) or p.deb(%0d)", EXTDBITW, $size(p.da, 3), $size(p.db, 3));
   initial if ($size(p.da, 2) != AUNITSIZ || $size(p.db, 2) != AUNITSIZ)
      $error("tdpram4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the unit size of array p.da(%0d) or p.db(%0d)", AUNITSIZ, $size(p.da, 2), $size(p.db, 2));
   initial if ($size(p.da, 1) != ARRAYSIZ || $size(p.db, 1) != ARRAYSIZ)
      $error("tdpram4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.da(%0d) or p.db(%0d)", ARRAYSIZ, $size(p.da, 1), $size(p.db, 1));
   initial if ($size(p.qa, 3) != DATABITW || $size(p.qb, 3) != DATABITW)
      $error("tdpram4if_packedunit_unpackedarray_extd: DATABITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", DATABITW, $size(p.qa, 3), $size(p.qb, 3));
   initial if ($size(p.qea, 1) != EXTDBITW || $size(p.qeb, 1) != EXTDBITW)
      $error("tdpram4if_packedunit_unpackedarray_extd: EXTDBITW(%0d) does not match the element bitwidth of array p.qa(%0d) or p.qb(%0d)", EXTDITW, $size(p.qea, 3), $size(p.qeb, 3));
   initial if ($size(p.qa, 2) != AUNITSIZ || $size(p.qb, 2) != AUNITSIZ)
      $error("tdpram4if_packedunit_unpackedarray_extd: AUNITSIZ(%0d) does not match the unit size of array p.qa(%0d) or p.qb(%0d)", AUNITSIZ, $size(p.qa, 2), $size(p.qb, 2));
   initial if ($size(p.qa, 1) != ARRAYSIZ || $size(p.qb, 1) != ARRAYSIZ)
      $error("tdpram4if_packedunit_unpackedarray_extd: ARRAYSIZ(%0d) does not match the size of array p.qa(%0d) or p.qb(%0d)", ARRAYSIZ, $size(p.qa, 1), $size(p.qb, 1));

   tdpram_unpackedunit_unpackedarray_extd #(
      .DATABITW(DATABITW),
      .AUNITSIZ(AUNITSIZ),
      .ARRAYSIZ(ARRAYSIZ),
      .EXTDBITW(EXTDBITW),
      .ADDRLEN (ADDRLEN ),
      .RAMMODE (RAMMODE ),
      .IMPLMOD (IMPLMOD ),
      .REGOUTP (REGOUTP )
   ) rami(
      .clk     (p.clk   ),
      .aclr    (p.aclr  ),
      .sclr    (p.sclr  ),
      .wea     (p.wea   ),
      .clkena  (p.clkena),
      .addra   (p.addra ),
      .da      (p.da    ),
      .qa      (p.qa    ),
      .dea     (p.dea   ),
      .qea     (p.qea   ),
      .web     (p.web   ),
      .clkenb  (p.clkenb),
      .addrb   (p.addrb ),
      .db      (p.db    ),
      .qb      (p.qb    ),
      .deb     (p.deb   ),
      .qeb     (p.qeb   )
   );
endmodule
