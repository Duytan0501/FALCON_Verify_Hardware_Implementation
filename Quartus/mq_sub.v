module mq_sub(
    input [15:0] x, 
    input [15:0] y, 
    output [15:0] z
);
    wire [31:0] sub = {16'd0, x} - {16'd0, y};
    wire [31:0] res = sub + 32'd12289;
    assign z = sub[31] ? res[15:0] : sub[15:0];
endmodule