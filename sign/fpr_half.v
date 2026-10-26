`timescale 1ns / 1ps

module fpr_half (
    input  wire [63:0] x,
    output wire [63:0] z
);
    wire [63:0] x_sub;
    wire [10:0] exp_sub;
    wire        t;
    assign x_sub = x - 64'h0010_0000_0000_0000;
    assign exp_sub = x_sub[62:52];
    assign t = (exp_sub + 11'd1) >> 11; 
    assign z = t ? 64'd0 : x_sub; 
endmodule