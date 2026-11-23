module fpr_neg (
    input  wire [63:0] x,
    output wire [63:0] z
);
    assign z = x ^ 64'h8000_0000_0000_0000; 
endmodule