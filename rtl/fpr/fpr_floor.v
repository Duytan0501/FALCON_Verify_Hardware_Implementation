`timescale 1ns / 1ps
module fpr_floor (
    input  wire [63:0] x,
    output wire [63:0] z
);
    wire [10:0] e;
    wire        t;
    wire [63:0] xi_initial;
    wire signed [63:0] xi_signed_pre;
    wire signed [31:0] cc;
    wire [5:0]  shift_amt;
    wire signed [63:0] xi_shifted;
    wire        is_oob;
    wire [63:0] xi_clamped;
    assign e = x[62:52];
    assign t = x[63];
    assign xi_initial = {1'b0, 1'b1, x[51:0], 10'd0}; 
    assign xi_signed_pre = t ? (~xi_initial + 1'b1) : xi_initial;
    assign cc = 32'sd1085 - $signed({21'd0, e});
    assign shift_amt = cc[5:0];
    assign xi_shifted = $signed(xi_signed_pre) >>> shift_amt;
    assign is_oob = (cc >= 32'sd64);
    assign xi_clamped = is_oob ? (t ? 64'hFFFF_FFFF_FFFF_FFFF : 64'd0) : xi_shifted;
    
    assign z = xi_clamped;
endmodule