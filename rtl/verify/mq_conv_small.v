module mq_conv_small (
    input  wire [15:0] x_in,   
    output wire [15:0] z_out   
);
    localparam Q = 16'd12289;
    assign z_out = x_in[15] ? (x_in + Q) : x_in;
endmodule