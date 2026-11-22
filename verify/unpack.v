`timescale 1ns / 1ps

module unpack #(
    parameter N         = 512,
    parameter PK_HEADER = 8'h09,
    parameter Q_VAL     = 14'd12289
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        abort,
    input  wire [7:0]  pk_data,
    input  wire        pk_valid,
    output wire        pk_ready,
    output reg  [8:0]  ram_h_addr,
    output reg  [15:0] ram_h_wdata,
    output reg         ram_h_we,
    output reg         valid_pk,
    output reg         done
);
    localparam S_IDLE         = 3'd0;
    localparam S_HDR_CHECK    = 3'd1;
    localparam S_READ_GRP     = 3'd2;
    localparam S_WRITE_COEFFS = 3'd3;
    localparam S_ACCEPT       = 3'd4;
    localparam S_REJECT       = 3'd5;
    reg [2:0]  state;
    reg [55:0] buf56;         
    reg [2:0]  byte_in_grp;   
    reg [1:0]  sub_idx;       
    reg [8:0]  coeff_idx;     
    wire [13:0] curr_h = buf56[55:42];
    assign pk_ready = !abort && ((state == S_HDR_CHECK) || (state == S_READ_GRP));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            ram_h_addr  <= 9'd0;
            ram_h_wdata <= 16'd0;
            ram_h_we    <= 1'b0;
            valid_pk    <= 1'b0;
            done        <= 1'b0;
            buf56       <= 56'd0;
            byte_in_grp <= 3'd0;
            sub_idx     <= 2'd0;
            coeff_idx   <= 9'd0;
        end else begin
            ram_h_we <= 1'b0;
            done     <= 1'b0;
            if (abort) begin
                state    <= S_IDLE;
                valid_pk <= 1'b0;
            end else begin
                case (state)
                    S_IDLE: begin
                        if (start) begin
                            coeff_idx   <= 9'd0;
                            valid_pk    <= 1'b0;
                            buf56       <= 56'd0;
                            byte_in_grp <= 3'd0;
                            sub_idx     <= 2'd0;
                            state       <= S_HDR_CHECK;
                        end
                    end

                    S_HDR_CHECK: begin
                        if (pk_valid) begin
                            if (pk_data != PK_HEADER) begin
                                state <= S_REJECT;
                            end else begin
                                byte_in_grp <= 3'd0;
                                state       <= S_READ_GRP;
                            end
                        end
                    end
                    S_READ_GRP: begin
                        if (pk_valid) begin
                            buf56 <= {buf56[47:0], pk_data};
                            if (byte_in_grp == 3'd6) begin
                                sub_idx <= 2'd0;
                                state   <= S_WRITE_COEFFS;
                            end else begin
                                byte_in_grp <= byte_in_grp + 3'd1;
                            end
                        end
                    end
                    S_WRITE_COEFFS: begin
                        if (curr_h >= Q_VAL) begin
                            state <= S_REJECT;
                        end else begin
                            ram_h_addr  <= coeff_idx;
                            ram_h_wdata <= {2'b00, curr_h};
                            ram_h_we    <= 1'b1;
                            buf56       <= buf56 << 14;
                        if (sub_idx == 2'd3) begin
                            if (coeff_idx == (N - 1)) begin
                                state <= S_ACCEPT;
                            end else begin
                                coeff_idx   <= coeff_idx + 9'd1;
                                byte_in_grp <= 3'd0;
                                state       <= S_READ_GRP;
                            end
                        end else begin
                                coeff_idx <= coeff_idx + 9'd1;
                                sub_idx   <= sub_idx + 2'd1;
                            end
                        end
                    end
                    S_ACCEPT: begin
                        valid_pk <= 1'b1;
                        done     <= 1'b1;
                        state    <= S_IDLE;
                    end
                    S_REJECT: begin
                        valid_pk <= 1'b0;
                        done     <= 1'b1;
                        state    <= S_IDLE;
                    end
                    default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule