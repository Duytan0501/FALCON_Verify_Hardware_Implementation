module poly_convert_s2 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output wire [8:0]  ram_s2_addr,
    input  wire [15:0] ram_s2_rdata,
    output wire [8:0]  ram_tt_addr,
    output wire [15:0] ram_tt_wdata,
    output wire        ram_tt_we,
    output reg         done
);
    localparam IDLE    = 2'd0;
    localparam PROCESS = 2'd1;
    localparam DONE   = 2'd2;
    reg [1:0]  state;
    reg [9:0]  rd_cnt;
    reg        rd_en;
    reg [8:0]  addr_q1;
    reg        valid_q1;
    wire [15:0] conv_out;
    mq_conv_small u_mq_conv (
        .x_in(ram_s2_rdata),
        .z_out(conv_out)
    );
    assign ram_s2_addr  = rd_cnt[8:0];
    assign ram_tt_addr  = addr_q1;
    assign ram_tt_wdata = conv_out;
    assign ram_tt_we    = valid_q1;
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
            done <= 1'b0; // Default
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
                        state <= DONE;
                        rd_en <= 1'b0;
                    end else begin
                        rd_cnt <= rd_cnt + 1'b1;
                    end
                end
                DONE: begin
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