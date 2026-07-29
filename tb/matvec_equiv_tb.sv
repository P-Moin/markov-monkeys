`timescale 1ns/1ps

module matvec_equiv_tb;
    localparam integer N      = 4;
    localparam integer DW     = 8;
    localparam integer ACC_W  = 32;
    localparam integer ADDR_W = $clog2(N*N);
    localparam integer CNT_W  = $clog2(N);
    localparam integer SEED   = 32'h4d415456;

    reg clk;
    reg rst_n;
    reg start;
    reg ld_en;
    reg ld_sel_ab;
    reg [ADDR_W-1:0] ld_addr;
    reg signed [DW-1:0] ld_data;
    reg rd_en;
    reg [ADDR_W-1:0] rd_addr;

    wire serial_done;
    wire parallel_busy;
    wire parallel_done;
    wire signed [ACC_W-1:0] serial_data;
    wire signed [ACC_W-1:0] parallel_data;

    reg signed [DW-1:0] matrix [0:N-1][0:N-1];
    reg signed [DW-1:0] vector [0:N-1];
    reg signed [ACC_W-1:0] expected [0:N-1];

    integer errors;
    integer checks;
    integer tests;
    integer seed;
    integer i;
    integer j;
    integer k;
    integer trial;
    integer serial_latency;
    integer parallel_latency;
    integer serial_latency_first;
    integer parallel_latency_first;

    serial_matvec_core #(
        .N(N), .DW(DW), .ACC_W(ACC_W), .ADDR_W(ADDR_W), .CNT_W(CNT_W)
    ) serial_dut (
        .clk(clk), .rst_n(rst_n), .start(start), .done(serial_done),
        .ld_en(ld_en), .ld_sel_ab(ld_sel_ab), .ld_addr(ld_addr),
        .ld_data(ld_data), .rd_en(rd_en), .rd_addr(rd_addr),
        .rd_data(serial_data)
    );

    parallel_matvec_core #(
        .N(N), .DW(DW), .ACC_W(ACC_W), .ADDR_W(ADDR_W), .CNT_W(CNT_W)
    ) parallel_dut (
        .clk(clk), .rst_n(rst_n), .start(start), .busy(parallel_busy),
        .done(parallel_done), .ld_en(ld_en), .ld_sel_ab(ld_sel_ab),
        .ld_addr(ld_addr), .ld_data(ld_data), .rd_en(rd_en),
        .rd_addr(rd_addr), .rd_data(parallel_data)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    function integer rand_int8;
        integer value;
        begin
            value = $random(seed) % 256;
            if (value < 0)
                value = value + 256;
            rand_int8 = value - 128;
        end
    endfunction

    task reset_duts;
        begin
            rst_n = 1'b0;
            start = 1'b0;
            ld_en = 1'b0;
            ld_sel_ab = 1'b0;
            ld_addr = '0;
            ld_data = '0;
            rd_en = 1'b0;
            rd_addr = '0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task load_operands;
        begin
            // Checked-in Owen convention: 0 loads P/B; 1 loads X/A.
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    @(negedge clk);
                    ld_en = 1'b1;
                    ld_sel_ab = 1'b0;
                    ld_addr = (i*N)+j;
                    ld_data = matrix[i][j];
                end
            end
            for (i = 0; i < N; i = i + 1) begin
                @(negedge clk);
                ld_en = 1'b1;
                ld_sel_ab = 1'b1;
                ld_addr = i;
                ld_data = vector[i];
            end
            @(negedge clk);
            ld_en = 1'b0;
        end
    endtask

    task make_reference;
        integer acc;
        begin
            for (j = 0; j < N; j = j + 1) begin
                acc = 0;
                for (k = 0; k < N; k = k + 1)
                    acc = acc + vector[k] * matrix[k][j];
                expected[j] = acc;
            end
        end
    endtask

    task launch_and_wait;
        input inject_busy_requests;
        integer cycles;
        integer serial_pulses;
        integer parallel_pulses;
        reg serial_seen;
        reg parallel_seen;
        reg serial_prev;
        reg parallel_prev;
        begin
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            serial_pulses = 0;
            parallel_pulses = 0;
            serial_seen = 1'b0;
            parallel_seen = 1'b0;
            serial_prev = 1'b0;
            parallel_prev = 1'b0;

            while (!(serial_seen && parallel_seen) && cycles < 200) begin
                if (inject_busy_requests && cycles == 1) begin
                    start = 1'b1;
                    ld_en = 1'b1;
                    ld_sel_ab = 1'b1;
                    ld_addr = '0;
                    ld_data = 8'sd99;
                end
                else begin
                    start = 1'b0;
                    ld_en = 1'b0;
                end

                @(posedge clk);
                #1;
                cycles = cycles + 1;

                if (serial_done) begin
                    serial_pulses = serial_pulses + 1;
                    if (!serial_seen)
                        serial_latency = cycles;
                    serial_seen = 1'b1;
                end
                if (parallel_done) begin
                    parallel_pulses = parallel_pulses + 1;
                    if (!parallel_seen)
                        parallel_latency = cycles;
                    parallel_seen = 1'b1;
                end
                if (serial_done && serial_prev) begin
                    $display("ERROR: serial done exceeded one cycle");
                    errors = errors + 1;
                end
                if (parallel_done && parallel_prev) begin
                    $display("ERROR: parallel done exceeded one cycle");
                    errors = errors + 1;
                end
                serial_prev = serial_done;
                parallel_prev = parallel_done;
            end

            start = 1'b0;
            ld_en = 1'b0;
            if (!(serial_seen && parallel_seen)) begin
                $display("ERROR: timeout serial_seen=%b parallel_seen=%b", serial_seen, parallel_seen);
                errors = errors + 1;
            end

            @(posedge clk);
            #1;
            checks = checks + 2;
            if (serial_done !== 1'b0 || serial_pulses != 1) begin
                $display("ERROR: serial done pulse count=%0d final=%b", serial_pulses, serial_done);
                errors = errors + 1;
            end
            if (parallel_done !== 1'b0 || parallel_pulses != 1) begin
                $display("ERROR: parallel done pulse count=%0d final=%b", parallel_pulses, parallel_done);
                errors = errors + 1;
            end
        end
    endtask

    task check_results;
        input integer test_id;
        begin
            rd_en = 1'b1;
            for (j = 0; j < N; j = j + 1) begin
                rd_addr = j;
                #1;
                checks = checks + 3;
                if (serial_data !== expected[j]) begin
                    $display("ERROR: test=%0d j=%0d serial=%0d expected=%0d",
                             test_id, j, $signed(serial_data), $signed(expected[j]));
                    errors = errors + 1;
                end
                if (parallel_data !== expected[j]) begin
                    $display("ERROR: test=%0d j=%0d parallel=%0d expected=%0d",
                             test_id, j, $signed(parallel_data), $signed(expected[j]));
                    errors = errors + 1;
                end
                if (serial_data !== parallel_data) begin
                    $display("ERROR: test=%0d j=%0d engines differ: serial=%0d parallel=%0d",
                             test_id, j, $signed(serial_data), $signed(parallel_data));
                    errors = errors + 1;
                end
            end

            // Invalid addresses and rd_en=0 are explicitly defined as zero.
            rd_addr = N;
            #1;
            checks = checks + 2;
            if (serial_data !== '0 || parallel_data !== '0) begin
                $display("ERROR: invalid read address did not return zero");
                errors = errors + 1;
            end
            rd_en = 1'b0;
            rd_addr = '0;
            #1;
            checks = checks + 2;
            if (serial_data !== '0 || parallel_data !== '0) begin
                $display("ERROR: disabled read did not return zero");
                errors = errors + 1;
            end
        end
    endtask

    task run_test;
        input integer test_id;
        input inject_busy_requests;
        begin
            tests = tests + 1;
            make_reference;
            load_operands;
            launch_and_wait(inject_busy_requests);
            check_results(test_id);
            if (tests == 1) begin
                serial_latency_first = serial_latency;
                parallel_latency_first = parallel_latency;
            end
            else begin
                checks = checks + 2;
                if (serial_latency != serial_latency_first) begin
                    $display("ERROR: serial latency changed from %0d to %0d",
                             serial_latency_first, serial_latency);
                    errors = errors + 1;
                end
                if (parallel_latency != parallel_latency_first) begin
                    $display("ERROR: parallel latency changed from %0d to %0d",
                             parallel_latency_first, parallel_latency);
                    errors = errors + 1;
                end
            end
        end
    endtask

    task reset_during_active_then_recover;
        begin
            load_operands;
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            repeat (2) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b0;
            repeat (3) @(posedge clk);
            #1;
            checks = checks + 3;
            if (serial_done || parallel_done || parallel_busy) begin
                $display("ERROR: active reset did not return engines to idle");
                errors = errors + 1;
            end
            @(negedge clk);
            rst_n = 1'b1;
            // Reload because an interrupted operation has no result contract.
            run_test(999, 1'b0);
        end
    endtask

    initial begin
        errors = 0;
        checks = 0;
        tests = 0;
        seed = SEED;
        reset_duts;
        $display("Deterministic seed: 0x%08x", SEED);

        // Identity.
        for (i = 0; i < N; i = i + 1) begin
            vector[i] = i - 2;
            for (j = 0; j < N; j = j + 1)
                matrix[i][j] = (i == j) ? 1 : 0;
        end
        run_test(1, 1'b1);

        // Zero matrix.
        for (i = 0; i < N; i = i + 1) begin
            vector[i] = 20 - i;
            for (j = 0; j < N; j = j + 1)
                matrix[i][j] = 0;
        end
        run_test(2, 1'b0);

        // Deterministic permutation.
        for (i = 0; i < N; i = i + 1) begin
            vector[i] = (i+1)*3;
            for (j = 0; j < N; j = j + 1)
                matrix[i][j] = (j == ((i+1) % N)) ? 1 : 0;
        end
        run_test(3, 1'b0);

        // Nonsymmetric matrix; the final k term changes every result.
        for (i = 0; i < N; i = i + 1) begin
            vector[i] = i + 1;
            for (j = 0; j < N; j = j + 1)
                matrix[i][j] = (i*N) + j - 5;
        end
        vector[N-1] = -8'sd17;
        run_test(4, 1'b0);

        // Maximum legal signed magnitudes.
        for (i = 0; i < N; i = i + 1) begin
            vector[i] = (i[0]) ? -8'sd128 : 8'sd127;
            for (j = 0; j < N; j = j + 1)
                matrix[i][j] = (j[0]) ? -8'sd128 : 8'sd127;
        end
        run_test(5, 1'b0);

        // Constrained deterministic random regression, back-to-back.
        for (trial = 0; trial < 40; trial = trial + 1) begin
            for (i = 0; i < N; i = i + 1) begin
                vector[i] = rand_int8();
                for (j = 0; j < N; j = j + 1)
                    matrix[i][j] = rand_int8();
            end
            run_test(100+trial, (trial == 7));
        end

        reset_during_active_then_recover;

        $display("Serial start-to-done latency (N=%0d):   %0d cycles", N, serial_latency_first);
        $display("Parallel start-to-done latency (N=%0d): %0d cycles", N, parallel_latency_first);
        $display("Tests=%0d Checks=%0d Errors=%0d", tests, checks, errors);
        if (errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $finish;
    end

    initial begin
        #2000000;
        $display("ERROR: GLOBAL TIMEOUT");
        $finish;
    end
endmodule
