module markov_top #(
    parameter N      = 8,
    parameter DW     = 8,
    parameter ACC_W  = 32,
    parameter ADDR_W = $clog2(N*N),
    parameter CYC_W  = 16,
    parameter FRAC_W = 8,
    localparam CNT_W = (N <= 1) ? 1 : $clog2(N)
)(
    input clk,
    input rst_n,

    // kicks off the whole N-cycle chain
    input start,
    input [CYC_W-1:0] max_cycles,
    input [ACC_W-1:0] tolerance,             
 
    output reg chain_done,                   // pulses once the final vector is stored and safe to read
    output reg converged,                    //Flags high if stopped early due to convergence

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
        .FRAC_W(FRAC_W),
        .ADDR_W(ADDR_W),
        .CNT_W(CNT_W)
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
    // Memory/Control - manages cycles and convergence checking
    //
    localparam IDLE    = 3'd0;
    localparam WAIT_MM = 3'd1;
    localparam READOUT = 3'd2;
    localparam COMMIT  = 3'd3;

    reg [2:0] state;
    reg [CNT_W-1:0] idx;
    reg [CYC_W-1:0] cycles_left;

    // Convergence checking registers and wires
    reg is_first_iteration;
    reg exceeded_tolerance;
    reg final_exceeded;

    wire is_readout_phase = (state == READOUT);
    
    // Difference calculation
    wire signed [ACC_W:0] diff = $signed(mm_rd_data) - $signed(state_mem_rdata);
    wire [ACC_W:0] abs_diff = diff[ACC_W] ? -diff : diff;
    wire [ACC_W:0] tol_ext  = {1'b0, tolerance};
    
    wire current_exceeds = (abs_diff > tol_ext);
    wire will_exceed     = exceeded_tolerance | current_exceeds;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= IDLE;
            mm_start           <= 0;
            chain_done         <= 0;
            converged          <= 0;
            need_load          <= 0;
            idx                <= 0;
            mm_rd_addr         <= 0;
            cycles_left        <= 0;
            vec_w_en           <= 0;
            is_first_iteration <= 1;
            exceeded_tolerance <= 0;
            final_exceeded      <= 0;
        end
        else begin

            mm_start   <= 0;
            chain_done <= 0;
            vec_w_en   <= 0;

            case (state)

                IDLE: begin
                    if (start) begin
                        need_load          <= 1'b1;
                        cycles_left        <= (max_cycles == 0) ? 0 : max_cycles - 1'b1;
                        is_first_iteration <= 1'b1;
                        converged          <= 1'b0;
                    end

                    if (load_ready) begin
                        need_load <= 1'b0;
                        mm_start  <= 1'b1;
                        state     <= WAIT_MM;
                    end
                end

                WAIT_MM: begin
                    if (mm_done) begin
                        idx                <= 0;
                        mm_rd_addr         <= 0;
                        state              <= READOUT;
                        // Force tolerance exceeded on first pass to ensure at least two iterations occur
                        exceeded_tolerance <= is_first_iteration ? 1'b1 : 1'b0;
                    end
                end

                READOUT: begin
                    vec_w_addr <= idx;
                    vec_w_data <= mm_rd_data;
                    vec_w_en   <= 1;

                    if (idx == N-1) begin
                        is_first_iteration <= 1'b0;
                        final_exceeded      <= will_exceed;
                        state               <= COMMIT;
                    end
                    else begin
                        idx        <= idx + 1'b1;
                        mm_rd_addr <= idx + 1'b1;
                        if (current_exceeds)
                            exceeded_tolerance <= 1'b1;
                    end
                end

                // Wait for the final registered state-memory write before
                // reporting completion or launching the next iteration.
                COMMIT: begin
                        if (cycles_left == 0 || !final_exceeded) begin
                            chain_done <= 1'b1;
                            converged  <= !final_exceeded;
                            state      <= IDLE;
                        end
                        else begin
                            cycles_left <= cycles_left - 1'b1;
                            need_load   <= 1'b1;
                            state       <= IDLE;
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
    
    // Multi-way muxing for memory address to allow combinational readout during convergence check
    assign state_mem_raddr = loader_feeding_back ? load_count[CNT_W-1:0] :
                             is_readout_phase    ? idx[CNT_W-1:0] : 
                                                   rd_vec_addr;

    always @(*) begin
        ld_en     = 1'b0;
        ld_sel_ab = 1'b0;
        ld_addr   = 0;
        ld_data   = 0;
        case (ldr_state)

            S_LOAD_P: begin
                ld_en     = 1'b1;
                ld_sel_ab = 1'b0;                          // P -> B
                ld_addr   = load_count;
                ld_data   = probability_matrix[load_count*DW +: DW];
            end

            S_LOAD_X: begin
                ld_en     = 1'b1;
                ld_sel_ab = 1'b1;                          // X -> A
                ld_addr   = load_count;
                ld_data   = first_pass ? initial_vector[load_count*DW +: DW]
                                       : state_mem_rdata [DW-1:0];
            end

        endcase
    end

endmodule
