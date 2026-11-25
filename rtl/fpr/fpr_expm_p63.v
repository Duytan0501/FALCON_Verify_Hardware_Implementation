`timescale 1ns / 1ps

module fpr_expm_p63 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] x,
    input  wire [63:0] ccs,
    output reg  [63:0] y_out,
    output reg         done
);
    localparam S_IDLE    = 2'd0;
    localparam S_HORNER  = 2'd1;
    localparam S_CCS_MUL = 2'd2;
    localparam [63:0] C0 = 64'h00000004741183A3;
    reg [1:0]  state;
    reg [3:0]  u_idx;
    reg [1:0]  sub;
    reg [63:0] z_reg;
    reg [63:0] y_reg;
    reg [63:0] ccs_reg;
    reg [31:0] p00_hi;
    reg [63:0] reg_a;
    reg [32:0] ab_hi;
    wire [63:0] fp_sel    = (state == S_IDLE) ? x : ccs_reg;
    wire [10:0] fp_exp    = fp_sel[62:52];
    wire [63:0] fp_scaled = (fp_exp == 11'd0) ? {fp_sel[63], 63'd0}
                                              : {fp_sel[63], fp_exp + 11'd63, fp_sel[51:0]};
    wire [63:0] trunc_out;
    fpr_trunc u_fpr_trunc (
        .x (fp_scaled),
        .z (trunc_out)
    );
    wire [63:0] z_fixed_w = {trunc_out[62:0], 1'b0};
    reg [63:0] c_rom;
    always @(*) begin
        case (u_idx)
            4'd1:    c_rom = 64'h00000036548CFC06;
            4'd2:    c_rom = 64'h0000024FDCBF140A;
            4'd3:    c_rom = 64'h0000171D939DE045;
            4'd4:    c_rom = 64'h0000D00CF58F6F84;
            4'd5:    c_rom = 64'h000680681CF796E3;
            4'd6:    c_rom = 64'h002D82D8305B0FEA;
            4'd7:    c_rom = 64'h011111110E066FD0;
            4'd8:    c_rom = 64'h0555555555070F00;
            4'd9:    c_rom = 64'h155555555581FF00;
            4'd10:   c_rom = 64'h400000000002B400;
            4'd11:   c_rom = 64'h7FFFFFFFFFFF4800;
            4'd12:   c_rom = 64'h8000000000000000;
            default: c_rom = 64'd0;
        endcase
    end
    wire [31:0] mul_a     = (sub[1] == 1'b0) ? z_reg[31:0] : z_reg[63:32];
    wire [31:0] mul_b     = (sub[0] == 1'b0) ? y_reg[31:0] : y_reg[63:32];
    wire [63:0] mul_p     = mul_a * mul_b;

    wire [63:0] a_next    = mul_p + {32'd0, p00_hi};
    wire [64:0] ab_sum    = {1'b0, reg_a} + {1'b0, mul_p};
    wire [63:0] umulh_res = mul_p + {31'd0, ab_hi};
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            u_idx   <= 4'd1;
            sub     <= 2'd0;
            z_reg   <= 64'd0;
            y_reg   <= 64'd0;
            ccs_reg <= 64'd0;
            p00_hi  <= 32'd0;
            reg_a   <= 64'd0;
            ab_hi   <= 33'd0;
            y_out   <= 64'd0;
            done    <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (start) begin
                        z_reg   <= z_fixed_w;
                        ccs_reg <= ccs;
                        y_reg   <= C0;
                        u_idx   <= 4'd1;
                        sub     <= 2'd0;
                        state   <= S_HORNER;
                    end
                end
                S_HORNER: begin
                    case (sub)
                        2'd0: begin
                            p00_hi <= mul_p[63:32];
                            sub    <= 2'd1;
                        end
                        2'd1: begin
                            reg_a <= a_next;
                            sub   <= 2'd2;
                        end
                        2'd2: begin
                            ab_hi <= ab_sum[64:32];
                            sub   <= 2'd3;
                        end
                        2'd3: begin
                            y_reg <= c_rom - umulh_res;
                            sub   <= 2'd0;
                            if (u_idx == 4'd12) begin
                                z_reg <= z_fixed_w;
                                state <= S_CCS_MUL;
                            end else begin
                                u_idx <= u_idx + 4'd1;
                            end
                        end
                    endcase
                end
                S_CCS_MUL: begin
                    case (sub)
                        2'd0: begin
                            p00_hi <= mul_p[63:32];
                            sub    <= 2'd1;
                        end
                        2'd1: begin
                            reg_a <= a_next;
                            sub   <= 2'd2;
                        end
                        2'd2: begin
                            ab_hi <= ab_sum[64:32];
                            sub   <= 2'd3;
                        end
                        2'd3: begin
                            y_out <= umulh_res;
                            done  <= 1'b1;
                            sub   <= 2'd0;
                            state <= S_IDLE;
                        end
                    endcase
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule