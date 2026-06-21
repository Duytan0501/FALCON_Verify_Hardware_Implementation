module mq_sub(
    input  wire [15:0] x, 
    input  wire [15:0] y, 
    output wire [15:0] z
);
    assign z = (x >= y) ? (x - y) : (x + 16'd12289 - y);
endmodule