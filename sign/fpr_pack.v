`timescale 1ns / 1ps

module fpr_pack (
    input  wire               s, 
    input  wire signed [31:0] e, 
    input  wire [63:0]        m, 
    output wire [63:0]        z  
);
    wire signed [31:0] e_plus_1076;
    wire               t1;
    wire [63:0]        m_adj;
    wire               t2;
    wire signed [31:0] e_final;
    wire [63:0]        x_base;
    wire [2:0]         f;
    wire               round_bit;
    assign e_plus_1076 = e + 32'd1076;
    assign t1 = e_plus_1076[31];
    assign m_adj = t1 ? 64'd0 : m; 
    assign t2 = m_adj[54]; 
    assign e_final = t2 ? e_plus_1076 : 32'd0;
    assign x_base = ({s, 63'd0} | (m_adj >> 2)) + ({32'd0, e_final} << 52);
    assign f = m_adj[2:0];
    assign round_bit = (8'hC8 >> f) & 1'b1;
    assign z = x_base + {63'd0, round_bit};

endmodule