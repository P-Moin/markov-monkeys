-----------------------------------------------
-----------------------------------------------


IGNORE THIS FILE FOR NOW



-----------------------------------------------
-----------------------------------------------




`timescale 1ns/1ps

module parallel_matvec_core #(
    parameter integer N      = 8,
    parameter integer DW     = 8,
    parameter integer ACC_W  = 32,
    parameter integer ADDR_W = (N*N <= 1) ? 1 : $clog2(N*N),
    parameter integer CNT_W  = (N <= 1) ? 1 : $clog2(N)
) (
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        start,
    output reg                         busy,
    output reg                         done,

    input  wire                        ld_en,
    input  wire                        ld_sel_ab,
    input  wire [ADDR_W-1:0]           ld_addr,
    input  wire signed [DW-1:0]        ld_data,

    input  wire                        rd_en,
    input  wire [ADDR_W-1:0]           rd_addr,
    output wire signed [ACC_W-1:0]     rd_data
);

    localparam integer X_ADDR_W = (N <= 1) ? 1 : $clog2(N);

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] FEED    = 3'd1;
    localparam [2:0] DRAIN   = 3'd2;
    localparam [2:0] CAPTURE = 3'd3;

    reg [2:0] state;
    reg [CNT_W-1:0] k_count;

    reg signed [DW-1:0] x_mem [0:N-1];

    // Retained because the parallel datapath requires N simultaneous reads.
    reg signed [DW-1:0] p_mem [0:N*N-1];

    reg signed [ACC_W-1:0] result_mem [0:N-1];

    wire lane_valid_in;
    wire lane_clear;

    reg final_pipe_0;
    reg final_pipe_1;

    wire signed [ACC_W-1:0] lane_acc [0:N-1];
    wire [N-1:0] lane_valid;

    assign lane_valid_in = (state == FEED);
    assign lane_clear    = lane_valid_in && (k_count == 0);

    assign rd_data =
        (rd_en && (rd_addr < N)) ? result_mem[rd_addr] : '0;

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : GEN_MAC
            wire signed [DW-1:0] p_value;

            assign p_value = p_mem[(k_count * N) + g];

            mac_unit #(
                .DW    (DW),
                .ACC_W (ACC_W)
            ) u_mac (
                .clk       (clk),
                .rst_n     (rst_n),
                .a         (x_mem[k_count]),
                .b         (p_value),
                .valid_in  (lane_valid_in),
                .clear_acc (lane_clear),
                .acc_out   (lane_acc[g]),
                .valid_out (lane_valid[g])
            );
        end
    endgenerate

    always @(posedge clk) begin
        if (ld_en) begin
    
            if (ld_sel_ab) begin
                if (ld_addr < N)
                    x_mem[ld_addr[X_ADDR_W-1:0]] <= ld_data;
            end
       
            else begin
                if (ld_addr < N*N)
                    p_mem[ld_addr] <= ld_data;
            end
        end
    end

    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            state        <= IDLE;
            busy         <= 1'b0;
            done         <= 1'b0;
            k_count      <= '0;
            final_pipe_0 <= 1'b0;
            final_pipe_1 <= 1'b0;

            for (i = 0; i < N; i = i + 1)
                result_mem[i] <= '0;
        end
        else begin
            done <= 1'b0;

            final_pipe_0 <= lane_valid_in && (k_count == N-1);
            final_pipe_1 <= final_pipe_0;

            case (state)
                IDLE: begin
                    if (start) begin
                        busy    <= 1'b1;
                        k_count <= '0;
                        state   <= FEED;
                    end
                end

                FEED: begin
                    if (k_count == N-1)
                        state <= DRAIN;
                    else
                        k_count <= k_count + 1'b1;
                end

                // The final accumulator update occurs on the detection edge.
                DRAIN: begin
                    if (lane_valid[0] && final_pipe_1)
                        state <= CAPTURE;
                end

                // One full cycle later, all lane accumulators are stable.
                CAPTURE: begin
                    for (i = 0; i < N; i = i + 1)
                        result_mem[i] <= lane_acc[i];

                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    busy  <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
