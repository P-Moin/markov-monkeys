

`timescale 1ns/1ps

module markov_top_tb;

  // Parameters (must match DUT instantiation)
  parameter N     = 8;
  parameter DW    = 8;
  parameter ACC_W = 32;
  parameter CYC_W = 16;
  parameter FRAC_W = 8;
  localparam CNT_W = (N <= 1) ? 1 : $clog2(N);

  localparam TIMEOUT_CYCLES = 5000;   // generous: round-1 in a base
                                       // (single-MAC) matmul_top can take
                                       // on the order of N^3 cycles

  // DUT signals
  reg clk;
  reg rst_n;
  reg start;
  reg [CYC_W-1:0] num_cycles;
  wire chain_done;
  reg signed [N*N*DW-1:0] probability_matrix;
  reg signed [N*DW-1:0]   initial_vector;
  reg  [CNT_W-1:0] rd_vec_addr;
  wire signed [DW-1:0] rd_vec_data;

  integer errors;
  integer checks;
  integer tests_run;

  integer i, j, k, r;

  // Test data kept as module-scope arrays (plain Verilog can't pass
  // arrays as task/function arguments).
  reg signed [DW-1:0]    mat_a     [0:N-1][0:N-1];
  reg signed [DW-1:0]    init_vec  [0:N-1];
  reg signed [DW-1:0]    cur_vec   [0:N-1];   // running DW-range vector fed into each round
  reg signed [ACC_W-1:0] gold_raw  [0:N-1];   // this round's raw (unsaturated) result
  reg signed [ACC_W-1:0] final_raw [0:N-1];   // last round's raw result -- what should be read back
  reg signed [DW-1:0] dut_vec [0:N-1];

  // DUT instantiation
  markov_top #(
    .N(N), .DW(DW), .ACC_W(ACC_W), .CYC_W(CYC_W), .FRAC_W(FRAC_W))
  ) dut (
    .clk(clk), .rst_n(rst_n),
    .start(start), .num_cycles(num_cycles),
    .chain_done(chain_done),
    .probability_matrix(probability_matrix),
    .initial_vector(initial_vector),
    .rd_vec_addr(rd_vec_addr), .rd_vec_data(rd_vec_data)
  );

  // Clock
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Reset
  task reset_dut;
    begin
      rst_n               = 1'b0;
      start               = 1'b0;
      num_cycles          = {CYC_W{1'b0}};
      probability_matrix  = {(N*N*DW){1'b0}};
      initial_vector      = {(N*DW){1'b0}};
      rd_vec_addr         = {CNT_W{1'b0}};
      repeat (5) @(posedge clk);
      rst_n = 1'b1;
      repeat (2) @(posedge clk);
      if (chain_done !== 1'b0) begin
        $display("ERROR: [reset_dut] chain_done not idle after reset (chain_done=%b)", chain_done);
        errors = errors + 1;
      end
    end
  endtask

  // Wait for chain_done, with a timeout so a DUT bug hangs the test
  // instead of hanging the simulator.
  task wait_for_chain_done;
    integer timeout_cnt;
    begin
      timeout_cnt = 0;
      while ((chain_done !== 1'b1) && (timeout_cnt < TIMEOUT_CYCLES)) begin
        @(posedge clk);
        timeout_cnt = timeout_cnt + 1;
      end
      if (chain_done !== 1'b1) begin
        $display("ERROR: [wait_for_chain_done] TIMEOUT after %0d cycles", TIMEOUT_CYCLES);
        errors = errors + 1;
      end
    end
  endtask

  // Pack mat_a / init_vec into the DUT's flat buses. Row-major: element
  // (row,col) at bit [(row*N+col)*DW +: DW], matching the loader's
  // ld_addr = load_count sequential walk over probability_matrix.
  task pack_matrix_to_bus;
    begin
      for (i = 0; i < N; i = i + 1) begin
        for (j = 0; j < N; j = j + 1) begin
          probability_matrix[(i*N + j)*DW +: DW] = mat_a[i][j];
        end
      end
    end
  endtask

  task pack_vector_to_bus;
    begin
      for (k = 0; k < N; k = k + 1) begin
        initial_vector[k*DW +: DW] = init_vec[k];
      end
    end
  endtask

  // Read the full N-element state vector out of the DUT's read port.
  // Only ever called after chain_done (see C6).
  task read_state_vector;
    begin
      for (k = 0; k < N; k = k + 1) begin
        @(posedge clk);
        rd_vec_addr = k[CNT_W-1:0];
        #1;
        dut_vec[k] = rd_vec_data;
      end
    end
  endtask

  // One round: gold_raw[j] = sum_k cur_vec[k] * mat_a[k][j]  (C1)
  task golden_multiply;
    integer gj, gk;
    integer acc;
    begin
      for (gj = 0; gj < N; gj = gj + 1) begin
        acc = 0;
        for (gk = 0; gk < N; gk = gk + 1) begin
          acc = acc + (cur_vec[gk] * mat_a[gk][gj]);
        end
        gold_raw[gj] = acc;
      end
    end
  endtask

  // Compare dut_vec (raw ACC_W-wide) against final_raw (C3: no saturation
  // on the last round).
  task compare_vec;
    input integer test_id;
    begin
      for (k = 0; k < N; k = k + 1) begin
        checks = checks + 1;
        if (dut_vec[k] !== final_raw[k]) begin
          $display("ERROR: test %0d elem %0d MISMATCH: dut=%0d gold=%0d",
                    test_id, k, $signed(dut_vec[k]), $signed(final_raw[k]));
          errors = errors + 1;
        end
      end
    end
  endtask

  // Full run of one Markov chain test.
  task run_markov_test;
    input integer num_iters_req;   // value driven on num_cycles
    input integer test_id;
    integer eff_iters;             // C5: 0 behaves like 1
    begin
      tests_run = tests_run + 1;
      $display("---- Running test %0d (num_cycles=%0d) ----", test_id, num_iters_req);

      reset_dut;
      pack_matrix_to_bus;
      pack_vector_to_bus;

      @(posedge clk);
      start      = 1'b1;
      num_cycles = num_iters_req[CYC_W-1:0];
      @(posedge clk);
      start = 1'b0;

      wait_for_chain_done;

      eff_iters = (num_iters_req == 0) ? 1 : num_iters_req;
      for (k = 0; k < N; k = k + 1) cur_vec[k] = init_vec[k];

      for (r = 1; r <= eff_iters; r = r + 1) begin
        golden_multiply;
        if (r < eff_iters) begin
          for (k = 0; k < N; k = k + 1) cur_vec[k] = gold_raw[k];
        end
        else begin
          for (k = 0; k < N; k = k + 1) final_raw[k] = gold_raw[k];
        end
      end

      read_state_vector;
      compare_vec(test_id);

      $display("---- Finished test %0d ----", test_id);
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

  task rand_matrix;
    begin
      for (i = 0; i < N; i = i + 1)
        for (j = 0; j < N; j = j + 1)
          mat_a[i][j] = rand_int8(0);
    end
  endtask

  task rand_vector;
    begin
      for (k = 0; k < N; k = k + 1)
        init_vec[k] = rand_int8(0);
    end
  endtask

  // Test cases
  integer t;
  integer n_iters;

  initial begin
    errors     = 0;
    checks     = 0;
    tests_run  = 0;
    rst_n      = 1'b0;
    start      = 1'b0;
    num_cycles = {CYC_W{1'b0}};

    // T1: near-identity matrix, single iteration (num_cycles=1).
    // Given note D1, this is the test most likely to expose the
    // round-1 load-race issue directly.
    for (i = 0; i < N; i = i + 1)
      for (j = 0; j < N; j = j + 1)
        mat_a[i][j] = (i == j) ? 8'sd100 : 8'sd0;
    for (k = 0; k < N; k = k + 1) init_vec[k] = 8'sd40 + k;
    run_markov_test(1, 1);

    // T2: small hand-traceable 2-state block, 3 iterations. Exercises
    // the repeated need_load/load_ready reload path (rounds 2-3,
    // which should be correctly synchronized per the RTL analysis).
    for (i = 0; i < N; i = i + 1)
      for (j = 0; j < N; j = j + 1)
        mat_a[i][j] = 8'sd0;
    mat_a[2][2] = 8'sd90;  mat_a[2][3] = 8'sd38;
    mat_a[3][2] = 8'sd38;  mat_a[3][3] = 8'sd90;
    for (k = 0; k < N; k = k + 1) init_vec[k] = 8'sd0;
    init_vec[2] = 8'sd127; init_vec[3] = -8'sd128;
    run_markov_test(3, 2);

    // T3: all-zero matrix -- every output element must come back
    // exactly 0.
    for (i = 0; i < N; i = i + 1)
      for (j = 0; j < N; j = j + 1)
        mat_a[i][j] = 8'sd0;
    for (k = 0; k < N; k = k + 1) init_vec[k] = 8'sd77 - k;
    run_markov_test(2, 3);

    // T4: max-magnitude matrix and vector entries -- checks the
    // intermediate-round saturation path (feedback), and that the
    // final round's raw (unsaturated) value is what actually comes
    // back on rd_vec_data.
    for (i = 0; i < N; i = i + 1)
      for (j = 0; j < N; j = j + 1)
        mat_a[i][j] = 8'sd127;
    for (k = 0; k < N; k = k + 1) init_vec[k] = 8'sd127;
    run_markov_test(2, 4);


    // T5: num_cycles == 0, which the RTL treats identically to
    // num_cycles == 1 (C5).
    for (i = 0; i < N; i = i + 1)
      for (j = 0; j < N; j = j + 1)
        mat_a[i][j] = (i == j) ? 8'sd64 : 8'sd10;
    for (k = 0; k < N; k = k + 1) init_vec[k] = 8'sd5 * k;
    run_markov_test(0, 5);

    // Randomized tests
    for (t = 0; t < 20; t = t + 1) begin
      rand_matrix;
      rand_vector;
      n_iters = ($random % 4);
      if (n_iters < 0) n_iters = n_iters + 4;
      n_iters = n_iters + 1;   // 1..4
      run_markov_test(n_iters, 100 + t);
    end

    // Summary
    $display("=====================================================");
    $display("Tests run:  %0d", tests_run);
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
    #5000000;
    $display("ERROR: GLOBAL SIMULATION TIMEOUT");
    $finish;
  end

endmodule
