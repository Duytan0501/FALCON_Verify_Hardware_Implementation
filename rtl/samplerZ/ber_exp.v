`timescale 1ns / 1ps

module ber_exp (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] x,
    input  wire [63:0] ccs,

    // PRNG 8-bit Stream interface (lazy consumption: 1..8 bytes)
    input  wire [7:0]  rng_data,
    input  wire        rng_valid,
    output wire        rng_ready,

    // Shared fpr_mul interface (4-stage pipeline)
    output reg         mul_in_valid,
    output reg  [63:0] mul_x,
    output reg  [63:0] mul_y,
    input  wire        mul_out_valid,
    input  wire [63:0] mul_z,

    // Shared fpr_add interface (4-stage pipeline)
    output reg         add_in_valid,
    output reg  [63:0] add_x,
    output reg  [63:0] add_y,
    input  wire        add_out_valid,
    input  wire [63:0] add_z,

    output reg         accept,
    output reg         done
);

    localparam [63:0] FPR_INV_LOG2 = 64'h3FF7_1547_652B_82FE;
    localparam [63:0] FPR_LOG2     = 64'h3FE6_2E42_FEFA_39EF;

    localparam S_IDLE      = 3'd0;
    localparam S_WAIT_MUL1 = 3'd1;
    localparam S_OF_MUL2   = 3'd2;
    localparam S_WAIT_MUL2 = 3'd3;
    localparam S_WAIT_SUB  = 3'd4;
    localparam S_WAIT_EXPM = 3'd5;
    localparam S_CMP_BYTES = 3'd6;

    reg [2:0]  state;
    reg [63:0] x_reg;
    reg [63:0] ccs_reg;
    reg [31:0] s_int_reg;
    reg [5:0]  s_clamp_reg;
    reg [63:0] z_reg;
    reg [2:0]  byte_cnt;

    reg        expm_start;
    reg [63:0] expm_x_reg;
    wire [63:0] expm_y;
    wire        expm_done;

    assign rng_ready = (state == S_CMP_BYTES);

    // =========================================================================
    // 1. CÁC KHỐI NỘI BỘ (TÁI SỬ DỤNG TỪ rtl/fpr/)
    // =========================================================================
    wire [63:0] s_trunc_w;
    fpr_trunc u_fpr_trunc (
        .x (mul_z),
        .z (s_trunc_w)
    );

    wire [31:0] s_int32_w = s_trunc_w[31:0];
    wire [31:0] diff_63_w = 32'd63 - s_int32_w;
    wire [5:0]  s_clamp_w = diff_63_w[31] ? 6'd63 : s_int32_w[5:0];

    wire [63:0] s_i64_w = {{32{s_int_reg[31]}}, s_int_reg};
    wire [63:0] s_fpr_w;
    fpr_of u_fpr_of (
        .i (s_i64_w),
        .z (s_fpr_w)
    );

    fpr_expm_p63 u_fpr_expm_p63 (
        .clk   (clk),
        .rst_n (rst_n),
        .start (expm_start),
        .x     (expm_x_reg),
        .ccs   (ccs_reg),
        .y_out (expm_y),
        .done  (expm_done)
    );

    wire [63:0] z_shifted_w = ({expm_y[62:0], 1'b0} - 64'd1) >> s_clamp_reg;

    // =========================================================================
    // 2. FSM ĐIỀU KHIỂN CHÍNH
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            x_reg        <= 64'd0;
            ccs_reg      <= 64'd0;
            s_int_reg    <= 32'd0;
            s_clamp_reg  <= 6'd0;
            z_reg        <= 64'd0;
            byte_cnt     <= 3'd0;
            mul_in_valid <= 1'b0;
            mul_x        <= 64'd0;
            mul_y        <= 64'd0;
            add_in_valid <= 1'b0;
            add_x        <= 64'd0;
            add_y        <= 64'd0;
            expm_start   <= 1'b0;
            expm_x_reg   <= 64'd0;
            accept       <= 1'b0;
            done         <= 1'b0;
        end else begin
            mul_in_valid <= 1'b0;
            add_in_valid <= 1'b0;
            expm_start   <= 1'b0;
            done         <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        x_reg        <= x;
                        ccs_reg      <= ccs;
                        mul_x        <= x;
                        mul_y        <= FPR_INV_LOG2;
                        mul_in_valid <= 1'b1;
                        state        <= S_WAIT_MUL1;
                    end
                end

                S_WAIT_MUL1: begin
                    if (mul_out_valid) begin
                        s_int_reg   <= s_int32_w;
                        s_clamp_reg <= s_clamp_w;
                        state       <= S_OF_MUL2;
                    end
                end

                S_OF_MUL2: begin
                    mul_x        <= s_fpr_w;
                    mul_y        <= FPR_LOG2;
                    mul_in_valid <= 1'b1;
                    state        <= S_WAIT_MUL2;
                end

                S_WAIT_MUL2: begin
                    if (mul_out_valid) begin
                        // r = fpr_sub(x, s * ln2) = fpr_add(x, -mul_z)
                        add_x        <= x_reg;
                        add_y        <= {~mul_z[63], mul_z[62:0]};
                        add_in_valid <= 1'b1;
                        state        <= S_WAIT_SUB;
                    end
                end

                S_WAIT_SUB: begin
                    if (add_out_valid) begin
                        expm_x_reg <= add_z;
                        expm_start <= 1'b1;
                        state      <= S_WAIT_EXPM;
                    end
                end

                S_WAIT_EXPM: begin
                    if (expm_done) begin
                        z_reg    <= z_shifted_w;
                        byte_cnt <= 3'd0;
                        state    <= S_CMP_BYTES;
                    end
                end

                S_CMP_BYTES: begin
                    if (rng_valid) begin
                        if (rng_data < z_reg[63:56]) begin
                            accept <= 1'b1;
                            done   <= 1'b1;
                            state  <= S_IDLE;
                        end else if (rng_data > z_reg[63:56]) begin
                            accept <= 1'b0;
                            done   <= 1'b1;
                            state  <= S_IDLE;
                        end else if (byte_cnt == 3'd7) begin
                            accept <= 1'b0;
                            done   <= 1'b1;
                            state  <= S_IDLE;
                        end else begin
                            z_reg    <= {z_reg[55:0], 8'd0};
                            byte_cnt <= byte_cnt + 3'd1;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule