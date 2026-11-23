`timescale 1ns / 1ps

module fpr_add (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [63:0] x,
    input  wire [63:0] y,
    output reg         out_valid,
    output reg  [63:0] z
);

    // =========================================================================
    // STAGE 1: CONDITIONAL MAGNITUDE SWAP, UNPACK & EXPONENT DIFF
    // =========================================================================
    wire               swap_en = (x[62:0] < y[62:0]) || ((x[62:0] == y[62:0]) && x[63]);
    wire [63:0]        xa      = swap_en ? y : x;
    wire [63:0]        ya      = swap_en ? x : y;

    wire               sx_w    = xa[63];
    wire               sy_w    = ya[63];
    wire [10:0]        ex_raw  = xa[62:52];
    wire [10:0]        ey_raw  = ya[62:52];
    wire               x_nz    = (ex_raw != 11'd0);
    wire               y_nz    = (ey_raw != 11'd0);

    wire [55:0]        xu_init = {x_nz, xa[51:0], 3'b000};
    wire [55:0]        yu_init = {y_nz, ya[51:0], 3'b000};
    wire [10:0]        cc_full = ex_raw - ey_raw;
    wire               cc_ge60 = (cc_full >= 11'd60);
    wire signed [12:0] ex_init = $signed({2'b00, ex_raw}) - 13'sd1078;

    reg                s1_valid;
    reg                s1_sx;
    reg                s1_eff_sub;
    reg signed [12:0]  s1_ex;
    reg [55:0]         s1_xu;
    reg [55:0]         s1_yu;
    reg [5:0]          s1_cc;
    reg                s1_ge60;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid   <= 1'b0;
            s1_sx      <= 1'b0;
            s1_eff_sub <= 1'b0;
            s1_ex      <= 13'sd0;
            s1_xu      <= 56'd0;
            s1_yu      <= 56'd0;
            s1_cc      <= 6'd0;
            s1_ge60    <= 1'b0;
        end else begin
            s1_valid <= in_valid;
            if (in_valid) begin
                s1_sx      <= sx_w;
                s1_eff_sub <= sx_w ^ sy_w;
                s1_ex      <= ex_init;
                s1_xu      <= xu_init;
                s1_yu      <= yu_init;
                s1_cc      <= cc_full[5:0];
                s1_ge60    <= cc_ge60;
            end
        end
    end

    // =========================================================================
    // STAGE 2: 6-LEVEL BARREL RIGHT-SHIFT + STICKY ALIGNMENT
    // =========================================================================
    wire [55:0] r5  = s1_cc[5] ? {32'd0, s1_yu[55:32]} : s1_yu;
    wire        st5 = s1_cc[5] && (|s1_yu[31:0]);

    wire [55:0] r4  = s1_cc[4] ? {16'd0, r5[55:16]} : r5;
    wire        st4 = s1_cc[4] && (|r5[15:0]);

    wire [55:0] r3  = s1_cc[3] ? {8'd0, r4[55:8]} : r4;
    wire        st3 = s1_cc[3] && (|r4[7:0]);

    wire [55:0] r2  = s1_cc[2] ? {4'd0, r3[55:4]} : r3;
    wire        st2 = s1_cc[2] && (|r3[3:0]);

    wire [55:0] r1  = s1_cc[1] ? {2'd0, r2[55:2]} : r2;
    wire        st1 = s1_cc[1] && (|r2[1:0]);

    wire [55:0] r0  = s1_cc[0] ? {1'b0, r1[55:1]} : r1;
    wire        st0 = s1_cc[0] && r1[0];

    wire        sticky_align = st5 | st4 | st3 | st2 | st1 | st0;
    wire [55:0] yu_aligned   = s1_ge60 ? 56'd0 : (r0 | {55'd0, sticky_align});

    reg               s2_valid;
    reg               s2_sx;
    reg               s2_eff_sub;
    reg signed [12:0] s2_ex;
    reg [55:0]        s2_xu;
    reg [55:0]        s2_yu_al;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid   <= 1'b0;
            s2_sx      <= 1'b0;
            s2_eff_sub <= 1'b0;
            s2_ex      <= 13'sd0;
            s2_xu      <= 56'd0;
            s2_yu_al   <= 56'd0;
        end else begin
            s2_valid <= s1_valid;
            if (s1_valid) begin
                s2_sx      <= s1_sx;
                s2_eff_sub <= s1_eff_sub;
                s2_ex      <= s1_ex;
                s2_xu      <= s1_xu;
                s2_yu_al   <= yu_aligned;
            end
        end
    end

    // =========================================================================
    // STAGE 3: 57-BIT ADD/SUB + BALANCED BINARY-TREE LZC (64-BIT)
    // =========================================================================
    wire [56:0] xu_sum_w = s2_eff_sub ? ({1'b0, s2_xu} - {1'b0, s2_yu_al})
                                      : ({1'b0, s2_xu} + {1'b0, s2_yu_al});

    wire [63:0] n0     = {7'd0, xu_sum_w};
    wire        v_hi32 = (|n0[63:32]);
    wire [31:0] v32    = v_hi32 ? n0[63:32] : n0[31:0];
    wire        v_hi16 = (|v32[31:16]);
    wire [15:0] v16    = v_hi16 ? v32[31:16] : v32[15:0];
    wire        v_hi8  = (|v16[15:8]);
    wire [7:0]  v8     = v_hi8  ? v16[15:8]  : v16[7:0];
    wire        v_hi4  = (|v8[7:4]);
    wire [3:0]  v4     = v_hi4  ? v8[7:4]    : v8[3:0];
    wire        v_hi2  = (|v4[3:2]);
    wire [1:0]  v2     = v_hi2  ? v4[3:2]    : v4[1:0];
    wire        v_hi1  = v2[1];

    wire [5:0]  lzc_w  = {~v_hi32, ~v_hi16, ~v_hi8, ~v_hi4, ~v_hi2, ~v_hi1};

    reg               s3_valid;
    reg               s3_sx;
    reg signed [12:0] s3_ex;
    reg [56:0]        s3_xu_sum;
    reg [5:0]         s3_lzc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_valid  <= 1'b0;
            s3_sx     <= 1'b0;
            s3_ex     <= 13'sd0;
            s3_xu_sum <= 57'd0;
            s3_lzc    <= 6'd0;
        end else begin
            s3_valid <= s2_valid;
            if (s2_valid) begin
                s3_sx     <= s2_sx;
                s3_ex     <= s2_ex;
                s3_xu_sum <= xu_sum_w;
                s3_lzc    <= lzc_w;
            end
        end
    end

    // =========================================================================
    // STAGE 4: LEFT-SHIFT || EXP-ADJUST -> STICKY-9 -> fpr_pack -> OUTPUT REG
    // =========================================================================
    wire [63:0]        xu_norm   = {7'd0, s3_xu_sum} << s3_lzc;
    wire signed [12:0] ex_final  = s3_ex - $signed({7'd0, s3_lzc}) + 13'sd9;
    wire               sticky_9  = (|xu_norm[8:0]);
    wire [63:0]        m_pack_w  = {9'd0, xu_norm[63:10], xu_norm[9] | sticky_9};
    wire signed [31:0] pack_e_in = {{19{ex_final[12]}}, ex_final};
    wire [63:0]        z_comb;
    fpr_pack u_fpr_pack (
        .s (s3_sx),
        .e (pack_e_in),
        .m (m_pack_w),
        .z (z_comb)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            z         <= 64'd0;
        end else begin
            out_valid <= s3_valid;
            if (s3_valid) begin
                z <= z_comb;
            end
        end
    end
endmodule