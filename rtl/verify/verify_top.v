`timescale 1ns / 1ps
module verify_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        load_pk,
    input  wire [7:0]  pk_data,
    input  wire        pk_valid,
    output wire        pk_ready,
    input  wire [7:0]  sig_data,
    input  wire        sig_valid,
    output wire        sig_ready,
    input  wire [15:0] c0_data,
    input  wire        c0_valid,
    output wire        c0_ready,
    output reg         done,
    output reg         valid_sig_out,
    output reg  [31:0] norm_out_sig,
    output reg  [2:0]  err_code
);
    localparam ERR_NONE        = 3'd0;
    localparam ERR_BAD_PK      = 3'd1;
    localparam ERR_BAD_SIG_FMT = 3'd2;
    localparam ERR_BAD_NORM    = 3'd3;
    localparam S_IDLE          = 3'd0;
    localparam S_LOAD_AND_HNTT = 3'd1;
    localparam S_CONV          = 3'd2;
    localparam S_NTT           = 3'd3;
    localparam S_SUBNORM       = 3'd4;
    localparam S_ISSHORT       = 3'd5;
    localparam S_DONE          = 3'd6;
    localparam S_REJECT        = 3'd7;
    localparam PK_IDLE         = 2'd0;
    localparam PK_UNPACK       = 2'd1;
    localparam PK_HNTT         = 2'd2;
    localparam PK_DONE         = 2'd3;
    reg [2:0] state;
    reg [1:0] pk_sub;
    reg       s2_done;
    reg       c0_done;
    reg       c0_loading;
    reg [8:0] c0_cnt;
    reg unpack_start, decomp_start, conv_start, ntt_start, sn_start, norm_start;
    wire [8:0]  unpack_h_addr;
    wire [15:0] unpack_h_wdata;
    wire        unpack_h_we, unpack_valid, unpack_done;
    wire [8:0]  decomp_s2_addr;
    wire [15:0] decomp_s2_wdata;
    wire        decomp_s2_we, decomp_valid, decomp_done;
    wire [8:0]  conv_s2_addr, conv_tt_addr;
    wire [15:0] conv_tt_wdata;
    wire        conv_tt_we, conv_done;
    wire [8:0]  ntt_addr_a, ntt_addr_b, ntt_h_addr;
    wire [15:0] ntt_wdata_a, ntt_wdata_b, ntt_h_wdata;
    wire        ntt_we_a, ntt_we_b, ntt_h_we, ntt_done;
    wire [8:0]  sn_tt_addr, sn_c0_addr, sn_s1_addr;
    wire [15:0] sn_s1_wdata;
    wire        sn_s1_we, sn_done;
    wire [8:0]  norm_s1_addr, norm_s2_addr;
    wire [31:0] hw_norm_out;
    wire        hw_valid_sig, norm_done;
    wire        pk_err       = unpack_done && !unpack_valid;
    wire        sig_err      = decomp_done && !decomp_valid;
    wire        abort_all    = (state == S_LOAD_AND_HNTT) && (pk_err || sig_err);
    assign      c0_ready     = (state == S_LOAD_AND_HNTT) && c0_loading && !abort_all;
    wire        c0_fire      = c0_valid && c0_ready;

    wire        h_done_next  = (pk_sub == PK_DONE) || ((pk_sub == PK_HNTT) && ntt_done);
    wire        s2_done_next = s2_done || (decomp_done && decomp_valid);
    wire        c0_done_next = c0_done || (c0_fire && (c0_cnt == 9'd511));
    reg  [8:0]  tt_addr_a,  tt_addr_b;
    reg  [15:0] tt_wdata_a, tt_wdata_b;
    reg         tt_we_a,    tt_we_b;
    wire [15:0] tt_rdata_a, tt_rdata_b;
    wire [15:0] h_rdata;
    wire [8:0]  s2_addr  = (state == S_LOAD_AND_HNTT) ? decomp_s2_addr :
                           (state == S_ISSHORT)       ? norm_s2_addr   :
                                                        conv_s2_addr;
    wire [15:0] s2_wdata = decomp_s2_wdata;
    wire        s2_we    = (state == S_LOAD_AND_HNTT) ? decomp_s2_we : 1'b0;
    wire [15:0] s2_rdata;
    wire [8:0]  c0_addr  = (state == S_LOAD_AND_HNTT) ? c0_cnt : sn_c0_addr;
    wire [15:0] c0_wdata = c0_data;
    wire        c0_we    = c0_fire;
    wire [15:0] c0_rdata;
    always @(*) begin
        tt_addr_a  = 9'd0;
        tt_wdata_a = 16'd0;
        tt_we_a    = 1'b0;
        tt_addr_b  = 9'd0;
        tt_wdata_b = 16'd0;
        tt_we_b    = 1'b0;
        case (state)
            S_LOAD_AND_HNTT: begin
                if (pk_sub == PK_UNPACK) begin
                    tt_addr_a  = unpack_h_addr;
                    tt_wdata_a = unpack_h_wdata;
                    tt_we_a    = unpack_h_we;
                end else if (pk_sub == PK_HNTT) begin
                    tt_addr_a  = ntt_addr_a;
                    tt_wdata_a = ntt_wdata_a;
                    tt_we_a    = ntt_we_a;
                    tt_addr_b  = ntt_addr_b;
                    tt_wdata_b = ntt_wdata_b;
                    tt_we_b    = ntt_we_b;
                end
            end
            S_CONV: begin
                tt_addr_a  = conv_tt_addr;
                tt_wdata_a = conv_tt_wdata;
                tt_we_a    = conv_tt_we;
            end
            S_NTT: begin
                tt_addr_a  = ntt_addr_a;
                tt_wdata_a = ntt_wdata_a;
                tt_we_a    = ntt_we_a;
                tt_addr_b  = ntt_addr_b;
                tt_wdata_b = ntt_wdata_b;
                tt_we_b    = ntt_we_b;
            end
            S_SUBNORM: begin
                tt_addr_a  = sn_tt_addr;
                tt_we_a    = 1'b0;
                tt_addr_b  = sn_s1_addr;
                tt_wdata_b = sn_s1_wdata;
                tt_we_b    = sn_s1_we;
            end
            S_ISSHORT: begin
                tt_addr_a  = norm_s1_addr;
                tt_we_a    = 1'b0;
            end
            default: ;
        endcase
    end
    dpram_512x16 u_ram_tt (
        .clk     (clk),
        .we_a    (tt_we_a),
        .addr_a  (tt_addr_a),
        .wdata_a (tt_wdata_a),
        .rdata_a (tt_rdata_a),
        .we_b    (tt_we_b),
        .addr_b  (tt_addr_b),
        .wdata_b (tt_wdata_b),
        .rdata_b (tt_rdata_b)
    );
    spram_512x16 u_ram_h (
        .clk   (clk),
        .we    (ntt_h_we),
        .addr  (ntt_h_addr),
        .wdata (ntt_h_wdata),
        .rdata (h_rdata)
    );
    spram_512x16 u_ram_s2 (
        .clk   (clk),
        .we    (s2_we),
        .addr  (s2_addr),
        .wdata (s2_wdata),
        .rdata (s2_rdata)
    );

    spram_512x16 u_ram_c0 (
        .clk   (clk),
        .we    (c0_we),
        .addr  (c0_addr),
        .wdata (c0_wdata),
        .rdata (c0_rdata)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            pk_sub        <= PK_IDLE;
            s2_done       <= 1'b0;
            c0_done       <= 1'b0;
            c0_loading    <= 1'b0;
            c0_cnt        <= 9'd0;
            unpack_start  <= 1'b0;
            decomp_start  <= 1'b0;
            conv_start    <= 1'b0;
            ntt_start     <= 1'b0;
            sn_start      <= 1'b0;
            norm_start    <= 1'b0;
            done          <= 1'b0;
            valid_sig_out <= 1'b0;
            norm_out_sig  <= 32'd0;
            err_code      <= ERR_NONE;
        end else begin
            unpack_start  <= 1'b0;
            decomp_start  <= 1'b0;
            conv_start    <= 1'b0;
            ntt_start     <= 1'b0;
            sn_start      <= 1'b0;
            norm_start    <= 1'b0;
            done          <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        valid_sig_out <= 1'b0;
                        norm_out_sig  <= 32'd0;
                        err_code      <= ERR_NONE;
                        s2_done       <= 1'b0;
                        c0_done       <= 1'b0;
                        c0_loading    <= 1'b1;
                        c0_cnt        <= 9'd0;
                        decomp_start  <= 1'b1;
                        if (load_pk) begin
                            unpack_start <= 1'b1;
                            pk_sub       <= PK_UNPACK;
                        end else begin
                            pk_sub       <= PK_DONE;
                        end
                        state <= S_LOAD_AND_HNTT;
                    end
                end

                S_LOAD_AND_HNTT: begin
                    if (pk_err || sig_err) begin
                        c0_loading <= 1'b0;
                        pk_sub     <= PK_IDLE;
                        err_code   <= pk_err ? ERR_BAD_PK : ERR_BAD_SIG_FMT;
                        state      <= S_REJECT;
                    end else begin
                        if (pk_sub == PK_UNPACK && unpack_done && unpack_valid) begin
                            pk_sub    <= PK_HNTT;
                            ntt_start <= 1'b1;
                        end else if (pk_sub == PK_HNTT && ntt_done) begin
                            pk_sub    <= PK_DONE;
                        end

                        if (decomp_done && decomp_valid) begin
                            s2_done <= 1'b1;
                        end

                        if (c0_fire) begin
                            if (c0_cnt == 9'd511) begin
                                c0_loading <= 1'b0;
                                c0_done    <= 1'b1;
                            end else begin
                                c0_cnt <= c0_cnt + 9'd1;
                            end
                        end

                        if (h_done_next && s2_done_next && c0_done_next) begin
                            conv_start <= 1'b1;
                            state      <= S_CONV;
                        end
                    end
                end

                S_CONV: begin
                    if (conv_done) begin
                        ntt_start <= 1'b1;
                        state     <= S_NTT;
                    end
                end

                S_NTT: begin
                    if (ntt_done) begin
                        sn_start <= 1'b1;
                        state    <= S_SUBNORM;
                    end
                end

                S_SUBNORM: begin
                    if (sn_done) begin
                        norm_start <= 1'b1;
                        state      <= S_ISSHORT;
                    end
                end

                S_ISSHORT: begin
                    if (norm_done) begin
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done          <= 1'b1;
                    valid_sig_out <= hw_valid_sig;
                    norm_out_sig  <= hw_norm_out;
                    err_code      <= hw_valid_sig ? ERR_NONE : ERR_BAD_NORM;
                    state         <= S_IDLE;
                end

                S_REJECT: begin
                    done          <= 1'b1;
                    valid_sig_out <= 1'b0;
                    norm_out_sig  <= 32'd0;
                    state         <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
    unpack u_unpack (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (unpack_start),
        .abort       (abort_all),
        .pk_data     (pk_data),
        .pk_valid    (pk_valid),
        .pk_ready    (pk_ready),
        .ram_h_addr  (unpack_h_addr),
        .ram_h_wdata (unpack_h_wdata),
        .ram_h_we    (unpack_h_we),
        .valid_pk    (unpack_valid),
        .done        (unpack_done)
    );

    decompress u_decompress (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (decomp_start),
        .abort        (abort_all),
        .sig_data     (sig_data),
        .sig_valid    (sig_valid),
        .sig_ready    (sig_ready),
        .ram_s2_addr  (decomp_s2_addr),
        .ram_s2_wdata (decomp_s2_wdata),
        .ram_s2_we    (decomp_s2_we),
        .valid_fmt    (decomp_valid),
        .done         (decomp_done)
    );

    poly_convert_s2 u_poly_convert_s2 (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (conv_start),
        .ram_s2_addr  (conv_s2_addr),
        .ram_s2_rdata (s2_rdata),
        .ram_tt_addr  (conv_tt_addr),
        .ram_tt_wdata (conv_tt_wdata),
        .ram_tt_we    (conv_tt_we),
        .done         (conv_done)
    );

    ntt_engine u_ntt_engine (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (ntt_start),
        .mode_tomonty (state == S_LOAD_AND_HNTT),
        .abort        (abort_all),
        .ram_addr_a   (ntt_addr_a),
        .ram_addr_b   (ntt_addr_b),
        .ram_rdata_a  (tt_rdata_a),
        .ram_rdata_b  (tt_rdata_b),
        .ram_wdata_a  (ntt_wdata_a),
        .ram_wdata_b  (ntt_wdata_b),
        .ram_we_a     (ntt_we_a),
        .ram_we_b     (ntt_we_b),
        .ram_h_addr   (ntt_h_addr),
        .ram_h_rdata  (h_rdata),
        .ram_h_wdata  (ntt_h_wdata),
        .ram_h_we     (ntt_h_we),
        .done         (ntt_done)
    );

    poly_sub_norm u_poly_sub_norm (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (sn_start),
        .ram_tt_addr  (sn_tt_addr),
        .ram_tt_rdata (tt_rdata_a),
        .ram_c0_addr  (sn_c0_addr),
        .ram_c0_rdata (c0_rdata),
        .ram_s1_addr  (sn_s1_addr),
        .ram_s1_wdata (sn_s1_wdata),
        .ram_s1_we    (sn_s1_we),
        .done         (sn_done)
    );

    is_short_engine u_is_short_engine (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (norm_start),
        .ram_s1_addr  (norm_s1_addr),
        .ram_s1_rdata (tt_rdata_a),
        .ram_s2_addr  (norm_s2_addr),
        .ram_s2_rdata (s2_rdata),
        .norm_out     (hw_norm_out),
        .valid_sig    (hw_valid_sig),
        .done         (norm_done)
    );

endmodule