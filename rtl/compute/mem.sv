`timescale 1ns/1ps

module mem #(

    parameter int DEPTH = 64,
    parameter int WIDTH = 8,
    parameter int ADDR_W = $clog2(DEPTH)
) (
   
    input  logic clk,

    
    input  logic                  we,
    input  logic [ADDR_W-1:0]     waddr,
    input  logic signed [WIDTH-1:0] wdata,

   
    input  logic [ADDR_W-1:0]     raddr,
    output logic signed [WIDTH-1:0] rdata
);

    
    logic signed [WIDTH-1:0] memory [0:DEPTH-1];

  
    always_ff @(posedge clk) begin
        if (we)
            memory[waddr] <= wdata;
    end

   
    always_comb begin
        rdata = memory[raddr];
    end


endmodule

