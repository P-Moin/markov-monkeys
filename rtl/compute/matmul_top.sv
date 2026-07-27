// Simulation delays use nanoseconds with picosecond precision.
// This module calculates C = A x B for two square matrices. Matrix entries
// are stored in one-dimensional memories using row-major order.
`timescale 1ns/1ps

module matmul_top #(
    // N controls the matrix size, DW controls input width, and ACC_W controls
    // the wider output and running-sum width.
    parameter int N     = 8,
    parameter int DW    = 8,
    parameter int ACC_W = 32
) (
    // clk coordinates registers. rst_n resets them when it is low.
    input  logic clk,
    input  logic rst_n,

    // start begins work while idle; done pulses when C is complete.
    input  logic start,
    output logic done,

    // Loading interface: ld_en enables a write, ld_sel_ab chooses A or B,
    // and ld_addr/ld_data say where and what to store.
    input  logic ld_en,
    input  logic ld_sel_ab,
    input  logic [$clog2(N*N)-1:0] ld_addr,
    input  logic signed [DW-1:0] ld_data,

    // Reading interface for result matrix C.
    input  logic rd_en,
    input  logic [$clog2(N*N)-1:0] rd_addr,
    output logic signed [ACC_W-1:0] rd_data
);

    // These constants calculate internal storage and counter widths.
    localparam int DEPTH  = N * N;
    localparam int ADDR_W = $clog2(DEPTH);
    localparam int IDX_W  = (N <= 1) ? 1 : $clog2(N);
    localparam int COUNT_W = $clog2(DEPTH + 1);

    // The controller waits in IDLE, feeds terms in COMPUTE, and waits for the
    // pipelined MAC to finish in DRAIN.
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        DRAIN
    } state_t;

    state_t state;

    // i is the output row, j is the output column, and k walks through the
    // terms that are added together for one output element.
    logic [IDX_W-1:0] i_count;
    logic [IDX_W-1:0] j_count;
    logic [IDX_W-1:0] k_count;

    // Flattened addresses select A[i][k], B[k][j], and C[i][j].
    logic [ADDR_W-1:0] a_read_addr;
    logic [ADDR_W-1:0] b_read_addr;
    logic [ADDR_W-1:0] current_c_addr;

    // Signed matrix values read from A and B for the next multiplication.
    logic signed [DW-1:0] a_read_data;
    logic signed [DW-1:0] b_read_data;

    // Control and result signals connecting the controller to the MAC.
    logic mac_valid_in;
    logic mac_clear_acc;

    logic signed [ACC_W-1:0] mac_acc_out;
    logic                    mac_valid_out;


    // The MAC is pipelined. These registers delay the C address and final-term
    // marker so they stay aligned with the result coming out of the MAC.
    logic [ADDR_W-1:0] c_addr_pipe_0;
    logic [ADDR_W-1:0] c_addr_pipe_1;

    logic final_pipe_0;
    logic final_pipe_1;

    // This counter records how many C elements have finished.
    logic [COUNT_W-1:0] completed_count;

    // A valid MAC output enables a write to result memory C.
    logic c_write_en;

    logic signed [ACC_W-1:0] c_read_data;


    // Row-major addressing converts [row][column] to row*N + column.
    // This combinational block also creates the MAC control signals.
    always_comb begin
        a_read_addr   = (i_count * N) + k_count;
        b_read_addr   = (k_count * N) + j_count;
        current_c_addr = (i_count * N) + j_count;

        mac_valid_in = 1'b0;
        mac_clear_acc = 1'b0;

        // Only the COMPUTE state sends real terms into the MAC. k=0 clears
        // the old accumulator because it begins a new dot product.
        if (state == COMPUTE) begin
            mac_valid_in  = 1'b1;
            mac_clear_acc = (k_count == 0);
        end
    end


    // Matrix A memory is written when loading is enabled and A is selected.
    mem #(
        .DEPTH (DEPTH),
        .WIDTH (DW),
        .ADDR_W(ADDR_W)
    ) mem_a (
        .clk   (clk),
        .we    (ld_en && !ld_sel_ab),
        .waddr (ld_addr),
        .wdata (ld_data),
        .raddr (a_read_addr),
        .rdata (a_read_data)
    );

    // Matrix B memory is written when loading is enabled and B is selected.

    mem #(
        .DEPTH (DEPTH),
        .WIDTH (DW),
        .ADDR_W(ADDR_W)
    ) mem_b (
        .clk   (clk),
        .we    (ld_en && ld_sel_ab),
        .waddr (ld_addr),
        .wdata (ld_data),
        .raddr (b_read_addr),
        .rdata (b_read_data)
    );


    // Matrix C memory stores completed output values.
    mem #(
        .DEPTH (DEPTH),
        .WIDTH (ACC_W),
        .ADDR_W(ADDR_W)
    ) mem_c (
        .clk   (clk),
        .we    (c_write_en),
        .waddr (c_addr_pipe_1),
        .wdata (mac_acc_out),
        .raddr (rd_addr),
        .rdata (c_read_data)
    );

    // Hide the internal C value unless a read was requested.
    always_comb begin
        if (rd_en)
            rd_data = c_read_data;
        else
            rd_data = '0;
    end


    // One MAC is reused over many cycles for every multiplication term.
    mac_unit #(
        .DW    (DW),
        .ACC_W (ACC_W)
    ) mac (
        .clk       (clk),
        .rst_n     (rst_n),
        .a         (a_read_data),
        .b         (b_read_data),
        .valid_in  (mac_valid_in),
        .clear_acc (mac_clear_acc),
        .acc_out   (mac_acc_out),
        .valid_out (mac_valid_out)
    );

    // Every valid MAC output is written into C memory.
    assign c_write_en = mac_valid_out;

    // Main clocked controller and pipeline bookkeeping.
    always_ff @(posedge clk) begin
        // Reset returns every control register to a known state.
        if (!rst_n) begin
            state           <= IDLE;
            done            <= 1'b0;

            i_count         <= '0;
            j_count         <= '0;
            k_count         <= '0;

            c_addr_pipe_0   <= '0;
            c_addr_pipe_1   <= '0;
            final_pipe_0    <= 1'b0;
            final_pipe_1    <= 1'b0;

            completed_count <= '0;
        end
        else begin
            // done is normally low, which makes its assertion a one-cycle pulse.
            done <= 1'b0;


            // Delay address and final-term information to match MAC latency.
            c_addr_pipe_0 <= current_c_addr;
            c_addr_pipe_1 <= c_addr_pipe_0;

            final_pipe_0 <= mac_valid_in && (k_count == N-1);
            final_pipe_1 <= final_pipe_0;

            // Choose behavior for the current operating phase.
            case (state)

                IDLE: begin
                    // Accept start only while idle and restart all loop indices.
                    if (start) begin
                        i_count         <= '0;
                        j_count         <= '0;
                        k_count         <= '0;
                        completed_count <= '0;
                        state           <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // k changes fastest because all k terms form one dot product.
                    if (k_count == N-1) begin
                        k_count <= '0;

                        // After the last column, wrap j and advance the row.
                        if (j_count == N-1) begin
                            j_count <= '0;

                            // The final input term has entered, so drain the pipeline.
                            if (i_count == N-1) begin
                                state <= DRAIN;
                            end
                            else begin
                                i_count <= i_count + 1'b1;
                            end
                        end
                        else begin
                            j_count <= j_count + 1'b1;
                        end
                    end
                    else begin
                        // Continue the current dot product with the next k value.
                        k_count <= k_count + 1'b1;
                    end
                end

                DRAIN: begin
                    // No new terms enter; the completion logic below waits.
                end

                default: begin
                    // Recover safely from an invalid state value.
                    state <= IDLE;
                end
            endcase


            // A valid final k term completes one C element. The last element
            // raises done and returns the controller to IDLE.
            if (mac_valid_out && final_pipe_1) begin
                if (completed_count == DEPTH-1) begin
                    completed_count <= completed_count + 1'b1;
                    done            <= 1'b1;
                    state           <= IDLE;
                end
                else begin
                    completed_count <= completed_count + 1'b1;
                end
            end
        end
    end

// End of the top-level matrix multiplier.
endmodule
