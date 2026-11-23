`timescale 1ns / 1ps
module fpr_mul (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [63:0] x,
    input  wire [63:0] y,
    output reg         out_valid,
    output reg  [63:0] z
);
    wire [10:0]        ex_raw   = x[62:52];
    wire [10:0]        ey_raw   = y[62:52];
    wire               s_w      = x[63] ^ y[63];
    wire               nz_w     = (ex_raw != 11'd0) && (ey_raw != 11'd0);
    wire signed [12:0] e_base_w = $signed({2'b00, ex_raw}) + $signed({2'b00, ey_raw}) - 13'sd2100;
    wire [52:0] xu = {1'b1, x[51:0]};
    wire [52:0] yu = {1'b1, y[51:0]};
    wire [24:0] x0 = xu[24:0];
    wire [27:0] x1 = xu[52:25];
    wire [24:0] y0 = yu[24:0];
    wire [27:0] y1 = yu[52:25];
    wire [49:0] p00_w = x0 * y0;
    wire [52:0] p01_w = x0 * y1;
    wire [52:0] p10_w = x1 * y0;
    wire [55:0] p11_w = x1 * y1;
    reg               s1_valid;
    reg               s1_s;
    reg               s1_nz;
    reg signed [12:0] s1_e_base;
    reg [49:0]        s1_p00;
    reg [52:0]        s1_p01;
    reg [52:0]        s1_p10;
    reg [55:0]        s1_p11;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid  <= 1'b0;
            s1_s      <= 1'b0;
            s1_nz     <= 1'b0;
            s1_e_base <= 13'sd0;
            s1_p00    <= 50'd0;
            s1_p01    <= 53'd0;
            s1_p10    <= 53'd0;
            s1_p11    <= 56'd0;
        end else begin
            s1_valid <= in_valid;
            if (in_valid) begin
                s1_s      <= s_w;
                s1_nz     <= nz_w;
                s1_e_base <= e_base_w;
                s1_p00    <= p00_w;
                s1_p01    <= p01_w;
                s1_p10    <= p10_w;
                s1_p11    <= p11_w;
            end
        end
    end
    wire [53:0] mid_sum_w = {1'b0, s1_p01} + {1'b0, s1_p10} + {29'd0, s1_p00[49:25]};
    wire        st_lo50_w = (|s1_p00[24:0]) | (|mid_sum_w[24:0]);

    reg               s2_valid;
    reg               s2_s;
    reg               s2_nz;
    reg signed [12:0] s2_e_base;
    reg [55:0]        s2_p11;
    reg [28:0]        s2_mid_hi;
    reg               s2_st_lo50;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid   <= 1'b0;
            s2_s       <= 1'b0;
            s2_nz      <= 1'b0;
            s2_e_base  <= 13'sd0;
            s2_p11     <= 56'd0;
            s2_mid_hi  <= 29'd0;
            s2_st_lo50 <= 1'b0;
        end else begin
            s2_valid <= s1_valid;
            if (s1_valid) begin
                s2_s       <= s1_s;
                s2_nz      <= s1_nz;
                s2_e_base  <= s1_e_base;
                s2_p11     <= s1_p11;
                s2_mid_hi  <= mid_sum_w[53:25];
                s2_st_lo50 <= st_lo50_w;
            end
        end
    end
    wire [55:0]        zu_raw_w   = s2_p11 + {27'd0, s2_mid_hi};
    wire [55:0]        zu_st_w    = zu_raw_w | {55'd0, s2_st_lo50};
    wire               norm_shift = zu_st_w[55];
    wire [54:0]        zu_norm_w  = norm_shift ? {zu_st_w[55:2], zu_st_w[1] | zu_st_w[0]}
                                               : zu_st_w[54:0];
    wire signed [12:0] e_final_w  = s2_e_base + $signed({12'd0, norm_shift});
    wire [54:0]        m_final_w  = s2_nz ? zu_norm_w : 55'd0;

    reg               s3_valid;
    reg               s3_s;
    reg signed [12:0] s3_e;
    reg [54:0]        s3_m;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_valid <= 1'b0;
            s3_s     <= 1'b0;
            s3_e     <= 13'sd0;
            s3_m     <= 55'd0;
        end else begin
            s3_valid <= s2_valid;
            if (s2_valid) begin
                s3_s <= s2_s;
                s3_e <= e_final_w;
                s3_m <= m_final_w;
            end
        end
    end
    wire signed [31:0] pack_e_in = {{19{s3_e[12]}}, s3_e};
    wire [63:0]        pack_m_in = {9'd0, s3_m};
    wire [63:0]        z_comb;
    fpr_pack u_fpr_pack (
        .s (s3_s),
        .e (pack_e_in),
        .m (pack_m_in),
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