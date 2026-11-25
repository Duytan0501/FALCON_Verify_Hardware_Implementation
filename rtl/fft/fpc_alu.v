`timescale 1ns / 1ps
module fpc_alu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [2:0]  op,
    input  wire        do_half,     
    input  wire [63:0] a_re,
    input  wire [63:0] a_im,
    input  wire [63:0] b_re,
    input  wire [63:0] b_im,
    input  wire [63:0] s_re,
    input  wire [63:0] s_im,
    output reg  [63:0] out0_re,
    output reg  [63:0] out0_im,
    output reg  [63:0] out1_re,
    output reg  [63:0] out1_im,
    output reg         busy,
    output reg         done
);
    localparam OP_ADD     = 3'd0;
    localparam OP_SUB     = 3'd1;
    localparam OP_MUL     = 3'd2;
    localparam OP_SCALE   = 3'd3;
    localparam OP_FFT_BF  = 3'd4;
    localparam OP_IFFT_BF = 3'd5;
    reg [2:0]  op_reg;
    reg        half_reg;
    reg [4:0]  step;
    reg [63:0] a_re_r, a_im_r;
    reg [63:0] b_re_r, b_im_r;
    reg [63:0] s_re_r, s_im_r;
    reg [63:0] t0, t1;
    reg         mul_in_valid;
    reg  [63:0] mul_x, mul_y;
    wire        mul_out_valid;
    wire [63:0] mul_z;
    reg         add_in_valid;
    reg  [63:0] add_x, add_y;
    wire        add_out_valid;
    wire [63:0] add_z;
    wire [63:0] half_add_z;
    fpr_mul u_fpr_mul (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (mul_in_valid),
        .x         (mul_x),
        .y         (mul_y),
        .out_valid (mul_out_valid),
        .z         (mul_z)
    );
    fpr_add u_fpr_add (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (add_in_valid),
        .x         (add_x),
        .y         (add_y),
        .out_valid (add_out_valid),
        .z         (add_z)
    );
    fpr_half u_fpr_half (
        .x (add_z),
        .z (half_add_z)
    );
    always @(*) begin
        mul_in_valid = 1'b0;
        mul_x        = 64'd0;
        mul_y        = 64'd0;
        add_in_valid = 1'b0;
        add_x        = 64'd0;
        add_y        = 64'd0;
        if (busy) begin
            case (op_reg)
                OP_ADD: begin
                    case (step)
                        5'd0: begin add_in_valid = 1'b1; add_x = a_re_r; add_y = b_re_r; end
                        5'd1: begin add_in_valid = 1'b1; add_x = a_im_r; add_y = b_im_r; end
                        default: ;
                    endcase
                end
                OP_SUB: begin
                    case (step)
                        5'd0: begin add_in_valid = 1'b1; add_x = a_re_r; add_y = {~b_re_r[63], b_re_r[62:0]}; end
                        5'd1: begin add_in_valid = 1'b1; add_x = a_im_r; add_y = {~b_im_r[63], b_im_r[62:0]}; end
                        default: ;
                    endcase
                end
                OP_SCALE: begin
                    case (step)
                        5'd0: begin mul_in_valid = 1'b1; mul_x = a_re_r; mul_y = s_re_r; end
                        5'd1: begin mul_in_valid = 1'b1; mul_x = a_im_r; mul_y = s_re_r; end
                        default: ;
                    endcase
                end
                OP_MUL: begin
                    case (step)
                        5'd0: begin mul_in_valid = 1'b1; mul_x = a_re_r; mul_y = b_re_r; end
                        5'd1: begin mul_in_valid = 1'b1; mul_x = a_im_r; mul_y = b_im_r; end
                        5'd2: begin mul_in_valid = 1'b1; mul_x = a_re_r; mul_y = b_im_r; end
                        5'd3: begin mul_in_valid = 1'b1; mul_x = a_im_r; mul_y = b_re_r; end
                        5'd5: begin add_in_valid = 1'b1; add_x = t0;     add_y = {~mul_z[63], mul_z[62:0]}; end
                        5'd7: begin add_in_valid = 1'b1; add_x = t0;     add_y = mul_z; end
                        default: ;
                    endcase
                end
                OP_FFT_BF: begin
                    case (step)
                        // t = b * s
                        5'd0:  begin mul_in_valid = 1'b1; mul_x = b_re_r; mul_y = s_re_r; end
                        5'd1:  begin mul_in_valid = 1'b1; mul_x = b_im_r; mul_y = s_im_r; end
                        5'd2:  begin mul_in_valid = 1'b1; mul_x = b_re_r; mul_y = s_im_r; end
                        5'd3:  begin mul_in_valid = 1'b1; mul_x = b_im_r; mul_y = s_re_r; end
                        5'd5:  begin add_in_valid = 1'b1; add_x = t0;     add_y = {~mul_z[63], mul_z[62:0]}; end
                        5'd7:  begin add_in_valid = 1'b1; add_x = t0;     add_y = mul_z; end
                        // out0 = a + t, out1 = a - t
                        5'd9:  begin add_in_valid = 1'b1; add_x = a_re_r; add_y = add_z; end
                        5'd10: begin add_in_valid = 1'b1; add_x = a_re_r; add_y = {~t0[63], t0[62:0]}; end
                        5'd11: begin add_in_valid = 1'b1; add_x = a_im_r; add_y = add_z; end
                        5'd12: begin add_in_valid = 1'b1; add_x = a_im_r; add_y = {~t0[63], t0[62:0]}; end
                        default: ;
                    endcase
                end
                OP_IFFT_BF: begin
                    case (step)
                        // d = a - b truoc, out0 = a + b sau
                        5'd0:  begin add_in_valid = 1'b1; add_x = a_re_r; add_y = {~b_re_r[63], b_re_r[62:0]}; end
                        5'd1:  begin add_in_valid = 1'b1; add_x = a_im_r; add_y = {~b_im_r[63], b_im_r[62:0]}; end
                        5'd2:  begin add_in_valid = 1'b1; add_x = a_re_r; add_y = b_re_r; end
                        5'd3:  begin add_in_valid = 1'b1; add_x = a_im_r; add_y = b_im_r; end
                        // out1 = d * s (day thang d_re/d_im tu add_z sang fpr_mul)
                        5'd4:  begin mul_in_valid = 1'b1; mul_x = add_z;  mul_y = s_re_r; end
                        5'd5:  begin mul_in_valid = 1'b1; mul_x = add_z;  mul_y = s_im_r; end
                        5'd6:  begin mul_in_valid = 1'b1; mul_x = t0;     mul_y = s_im_r; end
                        5'd7:  begin mul_in_valid = 1'b1; mul_x = t1;     mul_y = s_re_r; end
                        5'd9:  begin add_in_valid = 1'b1; add_x = t0;     add_y = {~mul_z[63], mul_z[62:0]}; end
                        5'd11: begin add_in_valid = 1'b1; add_x = t0;     add_y = mul_z; end
                        default: ;
                    endcase
                end
                default: ;
            endcase
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy     <= 1'b0;
            done     <= 1'b0;
            op_reg   <= 3'd0;
            half_reg <= 1'b0;
            step     <= 5'd0;
            a_re_r   <= 64'd0; a_im_r <= 64'd0;
            b_re_r   <= 64'd0; b_im_r <= 64'd0;
            s_re_r   <= 64'd0; s_im_r <= 64'd0;
            t0       <= 64'd0; t1     <= 64'd0;
            out0_re  <= 64'd0; out0_im <= 64'd0;
            out1_re  <= 64'd0; out1_im <= 64'd0;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                if (start) begin
                    busy     <= 1'b1;
                    op_reg   <= op;
                    half_reg <= do_half;
                    step     <= 5'd0;
                    a_re_r   <= a_re; a_im_r <= a_im;
                    b_re_r   <= b_re; b_im_r <= b_im;
                    s_re_r   <= s_re; s_im_r <= s_im;
                end
            end else begin
                step <= step + 5'd1;
                case (op_reg)
                    OP_ADD, OP_SUB: begin
                        if (step == 5'd4) out0_re <= add_z;
                        if (step == 5'd5) begin
                            out0_im <= add_z;
                            done    <= 1'b1;
                            busy    <= 1'b0;
                        end
                    end
                    OP_SCALE: begin
                        if (step == 5'd4) out0_re <= mul_z;
                        if (step == 5'd5) begin
                            out0_im <= mul_z;
                            done    <= 1'b1;
                            busy    <= 1'b0;
                        end
                    end
                    OP_MUL: begin
                        if (step == 5'd4) t0      <= mul_z;
                        if (step == 5'd6) t0      <= mul_z;
                        if (step == 5'd9) out0_re <= add_z;
                        if (step == 5'd11) begin
                            out0_im <= add_z;
                            done    <= 1'b1;
                            busy    <= 1'b0;
                        end
                    end
                    OP_FFT_BF: begin
                        if (step == 5'd4)  t0      <= mul_z;
                        if (step == 5'd6)  t0      <= mul_z;
                        if (step == 5'd9)  t0      <= add_z;
                        if (step == 5'd11) t0      <= add_z;
                        if (step == 5'd13) out0_re <= add_z;
                        if (step == 5'd14) out1_re <= add_z;
                        if (step == 5'd15) out0_im <= add_z;
                        if (step == 5'd16) begin
                            out1_im <= add_z;
                            done    <= 1'b1;
                            busy    <= 1'b0;
                        end
                    end
                    OP_IFFT_BF: begin
                        if (step == 5'd4)  t0      <= add_z;
                        if (step == 5'd5)  t1      <= add_z;
                        if (step == 5'd6)  out0_re <= half_reg ? half_add_z : add_z;
                        if (step == 5'd7)  out0_im <= half_reg ? half_add_z : add_z;
                        if (step == 5'd8)  t0      <= mul_z;
                        if (step == 5'd10) t0      <= mul_z;
                        if (step == 5'd13) out1_re <= half_reg ? half_add_z : add_z;
                        if (step == 5'd15) begin
                            out1_im <= half_reg ? half_add_z : add_z;
                            done    <= 1'b1;
                            busy    <= 1'b0;
                        end
                    end
                    default: busy <= 1'b0;
                endcase
            end
        end
    end
endmodule