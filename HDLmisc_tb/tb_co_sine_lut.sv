`timescale 1ps/1ps
module tb_co_sine_lut;
   wire clk, sclr;
   tb_sysclkaclr #(
      .ACLR_WIDTH(10)
   ) sysgeni(
      .clk(clk),.aclr(),.sclr(sclr)
   );
   localparam int sigbitw = 16;
   localparam int addrbitw = 8;
   logic[addrbitw-1:0]idx;
   always_ff @(posedge clk) begin
      if (sclr) idx <= '0;
      else      idx <= idx + 1;
   end
   co_sine_table #(
      .MAGBITW(43),.EXPBITW(11),.PHSLEN(2**addrbitw), .LEADING_ORTHOG(1'b0),  .MEM_MODE(0),.NONEGPHS(1'b0)
   ) wavgenim0f(
      .clk(clk),  .idxInPhs(idx),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(2**addrbitw), .LEADING_ORTHOG(1'b0),  .MEM_MODE(0),.NONEGPHS(1'b0)
   ) wavgenim0(
      .clk(clk),  .idxInPhs(idx),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(2**addrbitw), .LEADING_ORTHOG(1'b0),  .MEM_MODE(1),.NONEGPHS(1'b0)
   ) wavgenim1(
      .clk(clk),  .idxInPhs(idx),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(2**addrbitw), .LEADING_ORTHOG(1'b0),  .MEM_MODE(2),.NONEGPHS(1'b0)
   ) wavgenim2(
      .clk(clk),  .idxInPhs(idx),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(2**addrbitw), .LEADING_ORTHOG(1'b0),  .MEM_MODE(0),.NONEGPHS(1'b1)
   ) wavgenim0np(
      .clk(clk),  .idxInPhs(idx),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(2**addrbitw), .LEADING_ORTHOG(1'b0),  .MEM_MODE(1),.NONEGPHS(1'b1)
   ) wavgenim1np(
      .clk(clk),  .idxInPhs(idx),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(2**addrbitw), .LEADING_ORTHOG(1'b0),  .MEM_MODE(2),.NONEGPHS(1'b1)
   ) wavgenim2np(
      .clk(clk),  .idxInPhs(idx),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(43),.EXPBITW(11),.PHSLEN(2**addrbitw), .LEADING_ORTHOG(1'b0),  .MEM_MODE(2),.NONEGPHS(1'b1)
   ) wavgenfp(
      .clk(clk),  .idxInPhs(idx),.magInPhs(),.magOrthog()
   );

   localparam int addrlen2 = 2**addrbitw - 101;
   initial begin
      automatic miscs::divres_t dr;
      dr = miscs::fixdiv(miscs::q61_pi, addrlen2);
      $display("miscs::q61_pi = %0d, addrlen2 = %0d, dr.intp = %0d, dr.frac = %0d, Q.61 divres = %0d", miscs::q61_pi, addrlen2, dr.intp, dr.frac, miscs::divres2qfix(.dr(dr),.fracbits(1)));
   end
   logic[addrbitw-1:0]idx2, idx2np;
   always_ff @( posedge clk ) begin
      if (sclr) idx2 <= '0;
      else      idx2 <= (idx2 < (addrlen2-1)) ? idx2 + 1 : '0;
   end
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen2), .LEADING_ORTHOG(1'b0),  .MEM_MODE(0), .NONEGPHS(1'b1)
   ) wavgeni2(
      .clk(clk),  .idxInPhs(idx2),.magInPhs(),.magOrthog()
   );
   always_ff @(posedge clk) begin
      if (sclr)idx2np <= '0;
      else     idx2np <= (signed'(idx2np) > signed'(addrlen2/2)) ? -addrlen2/2 : idx2np + 1;
   end
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen2), .LEADING_ORTHOG(1'b0),  .MEM_MODE(0), .NONEGPHS(1'b0)
   ) wavgeni2np(
      .clk(clk),  .idxInPhs(idx2np),.magInPhs(),.magOrthog()
   );

   localparam int addrlen3 = 2**addrbitw - 98;
   logic[addrbitw-1:0]idx3, idx3np;
   always_ff @(posedge clk) begin
      if (sclr) idx3 <= '0;
      else      idx3 <= (idx3 < (addrlen3-1)) ? idx3 + 1 : '0;
   end
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen3), .LEADING_ORTHOG(1'b0),  .MEM_MODE(1), .NONEGPHS(1'b1)
   ) wavgeni3(
      .clk(clk),  .idxInPhs(idx3),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen3), .LEADING_ORTHOG(1'b0),  .MEM_MODE(0), .NONEGPHS(1'b1)
   ) wavgeni3_m0(
      .clk(clk),  .idxInPhs(idx3),.magInPhs(),.magOrthog()
   );
   always_ff @(posedge clk) begin
      if (sclr) idx3np <= '0;
      else      idx3np <= (signed'(idx3np) <= signed'(addrlen3/2)) ? idx3np + 1 : -addrlen3/2;
   end
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen3), .LEADING_ORTHOG(1'b0),  .MEM_MODE(1), .NONEGPHS(1'b0)
   ) wavgeni3np(
      .clk(clk),  .idxInPhs(idx3np),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen3), .LEADING_ORTHOG(1'b0),  .MEM_MODE(0), .NONEGPHS(1'b0)
   ) wavgeni3_m0np(
      .clk(clk),  .idxInPhs(idx3np),.magInPhs(),.magOrthog()
   );

   localparam int addrlen4 = 2**addrbitw - 100;
   logic[addrbitw-1:0]idx4, idx4np;
   always_ff @(posedge clk) begin
      if (sclr) idx4 <= '0;
      else      idx4 <= (idx4 < (addrlen4-1)) ? idx4 + 1 : '0;
   end
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen4), .LEADING_ORTHOG(1'b0),  .MEM_MODE(2), .NONEGPHS(1'b1)
   ) wavgeni4_m2(
      .clk(clk),  .idxInPhs(idx4),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen4), .LEADING_ORTHOG(1'b0),  .MEM_MODE(1), .NONEGPHS(1'b1)
   ) wavgeni4_m1(
      .clk(clk),  .idxInPhs(idx4),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen4), .LEADING_ORTHOG(1'b0),  .MEM_MODE(0), .NONEGPHS(1'b1)
   ) wavgeni4_m0(
      .clk(clk),  .idxInPhs(idx4),.magInPhs(),.magOrthog()
   );
   always_ff @(posedge clk) begin
      if (sclr) idx4np <= '0;
      else      idx4np <= (signed'(idx4np) <= signed'(addrlen4/2)) ? idx4np + 1 : -addrlen4/2;
   end
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen4), .LEADING_ORTHOG(1'b0),  .MEM_MODE(2), .NONEGPHS(1'b0)
   ) wavgeni4_m2np(
      .clk(clk),  .idxInPhs(idx4np),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen4), .LEADING_ORTHOG(1'b0),  .MEM_MODE(1), .NONEGPHS(1'b0)
   ) wavgeni4_m1np(
      .clk(clk),  .idxInPhs(idx4np),.magInPhs(),.magOrthog()
   );
   co_sine_table #(
      .MAGBITW(sigbitw),.EXPBITW(1),.PHSLEN(addrlen4), .LEADING_ORTHOG(1'b0),  .MEM_MODE(0), .NONEGPHS(1'b0)
   ) wavgeni4_m0np(
      .clk(clk),  .idxInPhs(idx4np),.magInPhs(),.magOrthog()
   );

   localparam int romaddrlen0 = 2**addrbitw;
   logic[addrbitw-1:0]idxm0;
   always_ff @(posedge clk) begin
      if (sclr)idxm0 <= '0;
      else     idxm0 <= (idxm0 < romaddrlen0 - 1) ? idxm0 + 1 : '0;
   end
   co_sine_rom #(
      .DATABITW(sigbitw),  .EXPBITW(1),.ADDRLEN(romaddrlen0),  .MEM_MODE(0)
   ) rom_mod00(
      .clk(clk),  .addr1(idxm0), .addr2(idxm0), .we(1'b0),  .wdata('0), .data1(),.data2()
   );
   co_sine_rom #(
      .DATABITW(sigbitw),  .EXPBITW(1),  .ADDRLEN(romaddrlen0),  .MEM_MODE(1)
   ) rom_mod01(
      .clk(clk),  .addr1(idxm0), .addr2(idxm0), .we(1'b0),  .wdata('0), .data1(),.data2()
   );
   co_sine_rom #(
      .DATABITW(sigbitw),  .EXPBITW(1),  .ADDRLEN(romaddrlen0),  .MEM_MODE(2)
   ) rom_mod02(
      .clk(clk),  .addr1(idxm0), .addr2(idxm0), .we(1'b0),  .wdata('0), .data1(),.data2()
   );

   localparam int romaddrlenm4 = 55*4;
   logic[addrbitw-1:0]idxm1m4;
   always_ff @(posedge clk) begin
      if (sclr)idxm1m4 <= '0;
      else     idxm1m4 <= (idxm1m4 < romaddrlenm4 - 1) ? idxm1m4 + 1 : '0;
   end
   co_sine_rom #(
      .DATABITW(sigbitw),  .EXPBITW(1),  .ADDRLEN(romaddrlenm4),  .MEM_MODE(0)
   ) rom_lenm4mod0(
      .clk(clk),  .addr1(idxm1m4), .addr2(idxm1m4), .we(1'b0),  .wdata('0), .data1(),.data2()
   );
   co_sine_rom #(
      .DATABITW(sigbitw),  .EXPBITW(1),  .ADDRLEN(romaddrlenm4),  .MEM_MODE(1)
   ) rom_lenm4mod1(
      .clk(clk),  .addr1(idxm1m4), .addr2(idxm1m4), .we(1'b0),  .wdata('0), .data1(),.data2()
   );
   co_sine_rom #(
      .DATABITW(sigbitw),  .EXPBITW(1),  .ADDRLEN(romaddrlenm4),  .MEM_MODE(2)
   ) rom_lenm4mod2(
      .clk(clk),  .addr1(idxm1m4), .addr2(idxm1m4), .we(1'b0),  .wdata('0), .data1(),.data2()
   );

   localparam int romaddrlenm2 = 101*2;
   logic[addrbitw-1:0]idxm2;
   always_ff @(posedge clk) begin
      if (sclr)idxm2 <= '0;
      else     idxm2 <= (idxm2 < romaddrlenm2 - 1) ? idxm2 + 1 : '0;
   end
   co_sine_rom #(
      .DATABITW(sigbitw),  .EXPBITW(1),  .ADDRLEN(romaddrlenm2),  .MEM_MODE(0)
   ) rom_lenm2mod0(
      .clk(clk),  .addr1(idxm2), .addr2(idxm2), .we(1'b0),  .wdata('0), .data1(),.data2()
   );
   co_sine_rom #(
      .DATABITW(sigbitw),  .EXPBITW(1),  .ADDRLEN(romaddrlenm2),  .MEM_MODE(1)
   ) rom_lenm2mod1(
      .clk(clk),  .addr1(idxm2), .addr2(idxm2), .we(1'b0),  .wdata('0), .data1(),.data2()
   );

   localparam int romaddrlenm1 = 203;
   logic[addrbitw-1:0]idxm1;
   always_ff @(posedge clk) begin
      if (sclr)idxm1 <= '0;
      else     idxm1 <= (idxm1 < romaddrlenm1 - 1) ? idxm1 + 1 : '0;
   end
   co_sine_rom #(
      .DATABITW(sigbitw),  .EXPBITW(1),  .ADDRLEN(romaddrlenm1),  .MEM_MODE(0)
   ) rom_lenm1mod0(
      .clk(clk),  .addr1(idxm1), .addr2(idxm1), .we(1'b0),  .wdata('0), .data1(),.data2()
   );
endmodule
