`timescale 1ns / 1ps

module fpr_rint (
    input  wire [63:0] x,
    output wire [63:0] z
);
    wire [10:0] e_orig;
    wire        s;
    wire [63:0] m_init;
    wire signed [31:0] e_val;
    wire        is_oob;
    wire [63:0] m_clamped;
    wire [5:0]  shift_amt;
    wire [63:0] d;
    wire [31:0] dd;
    wire [2:0]  f;
    wire [63:0] m_shifted;
    wire [63:0] m_rounded;
    assign e_orig = x[62:52];
    assign s = x[63];
    assign m_init = {1'b0, 1'b1, x[51:0], 10'd0}; 
    assign e_val = 32'sd1085 - $signed({21'd0, e_orig});
    assign is_oob = (e_val >= 32'sd64);
    assign m_clamped = is_oob ? 64'd0 : m_init;
    assign shift_amt = e_val[5:0];
    assign d = m_clamped << (6'd63 - shift_amt);
    assign dd = d[31:0] | (d[63:32] & 32'h1FFF_FFFF);
    assign f = { d[63:62], d[61] | (dd != 32'd0) };
    assign m_shifted = m_clamped >> shift_amt;
    assign m_rounded = m_shifted + {63'd0, (8'hC8 >> f) & 1'b1};
    assign z = s ? (~m_rounded + 1'b1) : m_rounded;
endmodule