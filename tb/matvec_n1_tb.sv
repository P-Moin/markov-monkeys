`timescale 1ns/1ps

module matvec_n1_tb;
    localparam integer N = 1;
    localparam integer DW = 8;
    localparam integer ACC_W = 32;
    localparam integer ADDR_W = 1;
    localparam integer CNT_W = 1;

    reg clk = 0;
    reg rst_n = 0;
    reg start = 0;
    reg ld_en = 0;
    reg ld_sel_ab = 0;
    reg [ADDR_W-1:0] ld_addr = 0;
    reg signed [DW-1:0] ld_data = 0;
    reg rd_en = 1;
    reg [ADDR_W-1:0] rd_addr = 0;
    wire serial_done;
    wire parallel_done;
    wire parallel_busy;
    wire signed [ACC_W-1:0] serial_data;
    wire signed [ACC_W-1:0] parallel_data;
    integer cycles;
    integer serial_pulses;
    integer parallel_pulses;
    reg serial_seen;
    reg parallel_seen;

    always #5 clk = ~clk;

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

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

        ld_en = 1;
        ld_sel_ab = 0;
        ld_data = -8'sd7;
        @(posedge clk);
        @(negedge clk);
        ld_sel_ab = 1;
        ld_data = 8'sd5;
        @(posedge clk);
        @(negedge clk);
        ld_en = 0;
        start = 1;
        @(posedge clk);
        @(negedge clk);
        start = 0;

        cycles = 0;
        serial_pulses = 0;
        parallel_pulses = 0;
        serial_seen = 0;
        parallel_seen = 0;
        while (!(serial_seen && parallel_seen) && cycles < 20) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if (serial_done) begin
                serial_seen = 1;
                serial_pulses = serial_pulses + 1;
            end
            if (parallel_done) begin
                parallel_seen = 1;
                parallel_pulses = parallel_pulses + 1;
            end
        end

        @(posedge clk);
        #1;
        if (serial_seen && parallel_seen &&
            serial_pulses == 1 && parallel_pulses == 1 &&
            !serial_done && !parallel_done &&
            serial_data === -32'sd35 && parallel_data === -32'sd35) begin
            $display("N=1 serial=%0d parallel=%0d", $signed(serial_data), $signed(parallel_data));
            $display("RESULT: PASS");
        end
        else begin
            $display("RESULT: FAIL serial=%0d parallel=%0d",
                     $signed(serial_data), $signed(parallel_data));
        end
        $finish;
    end
endmodule
