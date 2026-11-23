`timescale 1ns / 1ps

module verify (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,
    output reg         valid_sig_out,
    output reg  [31:0] norm_out_sig,
    output wire [8:0]  ram_s2_addr,
    input  wire [15:0] ram_s2_rdata,
    output wire [8:0]  ram_h_addr,
    input  wire [15:0] ram_h_rdata,
    output wire [8:0]  ram_c0_addr,
    input  wire [15:0] ram_c0_rdata,
    output wire [8:0]  ram_tt_addr_a,
    output wire [8:0]  ram_tt_addr_b,
    input  wire [15:0] ram_tt_rdata_a,
    input  wire [15:0] ram_tt_rdata_b,
    output wire [15:0] ram_tt_wdata_a,
    output wire [15:0] ram_tt_wdata_b,
    output wire        ram_tt_we_a,
    output wire        ram_tt_we_b,
    output wire [8:0]  ram_s1_addr,
    input  wire [15:0] ram_s1_rdata,
    output wire [15:0] ram_s1_wdata,
    output wire        ram_s1_we
);
    localparam IDLE          = 3'd0,
               STATE_CONV    = 3'd1,
               STATE_NTT     = 3'd2,
               STATE_SUBNORM = 3'd3,
               STATE_ISSHORT = 3'd4,
               STATE_DONE    = 3'd5;
    reg [2:0] state;
    reg conv_start;
    reg ntt_start;
    reg sn_start;
    reg norm_start;
    wire [8:0]  conv_s2_addr;
    wire [15:0] conv_tt_wdata;
    wire [8:0]  conv_tt_addr;
    wire        conv_tt_we;
    wire        conv_done;
    wire [8:0]  ntt_addr_a;
    wire [8:0]  ntt_addr_b;
    wire [15:0] ntt_wdata_a;
    wire [15:0] ntt_wdata_b;
    wire        ntt_we_a;
    wire        ntt_we_b;
    wire [8:0]  ntt_h_addr;
    wire        ntt_done;
    wire [8:0]  sn_tt_addr;
    wire [8:0]  sn_c0_addr;
    wire [8:0]  sn_s1_addr;
    wire [15:0] sn_s1_wdata;
    wire        sn_s1_we;
    wire        sn_done;
    wire [8:0]  norm_s1_addr;
    wire [8:0]  norm_s2_addr;
    wire [31:0] hw_norm_out;
    wire        hw_valid_sig;
    wire        norm_done;
    wire is_conv_running = (state == STATE_CONV);
    wire is_ntt_running  = (state == STATE_NTT);
    wire is_sn_running   = (state == STATE_SUBNORM);
    wire is_norm_running = (state == STATE_ISSHORT);
    assign ram_s2_addr = is_norm_running ? norm_s2_addr : conv_s2_addr;
    assign ram_h_addr  = ntt_h_addr;
    assign ram_c0_addr = sn_c0_addr;
    assign ram_tt_addr_a  = is_conv_running ? conv_tt_addr : 
                            (is_sn_running  ? sn_tt_addr   : ntt_addr_a);
    assign ram_tt_wdata_a = is_conv_running ? conv_tt_wdata : ntt_wdata_a;
    assign ram_tt_we_a    = is_conv_running ? conv_tt_we    : (is_ntt_running ? ntt_we_a : 1'b0);
    assign ram_tt_addr_b  = ntt_addr_b;
    assign ram_tt_wdata_b = ntt_wdata_b;
    assign ram_tt_we_b    = is_ntt_running ? ntt_we_b : 1'b0;
    assign ram_s1_addr  = is_norm_running ? norm_s1_addr : sn_s1_addr;
    assign ram_s1_wdata = sn_s1_wdata;
    assign ram_s1_we    = is_sn_running ? sn_s1_we : 1'b0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            conv_start    <= 1'b0;
            ntt_start     <= 1'b0;
            sn_start      <= 1'b0;
            norm_start    <= 1'b0;
            done          <= 1'b0;
            valid_sig_out <= 1'b0;
            norm_out_sig  <= 32'd0;
        end else begin
            conv_start    <= 1'b0;
            ntt_start     <= 1'b0;
            sn_start      <= 1'b0;
            norm_start    <= 1'b0;
            done          <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        state      <= STATE_CONV;
                        conv_start <= 1'b1;
                    end
                end
                STATE_CONV: begin
                    if (conv_done) begin
                        state     <= STATE_NTT;
                        ntt_start <= 1'b1;
                    end
                end
                STATE_NTT: begin
                    if (ntt_done) begin
                        state    <= STATE_SUBNORM;
                        sn_start <= 1'b1;
                    end
                end
                STATE_SUBNORM: begin
                    if (sn_done) begin
                        state      <= STATE_ISSHORT;
                        norm_start <= 1'b1;
                    end
                end
                STATE_ISSHORT: begin
                    if (norm_done) begin
                        state <= STATE_DONE;
                    end
                end
                STATE_DONE: begin
                    done          <= 1'b1;
                    valid_sig_out <= hw_valid_sig;
                    norm_out_sig  <= hw_norm_out;
                    state         <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
    poly_convert_s2 u_poly_convert_s2 (
        .clk(clk),
        .rst_n(rst_n),
        .start(conv_start),
        .ram_s2_addr(conv_s2_addr),
        .ram_s2_rdata(ram_s2_rdata),
        .ram_tt_addr(conv_tt_addr),
        .ram_tt_wdata(conv_tt_wdata),
        .ram_tt_we(conv_tt_we),
        .done(conv_done)
    );
    ntt_engine u_ntt_engine (
        .clk(clk),
        .rst_n(rst_n),
        .start(ntt_start),
        .ram_addr_a(ntt_addr_a),
        .ram_addr_b(ntt_addr_b),
        .ram_rdata_a(ram_tt_rdata_a),
        .ram_rdata_b(ram_tt_rdata_b),
        .ram_wdata_a(ntt_wdata_a),
        .ram_wdata_b(ntt_wdata_b),
        .ram_we_a(ntt_we_a),
        .ram_we_b(ntt_we_b),
        .ram_h_addr(ntt_h_addr),
        .ram_h_rdata(ram_h_rdata),
        .done(ntt_done)
    );
    poly_sub_norm u_poly_sub_norm (
        .clk(clk),
        .rst_n(rst_n),
        .start(sn_start),
        .ram_tt_addr(sn_tt_addr),
        .ram_tt_rdata(ram_tt_rdata_a),
        .ram_c0_addr(sn_c0_addr),
        .ram_c0_rdata(ram_c0_rdata),
        .ram_s1_addr(sn_s1_addr),
        .ram_s1_wdata(sn_s1_wdata),
        .ram_s1_we(sn_s1_we),
        .done(sn_done)
    );
    is_short_engine u_is_short_engine (
        .clk(clk),
        .rst_n(rst_n),
        .start(norm_start),
        .ram_s1_addr(norm_s1_addr),
        .ram_s1_rdata(ram_s1_rdata),
        .ram_s2_addr(norm_s2_addr),
        .ram_s2_rdata(ram_s2_rdata),
        .norm_out(hw_norm_out),
        .valid_sig(hw_valid_sig),
        .done(norm_done)
    );
endmodule