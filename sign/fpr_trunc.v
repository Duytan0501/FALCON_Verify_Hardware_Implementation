`timescale 1ns / 1ps

module fpr_trunc (
    input  wire [63:0] x,
    output wire [63:0] z
);
    wire [10:0] e;
    wire [63:0] xu_initial;
    wire signed [31:0] cc;
    wire [5:0]  shift_amt;
    wire [63:0] xu_shifted;
    wire        out_of_bounds;
    wire [63:0] xu_clamped;
    wire        t;
    assign e = x[62:52];
    assign xu_initial = {1'b0, 1'b1, x[51:0], 10'd0}; 
    assign cc = 32'sd1085 - $signed({21'd0, e});
    assign shift_amt = cc[5:0];
    assign xu_shifted = xu_initial >> shift_amt;
    assign out_of_bounds = (cc >= 32'sd64); 
    assign xu_clamped = out_of_bounds ? 64'd0 : xu_shifted;
    assign t = x[63];
    assign z = t ? ((~xu_clamped) + 1'b1) : xu_clamped;

endmodule