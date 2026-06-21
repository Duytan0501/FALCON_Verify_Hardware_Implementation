module mq_montymul(
    input [15:0] x, 
    input [15:0] y, 
    output [15:0] z
);
    wire [31:0] x32 = {16'd0, x};
    wire [31:0] y32 = {16'd0, y};
    wire [31:0] z_full = x32 * y32;
    wire [31:0] k_full = z_full * 32'd12287;
    wire [31:0] k      = k_full & 32'h0000FFFF;
    wire [31:0] w      = k * 32'd12289;
    wire [31:0] z_temp = (z_full + w) >> 16;
    wire [31:0] sub    = z_temp - 32'd12289;
    assign z = sub[31] ? z_temp[15:0] : sub[15:0];
endmodule