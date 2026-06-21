module mq_normalize (
    input  wire [15:0] x_in,
    output wire [15:0] z_out
);
    localparam Q      = 16'd12289;
    localparam Q_HALF = 16'd6144;
    
    assign z_out = (x_in > Q_HALF) ? (x_in - Q) : x_in;

endmodule