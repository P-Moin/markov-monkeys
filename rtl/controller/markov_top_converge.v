module markov_top #(
    parameter N      = 8,
    parameter DW     = 8,
    parameter ACC_W  = 32,
    parameter ADDR_W = $clog2(N*N),
    parameter CYC_W  = 16,
    localparam CNT_W = (N <= 1) ? 1 : $clog2(N)
)(
    input clk,
    input rst_n,

    // kicks off the whole N-cycle chain
    input start,
    input [CYC_W-1:0] num_cycles,
    output reg chain_done,          // pulses once the final vector is stored and safe to read

    input signed [N*N*DW-1:0] probability_matrix,
    input signed [N*DW-1:0]   initial_vector,

    // external read port into the state-vector memory
    input [CNT_W-1:0] rd_vec_addr,
    output signed [ACC_W-1:0] rd_vec_data
);

    reg  need_load;
    reg  load_ready;
    reg  ld_en, ld_sel_ab;
    reg  [ADDR_W-1:0] ld_addr;
    reg  signed [DW-1:0] ld_data;

    // Matrix Multiplier
    reg  mm_start;
    wire mm_done;
    reg  [ADDR_W-1:0] mm_rd_addr;
    wire signed [ACC_W-1:0] mm_rd_data;

    matmul_top #(
        .N(N),
        .DW(DW),
        .ACC_W(ACC_W),
        .ADDR_W(ADDR_W)
    ) mm (
        .clk(clk),
        .rst_n(rst_n),
        .start(mm_start),
        .done(mm_done),
        .ld_en(ld_en),
        .ld_sel_ab(ld_sel_ab),
        .ld_addr(ld_addr),
        .ld_data(ld_data),
        .rd_en(1'b1),
        .rd_addr(mm_rd_addr),
        .rd_data(mm_rd_data)
    );

    // State Vector Memory
    reg signed [ACC_W-1:0] vec_w_data;
    reg [CNT_W-1:0] vec_w_addr;
    reg vec_w_en;

    wire [CNT_W-1:0] state_mem_raddr;
    wire signed [ACC_W-1:0] state_mem_rdata;

    Memory #(
        .DW(ACC_W),
        .DATA_D(N),
        .ADDR_W(CNT_W)
    ) state_mem (
        .clk(clk),
        .w_data(vec_w_data),
        .w_address(vec_w_addr),
        .w_enable(vec_w_en),
        .r_address(state_mem_raddr),
        .r_data(state_mem_rdata)
    );

    assign rd_vec_data = state_mem_rdata;

    //
    // Memory/Control - manages when things are stored to memory, as well as keeps track of the number of cycles and decides when to stop multiplying and instead output the final result
    //
    localparam IDLE    = 3'd0;
    localparam WAIT_MM = 3'd1;
    localparam READOUT = 3'd2;

    reg [2:0] state;
    reg [CNT_W-1:0] idx;
    reg [CYC_W-1:0] cycles_left;

    reg  first_readout;             // true until the very first pass's READOUT has fully finished
    reg  signed [ACC_W-1:0] max_error;

    wire signed [ACC_W-1:0] error       = mm_rd_data - state_mem_rdata;
    wire signed [ACC_W-1:0] abs_error   = error[ACC_W-1] ? -error : error;
    wire signed [ACC_W-1:0] running_max = (idx == 0) ? abs_error : (abs_error > max_error) ? abs_error : max_error;
    wire converged = !first_readout && (running_max <= $signed({1'b0, tolerance}));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            mm_start    <= 0;
            chain_done  <= 0;
            need_load   <= 0;
            idx         <= 0;
            mm_rd_addr  <= 0;
            cycles_left <= 0;
            vec_w_en    <= 0;
            first_readout <= 1'b1;
            max_error     <= 0;
        end
        else begin

            mm_start   <= 0;
            chain_done <= 0;
            vec_w_en   <= 0;

            case (state)

                IDLE: begin
                    if (start) begin
                         cycles_left <= (max_cycles == 0) ? {CYC_W{1'b0}} : (max_cycles - 1'b1);
                    end
                    else if (load_ready) begin
                        need_load <= 0;
                        mm_start  <= 1;
                        state     <= WAIT_MM;
                    end
                end

                WAIT_MM: begin
                    if (mm_done) begin
                        idx        <= 0;
                        mm_rd_addr <= 0;
                        state      <= READOUT;
                    end
                end

                READOUT: begin
                    vec_w_addr <= idx;
                    vec_w_data <= mm_rd_data;
                    vec_w_en   <= 1;
                    max_error  <= running_max;

                     if (idx == N-1) begin
                        if (converged || cycles_left == 0) begin
                            chain_done    <= 1;
                            first_readout <= 1'b0;
                            state         <= IDLE;
                        end
                        else begin
                            cycles_left   <= cycles_left - 1'b1;
                            need_load     <= 1;
                            first_readout <= 1'b0;
                            state         <= IDLE;
                        end
                    end
                    else begin
                        idx        <= idx + 1;
                        mm_rd_addr <= idx + 1;
                    end
                end

            endcase
        end
    end

    //
    // Loader, sends state vectors into matmul to multiply them.
    //

    localparam S_IDLE   = 2'b00;
    localparam S_LOAD_P = 2'b01;
    localparam S_LOAD_X = 2'b10;
    localparam S_DONE   = 2'b11;

    localparam signed [ACC_W-1:0] DW_MAX = (1 <<< (DW-1)) - 1;
    localparam signed [ACC_W-1:0] DW_MIN = -(1 <<< (DW-1));

    function automatic signed [DW-1:0] saturate;
        input signed [ACC_W-1:0] val;
        begin
            if (val > DW_MAX)
                saturate = DW_MAX[DW-1:0];
            else if (val < DW_MIN)
                saturate = DW_MIN[DW-1:0];
            else
                saturate = val[DW-1:0];
        end
    endfunction

    wire trigger = start | need_load;

    reg [1:0] ldr_state;
    reg [ADDR_W-1:0] load_count;
    reg first_pass;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ldr_state  <= S_IDLE;
            load_count <= 0;
            load_ready <= 1'b0;
            first_pass <= 1'b1;
        end
        else begin
            case (ldr_state)

                S_IDLE: begin
                    load_ready <= 1'b0;

                    if (trigger) begin
                        load_count <= 0;
                        // P never changes across passes, so only reload it the first time
                        ldr_state <= first_pass ? S_LOAD_P : S_LOAD_X;
                    end
                end

                S_LOAD_P: begin
                    if (load_count == N*N-1) begin
                        load_count <= 0;
                        ldr_state  <= S_LOAD_X;
                    end
                    else begin
                        load_count <= load_count + 1'b1;
                    end
                end

                S_LOAD_X: begin
                    if (load_count == N-1) begin
                        load_count <= 0;
                        load_ready <= 1'b1;
                        first_pass <= 1'b0;
                        ldr_state  <= S_DONE;
                    end
                    else begin
                        load_count <= load_count + 1'b1;
                    end
                end

                S_DONE: begin
                    load_ready <= 1'b1;

                    if (!trigger)
                        ldr_state <= S_IDLE;
                end

                default: begin
                    ldr_state  <= S_IDLE;
                    load_count <= 0;
                    load_ready <= 1'b0;
                end

            endcase
        end
    end

    wire loader_feeding_back = (ldr_state == S_LOAD_X) && !first_pass;  
    assign state_mem_raddr = (state == READOUT) ? idx
                            : loader_feeding_back ? load_count[CNT_W-1:0]
                            : rd_vec_addr;

    always @(*) begin
        ld_en     = 1'b0;
        ld_sel_ab = 1'b0;
        ld_addr   = 0;
        ld_data   = 0;

        case (ldr_state)

            S_LOAD_P: begin
                ld_en     = 1'b1;
                ld_sel_ab = 1'b1;                        
                ld_addr   = load_count;
                ld_data   = probability_matrix[load_count*DW +: DW];
            end

            S_LOAD_X: begin
                ld_en     = 1'b1;
                ld_sel_ab = 1'b0;                      
                ld_addr   = load_count;
                ld_data   = first_pass ? initial_vector[load_count*DW +: DW]
                                       : saturate(state_mem_rdata);
            end

        endcase
    end

endmodule