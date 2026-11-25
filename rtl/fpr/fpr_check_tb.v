`timescale 1ns / 1ps

module fpr_check_tb();
    reg clk;
    reg rst_n;
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
    reg  [63:0] lt_x, lt_y;
    wire        lt_z_out;
    reg         lt_z_exp;
    fpr_lt dut_lt (.x(lt_x), .y(lt_y), .z(lt_z_out));
    reg                pack_s;
    reg  signed [31:0] pack_e;
    reg  [63:0]        pack_m;
    wire [63:0]        pack_z_out;
    reg  [63:0]        pack_z_exp;
    fpr_pack dut_pack (.s(pack_s), .e(pack_e), .m(pack_m), .z(pack_z_out));
    reg  [63:0] round_x;
    wire [63:0] trunc_z_out, floor_z_out, rint_z_out;
    reg  [63:0] trunc_z_exp, floor_z_exp, rint_z_exp;
    fpr_trunc dut_trunc (.x(round_x), .z(trunc_z_out));
    fpr_floor dut_floor (.x(round_x), .z(floor_z_out));
    fpr_rint  dut_rint  (.x(round_x), .z(rint_z_out));
    reg  [63:0] unary_i, unary_x;
    wire [63:0] of_z_out, half_z_out, double_z_out, neg_z_out;
    reg  [63:0] of_z_exp, half_z_exp, double_z_exp, neg_z_exp;
    fpr_of     dut_of     (.i(unary_i), .z(of_z_out));
    fpr_half   dut_half   (.x(unary_x), .z(half_z_out));
    fpr_double dut_double (.x(unary_x), .z(double_z_out));
    fpr_neg    dut_neg    (.x(unary_x), .z(neg_z_out));
    reg         add_in_valid;
    reg  [63:0] add_x, add_y, add_exp_in;
    wire        add_out_valid;
    wire [63:0] add_z_out;
    fpr_add dut_add (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (add_in_valid),
        .x         (add_x),
        .y         (add_y),
        .out_valid (add_out_valid),
        .z         (add_z_out)
    );
    reg         mul_in_valid;
    reg  [63:0] mul_x, mul_y, mul_exp_in;
    wire        mul_out_valid;
    wire [63:0] mul_z_out;
    fpr_mul dut_mul (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (mul_in_valid),
        .x         (mul_x),
        .y         (mul_y),
        .out_valid (mul_out_valid),
        .z         (mul_z_out)
    );
    reg         expm_start;
    reg  [63:0] expm_x, expm_ccs;
    wire [63:0] expm_y_out;
    wire        expm_done;
    fpr_expm_p63 dut_expm (
        .clk   (clk),
        .rst_n (rst_n),
        .start (expm_start),
        .x     (expm_x),
        .ccs   (expm_ccs),
        .y_out (expm_y_out),
        .done  (expm_done)
    );
    integer     f_log;
    reg         sb_add_active;
    reg  [1:0]  sb_add_mode;
    reg  [3:0]  sb_add_v;
    reg  [63:0] sb_add_x   [0:3];
    reg  [63:0] sb_add_y   [0:3];
    reg  [63:0] sb_add_exp [0:3];
    integer     sb_add_cnt, sb_add_err;
    wire        sb_add_match = (^add_z_out !== 1'bx) && (add_z_out === sb_add_exp[3]);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sb_add_v   <= 4'd0;
            sb_add_cnt <= 0;
            sb_add_err <= 0;
        end else if (sb_add_active) begin
            if (add_out_valid !== sb_add_v[3]) begin
                if (sb_add_err < 5)
                    $display("  [ERR] fpr_add valid mismatch (mode=%0d idx=%0d): exp=%b got=%b",
                             sb_add_mode, sb_add_cnt, sb_add_v[3], add_out_valid);
                $fdisplay(f_log, "[ADD-%s] [%05d] VALID_ERR exp=%b got=%b [ER]",
                          (sb_add_mode == 2'd1) ? "BUBBLE" : "STREAM", sb_add_cnt, sb_add_v[3], add_out_valid);
                sb_add_err <= sb_add_err + 1;
            end
            if (sb_add_v[3]) begin
                $fdisplay(f_log, "[ADD-%s] [%05d] X=%016h Y=%016h | HW=%016h == EXP=%016h [%2s]",
                          (sb_add_mode == 2'd1) ? "BUBBLE" : "STREAM",
                          sb_add_cnt, sb_add_x[3], sb_add_y[3], add_z_out, sb_add_exp[3],
                          sb_add_match ? "OK" : "ER");
                if (!sb_add_match) begin
                    if (sb_add_err < 5)
                        $display("  [ERR] fpr_add [%05d] X=%016h Y=%016h | HW=%016h EXP=%016h",
                                 sb_add_cnt, sb_add_x[3], sb_add_y[3], add_z_out, sb_add_exp[3]);
                    sb_add_err <= sb_add_err + 1;
                end
                sb_add_cnt <= sb_add_cnt + 1;
            end
            sb_add_v      <= {sb_add_v[2:0], add_in_valid};
            sb_add_x[0]   <= add_x;      sb_add_x[1]   <= sb_add_x[0];   sb_add_x[2]   <= sb_add_x[1];   sb_add_x[3]   <= sb_add_x[2];
            sb_add_y[0]   <= add_y;      sb_add_y[1]   <= sb_add_y[0];   sb_add_y[2]   <= sb_add_y[1];   sb_add_y[3]   <= sb_add_y[2];
            sb_add_exp[0] <= add_exp_in; sb_add_exp[1] <= sb_add_exp[0]; sb_add_exp[2] <= sb_add_exp[1]; sb_add_exp[3] <= sb_add_exp[2];
        end else begin
            sb_add_v   <= 4'd0;
            sb_add_cnt <= 0;
            sb_add_err <= 0;
        end
    end
    reg         sb_mul_active;
    reg  [1:0]  sb_mul_mode;
    reg  [3:0]  sb_mul_v;
    reg  [63:0] sb_mul_x   [0:3];
    reg  [63:0] sb_mul_y   [0:3];
    reg  [63:0] sb_mul_exp [0:3];
    integer     sb_mul_cnt, sb_mul_err;
    wire        sb_mul_match = (^mul_z_out !== 1'bx) && (mul_z_out === sb_mul_exp[3]);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sb_mul_v   <= 4'd0;
            sb_mul_cnt <= 0;
            sb_mul_err <= 0;
        end else if (sb_mul_active) begin
            if (mul_out_valid !== sb_mul_v[3]) begin
                if (sb_mul_err < 5)
                    $display("  [ERR] fpr_mul valid mismatch (mode=%0d idx=%0d): exp=%b got=%b",
                             sb_mul_mode, sb_mul_cnt, sb_mul_v[3], mul_out_valid);
                $fdisplay(f_log, "[MUL-%s] [%05d] VALID_ERR exp=%b got=%b [ER]",
                          (sb_mul_mode == 2'd1) ? "BUBBLE" : "STREAM", sb_mul_cnt, sb_mul_v[3], mul_out_valid);
                sb_mul_err <= sb_mul_err + 1;
            end
            if (sb_mul_v[3]) begin
                $fdisplay(f_log, "[MUL-%s] [%05d] X=%016h Y=%016h | HW=%016h == EXP=%016h [%2s]",
                          (sb_mul_mode == 2'd1) ? "BUBBLE" : "STREAM",
                          sb_mul_cnt, sb_mul_x[3], sb_mul_y[3], mul_z_out, sb_mul_exp[3],
                          sb_mul_match ? "OK" : "ER");
                if (!sb_mul_match) begin
                    if (sb_mul_err < 5)
                        $display("  [ERR] fpr_mul [%05d] X=%016h Y=%016h | HW=%016h EXP=%016h",
                                 sb_mul_cnt, sb_mul_x[3], sb_mul_y[3], mul_z_out, sb_mul_exp[3]);
                    sb_mul_err <= sb_mul_err + 1;
                end
                sb_mul_cnt <= sb_mul_cnt + 1;
            end
            sb_mul_v      <= {sb_mul_v[2:0], mul_in_valid};
            sb_mul_x[0]   <= mul_x;      sb_mul_x[1]   <= sb_mul_x[0];   sb_mul_x[2]   <= sb_mul_x[1];   sb_mul_x[3]   <= sb_mul_x[2];
            sb_mul_y[0]   <= mul_y;      sb_mul_y[1]   <= sb_mul_y[0];   sb_mul_y[2]   <= sb_mul_y[1];   sb_mul_y[3]   <= sb_mul_y[2];
            sb_mul_exp[0] <= mul_exp_in; sb_mul_exp[1] <= sb_mul_exp[0]; sb_mul_exp[2] <= sb_mul_exp[1]; sb_mul_exp[3] <= sb_mul_exp[2];
        end else begin
            sb_mul_v   <= 4'd0;
            sb_mul_cnt <= 0;
            sb_mul_err <= 0;
        end
    end
    integer f_lt, f_pack, f_round, f_unary, f_add, f_mul, f_expm, r;
    integer err_lt, err_pack, err_trunc, err_floor, err_rint;
    integer err_of, err_half, err_double, err_neg;
    integer err_add_s, err_add_b, err_add_f;
    integer err_mul_s, err_mul_b, err_mul_f;
    integer err_expm_val, err_expm_cyc;
    integer cnt_lt, cnt_pack, cnt_round, cnt_unary;
    integer cnt_add_s, cnt_add_b, cnt_add_f;
    integer cnt_mul_s, cnt_mul_b, cnt_mul_f;
    integer cnt_expm, cyc_cnt, sent_cnt;
    integer pass_cnt, total_vectors;
    reg [63:0] tmp_x, tmp_y, tmp_exp;
    reg [7:0]  lfsr;
    reg        ok_lt, ok_pack, ok_tr, ok_fl, ok_ri;
    reg        ok_of, ok_hf, ok_db, ok_ng;
    reg        ok_add, ok_mul, ok_expm_v, ok_expm_c;
    reg        phase_ok;
    initial begin
        rst_n         = 1'b0;
        sb_add_active = 1'b0; sb_add_mode = 2'd0;
        sb_mul_active = 1'b0; sb_mul_mode = 2'd0;
        add_in_valid  = 1'b0; add_x = 64'd0; add_y = 64'd0; add_exp_in = 64'd0;
        mul_in_valid  = 1'b0; mul_x = 64'd0; mul_y = 64'd0; mul_exp_in = 64'd0;
        expm_start    = 1'b0; expm_x = 64'd0; expm_ccs = 64'd0;
        lfsr          = 8'hA5;
        pass_cnt      = 0;
        err_lt = 0; err_pack = 0; err_trunc = 0; err_floor = 0; err_rint = 0;
        err_of = 0; err_half = 0; err_double = 0; err_neg = 0;
        err_add_s = 0; err_add_b = 0; err_add_f = 0;
        err_mul_s = 0; err_mul_b = 0; err_mul_f = 0;
        err_expm_val = 0; err_expm_cyc = 0;
        cnt_lt = 0; cnt_pack = 0; cnt_round = 0; cnt_unary = 0;
        cnt_add_s = 0; cnt_add_b = 0; cnt_add_f = 0;
        cnt_mul_s = 0; cnt_mul_b = 0; cnt_mul_f = 0;
        cnt_expm = 0;
        f_lt    = $fopen("test_lt.txt",       "r");
        f_pack  = $fopen("test_pack.txt",     "r");
        f_round = $fopen("test_round.txt",    "r");
        f_unary = $fopen("test_unary.txt",    "r");
        f_add   = $fopen("test_add.txt",      "r");
        f_mul   = $fopen("test_mul.txt",      "r");
        f_expm  = $fopen("test_expm_p63.txt", "r");
        f_log   = $fopen("fpr_full_log.txt",  "w");
        if (f_lt == 0 || f_pack == 0 || f_round == 0 || f_unary == 0 ||
            f_add == 0 || f_mul == 0 || f_expm == 0 || f_log == 0) begin
            $display("[FATAL] Thieu file test_*.txt hoac khong tao duoc fpr_full_log.txt!");
            $finish;
        end
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        $display("");
        $fdisplay(f_log, "=== [1/11] FPR_LT ===");
        while ($fscanf(f_lt, "%h %h %h\n", lt_x, lt_y, lt_z_exp) == 3) begin
            #1;
            ok_lt = (^lt_z_out !== 1'bx) && (lt_z_out === lt_z_exp);
            $fdisplay(f_log, "[LT]    [%05d] X=%016h Y=%016h | HW=%b == EXP=%b [%2s]",
                      cnt_lt, lt_x, lt_y, lt_z_out, lt_z_exp, ok_lt ? "OK" : "ER");
            if (!ok_lt) begin
                if (err_lt < 5)
                    $display("  [ERR] fpr_lt [%05d] X=%016h Y=%016h | HW=%b EXP=%b",
                             cnt_lt, lt_x, lt_y, lt_z_out, lt_z_exp);
                err_lt = err_lt + 1;
            end
            cnt_lt = cnt_lt + 1;
        end
        phase_ok = (err_lt == 0 && cnt_lt == 10000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[ 1/11] fpr_lt               : %s (%0d cases, err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_lt, err_lt);
        $fdisplay(f_log, "\n=== [2/11] FPR_PACK ===");
        while ($fscanf(f_pack, "%h %h %h %h\n", pack_s, pack_e, pack_m, pack_z_exp) == 4) begin
            #1;
            ok_pack = (^pack_z_out !== 1'bx) && (pack_z_out === pack_z_exp);
            $fdisplay(f_log, "[PACK]  [%05d] S=%b E=%08h M=%016h | HW=%016h == EXP=%016h [%2s]",
                      cnt_pack, pack_s, pack_e, pack_m, pack_z_out, pack_z_exp, ok_pack ? "OK" : "ER");
            if (!ok_pack) begin
                if (err_pack < 5)
                    $display("  [ERR] fpr_pack [%05d] S=%b E=%0d M=%016h | HW=%016h EXP=%016h",
                             cnt_pack, pack_s, pack_e, pack_m, pack_z_out, pack_z_exp);
                err_pack = err_pack + 1;
            end
            cnt_pack = cnt_pack + 1;
        end
        phase_ok = (err_pack == 0 && cnt_pack == 10000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[ 2/11] fpr_pack             : %s (%0d cases, err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_pack, err_pack);
        $fdisplay(f_log, "\n=== [3/11] FPR_TRUNC / FLOOR / RINT ===");
        while ($fscanf(f_round, "%h %h %h %h\n", round_x, trunc_z_exp, floor_z_exp, rint_z_exp) == 4) begin
            #1;
            ok_tr = (^trunc_z_out !== 1'bx) && (trunc_z_out === trunc_z_exp);
            ok_fl = (^floor_z_out !== 1'bx) && (floor_z_out === floor_z_exp);
            ok_ri = (^rint_z_out  !== 1'bx) && (rint_z_out  === rint_z_exp);
            $fdisplay(f_log, "[ROUND] [%05d] X=%016h | TR:%016h==%016h[%2s] FL:%016h==%016h[%2s] RI:%016h==%016h[%2s]",
                      cnt_round, round_x,
                      trunc_z_out, trunc_z_exp, ok_tr ? "OK" : "ER",
                      floor_z_out, floor_z_exp, ok_fl ? "OK" : "ER",
                      rint_z_out,  rint_z_exp,  ok_ri ? "OK" : "ER");
            if ((!ok_tr || !ok_fl || !ok_ri) && (err_trunc + err_floor + err_rint) < 5)
                $display("  [ERR] round [%05d] X=%016h | TR:%b FL:%b RI:%b",
                         cnt_round, round_x, ok_tr, ok_fl, ok_ri);
            if (!ok_tr) err_trunc = err_trunc + 1;
            if (!ok_fl) err_floor = err_floor + 1;
            if (!ok_ri) err_rint  = err_rint  + 1;
            cnt_round = cnt_round + 1;
        end
        phase_ok = (err_trunc == 0 && err_floor == 0 && err_rint == 0 && cnt_round == 10000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[ 3/11] fpr_trunc/floor/rint : %s (%0d cases, err=%0d/%0d/%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_round, err_trunc, err_floor, err_rint);
        $fdisplay(f_log, "\n=== [4/11] FPR_OF / HALF / DOUBLE / NEG ===");
        while ($fscanf(f_unary, "%h %h %h %h %h %h\n",
                       unary_i, unary_x, of_z_exp, half_z_exp, double_z_exp, neg_z_exp) == 6) begin
            #1;
            ok_of = (^of_z_out     !== 1'bx) && (of_z_out     === of_z_exp);
            ok_hf = (^half_z_out   !== 1'bx) && (half_z_out   === half_z_exp);
            ok_db = (^double_z_out !== 1'bx) && (double_z_out === double_z_exp);
            ok_ng = (^neg_z_out    !== 1'bx) && (neg_z_out    === neg_z_exp);
            $fdisplay(f_log, "[UNARY] [%05d] I=%016h X=%016h | OF:%016h==%016h[%2s] HF:%016h==%016h[%2s] DB:%016h==%016h[%2s] NG:%016h==%016h[%2s]",
                      cnt_unary, unary_i, unary_x,
                      of_z_out,     of_z_exp,     ok_of ? "OK" : "ER",
                      half_z_out,   half_z_exp,   ok_hf ? "OK" : "ER",
                      double_z_out, double_z_exp, ok_db ? "OK" : "ER",
                      neg_z_out,    neg_z_exp,    ok_ng ? "OK" : "ER");
            if ((!ok_of || !ok_hf || !ok_db || !ok_ng) && (err_of + err_half + err_double + err_neg) < 5)
                $display("  [ERR] unary [%05d] OF:%b HF:%b DB:%b NG:%b",
                         cnt_unary, ok_of, ok_hf, ok_db, ok_ng);
            if (!ok_of) err_of     = err_of     + 1;
            if (!ok_hf) err_half   = err_half   + 1;
            if (!ok_db) err_double = err_double + 1;
            if (!ok_ng) err_neg    = err_neg    + 1;
            cnt_unary = cnt_unary + 1;
        end
        phase_ok = (err_of == 0 && err_half == 0 && err_double == 0 && err_neg == 0 && cnt_unary == 10000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[ 4/11] fpr_of/half/dbl/neg  : %s (%0d cases, err=%0d/%0d/%0d/%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_unary, err_of, err_half, err_double, err_neg);
        $fdisplay(f_log, "\n=== [5/11] FPR_ADD SINGLE-SHOT ===");
        while (cnt_add_s < 2000 && $fscanf(f_add, "%h %h %h\n", tmp_x, tmp_y, tmp_exp) == 3) begin
            @(negedge clk);
            add_x = tmp_x; add_y = tmp_y; add_in_valid = 1'b1;
            @(negedge clk);
            add_in_valid = 1'b0;
            repeat (3) @(posedge clk);
            #1;
            ok_add = (add_out_valid === 1'b1) && (^add_z_out !== 1'bx) && (add_z_out === tmp_exp);
            @(posedge clk);
            #1;
            if (add_out_valid !== 1'b0 || add_z_out !== tmp_exp) ok_add = 1'b0;
            $fdisplay(f_log, "[ADD-SINGLE] [%05d] X=%016h Y=%016h | HW=%016h == EXP=%016h [%2s]",
                      cnt_add_s, tmp_x, tmp_y, add_z_out, tmp_exp, ok_add ? "OK" : "ER");
            if (!ok_add) begin
                if (err_add_s < 5)
                    $display("  [ERR] fpr_add single [%05d] X=%016h Y=%016h | HW=%016h EXP=%016h",
                             cnt_add_s, tmp_x, tmp_y, add_z_out, tmp_exp);
                err_add_s = err_add_s + 1;
            end
            cnt_add_s = cnt_add_s + 1;
        end
        phase_ok = (err_add_s == 0 && cnt_add_s == 2000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[ 5/11] fpr_add single-shot  : %s (%0d cases, err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_add_s, err_add_s);
        $fdisplay(f_log, "\n=== [6/11] FPR_ADD RANDOM-BUBBLE ===");
        @(negedge clk);
        sb_add_mode   = 2'd1;
        sb_add_active = 1'b1;
        sent_cnt      = 0;
        while (sent_cnt < 4000) begin
            lfsr = {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
            if (lfsr[0]) begin
                r = $fscanf(f_add, "%h %h %h\n", tmp_x, tmp_y, tmp_exp);
                if (r == 3) begin
                    add_x = tmp_x; add_y = tmp_y; add_exp_in = tmp_exp;
                    add_in_valid = 1'b1;
                    sent_cnt = sent_cnt + 1;
                end else begin
                    add_in_valid = 1'b0;
                end
            end else begin
                add_in_valid = 1'b0;
                add_x = 64'hDEAD_BEEF_CAFE_BABE;
                add_y = 64'h1234_5678_9ABC_DEF0;
            end
            @(posedge clk); @(negedge clk);
        end
        add_in_valid = 1'b0;
        repeat (5) begin @(posedge clk); @(negedge clk); end
        cnt_add_b     = sb_add_cnt;
        err_add_b     = sb_add_err;
        sb_add_active = 1'b0;
        @(posedge clk); @(negedge clk);
        phase_ok = (err_add_b == 0 && cnt_add_b == 4000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[ 6/11] fpr_add rand-bubble  : %s (%0d cases, err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_add_b, err_add_b);
        $fdisplay(f_log, "\n=== [7/11] FPR_ADD FULL-RATE ===");
        sb_add_mode   = 2'd2;
        sb_add_active = 1'b1;
        while ($fscanf(f_add, "%h %h %h\n", tmp_x, tmp_y, tmp_exp) == 3) begin
            add_x = tmp_x; add_y = tmp_y; add_exp_in = tmp_exp;
            add_in_valid = 1'b1;
            @(posedge clk); @(negedge clk);
        end
        add_in_valid = 1'b0;
        repeat (5) begin @(posedge clk); @(negedge clk); end
        cnt_add_f     = sb_add_cnt;
        err_add_f     = sb_add_err;
        sb_add_active = 1'b0;
        @(posedge clk); @(negedge clk);
        phase_ok = (err_add_f == 0 && cnt_add_f == 14000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[ 7/11] fpr_add full-rate    : %s (%0d cases, err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_add_f, err_add_f);
        $fdisplay(f_log, "\n=== [8/11] FPR_MUL SINGLE-SHOT ===");
        while (cnt_mul_s < 2000 && $fscanf(f_mul, "%h %h %h\n", tmp_x, tmp_y, tmp_exp) == 3) begin
            @(negedge clk);
            mul_x = tmp_x; mul_y = tmp_y; mul_in_valid = 1'b1;
            @(negedge clk);
            mul_in_valid = 1'b0;
            repeat (3) @(posedge clk);
            #1;
            ok_mul = (mul_out_valid === 1'b1) && (^mul_z_out !== 1'bx) && (mul_z_out === tmp_exp);
            @(posedge clk);
            #1;
            if (mul_out_valid !== 1'b0 || mul_z_out !== tmp_exp) ok_mul = 1'b0;
            $fdisplay(f_log, "[MUL-SINGLE] [%05d] X=%016h Y=%016h | HW=%016h == EXP=%016h [%2s]",
                      cnt_mul_s, tmp_x, tmp_y, mul_z_out, tmp_exp, ok_mul ? "OK" : "ER");
            if (!ok_mul) begin
                if (err_mul_s < 5)
                    $display("  [ERR] fpr_mul single [%05d] X=%016h Y=%016h | HW=%016h EXP=%016h",
                             cnt_mul_s, tmp_x, tmp_y, mul_z_out, tmp_exp);
                err_mul_s = err_mul_s + 1;
            end
            cnt_mul_s = cnt_mul_s + 1;
        end
        phase_ok = (err_mul_s == 0 && cnt_mul_s == 2000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[ 8/11] fpr_mul single-shot  : %s (%0d cases, err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_mul_s, err_mul_s);
        $fdisplay(f_log, "\n=== [9/11] FPR_MUL RANDOM-BUBBLE ===");
        @(negedge clk);
        sb_mul_mode   = 2'd1;
        sb_mul_active = 1'b1;
        sent_cnt      = 0;
        lfsr          = 8'h5C;
        while (sent_cnt < 4000) begin
            lfsr = {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
            if (lfsr[0]) begin
                r = $fscanf(f_mul, "%h %h %h\n", tmp_x, tmp_y, tmp_exp);
                if (r == 3) begin
                    mul_x = tmp_x; mul_y = tmp_y; mul_exp_in = tmp_exp;
                    mul_in_valid = 1'b1;
                    sent_cnt = sent_cnt + 1;
                end else begin
                    mul_in_valid = 1'b0;
                end
            end else begin
                mul_in_valid = 1'b0;
                mul_x = 64'hDEAD_BEEF_CAFE_BABE;
                mul_y = 64'h1234_5678_9ABC_DEF0;
            end
            @(posedge clk); @(negedge clk);
        end
        mul_in_valid = 1'b0;
        repeat (5) begin @(posedge clk); @(negedge clk); end
        cnt_mul_b     = sb_mul_cnt;
        err_mul_b     = sb_mul_err;
        sb_mul_active = 1'b0;
        @(posedge clk); @(negedge clk);
        phase_ok = (err_mul_b == 0 && cnt_mul_b == 4000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[ 9/11] fpr_mul rand-bubble  : %s (%0d cases, err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_mul_b, err_mul_b);
        $fdisplay(f_log, "\n=== [10/11] FPR_MUL FULL-RATE ===");
        sb_mul_mode   = 2'd2;
        sb_mul_active = 1'b1;
        while ($fscanf(f_mul, "%h %h %h\n", tmp_x, tmp_y, tmp_exp) == 3) begin
            mul_x = tmp_x; mul_y = tmp_y; mul_exp_in = tmp_exp;
            mul_in_valid = 1'b1;
            @(posedge clk); @(negedge clk);
        end
        mul_in_valid = 1'b0;
        repeat (5) begin @(posedge clk); @(negedge clk); end
        cnt_mul_f     = sb_mul_cnt;
        err_mul_f     = sb_mul_err;
        sb_mul_active = 1'b0;
        @(posedge clk); @(negedge clk);
        phase_ok = (err_mul_f == 0 && cnt_mul_f == 14000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[10/11] fpr_mul full-rate    : %s (%0d cases, err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_mul_f, err_mul_f);
        $fdisplay(f_log, "\n=== [11/11] FPR_EXPM_P63 ===");
        while ($fscanf(f_expm, "%h %h %h\n", tmp_x, tmp_y, tmp_exp) == 3) begin
            @(negedge clk);
            expm_x     = tmp_x;
            expm_ccs   = tmp_y;
            expm_start = 1'b1;
            cyc_cnt    = 0;
            @(negedge clk);
            expm_start = 1'b0;

            while (expm_done !== 1'b1 && cyc_cnt < 200) begin
                @(posedge clk);
                #1;
                cyc_cnt = cyc_cnt + 1;
            end
            ok_expm_v = (expm_done === 1'b1) && (^expm_y_out !== 1'bx) && (expm_y_out === tmp_exp);
            ok_expm_c = (cyc_cnt == 52);

            $fdisplay(f_log, "[EXPM]  [%04d] X=%016h CCS=%016h | HW=%016h == EXP=%016h | cyc=%0d [%2s]",
                      cnt_expm, tmp_x, tmp_y, expm_y_out, tmp_exp, cyc_cnt,
                      (ok_expm_v && ok_expm_c) ? "OK" : "ER");

            if ((!ok_expm_v || !ok_expm_c) && (err_expm_val + err_expm_cyc) < 5)
                $display("  [ERR] expm [%04d] HW=%016h EXP=%016h cyc=%0d",
                         cnt_expm, expm_y_out, tmp_exp, cyc_cnt);

            if (!ok_expm_v) err_expm_val = err_expm_val + 1;
            if (!ok_expm_c) err_expm_cyc = err_expm_cyc + 1;
            cnt_expm = cnt_expm + 1;
        end
        phase_ok = (err_expm_val == 0 && err_expm_cyc == 0 && cnt_expm == 5000);
        if (phase_ok) pass_cnt = pass_cnt + 1;
        $display("[11/11] fpr_expm_p63 (52cyc) : %s (%0d cases, val_err=%0d, cyc_err=%0d)",
                 phase_ok ? "PASS" : "FAIL", cnt_expm, err_expm_val, err_expm_cyc);

        $fclose(f_lt);
        $fclose(f_pack);
        $fclose(f_round);
        $fclose(f_unary);
        $fclose(f_add);
        $fclose(f_mul);
        $fclose(f_expm);
        $fclose(f_log);
        total_vectors = cnt_lt + cnt_pack + cnt_round + cnt_unary +
                        cnt_add_s + cnt_add_b + cnt_add_f +
                        cnt_mul_s + cnt_mul_b + cnt_mul_f + cnt_expm;

        if (pass_cnt == 11)
            $display("\nRESULT: PASS 11/11 (%0d vectors, log: fpr_full_log.txt)\n", total_vectors);
        else
            $display("\nRESULT: FAIL (%0d/11 passed, check [ER] in fpr_full_log.txt)\n", pass_cnt);

        $finish;
    end
endmodule