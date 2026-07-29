`timescale 1ns/1ps

module markov_protocol_tb;
    localparam integer N = 4;
    localparam integer DW = 8;
    localparam integer ACC_W = 32;
    localparam integer CYC_W = 16;
    localparam integer CNT_W = $clog2(N);

    reg clk = 0;
    reg rst_n = 0;
    reg start = 0;
    reg [CYC_W-1:0] num_cycles = 0;
    wire chain_done;
    reg signed [N*N*DW-1:0] probability_matrix = 0;
    reg signed [N*DW-1:0] initial_vector = 0;
    reg [CNT_W-1:0] rd_vec_addr = 0;
    wire signed [ACC_W-1:0] rd_vec_data;

    reg signed [DW-1:0] matrix [0:N-1][0:N-1];
    reg signed [DW-1:0] current [0:N-1];
    reg signed [ACC_W-1:0] expected [0:N-1];
    integer i;
    integer j;
    integer k;
    integer round;
    integer acc;
    integer latency;
    integer errors;

    always #5 clk = ~clk;

    markov_top #(
        .N(N), .DW(DW), .ACC_W(ACC_W), .CYC_W(CYC_W)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .num_cycles(num_cycles),
        .chain_done(chain_done), .probability_matrix(probability_matrix),
        .initial_vector(initial_vector), .rd_vec_addr(rd_vec_addr),
        .rd_vec_data(rd_vec_data)
    );

    task calculate_expected;
        begin
            for (round = 0; round < 3; round = round + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    acc = 0;
                    for (k = 0; k < N; k = k + 1)
                        acc = acc + current[k] * matrix[k][j];
                    expected[j] = acc;
                end
                if (round != 2)
                    for (k = 0; k < N; k = k + 1)
                        current[k] = expected[k][DW-1:0];
            end
        end
    endtask

    initial begin
        errors = 0;
        matrix[0][0] = 1; matrix[0][1] = 2; matrix[0][2] = 0;  matrix[0][3] = -1;
        matrix[1][0] = 0; matrix[1][1] = 1; matrix[1][2] = 1;  matrix[1][3] = 0;
        matrix[2][0] = 2; matrix[2][1] = 0; matrix[2][2] = -1; matrix[2][3] = 1;
        matrix[3][0] = 1; matrix[3][1] = 1; matrix[3][2] = 0;  matrix[3][3] = 1;
        current[0] = 3;
        current[1] = -2;
        current[2] = 5;
        current[3] = 1;

        for (i = 0; i < N; i = i + 1) begin
            initial_vector[i*DW +: DW] = current[i];
            for (j = 0; j < N; j = j + 1)
                probability_matrix[(i*N+j)*DW +: DW] = matrix[i][j];
        end
        calculate_expected;

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        num_cycles = 3;
        start = 1;
        @(posedge clk);
        @(negedge clk);
        start = 0;

        latency = 0;
        while (!chain_done && latency < 200) begin
            @(posedge clk);
            #1;
            latency = latency + 1;
        end
        if (!chain_done) begin
            $display("ERROR: chain_done timeout");
            errors = errors + 1;
        end

        // Check every address immediately in the chain_done cycle.  This
        // catches reporting completion before the final state write commits.
        for (j = 0; j < N; j = j + 1) begin
            rd_vec_addr = j;
            #1;
            if (rd_vec_data !== expected[j]) begin
                $display("ERROR: immediate read j=%0d dut=%0d expected=%0d",
                         j, $signed(rd_vec_data), $signed(expected[j]));
                errors = errors + 1;
            end
        end

        @(posedge clk);
        #1;
        if (chain_done) begin
            $display("ERROR: chain_done is longer than one cycle");
            errors = errors + 1;
        end

        $display("Three-iteration start-to-chain_done latency: %0d cycles", latency);
        $display("Errors=%0d", errors);
        if (errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $finish;
    end

    initial begin
        #1000000;
        $display("ERROR: GLOBAL TIMEOUT");
        $finish;
    end
endmodule
