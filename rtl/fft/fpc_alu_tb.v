`timescale 1ns / 1ps

module tb_fpc_alu();

    reg         clk;
    reg         rst_n;
    reg         start;
    reg  [2:0]  op;
    reg         do_half;
    reg  [63:0] a_re, a_im, b_re, b_im, s_re, s_im;

    wire [63:0] out0_re, out0_im, out1_re, out1_im;
    wire        busy, done;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    fpc_alu dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .op      (op),
        .do_half (do_half),
        .a_re    (a_re),
        .a_im    (a_im),
        .b_re    (b_re),
        .b_im    (b_im),
        .s_re    (s_re),
        .s_im    (s_im),
        .out0_re (out0_re),
        .out0_im (out0_im),
        .out1_re (out1_re),
        .out1_im (out1_im),
        .busy    (busy),
        .done    (done)
    );

    integer    fd, ph, k, r, cyc_cnt, exp_cyc;
    integer    op_in, hf_in, val_err, cyc_err, pass_cnt;
    reg [63:0] t_ar, t_ai, t_br, t_bi, t_sr, t_si;
    reg [63:0] e0r, e0i, e1r, e1i;
    reg [63:0] samp0r, samp0i;
    reg        chk_out1, ok_val, ok_cyc;

    initial begin
        rst_n    = 1'b0;
        start    = 1'b0;
        op       = 3'd0;
        do_half  = 1'b0;
        a_re = 64'd0; a_im = 64'd0;
        b_re = 64'd0; b_im = 64'd0;
        s_re = 64'd0; s_im = 64'd0;
        pass_cnt = 0;

        fd = $fopen("test_fpc_alu.txt", "r");
        if (fd == 0) begin
            $display("[FATAL] Khong mo duoc test_fpc_alu.txt!");
            $finish;
        end

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        $display("");

        for (ph = 0; ph < 7; ph = ph + 1) begin
            val_err = 0;
            cyc_err = 0;

            case (ph)
                0: begin exp_cyc = 6;  chk_out1 = 1'b0; end // OP_ADD
                1: begin exp_cyc = 6;  chk_out1 = 1'b0; end // OP_SUB
                2: begin exp_cyc = 12; chk_out1 = 1'b0; end // OP_MUL
                3: begin exp_cyc = 6;  chk_out1 = 1'b0; end // OP_SCALE
                4: begin exp_cyc = 17; chk_out1 = 1'b1; end // OP_FFT_BF
                5: begin exp_cyc = 16; chk_out1 = 1'b1; end // OP_IFFT_BF (iFFT)
                6: begin exp_cyc = 16; chk_out1 = 1'b1; end // OP_IFFT_BF (split)
            endcase

            for (k = 0; k < 500; k = k + 1) begin
                r = $fscanf(fd, "%d %d %h %h %h %h %h %h %h %h %h %h\n",
                            op_in, hf_in, t_ar, t_ai, t_br, t_bi, t_sr, t_si,
                            e0r, e0i, e1r, e1i);

                @(negedge clk);
                op      = op_in[2:0];
                do_half = hf_in[0];
                a_re    = t_ar; a_im = t_ai;
                b_re    = t_br; b_im = t_bi;
                s_re    = t_sr; s_im = t_si;
                start   = 1'b1;
                cyc_cnt = 0;
                @(negedge clk);
                start   = 1'b0;

                while (done !== 1'b1 && cyc_cnt < 100) begin
                    @(posedge clk); #1;
                    cyc_cnt = cyc_cnt + 1;
                end

                ok_val = (done === 1'b1) &&
                         (^out0_re !== 1'bx) && (^out0_im !== 1'bx) &&
                         (out0_re === e0r)   && (out0_im === e0i);
                if (chk_out1) begin
                    ok_val = ok_val &&
                             (^out1_re !== 1'bx) && (^out1_im !== 1'bx) &&
                             (out1_re === e1r)   && (out1_im === e1i);
                end
                ok_cyc = (cyc_cnt == exp_cyc);

                if (k == 5) begin samp0r = out0_re; samp0i = out0_im; end

                if ((!ok_val || !ok_cyc) && (val_err + cyc_err) < 5)
                    $display("  [ERR] ph=%0d k=%0d cyc=%0d/%0d | o0=(%016h,%016h) exp=(%016h,%016h)",
                             ph, k, cyc_cnt, exp_cyc, out0_re, out0_im, e0r, e0i);

                if (!ok_val) val_err = val_err + 1;
                if (!ok_cyc) cyc_err = cyc_err + 1;
            end

            if (val_err == 0 && cyc_err == 0) pass_cnt = pass_cnt + 1;

            case (ph)
                0: $display("[1/7] OP_ADD      ( 6 cyc) : %s (500 cases, err=%0d, cyc_err=%0d) | samp=%016h", (val_err==0 && cyc_err==0) ? "PASS" : "FAIL", val_err, cyc_err, samp0r);
                1: $display("[2/7] OP_SUB      ( 6 cyc) : %s (500 cases, err=%0d, cyc_err=%0d) | samp=%016h", (val_err==0 && cyc_err==0) ? "PASS" : "FAIL", val_err, cyc_err, samp0r);
                2: $display("[3/7] OP_MUL      (12 cyc) : %s (500 cases, err=%0d, cyc_err=%0d) | samp=%016h", (val_err==0 && cyc_err==0) ? "PASS" : "FAIL", val_err, cyc_err, samp0r);
                3: $display("[4/7] OP_SCALE    ( 6 cyc) : %s (500 cases, err=%0d, cyc_err=%0d) | samp=%016h", (val_err==0 && cyc_err==0) ? "PASS" : "FAIL", val_err, cyc_err, samp0r);
                4: $display("[5/7] OP_FFT_BF   (17 cyc) : %s (500 cases, err=%0d, cyc_err=%0d) | samp=%016h", (val_err==0 && cyc_err==0) ? "PASS" : "FAIL", val_err, cyc_err, samp0r);
                5: $display("[6/7] OP_IFFT_BF  (16 cyc) : %s (500 cases, err=%0d, cyc_err=%0d) | samp=%016h", (val_err==0 && cyc_err==0) ? "PASS" : "FAIL", val_err, cyc_err, samp0r);
                6: $display("[7/7] OP_SPLIT_BF (16 cyc) : %s (500 cases, err=%0d, cyc_err=%0d) | samp=%016h", (val_err==0 && cyc_err==0) ? "PASS" : "FAIL", val_err, cyc_err, samp0r);
            endcase
        end

        $fclose(fd);

        if (pass_cnt == 7)
            $display("\nRESULT: PASS 7/7 (3500 vectors)\n");
        else
            $display("\nRESULT: FAIL (%0d/7 passed)\n", pass_cnt);

        $finish;
    end

endmodule