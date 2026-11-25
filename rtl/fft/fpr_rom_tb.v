`timescale 1ns / 1ps

module tb_fpr_gm_rom();

    reg         clk;
    reg  [8:0]  addr;
    reg         conj;
    wire [63:0] s_re, s_im;
    reg  [3:0]  logn;
    wire [63:0] p2_val;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    fpr_gm_rom dut (
        .clk    (clk),
        .addr   (addr),
        .conj   (conj),
        .s_re   (s_re),
        .s_im   (s_im),
        .logn   (logn),
        .p2_val (p2_val)
    );

    reg [63:0] exp_re   [0:511];
    reg [63:0] exp_im   [0:511];
    reg [63:0] exp_im_c [0:511];
    reg [63:0] exp_p2   [0:10];

    integer fd, k, r, pass_cnt;
    integer err_c0, err_c1, err_sync_val, err_sync_hold, err_p2;

    reg [8:0]  rnd_addr;
    reg        rnd_conj;
    reg [63:0] prev_re, prev_im, cur_exp_re, cur_exp_im;

    initial begin
        addr     = 9'd0;
        conj     = 1'b0;
        logn     = 4'd0;
        pass_cnt = 0;

        fd = $fopen("c_gm_rom_ref.txt", "r");
        if (fd == 0) begin
            $display("[FATAL] Khong mo duoc c_gm_rom_ref.txt!");
            $finish;
        end
        for (k = 0; k < 512; k = k + 1)
            r = $fscanf(fd, "%h %h %h\n", exp_re[k], exp_im[k], exp_im_c[k]);
        for (k = 0; k <= 10; k = k + 1)
            r = $fscanf(fd, "%h\n", exp_p2[k]);
        $fclose(fd);

        repeat (2) @(posedge clk);
        $display("");

        // [1/4] Quet 512 o conj=0 (FFT / merge)
        err_c0 = 0;
        for (k = 0; k < 512; k = k + 1) begin
            @(negedge clk);
            addr = k[8:0];
            conj = 1'b0;
            @(posedge clk);
            #1;
            if ((^s_re === 1'bx) || (^s_im === 1'bx) || s_re !== exp_re[k] || s_im !== exp_im[k]) begin
                if (err_c0 < 5)
                    $display("  [ERR] conj=0 addr=%0d | HW=(%016h,%016h) EXP=(%016h,%016h)",
                             k, s_re, s_im, exp_re[k], exp_im[k]);
                err_c0 = err_c0 + 1;
            end
        end
        if (err_c0 == 0) pass_cnt = pass_cnt + 1;
        $display("[1/4] gm_tab conj=0 (0..511)  : %s (512 entries, err=%0d)",
                 (err_c0 == 0) ? "PASS" : "FAIL", err_c0);
        $display("  Sample addr=383: re=%016h im=%016h", exp_re[383], exp_im[383]);

        // [2/4] Quet 512 o conj=1 (iFFT / split)
        err_c1 = 0;
        for (k = 0; k < 512; k = k + 1) begin
            @(negedge clk);
            addr = k[8:0];
            conj = 1'b1;
            @(posedge clk);
            #1;
            if ((^s_re === 1'bx) || (^s_im === 1'bx) || s_re !== exp_re[k] || s_im !== exp_im_c[k]) begin
                if (err_c1 < 5)
                    $display("  [ERR] conj=1 addr=%0d | HW=(%016h,%016h) EXP=(%016h,%016h)",
                             k, s_re, s_im, exp_re[k], exp_im_c[k]);
                err_c1 = err_c1 + 1;
            end
        end
        if (err_c1 == 0) pass_cnt = pass_cnt + 1;
        $display("[2/4] gm_tab conj=1 (0..511)  : %s (512 entries, err=%0d)",
                 (err_c1 == 0) ? "PASS" : "FAIL", err_c1);
        $display("  Sample addr=383: re=%016h im=%016h", exp_re[383], exp_im_c[383]);

        // [3/4] Back-to-back streaming 1 addr/cycle + check hold truoc posedge
        err_sync_val  = 0;
        err_sync_hold = 0;
        prev_re       = 64'd0;
        prev_im       = 64'd0;

        for (k = 0; k < 1024; k = k + 1) begin
            rnd_addr   = (k * 37 + 13) & 9'h1FF;
            rnd_conj   = k[0] ^ k[3];
            cur_exp_re = exp_re[rnd_addr];
            cur_exp_im = rnd_conj ? exp_im_c[rnd_addr] : exp_im[rnd_addr];

            @(negedge clk);
            addr = rnd_addr;
            conj = rnd_conj;
            #1;
            // Truoc suon len clock, ngo ra phai giu nguyen gia tri chu ky truoc
            if (k > 0 && (s_re !== prev_re || s_im !== prev_im)) begin
                if (err_sync_hold < 5)
                    $display("  [ERR] sync hold k=%0d (ro to hop truoc posedge)", k);
                err_sync_hold = err_sync_hold + 1;
            end

            @(posedge clk);
            #1;
            if (s_re !== cur_exp_re || s_im !== cur_exp_im) begin
                if (err_sync_val < 5)
                    $display("  [ERR] sync val k=%0d addr=%0d conj=%b | HW=(%016h,%016h) EXP=(%016h,%016h)",
                             k, rnd_addr, rnd_conj, s_re, s_im, cur_exp_re, cur_exp_im);
                err_sync_val = err_sync_val + 1;
            end
            prev_re = cur_exp_re;
            prev_im = cur_exp_im;
        end
        if (err_sync_val == 0 && err_sync_hold == 0) pass_cnt = pass_cnt + 1;
        $display("[3/4] back-to-back 1-cyc sync : %s (1024 ops, val_err=%0d, hold_err=%0d)",
                 (err_sync_val == 0 && err_sync_hold == 0) ? "PASS" : "FAIL",
                 err_sync_val, err_sync_hold);

        // [4/4] Bang fpr_p2_tab (logn = 0..10)
        err_p2 = 0;
        for (k = 0; k <= 10; k = k + 1) begin
            logn = k[3:0];
            #1;
            if ((^p2_val === 1'bx) || p2_val !== exp_p2[k]) begin
                if (err_p2 < 5)
                    $display("  [ERR] p2_tab logn=%0d | HW=%016h EXP=%016h", k, p2_val, exp_p2[k]);
                err_p2 = err_p2 + 1;
            end
        end
        if (err_p2 == 0) pass_cnt = pass_cnt + 1;
        $display("[4/4] p2_tab (logn 0..10)     : %s (11 entries, err=%0d)",
                 (err_p2 == 0) ? "PASS" : "FAIL", err_p2);
        $display("  Sample logn=9  : p2=%016h", exp_p2[9]);

        if (pass_cnt == 4)
            $display("\nRESULT: PASS 4/4\n");
        else
            $display("\nRESULT: FAIL (%0d/4 passed)\n", pass_cnt);

        $finish;
    end

endmodule