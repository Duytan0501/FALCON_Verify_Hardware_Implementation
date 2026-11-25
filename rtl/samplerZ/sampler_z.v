`timescale 1ns / 1ps
module sampler_z #(
    parameter [63:0] FPR_SIGMA_MIN = 64'h3FF4_7201_BF1F_7A75
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] mu,
    input  wire [63:0] isigma,
    input  wire [7:0]  rng_data,
    input  wire        rng_valid,
    output wire        rng_ready,
    output reg  [31:0] z_out,
    output reg         done
);
    localparam [63:0] FPR_INV_2SQRSIGMA0 = 64'h3FC3_4F8B_C183_BBC2;
    localparam S_IDLE          = 4'd0;
    localparam S_INIT_1        = 4'd1;
    localparam S_INIT_2        = 4'd2;
    localparam S_INIT_WAIT1    = 4'd3;
    localparam S_INIT_WAIT2    = 4'd4;
    localparam S_WAIT_GAUSS0   = 4'd5;
    localparam S_GET_B         = 4'd6;
    localparam S_LOOP_SUB_Z    = 4'd7;
    localparam S_LOOP_MUL_T2   = 4'd8;
    localparam S_LOOP_WAIT_ZMR = 4'd9;
    localparam S_LOOP_WAIT_T2  = 4'd10;
    localparam S_LOOP_WAIT_SQ  = 4'd11;
    localparam S_LOOP_WAIT_T1  = 4'd12;
    localparam S_LOOP_WAIT_X   = 4'd13;
    localparam S_WAIT_BER      = 4'd14;
    reg [3:0]  state;
    reg [63:0] mu_reg;
    reg [63:0] isigma_reg;
    reg [31:0] s_reg;
    reg [63:0] r_reg;
    reg [63:0] dss_reg;
    reg [63:0] ccs_reg;
    reg [4:0]  z0_reg;
    reg [31:0] z_int_reg;
    reg [9:0]  z0_sq_reg;
    reg [63:0] term2_reg;
    reg [63:0] x_reg;
    reg        g0_start;
    wire       g0_rng_valid, g0_rng_ready;
    wire [4:0] g0_z0;
    wire       g0_done;
    reg        ber_start;
    wire       ber_rng_valid, ber_rng_ready;
    wire       ber_accept, ber_done;
    reg        sz_mul_in_valid;
    reg [63:0] sz_mul_x, sz_mul_y;
    reg        sz_add_in_valid;
    reg [63:0] sz_add_x, sz_add_y;
    wire       ber_mul_in_valid;
    wire [63:0] ber_mul_x, ber_mul_y;
    wire       ber_add_in_valid;
    wire [63:0] ber_add_x, ber_add_y;
    wire in_ber = (state == S_WAIT_BER);
    assign g0_rng_valid  = (state == S_WAIT_GAUSS0) ? rng_valid : 1'b0;
    assign ber_rng_valid = in_ber                   ? rng_valid : 1'b0;
    assign rng_ready     = (state == S_WAIT_GAUSS0) ? g0_rng_ready  :
                           (state == S_GET_B)       ? 1'b1          :
                           in_ber                   ? ber_rng_ready : 1'b0;
    wire        mul_in_valid = in_ber ? ber_mul_in_valid : sz_mul_in_valid;
    wire [63:0] mul_x        = in_ber ? ber_mul_x        : sz_mul_x;
    wire [63:0] mul_y        = in_ber ? ber_mul_y        : sz_mul_y;
    wire        mul_out_valid;
    wire [63:0] mul_z;

    wire        add_in_valid = in_ber ? ber_add_in_valid : sz_add_in_valid;
    wire [63:0] add_x        = in_ber ? ber_add_x        : sz_add_x;
    wire [63:0] add_y        = in_ber ? ber_add_y        : sz_add_y;
    wire        add_out_valid;
    wire [63:0] add_z;
    fpr_mul u_fpr_mul (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (mul_in_valid),
        .x         (mul_x),
        .y         (mul_y),
        .out_valid (mul_out_valid),
        .z         (mul_z)
    );
    fpr_add u_fpr_add (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (add_in_valid),
        .x         (add_x),
        .y         (add_y),
        .out_valid (add_out_valid),
        .z         (add_z)
    );
    wire [63:0] floor_out;
    fpr_floor u_fpr_floor (
        .x (mu_reg),
        .z (floor_out)
    );
    reg [63:0] of_in;
    always @(*) begin
        case (state)
            S_INIT_2:      of_in = {{32{s_reg[31]}}, s_reg};
            S_LOOP_SUB_Z:  of_in = {{32{z_int_reg[31]}}, z_int_reg};
            S_LOOP_MUL_T2: of_in = {54'd0, z0_sq_reg};
            default:       of_in = 64'd0;
        endcase
    end
    wire [63:0] of_out;
    fpr_of u_fpr_of (
        .i (of_in),
        .z (of_out)
    );
    wire [63:0] half_out;
    fpr_half u_fpr_half (
        .x (mul_z),
        .z (half_out)
    );
    wire [31:0] z0_ext32 = {27'd0, z0_reg};
    wire [31:0] z_cand_w = rng_data[0] ? (z0_ext32 + 32'd1) : ((~z0_ext32) + 32'd1);
    wire [9:0]  z0_sq_w  = z0_reg * z0_reg;
    gaussian0_sampler u_gaussian0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (g0_start),
        .rng_data  (rng_data),
        .rng_valid (g0_rng_valid),
        .rng_ready (g0_rng_ready),
        .z0_out    (g0_z0),
        .done      (g0_done)
    );
    ber_exp u_ber_exp (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (ber_start),
        .x             (x_reg),
        .ccs           (ccs_reg),
        .rng_data      (rng_data),
        .rng_valid     (ber_rng_valid),
        .rng_ready     (ber_rng_ready),
        .mul_in_valid  (ber_mul_in_valid),
        .mul_x         (ber_mul_x),
        .mul_y         (ber_mul_y),
        .mul_out_valid (in_ber ? mul_out_valid : 1'b0),
        .mul_z         (mul_z),
        .add_in_valid  (ber_add_in_valid),
        .add_x         (ber_add_x),
        .add_y         (ber_add_y),
        .add_out_valid (in_ber ? add_out_valid : 1'b0),
        .add_z         (add_z),
        .accept        (ber_accept),
        .done          (ber_done)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            mu_reg          <= 64'd0;
            isigma_reg      <= 64'd0;
            s_reg           <= 32'd0;
            r_reg           <= 64'd0;
            dss_reg         <= 64'd0;
            ccs_reg         <= 64'd0;
            z0_reg          <= 5'd0;
            z_int_reg       <= 32'd0;
            z0_sq_reg       <= 10'd0;
            term2_reg       <= 64'd0;
            x_reg           <= 64'd0;
            g0_start        <= 1'b0;
            ber_start       <= 1'b0;
            sz_mul_in_valid <= 1'b0;
            sz_mul_x        <= 64'd0;
            sz_mul_y        <= 64'd0;
            sz_add_in_valid <= 1'b0;
            sz_add_x        <= 64'd0;
            sz_add_y        <= 64'd0;
            z_out           <= 32'd0;
            done            <= 1'b0;
        end else begin
            g0_start        <= 1'b0;
            ber_start       <= 1'b0;
            sz_mul_in_valid <= 1'b0;
            sz_add_in_valid <= 1'b0;
            done            <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (start) begin
                        mu_reg     <= mu;
                        isigma_reg <= isigma;
                        state      <= S_INIT_1;
                    end
                end
                S_INIT_1: begin
                    // s = floor(mu) ; phóng lệnh 1 vào fpr_mul: isigma * isigma
                    s_reg           <= floor_out[31:0];
                    sz_mul_x        <= isigma_reg;
                    sz_mul_y        <= isigma_reg;
                    sz_mul_in_valid <= 1'b1;
                    state           <= S_INIT_2;
                end
                S_INIT_2: begin
                    sz_mul_x        <= isigma_reg;
                    sz_mul_y        <= FPR_SIGMA_MIN;
                    sz_mul_in_valid <= 1'b1;
                    sz_add_x        <= mu_reg;
                    sz_add_y        <= {~of_out[63], of_out[62:0]};
                    sz_add_in_valid <= 1'b1;
                    state           <= S_INIT_WAIT1;
                end
                S_INIT_WAIT1: begin
                    if (mul_out_valid) begin
                        dss_reg <= half_out; 
                        state   <= S_INIT_WAIT2;
                    end
                end
                S_INIT_WAIT2: begin
                    if (mul_out_valid && add_out_valid) begin
                        ccs_reg  <= mul_z;
                        r_reg    <= add_z;
                        g0_start <= 1'b1;
                        state    <= S_WAIT_GAUSS0;
                    end
                end
                S_WAIT_GAUSS0: begin
                    if (g0_done) begin
                        z0_reg <= g0_z0;
                        state  <= S_GET_B;
                    end
                end
                S_GET_B: begin
                    if (rng_valid) begin
                        z_int_reg <= z_cand_w;
                        z0_sq_reg <= z0_sq_w;
                        state     <= S_LOOP_SUB_Z;
                    end
                end
                S_LOOP_SUB_Z: begin
                    // Phóng fpr_add: (fpr_of(z) - r)
                    sz_add_x        <= of_out;
                    sz_add_y        <= {~r_reg[63], r_reg[62:0]};
                    sz_add_in_valid <= 1'b1;
                    state           <= S_LOOP_MUL_T2;
                end
                S_LOOP_MUL_T2: begin
                    sz_mul_x        <= of_out;
                    sz_mul_y        <= FPR_INV_2SQRSIGMA0;
                    sz_mul_in_valid <= 1'b1;
                    state           <= S_LOOP_WAIT_ZMR;
                end
                S_LOOP_WAIT_ZMR: begin
                    if (add_out_valid) begin
                        sz_mul_x        <= add_z;
                        sz_mul_y        <= add_z;
                        sz_mul_in_valid <= 1'b1;
                        state           <= S_LOOP_WAIT_T2;
                    end
                end
                S_LOOP_WAIT_T2: begin
                    if (mul_out_valid) begin
                        term2_reg <= mul_z;
                        state     <= S_LOOP_WAIT_SQ;
                    end
                end
                S_LOOP_WAIT_SQ: begin
                    if (mul_out_valid) begin
                        sz_mul_x        <= mul_z;
                        sz_mul_y        <= dss_reg;
                        sz_mul_in_valid <= 1'b1;
                        state           <= S_LOOP_WAIT_T1;
                    end
                end
                S_LOOP_WAIT_T1: begin
                    if (mul_out_valid) begin
                        // Có term1 -> phóng x = term1 - term2
                        sz_add_x        <= mul_z;
                        sz_add_y        <= {~term2_reg[63], term2_reg[62:0]};
                        sz_add_in_valid <= 1'b1;
                        state           <= S_LOOP_WAIT_X;
                    end
                end
                S_LOOP_WAIT_X: begin
                    if (add_out_valid) begin
                        x_reg     <= add_z;
                        ber_start <= 1'b1;
                        state     <= S_WAIT_BER;
                    end
                end
                S_WAIT_BER: begin
                    if (ber_done) begin
                        if (ber_accept) begin
                            z_out <= s_reg + z_int_reg;
                            done  <= 1'b1;
                            state <= S_IDLE;
                        end else begin
                            g0_start <= 1'b1;
                            state    <= S_WAIT_GAUSS0;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule