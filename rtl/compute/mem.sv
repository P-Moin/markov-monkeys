`timescale 1ns/1ps

module mem #(
    // DEPTH is the entry count, WIDTH is the bits per entry, and ADDR_W is
    // the number of address bits required to select one entry.
    parameter int DEPTH = 64,
    parameter int WIDTH = 8,
    parameter int ADDR_W = $clog2(DEPTH)
) (
    // Memory writes happen on rising clock edges.
    input  logic clk,

    // we enables writing; waddr chooses the entry; wdata supplies its value.
    input  logic                  we,
    input  logic [ADDR_W-1:0]     waddr,
    input  logic signed [WIDTH-1:0] wdata,

    // raddr chooses the entry continuously shown on rdata.
    input  logic [ADDR_W-1:0]     raddr,
    output logic signed [WIDTH-1:0] rdata
);

    // This array is the actual storage, indexed from 0 through DEPTH-1.
    logic signed [WIDTH-1:0] memory [0:DEPTH-1];

    // This is a synchronous write because it waits for a clock edge.
    always_ff @(posedge clk) begin
        if (we)
            memory[waddr] <= wdata;
    end

    // This is a combinational read, so changing raddr changes rdata without
    // waiting for a clock edge.
    always_comb begin
        rdata = memory[raddr];
    end

// End of the memory module.
endmodule

