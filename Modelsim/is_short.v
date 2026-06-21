module is_short_engine (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    
    output wire [8:0]  ram_s1_addr,
    input  wire [15:0] ram_s1_rdata,
    
    output wire [8:0]  ram_s2_addr,
    input  wire [15:0] ram_s2_rdata,
    
    output reg  [31:0] norm_out, // 32-bit để khớp 100% với uint32_t s
    output reg         valid_sig,
    output reg         done
);

    localparam SIG_BOUND = 32'd34034726; 

    localparam IDLE    = 2'd0;
    localparam PROCESS = 2'd1;
    localparam DRAIN   = 2'd2;

    reg [1:0]  state;
    reg [9:0]  rd_cnt;
    reg        rd_en;
    reg        valid_q1;
    reg        ng_flag;

    assign ram_s1_addr = rd_cnt[8:0];
    assign ram_s2_addr = rd_cnt[8:0];

    // Ép kiểu lên 32-bit có dấu trước khi nhân (tương đương int32_t z trong C)
    wire signed [31:0] s1_32 = $signed(ram_s1_rdata);
    wire signed [31:0] s2_32 = $signed(ram_s2_rdata);
    
    wire [31:0] current_sum = norm_out + (s1_32 * s1_32) + (s2_32 * s2_32);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_q1 <= 1'b0;
        else valid_q1 <= rd_en;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            rd_cnt    <= 10'd0;
            rd_en     <= 1'b0;
            norm_out  <= 32'd0;
            ng_flag   <= 1'b0;
            valid_sig <= 1'b0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;
            
            // Tích lũy (Chỉ trễ 1 nhịp để ăn khớp với RAM)
            if (valid_q1) begin
                norm_out <= current_sum;
                ng_flag  <= ng_flag | current_sum[31]; // ng |= s;
            end

            case (state)
                IDLE: begin
                    rd_cnt <= 10'd0;
                    if (start) begin
                        state    <= PROCESS;
                        rd_en    <= 1'b1;
                        norm_out <= 32'd0; 
                        ng_flag  <= 1'b0;
                    end else begin
                        rd_en    <= 1'b0;
                    end
                end

                PROCESS: begin
                    if (rd_cnt == 10'd511) begin
                        state <= DRAIN;
                        rd_en <= 1'b0;
                    end else begin
                        rd_cnt <= rd_cnt + 1'b1;
                    end
                end

                DRAIN: begin
                    if (!valid_q1) begin
                        // Logic bão hòa của C: s |= -(ng >> 31);
                        if (ng_flag) norm_out <= 32'hFFFFFFFF;
                        
                        valid_sig <= ((ng_flag ? 32'hFFFFFFFF : norm_out) <= SIG_BOUND) ? 1'b1 : 1'b0;
                        done      <= 1'b1;
                        state     <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule