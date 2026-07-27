`timescale 1ns/1ps
module mac_unit #(
    // Parameters let the same hardware description use different bit widths.
    // DW is the number of bits in each input value.
    parameter int DW    = 8,
    // ACC_W is the wider result width used to avoid overflow during addition.
    parameter int ACC_W = 32
) (
    // Registers update on each rising edge of clk.
    input  logic clk,
    // rst_n is active-low: 0 resets the unit and 1 lets it operate.
    input  logic rst_n,

    // a and b are signed, so they can hold positive or negative values.
    input  logic signed [DW-1:0] a,
    input  logic signed [DW-1:0] b,
    // valid_in marks a and b as a real term; clear_acc starts a new sum.
    input  logic                 valid_in,
    input  logic                 clear_acc,

    // acc_out is the running sum and valid_out marks an updated result.
    output logic signed [ACC_W-1:0] acc_out,
    output logic                    valid_out
);

    // A product can require twice the input width. The _q suffix means that
    // these values are saved in clocked registers.
    logic signed [(2*DW)-1:0] product_q;
    logic                     valid_q;
    logic                     clear_q;

    // This widened copy matches the product width to the accumulator width.
    // Signed assignment automatically extends the sign bit.
    logic signed [ACC_W-1:0] product_ext;

    // always_comb is combinational logic: no clock edge is needed.
    always_comb begin
        product_ext = product_q;
    end

    // always_ff describes registers. Nonblocking assignments (<=) make every
    // register use the values that existed before the current clock edge.
    always_ff @(posedge clk) begin
        // Reset gives every register a known value.
        if (!rst_n) begin
            product_q <= '0;
            valid_q   <= 1'b0;
            clear_q   <= 1'b0;
            acc_out   <= '0;
            valid_out <= 1'b0;
        end
        else begin
            // Pipeline stage 1 registers the new product and its controls.
            product_q <= $signed(a) * $signed(b);
            valid_q   <= valid_in;
            clear_q   <= clear_acc;

            // Pipeline stage 2 processes the product saved one cycle earlier.
            valid_out <= valid_q;

            // Invalid cycles do not change the accumulator.
            if (valid_q) begin
                // The first term replaces the old sum; later terms add to it.
                if (clear_q)
                    acc_out <= product_ext;
                else
                    acc_out <= acc_out + product_ext;
            end
        end
    end

// End of the multiply-accumulate unit.
endmodule
