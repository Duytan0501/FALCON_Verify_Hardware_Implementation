`timescale 1ns / 1ps

module fpr_lt (
    input  wire [63:0] x,
    input  wire [63:0] y,
    output wire        z
);
    wire signed [63:0] signed_x = x;
    wire signed [63:0] signed_y = y;
    wire cc0 = (signed_x < signed_y);
    wire cc1 = (signed_x > signed_y);
    wire both_neg = x[63] & y[63];
    assign z = cc0 ^ ((cc0 ^ cc1) & both_neg);
endmodule