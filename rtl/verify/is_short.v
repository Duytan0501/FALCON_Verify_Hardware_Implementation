module is_short_engine (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    
    output wire [8:0]  ram_s1_addr,
    input  wire [15:0] ram_s1_rdata,
    
    output wire [8:0]  ram_s2_addr,
    input  wire [15:0] ram_s2_rdata,
    
    output reg  [31:0] norm_out, 
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

    wire signed [15:0] s1_s  = ram_s1_rdata;
    wire signed [15:0] s2_s  = ram_s2_rdata;
    wire signed [31:0] s1_sq = s1_s * s1_s;
    wire signed [31:0] s2_sq = s2_s * s2_s;

    wire [31:0] sum_after_s1 = norm_out + s1_sq;
    wire [31:0] sum_after_s2 = sum_after_s1 + s2_sq;

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
        if (valid_q1) begin
                norm_out <= sum_after_s2;
                ng_flag  <= ng_flag | sum_after_s1[31] | sum_after_s2[31];
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