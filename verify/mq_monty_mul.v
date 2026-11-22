module mq_montymul (
    input  wire [15:0] x,
    input  wire [15:0] y,
    output wire [15:0] z
);
    wire [31:0] z_full = x * y;
    wire [15:0] k      = z_full[15:0] * 16'd12287;
    wire [31:0] w      = k * 16'd12289;
    wire [31:0] sum_zw = z_full + w;
    wire [15:0] z_temp = sum_zw[31:16];

    assign z = (z_temp >= 16'd12289) ? (z_temp - 16'd12289) : z_temp;
endmodule