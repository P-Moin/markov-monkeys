`timescale 1ns/1ps

// One-MAC engine: X_next[j] = sum_k X[k] * P[k][j].
module matmul_top #(
    parameter integer N      = 8,
    parameter integer DW     = 8,
    parameter integer ACC_W  = 32,
    parameter integer ADDR_W = (N*N <= 1) ? 1 : $clog2(N*N),
    parameter integer CNT_W  = (N <= 1) ? 1 : $clog2(N)
) (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output reg busy,
    output reg done,

    input  wire ld_en,
    input  wire ld_sel_ab,
    input  wire [ADDR_W-1:0] ld_addr,
    input  wire signed [DW-1:0] ld_data,

    input  wire rd_en,
    input  wire [ADDR_W-1:0] rd_addr,
    output wire signed [ACC_W-1:0] rd_data
);

    localparam integer X_ADDR_W = (N <= 1) ? 1 : $clog2(N);

    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] FEED  = 2'd1;
    localparam [1:0] DRAIN = 2'd2;

    reg [1:0] state;

    reg [CNT_W-1:0] j_count;
    reg [CNT_W-1:0] k_count;

    wire [X_ADDR_W-1:0] x_read_addr;
    wire [ADDR_W-1:0]   p_read_addr;

    wire signed [DW-1:0] mac_a;
    wire signed [DW-1:0] mac_b;
    wire mac_valid_in;
    wire mac_clear_acc;
    wire signed [ACC_W-1:0] mac_acc_out;
    wire mac_valid_out;

    reg final_pipe_0;
    reg final_pipe_1;

    reg [CNT_W-1:0] addr_pipe_0;
    reg [CNT_W-1:0] addr_pipe_1;

    wire result_write;
    wire signed [ACC_W-1:0] result_mem_data;

    assign x_read_addr = k_count;
    assign p_read_addr = (k_count * N) + j_count;

    assign mac_valid_in  = (state == FEED);
    assign mac_clear_acc = mac_valid_in && (k_count == 0);

    assign result_write = mac_valid_out && final_pipe_1;
    assign rd_data      = rd_en ? result_mem_data : '0;

    mac_unit #(
        .DW    (DW),
        .ACC_W (ACC_W)
    ) u_mac (
        .clk (clk),
        .rst_n (rst_n),
        .a (mac_a),
        .b (mac_b),
        .valid_in (mac_valid_in),
        .clear_acc (mac_clear_acc),
        .acc_out (mac_acc_out),
        .valid_out (mac_valid_out)
    );


    Memory #(
        .DATA_D (N),
        .DW     (DW),
        .ADDR_W (X_ADDR_W)
    ) u_x_mem (
        .clk   (clk),
        .w_enable  (ld_en && !ld_sel_ab && (ld_addr < N)),
        .w_address (ld_addr[X_ADDR_W-1:0]),
        .w_data    (ld_data),
        .r_address (x_read_addr),
        .r_data    (mac_a)
    );

   
    Memory #(
        .DATA_D (N*N),
        .DW     (DW),
        .ADDR_W (ADDR_W)
    ) u_p_mem (
        .clk   (clk),
        .w_enable (ld_en && ld_sel_ab && (ld_addr < N*N)),
        .w_address (ld_addr),
        .w_data (ld_data),
        .r_address (p_read_addr),
        .r_data (mac_b)
    );

    
    Memory #(
        .DATA_D (N),
        .DW     (ACC_W),
        .ADDR_W (ADDR_W)
    ) u_result_mem (
        .clk   (clk),
        .w_enable  (result_write),
        .w_address ({{(ADDR_W-CNT_W){1'b0}}, addr_pipe_1}),
        .w_data    (mac_acc_out),
        .r_address (rd_addr),
        .r_data    (result_mem_data)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            j_count <= '0;
            k_count <= '0;
            final_pipe_0 <= 1'b0;
            final_pipe_1 <= 1'b0;
            addr_pipe_0  <= '0;
            addr_pipe_1  <= '0;
        end
        else begin
            done <= 1'b0;

            final_pipe_0 <= mac_valid_in && (k_count == N-1);
            final_pipe_1 <= final_pipe_0;

            addr_pipe_0 <= j_count;
            addr_pipe_1 <= addr_pipe_0;

            case (state)
                IDLE: begin
                    if (start) begin
                        busy    <= 1'b1;
                        j_count <= '0;
                        k_count <= '0;
                        state   <= FEED;
                    end
                end

                FEED: begin
                    if (k_count == N-1) begin
                        k_count <= '0;

                        if (j_count == N-1)
                            state <= DRAIN;
                        else
                            j_count <= j_count + 1'b1;
                    end
                    else begin
                        k_count <= k_count + 1'b1;
                    end
                end

                DRAIN: begin
                    if (result_write && (addr_pipe_1 == N-1)) begin
                        busy  <= 1'b0;
                        done  <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: begin
                    busy  <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
