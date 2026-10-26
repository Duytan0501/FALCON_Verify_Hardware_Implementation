`timescale 1ns / 1ps

module fpr_double (
    input  wire [63:0] x,
    output wire [63:0] z
);
    wire [10:0] exp;
    wire        t;
    
    assign exp = x[62:52];
    
    // t = (exp + 0x7FF) >> 11;
    // Tương đương: Nếu exp != 0 thì t = 1, nếu exp = 0 thì t = 0
    assign t = (exp != 11'd0) ? 1'b1 : 1'b0;
    
    // x += (uint64_t)t << 52;
    assign z = x + {11'd0, t, 52'd0};
endmodule