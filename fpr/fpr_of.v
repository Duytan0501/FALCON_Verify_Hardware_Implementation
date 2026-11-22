`timescale 1ns / 1ps

module fpr_of (
    input  wire [63:0] i, 
    output wire [63:0] z   
);
    wire        s;
    wire [63:0] abs_i;
    reg  [5:0]  lzc;
    integer     j;
    wire [63:0] m_norm;
    wire signed [31:0] e_norm;
    wire        sticky; 
    wire [63:0] m_final;
    wire        is_zero;
    wire signed [31:0] e_pack;
    wire [63:0] m_pack;
    assign s = i[63];
    assign abs_i = s ? (~i + 1'b1) : i; 
    always @(*) begin
        lzc = 6'd63; 
        for (j = 63; j >= 0; j = j - 1) begin
            if (abs_i[j]) begin
                lzc = 63 - j;
                break;
            end
        end
        if (abs_i == 64'd0) lzc = 6'd0;
    end
    assign m_norm = abs_i << lzc;
    assign e_norm = 32'sd9 - $signed({26'd0, lzc});
    assign sticky = (m_norm[8:0] != 9'd0);
    assign m_final = (m_norm >> 9) | {63'd0, sticky};
    assign is_zero = (abs_i == 64'd0);
    assign e_pack = is_zero ? 32'd0 : e_norm;
    assign m_pack = is_zero ? 64'd0 : m_final;
    fpr_pack pack_inst (
        .s(s),
        .e(e_pack),
        .m(m_pack),
        .z(z)
    );
endmodule