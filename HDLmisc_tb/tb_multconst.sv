`timescale 1ps/1ps
`include "miscs.svh"
`include "multconst.svh"
module tb_multconst;
   
   import miscs::*;
   reg clk, rst;
   localparam int var_bitw = 8;
   reg [var_bitw-1:0] test_var;
   initial begin
      clk = 0;
      rst = 1;
      # 5 rst = 0;
   end
   always #1 clk = ~clk;
   always_ff @(posedge clk, posedge rst) begin
      if (rst) test_var <= 8'h7D;
      else     test_var <= test_var + 1;
   end
   localparam bit uhc = 1'b0;
   localparam bit rndrlsb = 1'b0;
   localparam int constarg2test = 86;
   localparam int truncbits = 8;
   localparam int res_bitw0  = multconst_pkg::bitwOfUnsignedMultRes_constUnsigned(0, 2**var_bitw-1, constarg2test);
   wire[res_bitw0-1:truncbits]res_test_msb, res_test_lsb;
   umultconst #(
      .MINOF_VAR(0),    .MAXOF_VAR(2**var_bitw-1),    .CONSTARG(constarg2test),  .VARBITW(0),.CONSTBITW(0),
      .RESBITW(res_bitw0-truncbits),.USEHRDCOR(uhc),  .RNDRESLSB(rndrlsb), .DELAYTAPS(0)  
   ) mult_u_msb(
      .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
      .var_arg(test_var),  .var_valid(1'b1),
      .res(res_test_msb),  .res_valid()
   );
   wire[res_bitw0-1:0] resr_test = (res_bitw0)'(test_var * constarg2test);
   wire[res_bitw0-1:truncbits] resr2cmp_msb = resr_test[res_bitw0-1:truncbits] + resr_test[truncbits-1];
   always_ff @(posedge clk) assert(res_test_msb == resr2cmp_msb);
   umultconst #(
      .MINOF_VAR(0),       .MAXOF_VAR(2**var_bitw-1),    .CONSTARG(constarg2test),  .VARBITW(0),.CONSTBITW(0),
      .RESBITW(-(res_bitw0-truncbits)),.USEHRDCOR(uhc),  .RNDRESLSB(rndrlsb), .DELAYTAPS(0)
   ) mult_u_lsb(
      .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
      .var_arg(test_var),  .var_valid(1'b1),
      .res(res_test_lsb),  .res_valid()
   );
   wire[res_bitw0-1:truncbits] resr2cmp_lsb = resr_test[res_bitw0-truncbits-1:0];
   always_ff @(posedge clk) assert(res_test_lsb == resr2cmp_lsb);
   localparam int res_bitw1 = multconst_pkg::bitwOfSignedMultRes_constSigned(-2**(var_bitw-1), 2**(var_bitw-1)-1, 1'b1, constarg2test);
   wire[res_bitw1-1:truncbits]ires_test_msb, ires_test_lsb;
   imultconst #(
      .MINOF_VAR(-2**(var_bitw-1)), .MAXOF_VAR(2**(var_bitw-1)-1),.SIGNED_VAR(1'b1),.CONSTARG(constarg2test),  .VARBITW(0),.CONSTBITW(0),
      .RESBITW(res_bitw1-truncbits),.USEHRDCOR(uhc),              .RNDRESLSB(rndrlsb), .DELAYTAPS(0)  
   ) mult_i_msb(
      .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
      .var_arg(test_var),  .var_valid(1'b1),
      .res(ires_test_msb), .res_valid()
   );
   wire[res_bitw1-1:0] iresr_test = (res_bitw1)'(signed'(test_var) * constarg2test);
   wire[res_bitw1-1:truncbits] iresr2cmp_msb;
   roundint #(.ARGBITW(res_bitw1),  .SIGNEDARG(1'b1), .RESBITW(res_bitw1-truncbits),.DELAYOUT(1'b0))
   rndiresr(.clk(clk),  .aclr(rst), .sclr(1'b0),.clken(1'b1),  .a(iresr_test),.r(iresr2cmp_msb));
   wire[res_bitw1-1:truncbits] iresr2cmp_msb2 = iresr_test[res_bitw1-1:truncbits];
   always_ff @(posedge clk) assert(ires_test_msb == iresr2cmp_msb);
   imultconst #(
      .MINOF_VAR(-2**(var_bitw-1)),    .MAXOF_VAR(2**(var_bitw-1)-1),.SIGNED_VAR(1'b1),.CONSTARG(constarg2test),  .VARBITW(0),.CONSTBITW(0),
      .RESBITW(-(res_bitw1-truncbits)),.USEHRDCOR(uhc),              .RNDRESLSB(rndrlsb), .DELAYTAPS(0)
   ) mult_i_lsb(
      .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
      .var_arg(test_var),  .var_valid(1'b1),
      .res(ires_test_lsb), .res_valid()
   );
   wire[res_bitw0-1:truncbits] iresr2cmp_lsb = iresr_test[res_bitw0-truncbits-1:0];
   always_ff @(posedge clk) assert(ires_test_lsb == iresr2cmp_lsb);

   localparam int const_begin = 256*0;//-256*3;
   localparam int const_sign_begin = 256*10;
   localparam int const_testcount = 2;//256;
   genvar const_arg; generate for (const_arg = const_begin; const_arg < const_begin + const_testcount; const_arg++) begin: ARRAY
      localparam int res_bitw  = multconst_pkg::bitwOfUnsignedMultRes_constUnsigned(0, 2**var_bitw-1, const_arg);
      wire[res_bitw-1:0] res;
      umultconst #(
         .MINOF_VAR(0), .MAXOF_VAR(2**var_bitw-1), .CONSTARG(const_arg),  .VARBITW(0),.CONSTBITW(0),
         .RESBITW(0),   .USEHRDCOR(uhc),           .RNDRESLSB(rndrlsb),    .DELAYTAPS(0)
      ) mult_i(
         .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
         .var_arg(test_var),  .var_valid(1'b1),
         .res(res),           .res_valid()
      );
      wire[res_bitw-1:0] res2ref = (res_bitw)'(test_var*const_arg);
      always_ff @(posedge clk) begin
         assert(res == res2ref);
      end
      wire[res_bitw-1:0] res0;
      umultconst #(
         .MINOF_VAR(0),       .MAXOF_VAR(2**var_bitw-1), .CONSTARG(const_arg),  .VARBITW(0),.CONSTBITW(0),
         .RESBITW(res_bitw),  .USEHRDCOR(uhc),           .RNDRESLSB(rndrlsb),    .DELAYTAPS(0)
      ) mult_i0(
         .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
         .var_arg(test_var),  .var_valid(1'b1),
         .res(res0),          .res_valid()
      );
      always_ff @(posedge clk) begin
         assert(res0 == res2ref);
      end
      if (res_bitw > 1) begin
         wire[res_bitw-1:1] res1, res2;
         umultconst #(
            .MINOF_VAR(0),       .MAXOF_VAR(2**var_bitw-1), .CONSTARG(const_arg),  .VARBITW(0),.CONSTBITW(0),
            .RESBITW(res_bitw-1),.USEHRDCOR(uhc),           .RNDRESLSB(rndrlsb),    .DELAYTAPS(0)
         ) mult_i1(
            .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
            .var_arg(test_var),  .var_valid(1'b1),
            .res(res1),          .res_valid()
         );
         always_ff @(posedge clk) begin
            assert(res1 == (res2ref[res_bitw-1:1] + res2ref[0]));
         end
         umultconst #(
            .MINOF_VAR(0),          .MAXOF_VAR(2**var_bitw-1), .CONSTARG(const_arg),  .VARBITW(0),.CONSTBITW(0),
            .RESBITW(-(res_bitw-1)),.USEHRDCOR(uhc),           .RNDRESLSB(rndrlsb),    .DELAYTAPS(0)
         ) mult_i2(
            .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
            .var_arg(test_var),  .var_valid(1'b1),
            .res(res2),          .res_valid()
         );
         always_ff @(posedge clk) begin
            assert(res2 == res2ref[res_bitw-2:0]);
         end

      end
   end
   for (const_arg = const_sign_begin; const_arg < const_sign_begin + const_testcount; const_arg++) begin: SIGNED_ARRAY
      localparam int res_bitw  = multconst_pkg::bitwOfSignedMultRes_constSigned(0, 2**var_bitw-1, 1'b0, const_arg);
      wire[res_bitw-1:0] resu;
      imultconst #(
         .MINOF_VAR(0), .MAXOF_VAR(2**var_bitw-1), .SIGNED_VAR(0),   .CONSTARG(const_arg),  .VARBITW(0),.CONSTBITW(0),
         .RESBITW(0),   .USEHRDCOR(uhc),           .RNDRESLSB(rndrlsb), .DELAYTAPS(0)
      ) umci_i(
         .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
         .var_arg(test_var),  .var_valid(1'b1),
         .res(resu),          .res_valid()
      );
      wire[res_bitw-1:0] resu2ref = (res_bitw)'((unsigned'(test_var))*const_arg);
      always_ff @(posedge clk) begin
         assert(resu == resu2ref);
      end
      if (res_bitw > 1) begin
         wire[res_bitw-1:1] resu0, resu0r;
         imultconst #(
            .MINOF_VAR(0),       .MAXOF_VAR(2**var_bitw-1), .SIGNED_VAR(0),   .CONSTARG(const_arg),  .VARBITW(0),.CONSTBITW(0),
            .RESBITW(res_bitw-1),.USEHRDCOR(uhc),           .RNDRESLSB(rndrlsb), .DELAYTAPS(0)
         ) umci_i0(
            .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
            .var_arg(test_var),  .var_valid(1'b1),
            .res(resu0),         .res_valid()
         );
         assign resu0r = resu2ref[res_bitw-1:1];
         always_ff @(posedge clk) begin
            assert(resu0 == resu2ref[res_bitw-1:1] + resu2ref[0]);
         end
         wire[res_bitw-1:1] resu1;
         imultconst #(
            .MINOF_VAR(0),          .MAXOF_VAR(2**var_bitw-1), .SIGNED_VAR(0),   .CONSTARG(const_arg),  .VARBITW(0),.CONSTBITW(0),
            .RESBITW(-(res_bitw-1)),.USEHRDCOR(uhc),           .RNDRESLSB(rndrlsb), .DELAYTAPS(0)
         ) umci_i1(
            .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
            .var_arg(test_var),  .var_valid(1'b1),
            .res(resu1),         .res_valid()
         );
         always_ff @(posedge clk) begin
            assert(resu1 == resu2ref[res_bitw-2:0]);
         end
      end
      localparam int resi_bitw  = multconst_pkg::bitwOfSignedMultRes_constSigned(-2**(var_bitw-1), 2**(var_bitw-1)-1, 1'b1, const_arg);
      wire[resi_bitw-1:0] resi;
      imultconst #(
         .MINOF_VAR(-2**(var_bitw-1)), .MAXOF_VAR(2**(var_bitw-1)-1),.SIGNED_VAR(1),   .CONSTARG(const_arg),  .VARBITW(0),.CONSTBITW(0),
         .RESBITW(0),                  .USEHRDCOR(uhc),              .RNDRESLSB(rndrlsb), .DELAYTAPS(0)
      ) imci_i(
         .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
         .var_arg(test_var),  .var_valid(1'b1),
         .res(resi),          .res_valid()
      );
      wire[resi_bitw-1:0] resi2ref = (resi_bitw)'((signed'(test_var))*const_arg);
      always_ff @(posedge clk) begin
         assert(resi == resi2ref);
      end
      if (resi_bitw > 1) begin: genblk2
         wire[resi_bitw-1:1] resi0, resir;
         imultconst #(
            .MINOF_VAR(-2**(var_bitw-1)), .MAXOF_VAR(2**(var_bitw-1)-1),.SIGNED_VAR(1),   .CONSTARG(const_arg),  .VARBITW(0),.CONSTBITW(0),
            .RESBITW(resi_bitw-1),        .USEHRDCOR(uhc),              .RNDRESLSB(rndrlsb), .DELAYTAPS(0)
         ) imci_i0(
            .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
            .var_arg(test_var),  .var_valid(1'b1),
            .res(resi0),         .res_valid()
         );
         assign resir = signed'(resi2ref[resi_bitw-1:1]) + resi2ref[0];
         wire error_flag = (resi0 == resir) ? 1'b0 : 1'b1;
         always_ff @(posedge clk) begin
            assert(resi0 == resir);//signed'(resi2ref[resi_bitw-1:1]) + resi2ref[0]);
         end
         wire[resi_bitw-1:1] resi1;
         imultconst #(
            .MINOF_VAR(-2**(var_bitw-1)), .MAXOF_VAR(2**(var_bitw-1)-1),.SIGNED_VAR(1),   .CONSTARG(const_arg),  .VARBITW(0),.CONSTBITW(0),
            .RESBITW(-(resi_bitw-1)),     .USEHRDCOR(uhc),              .RNDRESLSB(rndrlsb), .DELAYTAPS(0)
         ) imci_i1(
            .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
            .var_arg(test_var),  .var_valid(1'b1),
            .res(resi1),         .res_valid()
         );
         always_ff @(posedge clk) begin
            assert(resi1 == resi2ref[resi_bitw-2:0]);
         end
      end
   end
   endgenerate

   localparam int lvar_bitw = 35;
   localparam longint lvar_max = 35'h7FFFFFFFF;
   localparam longint lvar_min = 0;
   localparam int signed lres_bitw = 37;
   localparam longint lconstarg = 36'h123456789;
   localparam int lcbitw = bits_of_longint(lconstarg, 63);
   import multconst_localpkg::*;
   initial begin
      automatic int cbitw, cbitwh, cbitwl, vbitwh, vbitwl, cargh, cargl, vminh, vminl, vmaxh, vmaxl;
      cbitw = bits_of_longint(lconstarg, 64);
      cbitwl = lowerpartbitw_ofbitw(cbitw);
      cbitwh = higherpartbitw_ofbitw(cbitw);
      vbitwl = lowerpartbitw_ofbitw(lvar_bitw);
      vbitwh = higherpartbitw_ofbitw(lvar_bitw);
      $display("cbitw = %0d, cbitwh = %0d, cbitwl = %0d, lvar_bitw = %0d, vbitwh = %0d, vbitwl = %0d", cbitw, cbitwh, cbitwl, lvar_bitw, vbitwh, vbitwl);
      cargh  = int'(lconstarg>>cbitwl);
      cargl  = int'(lconstarg&(~((-1)<<cbitwl)));
      vminh  = int'(lvar_min>>vbitwl);
      vminl  = vbitwh > 0 ? 0 : int'(lvar_min);
      vmaxh  = int'(lvar_max>>vbitwl);
      vmaxl  = vbitwh > 0 ? (2**vbitwl-1) : int'(lvar_max);
      $display("lconstarg = %0d, cargh = %0d, cargl = %0d, vminh = %0d, vminl = %0d, vmaxh = %0d, vmaxl = %0d", lconstarg, cargh, cargl, vminh, vminl, vmaxh, vmaxl);
   end
   reg[lvar_bitw-1:0]lvar2test;
   always_ff @(posedge clk) begin
      if (rst) lvar2test <= 35'h3FFFFFFFF;
      else     lvar2test <= lvar2test + 1;
   end
   localparam int ulres_bitw_e = 68;//bitwOfUnsignedMultRes_constUnsigned(lvar_min, lvar_max, lconstarg);
   wire [ulres_bitw_e-1:0] lres_ref;
   assign lres_ref = (unsigned'(lvar2test)) * (unsigned'((lcbitw)'(lconstarg)));
   wire [lres_bitw-1:0]    lres, lres2cmp, lreslsb;
   roundint #(.ARGBITW(ulres_bitw_e),  .SIGNEDARG(1'b0), .RESBITW(lres_bitw), .DELAYOUT(1'b0))
   ulmc_resref(.clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),  .a(lres_ref),  .r(lres2cmp));
   ulmultconst #(
      .MINOF_VAR(lvar_min),.MAXOF_VAR(lvar_max),.CONSTARG(lconstarg),
      .RESBITW(lres_bitw), .USEHRDCOR(uhc),     .RNDRESLSB(1'b1), .DELAYTAPS(0)
   ) ulmc_i_msb(
      .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
      .var_arg(lvar2test), .var_valid(1'b1),
      .res(lres),          .res_valid()
   );
   always_ff @(posedge clk) assert(lres == lres2cmp);
   ulmultconst #(
      .MINOF_VAR(lvar_min),.MAXOF_VAR(lvar_max),.CONSTARG(lconstarg),
      .RESBITW(-lres_bitw),.USEHRDCOR(uhc),     .RNDRESLSB(1'b1), .DELAYTAPS(0)
   ) ulmc_i_lsb(
      .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
      .var_arg(lvar2test), .var_valid(1'b1),
      .res(lreslsb),       .res_valid()
   );
   always_ff @(posedge clk) assert(lreslsb == lres_ref[lres_bitw-1:0]);
   localparam longint signed ilvar_max = longint'(35'h3FFFFFFFF);
   localparam longint signed ilvar_min = -longint'(35'h3FFFFFFFF)-1;
   localparam int ilres_bitw_e = 68;//bitwOfSignedMultRes_constUnsigned(ilvar_min, ilvar_max,1'b1, lconstarg);
   wire [ilres_bitw_e-1:0] lires_ref;
   assign lires_ref = (signed'(lvar2test)) * (signed'((lcbitw+1)'(lconstarg)));
   wire [lres_bitw-1:0]    lires, lires2cmp, lireslsb;
   roundint #(.ARGBITW(ilres_bitw_e),  .SIGNEDARG(1'b1), .RESBITW(lres_bitw), .DELAYOUT(1'b0))
   ilmc_resref(.clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),  .a(lires_ref), .r(lires2cmp));
   ilmultconst #(
      .MINOF_VAR(ilvar_min),  .MAXOF_VAR(ilvar_max),  .SIGNED_VAR(1'b1),.CONSTARG(lconstarg),
      .RESBITW(lres_bitw),    .USEHRDCOR(uhc),        .RNDRESLSB(1'b1), .DELAYTAPS(0)
   ) ilmc_i_msb(
      .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
      .var_arg(lvar2test), .var_valid(1'b1),
      .res(lires),         .res_valid()
   );
   always_ff @(posedge clk) assert(lires == lires2cmp);
   ilmultconst #(
      .MINOF_VAR(ilvar_min),  .MAXOF_VAR(ilvar_max),  .SIGNED_VAR(1'b1),.CONSTARG(lconstarg),
      .RESBITW(-lres_bitw),   .USEHRDCOR(uhc),        .RNDRESLSB(1'b1), .DELAYTAPS(0)
   ) ilmc_i_lsb(
      .clk(clk),  .aclr(rst), .sclr('0),  .clken(1'b1),
      .var_arg(lvar2test), .var_valid(1'b1),
      .res(lireslsb),      .res_valid()
   );
   always_ff @(posedge clk) assert(lireslsb == lires_ref[lres_bitw-1:0]);
   import multconst_pkg::*;
   initial begin
      automatic longint signed maxlv, minlv, clv;
      automatic int bitw;
      maxlv = 35'h3FFFFFFFF;
      minlv = -longint'(35'h3FFFFFFFF);
      bitw = minbitw_of_signed_longint(minlv, $bits(minlv));
      $display("bits_of_signed_longint(%0d, %0d) = %0d", minlv, $bits(minlv), bitw);
      bitw = minbitw_of_signed_longint(maxlv, $bits(minlv));
      $display("bits_of_signed_longint(%0d, %0d) = %0d", maxlv, $bits(maxlv), bitw);
      bitw = bitwOfSignedVar(minlv, maxlv);
      $display("bitwOfSignedVar(%0d, %0d) = %0d", minlv, maxlv, bitw);
      maxlv = 64'hffffffff;
      minlv = -maxlv-1;
//    bitw = bitwOfSignedMultRes_constSigned(minlv, maxlv, 1'b1, 64'h1);
//    $display("bitwOfSignedMultRes_constSigned(%0d, %0d, 1'b1, 64'h1) = %0d", minlv, maxlv, bitw);
//    maxlv = 64'h3fffff;
//    minlv = -maxlv-1;
//    bitw = bitwOfSignedVar(minlv, maxlv);
//    $display("bitwOfSignedVar(%0d[%0h], %0d[%0h]) = %0d", minlv, minlv, maxlv, maxlv, bitw);
//    maxlv = 64'hffff;
//    minlv = -maxlv-1;
//    bitw = bitwOfSignedMultRes_constSigned(minlv, maxlv, 1'b1, -64'h1);
//    $display("bitwOfSignedMultRes_constSigned(%0d, %0d, 1'b1, -64'h1) = %0d", minlv, maxlv, bitw);
//    maxlv = 64'hffff;
//    minlv = -maxlv-1;
//    bitw = bitwOfSignedMultRes_constSigned(minlv, maxlv, 1'b1, 64'h1);
//    $display("bitwOfSignedMultRes_constSigned(%0d, %0d, 1'b1, 64'h1) = %0d", minlv, maxlv, bitw);
      maxlv = 64'd127;
      minlv = -64'd128;
      clv = -64'd16;
      bitw = bitwOfSignedMultRes_constSigned(minlv, maxlv, 1'b1, clv);
      $display("bitwOfSignedMultRes_constSigned(%0d, %0d, 1'b1, %0h) = %0d", minlv, maxlv, clv, bitw);
      maxlv = 64'd127;
      minlv = -64'd128;
      clv = -64'd16;
      bitw = bitwOfSignedMultRes_constSigned(-maxlv, -minlv, 1'b1, -clv);
      $display("bitwOfSignedMultRes_constSigned(%0d, %0d, 1'b1, %0h) = %0d", minlv, maxlv, clv, bitw);
   end

endmodule

