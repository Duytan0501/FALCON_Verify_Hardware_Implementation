module poly_sub_norm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output wire [8:0]  ram_tt_addr,
    input  wire [15:0] ram_tt_rdata,
    output wire [8:0]  ram_c0_addr,
    input  wire [15:0] ram_c0_rdata,
    output wire [8:0]  ram_s1_addr,
    output wire [15:0] ram_s1_wdata,
    output wire        ram_s1_we,
    output reg         done
);
    localparam IDLE    = 2'd0;
    localparam PROCESS = 2'd1;
    localparam DRAIN   = 2'd2;
    reg [1:0]  state;
    reg [9:0]  rd_cnt;
    reg        rd_en;
    reg [8:0]  addr_q1;
    reg        valid_q1;
    wire [15:0] sub_out;
    wire [15:0] norm_out;
    mq_sub u_mq_sub (
        .x(ram_tt_rdata),
        .y(ram_c0_rdata),
        .z(sub_out)
    );
    mq_normalize u_mq_norm (
        .x_in(sub_out),
        .z_out(norm_out)
    );
    assign ram_tt_addr  = rd_cnt[8:0];
    assign ram_c0_addr  = rd_cnt[8:0];
    assign ram_s1_addr  = addr_q1;
    assign ram_s1_wdata = norm_out;
    assign ram_s1_we    = valid_q1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_q1  <= 9'd0;
            valid_q1 <= 1'b0;
        end else begin
            addr_q1  <= rd_cnt[8:0];
            valid_q1 <= rd_en;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state  <= IDLE;
            rd_cnt <= 10'd0;
            rd_en  <= 1'b0;
            done   <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    rd_cnt <= 10'd0;
                    if (start) begin
                        state <= PROCESS;
                        rd_en <= 1'b1;
                    end else begin
                        rd_en <= 1'b0;
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
                        done  <= 1'b1;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule