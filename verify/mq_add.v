module mq_add(  
    input  wire [15:0] x, 
    input  wire [15:0] y, 
    output wire [15:0] z
);
    wire [15:0] sum = x + y;
    assign z = (sum >= 16'd12289) ? (sum - 16'd12289) : sum;
endmodule