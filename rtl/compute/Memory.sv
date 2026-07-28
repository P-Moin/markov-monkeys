`timescale 1ns/1ps


module Memory #(
    parameter integer DW     = 8,
    parameter integer DATA_D = 64,
    parameter integer ADDR_W = (DATA_D <= 1) ? 1 : $clog2(DATA_D)
) (
    input  wire clk,

    input  wire signed [DW-1:0] w_data,
    input  wire [ADDR_W-1:0] w_address,
    input  wire w_enable,

    input  wire [ADDR_W-1:0] r_address,
    output reg  signed [DW-1:0] r_data
);

    reg signed [DW-1:0] memory [0:DATA_D-1];

    always @(posedge clk) begin
        if (w_enable)
            memory[w_address] <= w_data;
    end

    always @(*) begin
        r_data = memory[r_address];
    end

endmodule
