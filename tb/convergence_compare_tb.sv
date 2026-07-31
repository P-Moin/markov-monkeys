`timescale 1ns/1ps

module convergence_compare_tb;
    localparam integer W = 32;

    reg signed [W-1:0] new_value;
    reg signed [W-1:0] old_value;
    reg [W-1:0] tolerance;
    wire exceeds_tolerance;
    integer errors;
    integer checks;

    convergence_compare #(.WIDTH(W)) dut (
        .new_value(new_value),
        .old_value(old_value),
        .tolerance(tolerance),
        .exceeds_tolerance(exceeds_tolerance)
    );

    task check;
        input signed [W-1:0] new_v;
        input signed [W-1:0] old_v;
        input [W-1:0] tol;
        input expected;
        begin
            new_value = new_v;
            old_value = old_v;
            tolerance = tol;
            #1;
            checks = checks + 1;
            if (exceeds_tolerance !== expected) begin
                $display("ERROR: new=%0d old=%0d tol=%0d got=%b expected=%b",
                         new_v, old_v, tol, exceeds_tolerance, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        checks = 0;

        check(0, 0, 0, 1'b0);
        check(1, 0, 0, 1'b1);
        check(-1, 0, 1, 1'b0);
        check(0, -1, 1, 1'b0);
        check(16, -16, 31, 1'b1);
        check(16, -16, 32, 1'b0);
        check(32'sh7fffffff, 32'sh80000000, 32'hffffffff, 1'b0);
        check(32'sh7fffffff, 32'sh80000000, 32'hfffffffe, 1'b1);
        check(32'sh80000000, 32'sh7fffffff, 32'hffffffff, 1'b0);
        check(32'sh80000000, 0, 32'h7fffffff, 1'b1);
        check(32'sh80000000, 0, 32'h80000000, 1'b0);

        $display("Checks run: %0d", checks);
        $display("Errors:     %0d", errors);
        if (errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $finish;
    end
endmodule
