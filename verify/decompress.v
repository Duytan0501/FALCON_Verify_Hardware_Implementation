`timescale 1ns / 1ps

module decompress #(
    parameter N         = 512,
    parameter STR_BYTES = 625   // FALCON-512: 666 - 1 (header) - 40 (salt) = 625 bytes (5000 bits)
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg  [9:0]  ram_sig_addr,
    input  wire [7:0]  ram_sig_rdata,
    output reg  [8:0]  ram_s2_addr,
    output reg  [15:0] ram_s2_wdata,
    output reg         ram_s2_we,
    output reg         valid_fmt,   
    output reg         done         
);
    localparam S_IDLE           = 4'd0;
    localparam S_FETCH_WAIT     = 4'd1;  
    localparam S_FETCH_LATCH    = 4'd2;  
    localparam S_GET_SIGN_LOW   = 4'd3; 
    localparam S_UNARY          = 4'd4;  
    localparam S_WRITE_COEFF    = 4'd5;  
    localparam S_CHECK_BUF_TAIL = 4'd6;  
    localparam S_TAIL_WAIT      = 4'd7;  
    localparam S_TAIL_CHECK     = 4'd8;  
    localparam S_ACCEPT         = 4'd9; 
    localparam S_REJECT         = 4'd10; 
    reg [3:0]  state;
    reg [3:0]  ret_state;      
    reg [15:0] bit_buf;        
    reg [4:0]  bit_cnt;       
    reg [9:0]  byte_idx;       
    reg [8:0]  coeff_idx;      
    reg        sign_reg;       
    reg [6:0]  low_reg;        
    reg [3:0]  k_cnt;         
    wire [15:0] mag_val    = {5'd0, k_cnt, low_reg};           
    wire [15:0] signed_val = sign_reg ? (~mag_val + 16'd1) : mag_val;
    wire        is_neg_zero = sign_reg && (k_cnt == 4'd0) && (low_reg == 7'd0);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            ret_state    <= S_IDLE;
            ram_sig_addr <= 10'd0;
            ram_s2_addr  <= 9'd0;
            ram_s2_wdata <= 16'd0;
            ram_s2_we    <= 1'b0;
            valid_fmt    <= 1'b0;
            done         <= 1'b0;
            bit_buf      <= 16'd0;
            bit_cnt      <= 5'd0;
            byte_idx     <= 10'd0;
            coeff_idx    <= 9'd0;
            sign_reg     <= 1'b0;
            low_reg      <= 7'd0;
            k_cnt        <= 4'd0;
        end else begin
            ram_s2_we <= 1'b0;
            done      <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (start) begin
                        bit_buf   <= 16'd0;
                        bit_cnt   <= 5'd0;
                        byte_idx  <= 10'd0;
                        coeff_idx <= 9'd0;
                        valid_fmt <= 1'b0;
                        state     <= S_GET_SIGN_LOW;
                    end
                end

                // -------------------------------------------------------------
                // Thủ tục nạp thêm 1 byte từ RAM đồng bộ vào bit_buf
                // (Chỉ được gọi khi bit_cnt <= 7 nên bit_cnt[2:0] luôn chính xác)
                S_FETCH_WAIT: begin
                    state <= S_FETCH_LATCH;
                end

                S_FETCH_LATCH: begin
                    bit_buf <= bit_buf | ({ram_sig_rdata, 8'd0} >> bit_cnt[2:0]);
                    bit_cnt <= bit_cnt + 5'd8;
                    state   <= ret_state;
                end

                // -------------------------------------------------------------
                // Bước 1 & 2: Rút 8 bit (1 bit sign + 7 bit low) trong 1 nhịp
                S_GET_SIGN_LOW: begin
                    if (bit_cnt < 5'd8) begin
                        if (byte_idx >= STR_BYTES) begin
                            state <= S_REJECT; // Hết bit trước khi đủ 512 hệ số
                        end else begin
                            ram_sig_addr <= byte_idx;
                            byte_idx     <= byte_idx + 10'd1;
                            ret_state    <= S_GET_SIGN_LOW;
                            state        <= S_FETCH_WAIT;
                        end
                    end else begin
                        sign_reg <= bit_buf[15];
                        low_reg  <= bit_buf[14:8];
                        bit_buf  <= bit_buf << 8;
                        bit_cnt  <= bit_cnt - 5'd8;
                        k_cnt    <= 4'd0;
                        state    <= S_UNARY;
                    end
                end

                // -------------------------------------------------------------
                // Bước 3: Đọc mã Unary (đếm bit 0 cho đến khi gặp bit 1)
                S_UNARY: begin
                    if (bit_cnt == 5'd0) begin
                        if (byte_idx >= STR_BYTES) begin
                            state <= S_REJECT; // Hết bit giữa chừng
                        end else begin
                            ram_sig_addr <= byte_idx;
                            byte_idx     <= byte_idx + 10'd1;
                            ret_state    <= S_UNARY;
                            state        <= S_FETCH_WAIT;
                        end
                    end else begin
                        bit_buf <= bit_buf << 1;
                        bit_cnt <= bit_cnt - 5'd1;

                        if (bit_buf[15] == 1'b1) begin
                            state <= S_WRITE_COEFF;
                        end else begin
                            if (k_cnt == 4'd15) begin
                                state <= S_REJECT; // k >= 16 => |s_i| >= 2048 (tràn biên độ)
                            end else begin
                                k_cnt <= k_cnt + 4'd1;
                            end
                        end
                    end
                end

                // -------------------------------------------------------------
                // Bước 4: Kiểm tra lỗi -0 và ghi hệ số s2[i] ra RAM
                S_WRITE_COEFF: begin
                    if (is_neg_zero) begin
                        state <= S_REJECT; // Cấm mã hóa -0 (100000001)
                    end else begin
                        ram_s2_addr  <= coeff_idx;
                        ram_s2_wdata <= signed_val;
                        ram_s2_we    <= 1'b1;

                        if (coeff_idx == (N - 1)) begin
                            state <= S_CHECK_BUF_TAIL;
                        end else begin
                            coeff_idx <= coeff_idx + 9'd1;
                            state     <= S_GET_SIGN_LOW;
                        end
                    end
                end

                // -------------------------------------------------------------
                // Bước 5: Kiểm tra toàn bộ bit đệm còn lại phải bằng 0
                S_CHECK_BUF_TAIL: begin
                    if (bit_buf != 16'd0) begin
                        state <= S_REJECT; // Có bit 1 lọt trong phần dư của bit_buf
                    end else if (byte_idx >= STR_BYTES) begin
                        state <= S_ACCEPT; // Đã kiểm hết 625 byte
                    end else begin
                        ram_sig_addr <= byte_idx;
                        byte_idx     <= byte_idx + 10'd1;
                        state        <= S_TAIL_WAIT;
                    end
                end

                S_TAIL_WAIT: begin
                    state <= S_TAIL_CHECK;
                end

                S_TAIL_CHECK: begin
                    if (ram_sig_rdata != 8'd0) begin
                        state <= S_REJECT; // Có byte đệm cuối khác 0
                    end else if (byte_idx >= STR_BYTES) begin
                        state <= S_ACCEPT;
                    end else begin
                        ram_sig_addr <= byte_idx;
                        byte_idx     <= byte_idx + 10'd1;
                        state        <= S_TAIL_WAIT;
                    end
                end

                // -------------------------------------------------------------
                S_ACCEPT: begin
                    valid_fmt <= 1'b1;
                    done      <= 1'b1;
                    state     <= S_IDLE;
                end

                S_REJECT: begin
                    valid_fmt <= 1'b0;
                    done      <= 1'b1;
                    state     <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule