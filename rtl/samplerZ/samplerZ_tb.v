`timescale 1ns / 1ps

module sampler_z_tb();

    reg clk;
    reg rst_n;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // 1. DUT 1: gaussian0_sampler
    // =========================================================================
    reg        g0_start;
    reg        g0_stream_en;
    reg  [7:0] g0_vec [0:8];
    reg  [3:0] g0_idx;
    wire       g0_rng_valid = g0_stream_en && (g0_idx < 4'd9);
    wire [7:0] g0_rng_data  = g0_rng_valid ? g0_vec[g0_idx] : 8'hAA;
    wire       g0_rng_ready;
    wire [4:0] g0_z0_out;
    wire       g0_done;

    gaussian0_sampler u_g0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (g0_start),
        .rng_data  (g0_rng_data),
        .rng_valid (g0_rng_valid),
        .rng_ready (g0_rng_ready),
        .z0_out    (g0_z0_out),
        .done      (g0_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        g0_idx <= 4'd0;
        else if (g0_start) g0_idx <= 4'd0;
        else if (g0_rng_valid && g0_rng_ready) g0_idx <= g0_idx + 4'd1;
    end

    // =========================================================================
    // 2. DUT 2: ber_exp (nối với fpr_mul + fpr_add thật)
    // =========================================================================
    reg         ber_start;
    reg  [63:0] ber_x_in, ber_ccs_in;
    reg         ber_stream_en;
    reg  [7:0]  ber_vec [0:7];
    reg  [3:0]  ber_idx;
    wire        ber_rng_valid = ber_stream_en && (ber_idx < 4'd8);
    wire [7:0]  ber_rng_data  = ber_rng_valid ? ber_vec[ber_idx] : 8'hAA;
    wire        ber_rng_ready;
    wire        ber_accept, ber_done;

    wire        b_mul_iv, b_mul_ov, b_add_iv, b_add_ov;
    wire [63:0] b_mul_x, b_mul_y, b_mul_z, b_add_x, b_add_y, b_add_z;

    fpr_mul u_ber_mul (
        .clk(clk), .rst_n(rst_n), .in_valid(b_mul_iv),
        .x(b_mul_x), .y(b_mul_y), .out_valid(b_mul_ov), .z(b_mul_z)
    );
    fpr_add u_ber_add (
        .clk(clk), .rst_n(rst_n), .in_valid(b_add_iv),
        .x(b_add_x), .y(b_add_y), .out_valid(b_add_ov), .z(b_add_z)
    );

    ber_exp u_ber (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (ber_start),
        .x             (ber_x_in),
        .ccs           (ber_ccs_in),
        .rng_data      (ber_rng_data),
        .rng_valid     (ber_rng_valid),
        .rng_ready     (ber_rng_ready),
        .mul_in_valid  (b_mul_iv),
        .mul_x         (b_mul_x),
        .mul_y         (b_mul_y),
        .mul_out_valid (b_mul_ov),
        .mul_z         (b_mul_z),
        .add_in_valid  (b_add_iv),
        .add_x         (b_add_x),
        .add_y         (b_add_y),
        .add_out_valid (b_add_ov),
        .add_z         (b_add_z),
        .accept        (ber_accept),
        .done          (ber_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)         ber_idx <= 4'd0;
        else if (ber_start) ber_idx <= 4'd0;
        else if (ber_rng_valid && ber_rng_ready) ber_idx <= ber_idx + 4'd1;
    end

    // =========================================================================
    // 3. DUT 3: sampler_z (Full end-to-end)
    // =========================================================================
    reg         sz_start;
    reg  [63:0] sz_mu_in, sz_isig_in;
    reg         sz_stream_en;
    reg         sz_stall_en;
    reg  [7:0]  sz_buf [0:511];
    reg  [9:0]  sz_len, sz_idx;
    reg  [7:0]  lfsr;
    wire        sz_rng_valid = sz_stream_en && (sz_idx < sz_len) && (!sz_stall_en || lfsr[0]);
    wire [7:0]  sz_rng_data  = sz_rng_valid ? sz_buf[sz_idx] : 8'hAA;
    wire        sz_rng_ready;
    wire [31:0] sz_z_out;
    wire        sz_done;

    sampler_z u_sz (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (sz_start),
        .mu        (sz_mu_in),
        .isigma    (sz_isig_in),
        .rng_data  (sz_rng_data),
        .rng_valid (sz_rng_valid),
        .rng_ready (sz_rng_ready),
        .z_out     (sz_z_out),
        .done      (sz_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sz_idx <= 10'd0;
            lfsr   <= 8'hE1;
        end else if (sz_start) begin
            sz_idx <= 10'd0;
        end else if (sz_stream_en) begin
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
            if (sz_rng_valid && sz_rng_ready) sz_idx <= sz_idx + 10'd1;
        end
    end

    // =========================================================================
    // 4. KỊCH BẢN KIỂM THỬ 4 PHA TRÊN DATA KAT THẬT
    // =========================================================================
    integer f_g0, f_ber, f_sz, f_log, r, j;
    integer cyc_cnt, sum_cyc, max_cyc, pass_cnt;
    integer cnt_g0, err_g0_val, err_g0_cyc, err_g0_byte;
    integer cnt_ber, err_ber_acc, err_ber_byte;
    integer cnt_sz_c, err_sz_c_val, err_sz_c_byte;
    integer cnt_sz_s, err_sz_s_val, err_sz_s_byte;
    integer exp_z0, exp_acc, exp_used, exp_z, exp_bytes, exp_iters;

    reg [63:0] tmp_a, tmp_b;
    reg        ok1, ok2, ok3, phase_ok;

    // Lưu 5 mẫu đầu của mỗi pha để in gọn ra Console
    reg [4:0]         samp_g0    [0:4];
    reg               samp_ber_a [0:4];
    reg [3:0]         samp_ber_b [0:4];
    reg signed [31:0] samp_sz_c  [0:4];
    reg signed [31:0] samp_sz_s  [0:4];

    initial begin
        rst_n         = 1'b0;
        g0_start      = 1'b0; g0_stream_en  = 1'b0;
        ber_start     = 1'b0; ber_stream_en = 1'b0; ber_x_in = 64'd0; ber_ccs_in = 64'd0;
        sz_start      = 1'b0; sz_stream_en  = 1'b0; sz_stall_en = 1'b0;
        sz_mu_in      = 64'd0; sz_isig_in   = 64'd0; sz_len = 10'd0;
        pass_cnt      = 0;

        f_g0  = $fopen("kat_gauss0.txt",     "r");
        f_ber = $fopen("kat_ber_exp.txt",    "r");
        f_sz  = $fopen("kat_sampler_z.txt",  "r");
        f_log = $fopen("sampler_kat_log.txt","w");

        if (f_g0 == 0 || f_ber == 0 || f_sz == 0 || f_log == 0) begin
            $display("[FATAL] Thieu file kat_gauss0.txt / kat_ber_exp.txt / kat_sampler_z.txt!");
            $finish;
        end

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("");

        // ---------------------------------------------------------------------
        // [1/4] gaussian0_sampler (KAT)
        // ---------------------------------------------------------------------
        cnt_g0 = 0; err_g0_val = 0; err_g0_cyc = 0; err_g0_byte = 0;
        $fdisplay(f_log, "=== [1/4] gaussian0_sampler (KAT) ===");

        while ($fscanf(f_g0, "%h %h %h %h %h %h %h %h %h %d\n",
                       g0_vec[0], g0_vec[1], g0_vec[2],
                       g0_vec[3], g0_vec[4], g0_vec[5],
                       g0_vec[6], g0_vec[7], g0_vec[8], exp_z0) == 10) begin
            @(negedge clk);
            g0_stream_en = 1'b1;
            g0_start     = 1'b1;
            cyc_cnt      = 0;
            @(negedge clk);
            g0_start     = 1'b0;

            while (g0_done !== 1'b1 && cyc_cnt < 200) begin
                @(posedge clk); #1;
                cyc_cnt = cyc_cnt + 1;
            end
            g0_stream_en = 1'b0;

            ok1 = (g0_done === 1'b1) && (^g0_z0_out !== 1'bx) && (g0_z0_out === exp_z0[4:0]);
            ok2 = (cyc_cnt == 27);
            ok3 = (g0_idx == 4'd9);

            if (cnt_g0 < 5) samp_g0[cnt_g0] = g0_z0_out;
            $fdisplay(f_log, "[G0]  [%04d] HW=%2d EXP=%2d cyc=%2d B=%0d [%2s]",
                      cnt_g0, g0_z0_out, exp_z0, cyc_cnt, g0_idx, (ok1 && ok2 && ok3) ? "OK" : "ER");

            if (!(ok1 && ok2 && ok3) && (err_g0_val + err_g0_cyc + err_g0_byte) < 5)
                $display("  [ERR] g0 [%04d] HW=%0d EXP=%0d cyc=%0d B=%0d",
                         cnt_g0, g0_z0_out, exp_z0, cyc_cnt, g0_idx);

            if (!ok1) err_g0_val  = err_g0_val  + 1;
            if (!ok2) err_g0_cyc  = err_g0_cyc  + 1;
            if (!ok3) err_g0_byte = err_g0_byte + 1;
            cnt_g0 = cnt_g0 + 1;
        end
        $fclose(f_g0);

        phase_ok = (cnt_g0 > 0) && (err_g0_val == 0) && (err_g0_cyc == 0) && (err_g0_byte == 0);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[1/4] gaussian0_sampler (KAT) : %s (%0d cases, val_err=%0d, cyc_err=%0d, byte_err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_g0, err_g0_val, err_g0_cyc, err_g0_byte);
        $display("  Out (first 5): z0 = %0d, %0d, %0d, %0d, %0d | cyc=27/sample",
                 samp_g0[0], samp_g0[1], samp_g0[2], samp_g0[3], samp_g0[4]);

        // ---------------------------------------------------------------------
        // [2/4] ber_exp (KAT)
        // ---------------------------------------------------------------------
        cnt_ber = 0; err_ber_acc = 0; err_ber_byte = 0; sum_cyc = 0;
        $fdisplay(f_log, "\n=== [2/4] ber_exp (KAT) ===");

        while ($fscanf(f_ber, "%h %h %h %h %h %h %h %h %h %h %d %d\n",
                       tmp_a, tmp_b,
                       ber_vec[0], ber_vec[1], ber_vec[2], ber_vec[3],
                       ber_vec[4], ber_vec[5], ber_vec[6], ber_vec[7],
                       exp_acc, exp_used) == 12) begin
            @(negedge clk);
            ber_x_in      = tmp_a;
            ber_ccs_in    = tmp_b;
            ber_stream_en = 1'b1;
            ber_start     = 1'b1;
            cyc_cnt       = 0;
            @(negedge clk);
            ber_start     = 1'b0;

            while (ber_done !== 1'b1 && cyc_cnt < 300) begin
                @(posedge clk); #1;
                cyc_cnt = cyc_cnt + 1;
            end
            ber_stream_en = 1'b0;

            ok1 = (ber_done === 1'b1) && (ber_accept === exp_acc[0]);
            ok2 = (ber_idx === exp_used[3:0]);
            sum_cyc = sum_cyc + cyc_cnt;

            if (cnt_ber < 5) begin
                samp_ber_a[cnt_ber] = ber_accept;
                samp_ber_b[cnt_ber] = ber_idx;
            end
            $fdisplay(f_log, "[BER] [%04d] X=%016h CCS=%016h | ACC:%b/%0d B:%0d/%0d cyc=%2d [%2s]",
                      cnt_ber, tmp_a, tmp_b, ber_accept, exp_acc, ber_idx, exp_used, cyc_cnt,
                      (ok1 && ok2) ? "OK" : "ER");

            if (!(ok1 && ok2) && (err_ber_acc + err_ber_byte) < 5)
                $display("  [ERR] ber [%04d] ACC=%b/%0d B=%0d/%0d",
                         cnt_ber, ber_accept, exp_acc, ber_idx, exp_used);

            if (!ok1) err_ber_acc  = err_ber_acc  + 1;
            if (!ok2) err_ber_byte = err_ber_byte + 1;
            cnt_ber = cnt_ber + 1;
        end
        $fclose(f_ber);

        phase_ok = (cnt_ber > 0) && (err_ber_acc == 0) && (err_ber_byte == 0);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("\n[2/4] ber_exp (KAT)           : %s (%0d cases, acc_err=%0d, byte_err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_ber, err_ber_acc, err_ber_byte);
        $display("  Out (first 5): acc = %b(%0dB), %b(%0dB), %b(%0dB), %b(%0dB), %b(%0dB) | avg_cyc=%0d",
                 samp_ber_a[0], samp_ber_b[0], samp_ber_a[1], samp_ber_b[1],
                 samp_ber_a[2], samp_ber_b[2], samp_ber_a[3], samp_ber_b[3],
                 samp_ber_a[4], samp_ber_b[4], (cnt_ber > 0) ? (sum_cyc / cnt_ber) : 0);

        // ---------------------------------------------------------------------
        // [3/4] sampler_z (KAT, continuous stream)
        // ---------------------------------------------------------------------
        cnt_sz_c = 0; err_sz_c_val = 0; err_sz_c_byte = 0; sum_cyc = 0; max_cyc = 0;
        $fdisplay(f_log, "\n=== [3/4] sampler_z (KAT, continuous) ===");

        while ($fscanf(f_sz, "%h %h %d %d %d\n",
                       tmp_a, tmp_b, exp_z, exp_bytes, exp_iters) == 5) begin
            for (j = 0; j < exp_bytes; j = j + 1) r = $fscanf(f_sz, "%h", sz_buf[j]);

            @(negedge clk);
            sz_mu_in     = tmp_a;
            sz_isig_in   = tmp_b;
            sz_len       = exp_bytes[9:0];
            sz_stall_en  = 1'b0;
            sz_stream_en = 1'b1;
            sz_start     = 1'b1;
            cyc_cnt      = 0;
            @(negedge clk);
            sz_start     = 1'b0;

            while (sz_done !== 1'b1 && cyc_cnt < 10000) begin
                @(posedge clk); #1;
                cyc_cnt = cyc_cnt + 1;
            end
            sz_stream_en = 1'b0;

            ok1 = (sz_done === 1'b1) && (^sz_z_out !== 1'bx) && ($signed(sz_z_out) === exp_z);
            ok2 = (sz_idx === exp_bytes[9:0]);
            sum_cyc = sum_cyc + cyc_cnt;
            if (cyc_cnt > max_cyc) max_cyc = cyc_cnt;

            if (cnt_sz_c < 5) samp_sz_c[cnt_sz_c] = $signed(sz_z_out);
            $fdisplay(f_log, "[SZ-C] [%04d] MU=%016h ISIG=%016h | HW=%5d EXP=%5d | B:%3d/%3d it=%2d cyc=%4d [%2s]",
                      cnt_sz_c, tmp_a, tmp_b, $signed(sz_z_out), exp_z, sz_idx, exp_bytes, exp_iters, cyc_cnt,
                      (ok1 && ok2) ? "OK" : "ER");

            if (!(ok1 && ok2) && (err_sz_c_val + err_sz_c_byte) < 5)
                $display("  [ERR] sz_cont [%04d] HW=%0d EXP=%0d B=%0d/%0d",
                         cnt_sz_c, $signed(sz_z_out), exp_z, sz_idx, exp_bytes);

            if (!ok1) err_sz_c_val  = err_sz_c_val  + 1;
            if (!ok2) err_sz_c_byte = err_sz_c_byte + 1;
            cnt_sz_c = cnt_sz_c + 1;
        end
        $fclose(f_sz);

        phase_ok = (cnt_sz_c > 0) && (err_sz_c_val == 0) && (err_sz_c_byte == 0);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("\n[3/4] sampler_z (KAT, cont)   : %s (%0d cases, val_err=%0d, byte_err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_sz_c, err_sz_c_val, err_sz_c_byte);
        $display("  Out (first 5): z = %0d, %0d, %0d, %0d, %0d | avg_cyc=%0d, max_cyc=%0d",
                 samp_sz_c[0], samp_sz_c[1], samp_sz_c[2], samp_sz_c[3], samp_sz_c[4],
                 (cnt_sz_c > 0) ? (sum_cyc / cnt_sz_c) : 0, max_cyc);

        // ---------------------------------------------------------------------
        // [4/4] sampler_z (KAT, random stall + 0xAA garbage)
        // ---------------------------------------------------------------------
        f_sz = $fopen("kat_sampler_z.txt", "r");
        cnt_sz_s = 0; err_sz_s_val = 0; err_sz_s_byte = 0; sum_cyc = 0;
        $fdisplay(f_log, "\n=== [4/4] sampler_z (KAT, random-stall) ===");

        while ($fscanf(f_sz, "%h %h %d %d %d\n",
                       tmp_a, tmp_b, exp_z, exp_bytes, exp_iters) == 5) begin
            for (j = 0; j < exp_bytes; j = j + 1) r = $fscanf(f_sz, "%h", sz_buf[j]);

            @(negedge clk);
            sz_mu_in     = tmp_a;
            sz_isig_in   = tmp_b;
            sz_len       = exp_bytes[9:0];
            sz_stall_en  = 1'b1;
            sz_stream_en = 1'b1;
            sz_start     = 1'b1;
            cyc_cnt      = 0;
            @(negedge clk);
            sz_start     = 1'b0;

            while (sz_done !== 1'b1 && cyc_cnt < 20000) begin
                @(posedge clk); #1;
                cyc_cnt = cyc_cnt + 1;
            end
            sz_stream_en = 1'b0;

            ok1 = (sz_done === 1'b1) && (^sz_z_out !== 1'bx) && ($signed(sz_z_out) === exp_z);
            ok2 = (sz_idx === exp_bytes[9:0]);
            sum_cyc = sum_cyc + cyc_cnt;

            if (cnt_sz_s < 5) samp_sz_s[cnt_sz_s] = $signed(sz_z_out);
            $fdisplay(f_log, "[SZ-S] [%04d] HW=%5d EXP=%5d | B:%3d/%3d cyc=%4d [%2s]",
                      cnt_sz_s, $signed(sz_z_out), exp_z, sz_idx, exp_bytes, cyc_cnt,
                      (ok1 && ok2) ? "OK" : "ER");

            if (!(ok1 && ok2) && (err_sz_s_val + err_sz_s_byte) < 5)
                $display("  [ERR] sz_stall [%04d] HW=%0d EXP=%0d B=%0d/%0d",
                         cnt_sz_s, $signed(sz_z_out), exp_z, sz_idx, exp_bytes);

            if (!ok1) err_sz_s_val  = err_sz_s_val  + 1;
            if (!ok2) err_sz_s_byte = err_sz_s_byte + 1;
            cnt_sz_s = cnt_sz_s + 1;
        end
        $fclose(f_sz);
        $fclose(f_log);

        phase_ok = (cnt_sz_s > 0) && (err_sz_s_val == 0) && (err_sz_s_byte == 0);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("\n[4/4] sampler_z (KAT, stall)  : %s (%0d cases, val_err=%0d, byte_err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_sz_s, err_sz_s_val, err_sz_s_byte);
        $display("  Out (first 5): z = %0d, %0d, %0d, %0d, %0d | avg_cyc=%0d",
                 samp_sz_s[0], samp_sz_s[1], samp_sz_s[2], samp_sz_s[3], samp_sz_s[4],
                 (cnt_sz_s > 0) ? (sum_cyc / cnt_sz_s) : 0);

        // SUMMARY
        if (pass_cnt == 4)
            $display("\nRESULT: PASS 4/4 (log: sampler_kat_log.txt)\n");
        else
            $display("\nRESULT: FAIL (%0d/4 passed, check [ER] in sampler_kat_log.txt)\n", pass_cnt);

        $finish;
    end

endmodule