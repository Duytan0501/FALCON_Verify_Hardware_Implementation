`timescale 1ns / 1ps

module tb_verify_top();

    localparam PK_BYTES  = 897;
    localparam SIG_BYTES = 625;
    localparam N         = 512;

    localparam ERR_NONE        = 3'd0;
    localparam ERR_BAD_PK      = 3'd1;
    localparam ERR_BAD_SIG_FMT = 3'd2;
    localparam ERR_BAD_NORM    = 3'd3;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg         load_pk;

    wire [7:0]  pk_data;
    wire        pk_valid;
    wire        pk_ready;

    wire [7:0]  sig_data;
    wire        sig_valid;
    wire        sig_ready;

    wire [15:0] c0_data;
    wire        c0_valid;
    wire        c0_ready;

    wire        done;
    wire        valid_sig_out;
    wire [31:0] norm_out_sig;
    wire [2:0]  err_code;
    reg [7:0]  mem_pk_ref  [0:PK_BYTES-1];
    reg [7:0]  mem_sig_ref [0:SIG_BYTES-1];
    reg [15:0] mem_c0_ref  [0:N-1];

    reg [7:0]  mem_pk      [0:PK_BYTES-1];
    reg [7:0]  mem_sig     [0:SIG_BYTES-1];
    reg [15:0] mem_c0      [0:N-1];

    reg [15:0] exp_h       [0:N-1];
    reg [15:0] exp_s2      [0:N-1];
    reg [15:0] exp_s1      [0:N-1];
    reg [31:0] exp_norm;

    integer c_cyc_unpack, c_cyc_hntt, c_cyc_decomp, c_cyc_vrfy;
    integer c_cyc_full, c_cyc_cached, c_cyc_shake;
    reg     has_c_cycles;
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
    verify_top uut (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .load_pk       (load_pk),
        .pk_data       (pk_data),
        .pk_valid      (pk_valid),
        .pk_ready      (pk_ready),
        .sig_data      (sig_data),
        .sig_valid     (sig_valid),
        .sig_ready     (sig_ready),
        .c0_data       (c0_data),
        .c0_valid      (c0_valid),
        .c0_ready      (c0_ready),
        .done          (done),
        .valid_sig_out (valid_sig_out),
        .norm_out_sig  (norm_out_sig),
        .err_code      (err_code)
    );
    reg       stream_en;
    reg [9:0] pk_idx;
    reg [9:0] sig_idx;
    reg [9:0] c0_idx;

    assign pk_valid  = stream_en && (pk_idx  < PK_BYTES);
    assign pk_data   = (pk_idx  < PK_BYTES)  ? mem_pk[pk_idx]   : 8'd0;

    assign sig_valid = stream_en && (sig_idx < SIG_BYTES);
    assign sig_data  = (sig_idx < SIG_BYTES) ? mem_sig[sig_idx] : 8'd0;

    assign c0_valid  = stream_en && (c0_idx  < N);
    assign c0_data   = (c0_idx  < N)         ? mem_c0[c0_idx]   : 16'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pk_idx  <= 10'd0;
            sig_idx <= 10'd0;
            c0_idx  <= 10'd0;
        end else if (start) begin
            pk_idx  <= 10'd0;
            sig_idx <= 10'd0;
            c0_idx  <= 10'd0;
        end else if (stream_en) begin
            if (pk_valid  && pk_ready)  pk_idx  <= pk_idx  + 10'd1;
            if (sig_valid && sig_ready) sig_idx <= sig_idx + 10'd1;
            if (c0_valid  && c0_ready)  c0_idx  <= c0_idx  + 10'd1;
        end
    end
    reg     is_running;
    integer cyc_total;
    integer cyc_load_phase;
    integer cyc_unpack;
    integer cyc_h_ntt;
    integer cyc_decomp;
    integer cyc_c0_load;
    integer cyc_conv;
    integer cyc_ntt;
    integer cyc_subnorm;
    integer cyc_isshort;
    integer cyc_finish;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_running     <= 1'b0;
            cyc_total      <= 0;
            cyc_load_phase <= 0;
            cyc_unpack     <= 0;
            cyc_h_ntt      <= 0;
            cyc_decomp     <= 0;
            cyc_c0_load    <= 0;
            cyc_conv       <= 0;
            cyc_ntt        <= 0;
            cyc_subnorm    <= 0;
            cyc_isshort    <= 0;
            cyc_finish     <= 0;
        end else if (start) begin
            is_running     <= 1'b1;
            cyc_total      <= 0;
            cyc_load_phase <= 0;
            cyc_unpack     <= 0;
            cyc_h_ntt      <= 0;
            cyc_decomp     <= 0;
            cyc_c0_load    <= 0;
            cyc_conv       <= 0;
            cyc_ntt        <= 0;
            cyc_subnorm    <= 0;
            cyc_isshort    <= 0;
            cyc_finish     <= 0;
        end else if (is_running) begin
            if (done) begin
                is_running <= 1'b0;
            end else begin
                cyc_total <= cyc_total + 1;
                case (uut.state)
                    3'd1: begin // S_LOAD_AND_HNTT
                        cyc_load_phase <= cyc_load_phase + 1;
                        if (uut.pk_sub == 2'd1) cyc_unpack  <= cyc_unpack  + 1;
                        if (uut.pk_sub == 2'd2) cyc_h_ntt   <= cyc_h_ntt   + 1;
                        if (!uut.s2_done)       cyc_decomp  <= cyc_decomp  + 1;
                        if (uut.c0_loading)     cyc_c0_load <= cyc_c0_load + 1;
                    end
                    3'd2: cyc_conv    <= cyc_conv    + 1;
                    3'd3: cyc_ntt     <= cyc_ntt     + 1;
                    3'd4: cyc_subnorm <= cyc_subnorm + 1;
                    3'd5: cyc_isshort <= cyc_isshort + 1;
                    3'd6, 3'd7: cyc_finish <= cyc_finish + 1;
                    default: ;
                endcase
            end
        end
    end
    integer fd, scan_ret, k, total_fail;
    integer err_h, err_s2, err_s1, x_cnt;
    integer hw_vrfy_raw;
    reg     timeout_flag;

    task load_clean_inputs;
        integer idx;
        begin
            for (idx = 0; idx < PK_BYTES;  idx = idx + 1) mem_pk[idx]  = mem_pk_ref[idx];
            for (idx = 0; idx < SIG_BYTES; idx = idx + 1) mem_sig[idx] = mem_sig_ref[idx];
            for (idx = 0; idx < N;         idx = idx + 1) mem_c0[idx]  = mem_c0_ref[idx];
        end
    endtask

    task run_verify;
        input use_load_pk;
        integer wd;
        begin
            timeout_flag = 1'b0;
            wd           = 0;

            @(negedge clk);
            load_pk   = use_load_pk;
            stream_en = 1'b1;
            start     = 1'b1;
            @(negedge clk);
            start     = 1'b0;

            while (done !== 1'b1 && wd < 60000) begin
                @(negedge clk);
                wd = wd + 1;
            end

            stream_en = 1'b0;
            if (done !== 1'b1) begin
                timeout_flag = 1'b1;
                $display("  [ERROR] TIMEOUT sau %0d cycles! (uut.state=%0d, pk_sub=%0d)",
                         wd, uut.state, uut.pk_sub);
            end
            @(negedge clk);
        end
    endtask

    task print_phase_report;
        input is_full_mode;
        integer c_ref_total;
        real    ratio_val;
        begin
            hw_vrfy_raw = cyc_conv + cyc_ntt + cyc_subnorm + cyc_isshort;

            $display("-------------------------------------------------------------------------------------");
            $display("  HW PER-PHASE CYCLE BREAKDOWN (3-Channel Parallel Stream)");
            $display("-------------------------------------------------------------------------------------");
            $display("  [Phase 0 - Parallel Load & H_NTT] : %6d cycles (Wall time)", cyc_load_phase);
            $display("      |-- Channel 1a: PK Unpack     : %6d cycles (bytes read: %0d/%0d)", cyc_unpack, pk_idx, PK_BYTES);
            $display("      |-- Channel 1b: H to_ntt      : %6d cycles (overlapped with SIG & C0)", cyc_h_ntt);
            $display("      |-- Channel 2 : SIG Decomp    : %6d cycles (bytes read: %0d/%0d)", cyc_decomp, sig_idx, SIG_BYTES);
            $display("      |-- Channel 3 : C0 Stream     : %6d cycles (words read: %0d/%0d)", cyc_c0_load, c0_idx, N);
            $display("  [Phase 1 - poly_convert_s2]       : %6d cycles", cyc_conv);
            $display("  [Phase 2 - NTT + PWM + iNTT]      : %6d cycles", cyc_ntt);
            $display("  [Phase 3 - poly_sub_norm (-s1)]   : %6d cycles", cyc_subnorm);
            $display("  [Phase 4 - is_short_engine]       : %6d cycles", cyc_isshort);
            $display("  [Overhead - DONE/REJECT state]    : %6d cycles", cyc_finish);
            $display("  -----------------------------------------------------------------------------------");
            $display("  TOTAL HW CYCLES                   : %6d cycles (verify_raw core = %0d)", cyc_total, hw_vrfy_raw);

            if (has_c_cycles) begin
                c_ref_total = is_full_mode ? c_cyc_full : c_cyc_cached;
                ratio_val   = (cyc_total > 0) ? (1.0 * c_ref_total / cyc_total) : 0.0;
                $display("-------------------------------------------------------------------------------------");
                $display("  HW (RTL) vs C (x86 CPU __rdtscp) CYCLE COMPARISON (Excluding SHAKE-256)");
                $display("-------------------------------------------------------------------------------------");
                $display("  | Stage               |  HW RTL (cyc)  |  C CPU (cyc)   |  Ratio (C / HW) |");
                $display("  |---------------------|----------------|----------------|-----------------|");
                if (is_full_mode) begin
                    $display("  | Unpack PK           | %14d | %14d | %14.2fx |",
                             cyc_unpack, c_cyc_unpack, (cyc_unpack > 0) ? (1.0 * c_cyc_unpack / cyc_unpack) : 0.0);
                    $display("  | H to_ntt_monty      | %14d | %14d | %14.2fx |",
                             cyc_h_ntt, c_cyc_hntt, (cyc_h_ntt > 0) ? (1.0 * c_cyc_hntt / cyc_h_ntt) : 0.0);
                end
                $display("  | Decompress SIG      | %14d | %14d | %14.2fx |",
                         cyc_decomp, c_cyc_decomp, (cyc_decomp > 0) ? (1.0 * c_cyc_decomp / cyc_decomp) : 0.0);
                $display("  | Verify Raw (P1..P4) | %14d | %14d | %14.2fx |",
                         hw_vrfy_raw, c_cyc_vrfy, (hw_vrfy_raw > 0) ? (1.0 * c_cyc_vrfy / hw_vrfy_raw) : 0.0);
                $display("  |---------------------|----------------|----------------|-----------------|");
                $display("  | TOTAL (No SHAKE256) | %14d | %14d | %14.2fx |",
                         cyc_total, c_ref_total, ratio_val);
                $display("  (Reference only: C SHAKE-256 + HashToPoint = %0d cycles)", c_cyc_shake);
            end
            $display("-------------------------------------------------------------------------------------");
        end
    endtask

    // =========================================================================
    // 6. KỊCH BẢN KIỂM THỬ TỔNG
    // =========================================================================
    initial begin
        rst_n        = 1'b0;
        start        = 1'b0;
        load_pk      = 1'b1;
        stream_en    = 1'b0;
        total_fail   = 0;
        has_c_cycles = 1'b0;

        $readmemh("tb_pk.txt",        mem_pk_ref);
        $readmemh("tb_sig_comp.txt",  mem_sig_ref);
        $readmemh("tb_c0.txt",        mem_c0_ref);
        $readmemh("tb_exp_h_ntt.txt", exp_h);
        $readmemh("tb_exp_s2.txt",    exp_s2);
        $readmemh("tb_exp_s1.txt",    exp_s1);

        if (^mem_pk_ref[0] === 1'bx || ^mem_sig_ref[0] === 1'bx || ^mem_c0_ref[0] === 1'bx ||
            ^exp_h[0]      === 1'bx || ^exp_s2[0]      === 1'bx || ^exp_s1[0]     === 1'bx) begin
            $display("[FATAL] Thieu hoac loi doc file .txt dump tu C (du lieu chua X)!");
            $finish;
        end

        fd = $fopen("tb_exp_norm.txt", "r");
        if (fd == 0) begin
            $display("[FATAL] Khong mo duoc tb_exp_norm.txt!");
            $finish;
        end
        scan_ret = $fscanf(fd, "%h", exp_norm);
        $fclose(fd);

        fd = $fopen("tb_c_cycles.txt", "r");
        if (fd != 0) begin
            scan_ret = $fscanf(fd, "%d\n%d\n%d\n%d\n%d\n%d\n%d\n",
                               c_cyc_unpack, c_cyc_hntt, c_cyc_decomp, c_cyc_vrfy,
                               c_cyc_full, c_cyc_cached, c_cyc_shake);
            $fclose(fd);
            if (scan_ret == 7) has_c_cycles = 1'b1;
        end else begin
            $display("[WARN] Chua tim thay tb_c_cycles.txt -> chi in cycle phan cung.");
        end

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("\n=====================================================================================");
        $display("  FALCON-512 VERIFY TOP TESTBENCH (3-CHANNEL PARALLEL STREAM + 4 INTERNAL SRAMS)");
        $display("=====================================================================================");

        // =====================================================================
        // CASE 1: FULL VERIFY (load_pk = 1) - IN ĐỦ 512 DÒNG + SO SÁNH CYCLE
        // =====================================================================
        $display("\n[CASE 1] Full Verify Flow (load_pk = 1, 3 Streams in Parallel)");
        load_clean_inputs();
        run_verify(1'b1);

        $display("=====================================================================================");
        $display("| Idx |   Unpack+NTT (u_ram_h)  |  Decompress (u_ram_s2)  |   SubNorm (u_ram_tt)    |");
        $display("|     | HW Out == C Exp  [Stat] | HW Out == C Exp  [Stat] | HW Out == C Exp  [Stat] |");
        $display("=====================================================================================");

        err_h  = 0;
        err_s2 = 0;
        err_s1 = 0;
        x_cnt  = 0;

        for (k = 0; k < N; k = k + 1) begin
            if (^uut.u_ram_h.mem[k]  === 1'bx || ^uut.u_ram_s2.mem[k] === 1'bx || ^uut.u_ram_tt.mem[k] === 1'bx)
                x_cnt = x_cnt + 1;
            if (uut.u_ram_h.mem[k]  !== exp_h[k])  err_h  = err_h  + 1;
            if (uut.u_ram_s2.mem[k] !== exp_s2[k]) err_s2 = err_s2 + 1;
            if (uut.u_ram_tt.mem[k] !== exp_s1[k]) err_s1 = err_s1 + 1;

            $display("| %03d |  %04h  ==  %04h   [%2s]  |  %04h  ==  %04h   [%2s]  |  %04h  ==  %04h   [%2s]  |",
                     k,
                     uut.u_ram_h.mem[k],  exp_h[k],  (uut.u_ram_h.mem[k]  === exp_h[k])  ? "OK" : "ER",
                     uut.u_ram_s2.mem[k], exp_s2[k], (uut.u_ram_s2.mem[k] === exp_s2[k]) ? "OK" : "ER",
                     uut.u_ram_tt.mem[k], exp_s1[k], (uut.u_ram_tt.mem[k] === exp_s1[k]) ? "OK" : "ER"
            );
        end
        $display("=====================================================================================");
        $display("  Errors -> h_ntt: %0d/512 | s2: %0d/512 | -s1: %0d/512 | X/Z: %0d",
                 err_h, err_s2, err_s1, x_cnt);
        $display("  Norm   -> HW: 0x%08X | EXP (C): 0x%08X | Match: %s",
                 norm_out_sig, exp_norm, (norm_out_sig === exp_norm) ? "OK" : "ERROR");
        $display("  Status -> valid_sig_out = %b | err_code = %0d (expect 0=ERR_NONE)",
                 valid_sig_out, err_code);

        print_phase_report(1'b1);

        if (!timeout_flag && err_h == 0 && err_s2 == 0 && err_s1 == 0 && x_cnt == 0 &&
            norm_out_sig === exp_norm && valid_sig_out === 1'b1 && err_code === ERR_NONE) begin
            $display("  >>> [CASE 1 PASS] FULL VERIFY BIT-EXACT MATCH!");
        end else begin
            $display("  >>> [CASE 1 FAIL]");
            total_fail = total_fail + 1;
        end

        // =====================================================================
        // CASE 2: CACHED PK FLOW (load_pk = 0) - TÁI SỬ DỤNG u_ram_h
        // =====================================================================
        $display("\n[CASE 2] Cached PK Verify Flow (load_pk = 0, Reuse u_ram_h)");
        load_clean_inputs();
        mem_pk[0] = 8'hFF; // Cố tình phá PK để chứng minh kênh PK không hề được đọc
        run_verify(1'b0);

        err_s2 = 0;
        err_s1 = 0;
        for (k = 0; k < N; k = k + 1) begin
            if (uut.u_ram_s2.mem[k] !== exp_s2[k]) err_s2 = err_s2 + 1;
            if (uut.u_ram_tt.mem[k] !== exp_s1[k]) err_s1 = err_s1 + 1;
        end

        $display("  Errors -> s2: %0d/512 | -s1: %0d/512 | pk_bytes_consumed: %0d (expect 0)",
                 err_s2, err_s1, pk_idx);
        $display("  Norm   -> HW: 0x%08X | EXP (C): 0x%08X | valid=%b | err_code=%0d",
                 norm_out_sig, exp_norm, valid_sig_out, err_code);

        print_phase_report(1'b0);

        if (!timeout_flag && pk_idx == 10'd0 && cyc_unpack == 0 && cyc_h_ntt == 0 &&
            err_s2 == 0 && err_s1 == 0 && norm_out_sig === exp_norm &&
            valid_sig_out === 1'b1 && err_code === ERR_NONE) begin
            $display("  >>> [CASE 2 PASS] CACHED PK REUSE VERIFIED!");
        end else begin
            $display("  >>> [CASE 2 FAIL]");
            total_fail = total_fail + 1;
        end

        // =====================================================================
        // CASE 3: FAIL-FAST BAD PK HEADER (0x0A) KHI 3 KÊNH ĐANG STREAM SONG SONG
        // =====================================================================
        $display("\n[CASE 3] Fail-Fast Abort: Bad PK Header (0x0A)");
        load_clean_inputs();
        mem_pk[0] = 8'h0A;
        run_verify(1'b1);

        $display("  Result -> valid=%b | err_code=%0d (expect 1=ERR_BAD_PK) | cycles=%0d | pk=%0d sig=%0d c0=%0d",
                 valid_sig_out, err_code, cyc_total, pk_idx, sig_idx, c0_idx);

        if (!timeout_flag && valid_sig_out === 1'b0 && err_code === ERR_BAD_PK && cyc_total < 50) begin
            $display("  >>> [CASE 3 PASS] Aborted early on bad PK header!");
        end else begin
            $display("  >>> [CASE 3 FAIL]");
            total_fail = total_fail + 1;
        end

        // =====================================================================
        // CASE 4: FAIL-FAST BAD SIG PADDING (BYTE 624 |= 0x01) - NGẮT H_NTT GIỮA CHỪNG
        // =====================================================================
        $display("\n[CASE 4] Fail-Fast Abort: Bad SIG Trailing Padding (Interrupts H_NTT mid-flight)");
        load_clean_inputs();
        mem_sig[SIG_BYTES-1] = mem_sig[SIG_BYTES-1] | 8'h01;
        run_verify(1'b1);

        $display("  Result -> valid=%b | err_code=%0d (expect 2=ERR_BAD_SIG_FMT) | total_cyc=%0d | h_ntt_interrupted_at=%0d",
                 valid_sig_out, err_code, cyc_total, cyc_h_ntt);

        if (!timeout_flag && valid_sig_out === 1'b0 && err_code === ERR_BAD_SIG_FMT &&
            cyc_conv == 0 && cyc_ntt == 0) begin
            $display("  >>> [CASE 4 PASS] Aborted cleanly on bad SIG padding!");
        end else begin
            $display("  >>> [CASE 4 FAIL]");
            total_fail = total_fail + 1;
        end

        // =====================================================================
        // CASE 5: BAD NORM (LÀM LỆCH 8 HỆ SỐ ĐẦU CỦA C0 -> VƯỢT NGƯỠNG 34,034,726)
        // =====================================================================
        $display("\n[CASE 5] Bad Norm Rejection (Perturbed c0[0..7], Valid PK & SIG)");
        load_clean_inputs();
        for (k = 0; k < 8; k = k + 1) begin
            mem_c0[k] = (mem_c0[k] >= 16'd8289) ? (mem_c0[k] - 16'd8289) : (mem_c0[k] + 16'd4000);
        end
        run_verify(1'b1);

        $display("  Result -> valid=%b | err_code=%0d (expect 3=ERR_BAD_NORM) | HW norm=%0d (> 34034726) | cycles=%0d",
                 valid_sig_out, err_code, norm_out_sig, cyc_total);

        if (!timeout_flag && valid_sig_out === 1'b0 && err_code === ERR_BAD_NORM &&
            norm_out_sig > 32'd34034726) begin
            $display("  >>> [CASE 5 PASS] Rejected oversized signature norm!");
        end else begin
            $display("  >>> [CASE 5 FAIL]");
            total_fail = total_fail + 1;
        end

        // =====================================================================
        // TỔNG KẾT
        // =====================================================================
        $display("\n=====================================================================================");
        if (total_fail == 0) begin
            $display("  FINAL VERDICT: ALL 5 TEST CASES PASSED!");
        end else begin
            $display("  FINAL VERDICT: FAILED %0d / 5 TEST CASES!", total_fail);
        end
        $display("=====================================================================================\n");
        $finish;
    end
endmodule