`timescale 1ns/1ps
 
module Memory_tb;
 
  // Parameters (must match DUT instantiation)
  parameter DW     = 8;
  parameter DATA_D = 64;
  localparam ADDR_W = (DATA_D <= 1) ? 1 : $clog2(DATA_D);
 
  localparam integer DW_MAX = (1 << (DW-1)) - 1;   // +127
  localparam integer DW_MIN = -(1 << (DW-1));      // -128
 
  // DUT signals
  reg clk;
  reg signed [DW-1:0] w_data;
  reg [ADDR_W-1:0]    w_address;
  reg                 w_enable;
  reg [ADDR_W-1:0]    r_address;
  wire signed [DW-1:0] r_data;
 
  integer errors;
  integer checks;
 
  // Shadow model of memory contents, mirroring the RTL's own array.
  reg signed [DW-1:0] gold_mem [0:DATA_D-1];
 
  integer i;
 
  // DUT instantiation
  Memory #(
    .DW(DW), .DATA_D(DATA_D)
  ) dut (
    .clk(clk),
    .w_data(w_data), .w_address(w_address), .w_enable(w_enable),
    .r_address(r_address), .r_data(r_data)
  );
 
  // Clock
  initial clk = 1'b0;
  always #5 clk = ~clk;
 
  // Compare r_data against gold_mem[r_address], tagging pre/post-edge
  // in the error message so a mismatch is easy to localize.
  task check_read;
    input integer test_id;
    input [127:0] phase;   // holds an ASCII tag like "pre-edge"/"post-edge"
    begin
      checks = checks + 1;
      if (r_data !== gold_mem[r_address]) begin
        $display("ERROR: test %0d [%0s] r_address=%0d MISMATCH: dut=%0d gold=%0d",
                  test_id, phase, r_address, $signed(r_data), $signed(gold_mem[r_address]));
        errors = errors + 1;
      end
    end
  endtask
 
  // Drive one full cycle: set write/read signals, check the combinational
  // read BEFORE the edge, take the edge, update the golden model to
  // match the RTL's synchronous write, then check the read again AFTER
  // the edge.
  task do_cycle;
    input [ADDR_W-1:0] w_addr_in;
    input signed [DW-1:0] w_data_in;
    input w_en_in;
    input [ADDR_W-1:0] r_addr_in;
    input integer test_id;
    begin
      w_address = w_addr_in;
      w_data    = w_data_in;
      w_enable  = w_en_in;
      r_address = r_addr_in;
 
      #1;
      check_read(test_id, "pre-edge");
 
      @(posedge clk);
      if (w_en_in)
        gold_mem[w_addr_in] = w_data_in;
 
      #1;
      check_read(test_id, "post-edge");
    end
  endtask
 
  // Random helpers
  function integer rand_signed_dw;
    input integer dummy;
    integer rv;
    integer span;
    begin
      span = DW_MAX - DW_MIN + 1;
      rv = $random % span;
      if (rv < 0) rv = rv + span;
      rand_signed_dw = rv + DW_MIN;
    end
  endfunction
 
  function integer rand_addr;
    input integer dummy;
    integer rv;
    begin
      rv = $random % DATA_D;
      if (rv < 0) rv = rv + DATA_D;
      rand_addr = rv;
    end
  endfunction
 
  // Test cases
  integer a1, a2, trial;
  integer wa, ra;
 
  initial begin
    errors = 0;
    checks = 0;
    w_address = {ADDR_W{1'b0}};
    w_data    = {DW{1'b0}};
    w_enable  = 1'b0;
    r_address = {ADDR_W{1'b0}};
 
    // Prefill: write every address once with a known pattern so no
    // later read ever hits an unwritten (X) location. Also doubles
    // as coverage of every address 0..DATA_D-1, including the two
    // boundary addresses (0 and DATA_D-1).
    for (i = 0; i < DATA_D; i = i + 1) begin
      do_cycle(i[ADDR_W-1:0], (i % 251) - 100, 1'b1, i[ADDR_W-1:0], 1);
    end
 
    // T2: write-disabled must not alter memory. Try to overwrite an
    // already-known address with different data but w_enable=0, then
    // confirm the read still matches the OLD (prefilled) value.
    a1 = 5;
    do_cycle(a1[ADDR_W-1:0], 8'sd99, 1'b0, a1[ADDR_W-1:0], 2);
 
    // T3: overwrite an address twice in a row -- last write wins.
    a1 = 12;
    do_cycle(a1[ADDR_W-1:0], 8'sd10, 1'b1, a1[ADDR_W-1:0], 3);
    do_cycle(a1[ADDR_W-1:0], 8'sd20, 1'b1, a1[ADDR_W-1:0], 3);
 
    // T4: read a DIFFERENT address than the one being written, to
    // confirm writes don't leak into unrelated locations.
    a1 = 3;  a2 = 40;
    do_cycle(a1[ADDR_W-1:0], 8'sd55, 1'b1, a2[ADDR_W-1:0], 4);
 
    // T5: extreme signed values at the boundary addresses.
    do_cycle({ADDR_W{1'b0}}, DW_MAX[DW-1:0], 1'b1, {ADDR_W{1'b0}}, 5);
    do_cycle((DATA_D-1), DW_MIN[DW-1:0], 1'b1, (DATA_D-1), 5);
 
    // T6: back-to-back writes to different addresses each cycle,
    // reading back the previous cycle's address each time (checks
    // that unrelated addresses hold their value across other writes).
    do_cycle(20, 8'sd1, 1'b1, 20, 6);
    do_cycle(21, 8'sd2, 1'b1, 20, 6);
    do_cycle(22, 8'sd3, 1'b1, 21, 6);
    do_cycle(23, 8'sd4, 1'b1, 22, 6);
 
    // T7: read-during-write to the SAME address, explicitly, to
    // highlight the pre-edge/post-edge distinction (do_cycle checks
    // this automatically on every call, but this makes the intent
    // explicit with a clean before/after pair of values).
    a1 = 30;
    do_cycle(a1[ADDR_W-1:0], 8'sd7,  1'b1, a1[ADDR_W-1:0], 7);   // establish known value
    do_cycle(a1[ADDR_W-1:0], 8'sd42, 1'b1, a1[ADDR_W-1:0], 7);   // overwrite while reading same addr
 
    // T8: randomized writes/reads -- random address, random data,
    // random write-enable, random (possibly matching) read address.
    for (trial = 0; trial < 200; trial = trial + 1) begin
      wa = rand_addr(0);
      ra = ($random % 4 == 0) ? wa : rand_addr(0);   // sometimes force same-address read/write
      do_cycle(wa[ADDR_W-1:0], rand_signed_dw(0), ($random % 4 != 0), ra[ADDR_W-1:0], 800 + trial);
    end
 
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
