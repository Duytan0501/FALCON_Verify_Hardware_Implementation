`timescale 1ns / 1ps

module gaussian0_sampler (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,

    input  wire [7:0] rng_data,
    input  wire       rng_valid,
    output wire       rng_ready,

    output reg  [4:0] z0_out,
    output reg        done
);

    localparam S_IDLE = 2'd0;
    localparam S_LOAD = 2'd1;
    localparam S_CMP  = 2'd2;

    reg [1:0]  state;
    reg [3:0]  byte_cnt;
    reg [4:0]  idx;
    reg [71:0] v_reg;
    reg [4:0]  z_acc;

    assign rng_ready = (state == S_LOAD);

    // ROM 18 mốc 72-bit = {dist[3*k + 0], dist[3*k + 1], dist[3*k + 2]} từ sign.c
    reg [71:0] dist_rom;
    always @(*) begin
        case (idx)
            5'd0:    dist_rom = {24'd10745844, 24'd3068844,  24'd3741698};
            5'd1:    dist_rom = {24'd5559083,  24'd1580863,  24'd8248194};
            5'd2:    dist_rom = {24'd2260429,  24'd13669192, 24'd2736639};
            5'd3:    dist_rom = {24'd708981,   24'd4421575,  24'd10046180};
            5'd4:    dist_rom = {24'd169348,   24'd7122675,  24'd4136815};
            5'd5:    dist_rom = {24'd30538,    24'd13063405, 24'd7650655};
            5'd6:    dist_rom = {24'd4132,     24'd14505003, 24'd7826148};
            5'd7:    dist_rom = {24'd417,      24'd16768101, 24'd11363290};
            5'd8:    dist_rom = {24'd31,       24'd8444042,  24'd8086568};
            5'd9:    dist_rom = {24'd1,        24'd12844466, 24'd265321};
            5'd10:   dist_rom = {24'd0,        24'd1232676,  24'd13644283};
            5'd11:   dist_rom = {24'd0,        24'd38047,    24'd9111839};
            5'd12:   dist_rom = {24'd0,        24'd870,      24'd6138264};
            5'd13:   dist_rom = {24'd0,        24'd14,       24'd12545723};
            5'd14:   dist_rom = {24'd0,        24'd0,        24'd3104126};
            5'd15:   dist_rom = {24'd0,        24'd0,        24'd28824};
            5'd16:   dist_rom = {24'd0,        24'd0,        24'd198};
            5'd17:   dist_rom = {24'd0,        24'd0,        24'd1};
            default: dist_rom = 72'd0;
        endcase
    end

    wire       is_less = (v_reg < dist_rom);
    wire [4:0] z_next  = z_acc + {4'd0, is_less};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            byte_cnt <= 4'd0;
            idx      <= 5'd0;
            v_reg    <= 72'd0;
            z_acc    <= 5'd0;
            z0_out   <= 5'd0;
            done     <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        byte_cnt <= 4'd0;
                        idx      <= 5'd0;
                        v_reg    <= 72'd0;
                        z_acc    <= 5'd0;
                        state    <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    if (rng_valid) begin
                        v_reg <= {rng_data, v_reg[71:8]};
                        if (byte_cnt == 4'd8) begin
                            idx   <= 5'd0;
                            state <= S_CMP;
                        end else begin
                            byte_cnt <= byte_cnt + 4'd1;
                        end
                    end
                end

                S_CMP: begin
                    if (idx == 5'd17) begin
                        z0_out <= z_next;
                        done   <= 1'b1;
                        state  <= S_IDLE;
                    end else begin
                        z_acc <= z_next;
                        idx   <= idx + 5'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule