`timescale 1ns/1ps
 
module mac_unit_tb;
 
  // Parameters
  parameter DW    = 8;
  parameter ACC_W = 32;
 
  // DUT signals
  reg clk;
  reg rst_n;
  reg signed [DW-1:0] a;
  reg signed [DW-1:0] b;
  reg valid_in;
  reg clear_acc;
  wire signed [ACC_W-1:0] acc_out;
  wire valid_out;
 
  integer errors;
  integer checks;
 
  // Mirrors mac_unit's internal pipeline registers
  reg signed [(2*DW)-1:0] g_product_q;
  reg g_valid_q;
  reg g_clear_q;
  reg signed [ACC_W-1:0] g_acc_out;
  reg g_valid_out;
 
  // DUT instantiation
  mac_unit #(
    .DW(DW), .ACC_W(ACC_W)
  ) dut (
    .clk(clk), .rst_n(rst_n),
    .a(a), .b(b),
    .valid_in(valid_in), .clear_acc(clear_acc),
    .acc_out(acc_out), .valid_out(valid_out)
  );
 
  // Clock
  initial clk = 1'b0;
  always #5 clk = ~clk;
 
  // Reset
  task reset_dut;
    begin
      rst_n     = 1'b0;
      a         = {DW{1'b0}};
      b         = {DW{1'b0}};
      valid_in  = 1'b0;
      clear_acc = 1'b0;
      repeat (3) @(posedge clk);
      rst_n = 1'b1;
 
      g_product_q = {(2*DW){1'b0}};
      g_valid_q   = 1'b0;
      g_clear_q   = 1'b0;
      g_acc_out   = {ACC_W{1'b0}};
      g_valid_out = 1'b0;
    end
  endtask
 
  // Mirrors the DUT's always block exactly:
  // acc_out/valid_out are produced from the OLD (pre-update) pipeline
  // state, THEN the pipeline registers advance to the new incoming term.
  // Call this with the SAME stimulus being driven for the upcoming edge.
  task golden_step;
    input signed [DW-1:0] a_in;
    input signed [DW-1:0] b_in;
    input vin;
    input cin;
    begin
      if (g_valid_q) begin
        if (g_clear_q)
          g_acc_out = {{(ACC_W-(2*DW)){g_product_q[(2*DW)-1]}}, g_product_q};
        else
          g_acc_out = g_acc_out + {{(ACC_W-(2*DW)){g_product_q[(2*DW)-1]}}, g_product_q};
      end
      g_valid_out = g_valid_q;
 
      g_product_q = a_in * b_in;
      g_valid_q   = vin;
      g_clear_q   = cin;
    end
  endtask
 
  // Drive one cycle's stimulus, predict the resulting DUT outputs via
  // the golden model, wait for the edge, then compare.
  task apply_and_check;
    input signed [DW-1:0] a_in;
    input signed [DW-1:0] b_in;
    input vin;
    input cin;
    input integer test_id;
    begin
      a         = a_in;
      b         = b_in;
      valid_in  = vin;
      clear_acc = cin;
 
      golden_step(a_in, b_in, vin, cin);
 
      @(posedge clk);
      #1;
 
      checks = checks + 1;
      if ((acc_out !== g_acc_out) || (valid_out !== g_valid_out)) begin
        $display("ERROR: test %0d MISMATCH: dut(acc=%0d,valid=%b) gold(acc=%0d,valid=%b)",
                  test_id, $signed(acc_out), valid_out, $signed(g_acc_out), g_valid_out);
        errors = errors + 1;
      end
    end
  endtask
 
  // Convenience: N idle/bubble cycles (valid_in=0). Uses nonzero a/b on
  // some bubbles so an implementation that forgets to gate on valid_in
  // gets caught.
  task drain;
    input integer n;
    integer d;
    input integer test_id;
    begin
      for (d = 0; d < n; d = d + 1)
        apply_and_check(8'sd55, -8'sd12, 1'b0, 1'b0, test_id);
    end
  endtask
 
  // Random INT8 helper
  function integer rand_int8;
    input integer dummy;
    integer rv;
    begin
      rv = $random % 256;
      if (rv < 0) rv = rv + 256;
      rand_int8 = rv - 128;
    end
  endfunction
 
  // Test cases
  integer idx, len, gap, gi, trial;
 
  initial begin
    errors = 0;
    checks = 0;
    rst_n  = 1'b0;
 
    // A: worked example from the spec -- (2,4,1) . (3,5,1) = 27
    reset_dut;
    apply_and_check( 8'sd2,  8'sd3, 1'b1, 1'b1, 1);   // term 1 (clear)
    apply_and_check( 8'sd4,  8'sd5, 1'b1, 1'b0, 1);   // term 2
    apply_and_check( 8'sd1,  8'sd1, 1'b1, 1'b0, 1);   // term 3
    drain(2, 1);
 
    // B: length-1 dot product (clear and only term on the same beat)
    reset_dut;
    apply_and_check( 8'sd9,  8'sd7, 1'b1, 1'b1, 2);
    drain(2, 2);
 
    // C: bubble immediately following clear_acc
    reset_dut;
    apply_and_check( 8'sd3,  8'sd3, 1'b1, 1'b1, 3);   // clear term
    apply_and_check( 8'sd0,  8'sd0, 1'b0, 1'b0, 3);   // bubble right after clear
    apply_and_check( 8'sd4,  8'sd4, 1'b1, 1'b0, 3);   // continuing term
    drain(2, 3);
 
    // D: bubble in the middle of an otherwise-continuous dot product
    reset_dut;
    apply_and_check( 8'sd2,  8'sd2, 1'b1, 1'b1, 4);
    apply_and_check( 8'sd3,  8'sd3, 1'b1, 1'b0, 4);
    apply_and_check( 8'sd0,  8'sd0, 1'b0, 1'b0, 4);   // bubble mid-stream
    apply_and_check( 8'sd5,  8'sd5, 1'b1, 1'b0, 4);   // resume same sum
    drain(2, 4);
 
    // E: back-to-back dot products, zero idle cycles between the last
    // term of one and the clear_acc term of the next
    reset_dut;
    apply_and_check( 8'sd1,  8'sd1, 1'b1, 1'b1, 5);   // dp1 term1 (clear)
    apply_and_check( 8'sd2,  8'sd2, 1'b1, 1'b0, 5);   // dp1 term2 (last)
    apply_and_check( 8'sd6,  8'sd6, 1'b1, 1'b1, 5);   // dp2 term1 (clear) -- same cycle, no gap
    apply_and_check( 8'sd7,  8'sd7, 1'b1, 1'b0, 5);   // dp2 term2
    drain(2, 5);
 
    // F: clear_acc asserted while the previous dot product's terms
    // are still draining through the pipeline
    reset_dut;
    apply_and_check( 8'sd2,  8'sd2, 1'b1, 1'b1, 6);   // dp_old term1 (clear)
    apply_and_check( 8'sd3,  8'sd3, 1'b1, 1'b0, 6);   // dp_old term2 -- still draining
    apply_and_check( 8'sd9,  8'sd9, 1'b1, 1'b1, 6);   // dp_new starts (clear) mid-drain
    drain(2, 6);
 
    // G: extreme INT8 operand values, individually and combined
    reset_dut;
    apply_and_check(  8'sd127,  8'sd127, 1'b1, 1'b1, 7);  drain(2, 7);
    apply_and_check( -8'sd128, -8'sd128, 1'b1, 1'b1, 7);  drain(2, 7);
    apply_and_check(  8'sd127, -8'sd128, 1'b1, 1'b1, 7);  drain(2, 7);
    apply_and_check( -8'sd128,  8'sd127, 1'b1, 1'b1, 7);  drain(2, 7);
 
    // H: long dot product -- sustained accumulation over many terms
    reset_dut;
    for (idx = 0; idx < 50; idx = idx + 1) begin
      apply_and_check(rand_int8(0), rand_int8(0), 1'b1, (idx == 0), 8);
    end
    drain(2, 8);
 
    // I: randomized dot products -- random length, random bubble
    // placement, random idle gaps between back-to-back sums
    reset_dut;
    for (trial = 0; trial < 30; trial = trial + 1) begin
      len = ($random % 8);
      if (len < 0) len = len + 8;
      len = len + 1;   // 1..8 terms
 
      for (idx = 0; idx < len; idx = idx + 1) begin
        // occasionally insert 0-2 bubble cycles before this term
        gap = ($random % 3);
        if (gap < 0) gap = gap + 3;
        for (gi = 0; gi < gap; gi = gi + 1)
          apply_and_check(rand_int8(0), rand_int8(0), 1'b0, 1'b0, 100 + trial);
 
        apply_and_check(rand_int8(0), rand_int8(0), 1'b1, (idx == 0), 100 + trial);
      end
    end
    drain(3, 999);
 
    // Summary
    $display("=====================================================");
    $display("Checks run: %0d", checks);
    $display("Errors:     %0d", errors);
    if (errors == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");
    $display("=====================================================");
 
    $finish;
  end
 
  // Global safety-valve timeout
  initial begin
    #1000000;
    $display("ERROR: GLOBAL SIMULATION TIMEOUT");
    $finish;
  end
 
endmodule
