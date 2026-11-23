module mq_add(  
    input [15:0] x, 
    input [15:0] y, 
    output [15:0] z
);
    wire [31:0] sum = {16'd0, x} + {16'd0, y};
    wire [31:0] sub = sum - 32'd12289;
    
    assign z = sub[31] ? sum[15:0] : sub[15:0];
endmodule