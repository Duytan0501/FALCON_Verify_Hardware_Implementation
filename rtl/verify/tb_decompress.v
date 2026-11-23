`timescale 1ns / 1ps

module decompress_tb();

    localparam N         = 512;
    localparam STR_BYTES = 625;

    reg         clk;
    reg         rst_n;
    reg         start;

    wire [9:0]  ram_sig_addr;
    reg  [7:0]  ram_sig_rdata;

    wire [8:0]  ram_s2_addr;
    wire [15:0] ram_s2_wdata;
    wire        ram_s2_we;

    wire        valid_fmt;
    wire        done;
    reg [7:0]  mem_sig     [0:STR_BYTES-1];
    reg [7:0]  mem_sig_ref [0:STR_BYTES-1];
    reg [15:0] mem_s2      [0:N-1];
    reg [15:0] exp_s2      [0:N-1];

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        ram_sig_rdata <= mem_sig[ram_sig_addr];
        if (ram_s2_we) begin
            mem_s2[ram_s2_addr] <= ram_s2_wdata;
        end
    end
    decompress #(
        .N(N),
        .STR_BYTES(STR_BYTES)
    ) uut (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .ram_sig_addr  (ram_sig_addr),
        .ram_sig_rdata (ram_sig_rdata),
        .ram_s2_addr   (ram_s2_addr),
        .ram_s2_wdata  (ram_s2_wdata),
        .ram_s2_we     (ram_s2_we),
        .valid_fmt     (valid_fmt),
        .done          (done)
    )
    reg [3:0]  prev_dut_state;
    reg [3:0]  rej_from_state;
    reg [8:0]  rej_coeff_idx;
    reg [9:0]  rej_byte_idx;
    reg [3:0]  rej_k_cnt;
    reg        rej_sign;
    reg [6:0]  rej_low;
    reg [15:0] rej_bit_buf;
    reg [7:0]  rej_tail_byte;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_dut_state <= 4'd0;
            rej_from_state <= 4'd0;
            rej_coeff_idx  <= 9'd0;
            rej_byte_idx   <= 10'd0;
            rej_k_cnt      <= 4'd0;
            rej_sign       <= 1'b0;
            rej_low        <= 7'd0;
            rej_bit_buf    <= 16'd0;
            rej_tail_byte  <= 8'd0;
        end else begin
            prev_dut_state <= uut.state;
            if (start) begin
                rej_from_state <= 4'd0;
            end else if (uut.state == 4'd10 && prev_dut_state != 4'd10) begin
                // Vừa chuyển vào S_REJECT (4'd10) -> lưu lại toàn bộ hiện trường
                rej_from_state <= prev_dut_state;
                rej_coeff_idx  <= uut.coeff_idx;
                rej_byte_idx   <= uut.byte_idx;
                rej_k_cnt      <= uut.k_cnt;
                rej_sign       <= uut.sign_reg;
                rej_low        <= uut.low_reg;
                rej_bit_buf    <= uut.bit_buf;
                rej_tail_byte  <= ram_sig_rdata;
            end
        end
    end

    task print_reject_reason;
        input [3:0] st;
        begin
            case (st)
                4'd3: $write("S_GET_SIGN_LOW (Het byte khi doc sign+low)");
                4'd4: $write("S_UNARY (Tran k>=16 hoac het byte khi dem unary)");
                4'd5: $write("S_WRITE_COEFF (Phat hien ma hoa cam -0)");
                4'd6: $write("S_CHECK_BUF_TAIL (Bit du trong bit_buf != 0)");
                4'd8: $write("S_TAIL_CHECK (Byte dem cuoi trong RAM != 0)");
                default: $write("STATE_%0d", st);
            endcase
        end
    endtask
    integer cyc_cnt;
    integer total_fail;
    integer i, err_cnt, x_cnt;
    integer pos_cnt, neg_cnt, zero_cnt;
    reg     timeout_flag;

    task run_dut;
        begin
            cyc_cnt      = 0;
            timeout_flag = 1'b0;

            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            while (done !== 1'b1 && cyc_cnt < 20000) begin
                @(posedge clk);
                cyc_cnt = cyc_cnt + 1;
            end

            if (done !== 1'b1) begin
                timeout_flag = 1'b1;
                $display("  [ERROR] TIMEOUT sau %0d cycles!", cyc_cnt);
            end
            @(posedge clk);
        end
    endtask

    task clear_s2_ram;
        integer idx;
        begin
            for (idx = 0; idx < N; idx = idx + 1) begin
                mem_s2[idx] = 16'hDEAD;
            end
        end
    endtask
    initial begin
        rst_n      = 1'b0;
        start      = 1'b0;
        total_fail = 0;

        $readmemh("tb_sig_comp.txt", mem_sig_ref);
        $readmemh("tb_s2_exp.txt",   exp_s2);

        // Chặn pass ảo nếu chưa nạp được file .txt
        if (^mem_sig_ref[0] === 1'bx || ^exp_s2[0] === 1'bx) begin
            $display("[FATAL] Khong doc duoc tb_sig_comp.txt hoac tb_s2_exp.txt (du lieu la X)!");
            $finish;
        end

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("\n===========================================================================");
        $display("  STANDALONE TESTBENCH (VERBOSE PROOF): sig_decompress (FALCON-512)");
        $display("===========================================================================");
        $display("\n[CASE 1] Valid Signature from C Reference");
        $write("  First 16 input bytes (tb_sig_comp.txt): ");
        for (i = 0; i < 16; i = i + 1) $write("%02X ", mem_sig_ref[i]);
        $display("\n");

        clear_s2_ram();
        for (i = 0; i < STR_BYTES; i = i + 1) mem_sig[i] = mem_sig_ref[i];

        run_dut();

        $display("---------------------------------------------------------------------------");
        $display("| Idx |   HW Out (Hex / Signed)   |  EXP C (Hex / Signed)    |   Status   |");
        $display("---------------------------------------------------------------------------");

        err_cnt  = 0;
        x_cnt    = 0;
        pos_cnt  = 0;
        neg_cnt  = 0;
        zero_cnt = 0;

        for (i = 0; i < N; i = i + 1) begin
            if (^mem_s2[i] === 1'bx || ^exp_s2[i] === 1'bx) begin
                x_cnt   = x_cnt + 1;
                err_cnt = err_cnt + 1;
            end else if (mem_s2[i] !== exp_s2[i]) begin
                err_cnt = err_cnt + 1;
            end

            if ($signed(mem_s2[i]) > 0)      pos_cnt  = pos_cnt + 1;
            else if ($signed(mem_s2[i]) < 0) neg_cnt  = neg_cnt + 1;
            else                             zero_cnt = zero_cnt + 1;

            $display("| %03d |  0x%04X  (%6d)         |  0x%04X  (%6d)        |    [%2s]    |",
                     i,
                     mem_s2[i], $signed(mem_s2[i]),
                     exp_s2[i], $signed(exp_s2[i]),
                     ((^mem_s2[i] !== 1'bx) && (mem_s2[i] === exp_s2[i])) ? "OK" : "ER"
            );
        end
        $display("---------------------------------------------------------------------------");
        $display("  Stats      : Positive=%0d | Negative=%0d | Zero=%0d (Sum=%0d)",
                 pos_cnt, neg_cnt, zero_cnt, pos_cnt + neg_cnt + zero_cnt);
        $display("  Read Bytes : %0d / %0d | X/Z count: %0d | Mismatches: %0d / 512",
                 uut.byte_idx, STR_BYTES, x_cnt, err_cnt);

        if (!timeout_flag && valid_fmt === 1'b1 && err_cnt == 0 && x_cnt == 0) begin
            $display("  -> [CASE 1 PASS] valid_fmt=1 | 512/512 MATCH | Cycles: %0d", cyc_cnt);
        end else begin
            $display("  -> [CASE 1 FAIL] valid_fmt=%b | Errors: %0d/512 | Cycles: %0d",
                     valid_fmt, err_cnt, cyc_cnt);
            total_fail = total_fail + 1;
        end

        // ---------------------------------------------------------------------
        // CASE 2: LỖI MÃ HÓA -0 (100000001)
        // ---------------------------------------------------------------------
        $display("\n[CASE 2] Negative Zero Violation (100000001 at coeff 0)");
        for (i = 0; i < STR_BYTES; i = i + 1) mem_sig[i] = 8'h00;
        mem_sig[0] = 8'h80; // sign=1, low=0
        mem_sig[1] = 8'h80; // stop bit=1 (k=0)

        run_dut();

        $write("  Reject Trace: From "); print_reject_reason(rej_from_state); $display("");
        $display("  Snapshot    : coeff_idx=%0d | byte_idx=%0d | sign=%b | low=%0d | k=%0d",
                 rej_coeff_idx, rej_byte_idx, rej_sign, rej_low, rej_k_cnt);

        if (!timeout_flag && valid_fmt === 1'b0 && rej_from_state == 4'd5 && rej_coeff_idx == 9'd0) begin
            $display("  -> [CASE 2 PASS] Dung loi -0 tai coeff 0 | Cycles: %0d", cyc_cnt);
        end else begin
            $display("  -> [CASE 2 FAIL] valid_fmt=%b | rej_state=%0d", valid_fmt, rej_from_state);
            total_fail = total_fail + 1;
        end

        // ---------------------------------------------------------------------
        // CASE 3: LỖI BIT ĐỆM CUỐI KHÁC 0
        // ---------------------------------------------------------------------
        $display("\n[CASE 3] Non-Zero Trailing Padding Bit (byte 624 |= 0x01)");
        for (i = 0; i < STR_BYTES; i = i + 1) mem_sig[i] = mem_sig_ref[i];
        mem_sig[STR_BYTES-1] = mem_sig[STR_BYTES-1] | 8'h01;

        run_dut();

        $write("  Reject Trace: From "); print_reject_reason(rej_from_state); $display("");
        $display("  Snapshot    : coeff_idx=%0d | byte_idx=%0d | tail_byte=0x%02X | bit_buf=0x%04X",
                 rej_coeff_idx, rej_byte_idx, rej_tail_byte, rej_bit_buf);

        if (!timeout_flag && valid_fmt === 1'b0 &&
            (rej_from_state == 4'd6 || rej_from_state == 4'd8) && rej_coeff_idx == 9'd511) begin
            $display("  -> [CASE 3 PASS] Giai nen xong 512 he so roi bat dung loi padding | Cycles: %0d", cyc_cnt);
        end else begin
            $display("  -> [CASE 3 FAIL] valid_fmt=%b | rej_state=%0d", valid_fmt, rej_from_state);
            total_fail = total_fail + 1;
        end

        // ---------------------------------------------------------------------
        // CASE 4: LỖI TRÀN BIÊN ĐỘ (k >= 16)
        // ---------------------------------------------------------------------
        $display("\n[CASE 4] Unary Overflow (k >= 16 => |s_i| >= 2048)");
        for (i = 0; i < STR_BYTES; i = i + 1) mem_sig[i] = 8'h00;
        mem_sig[0] = 8'h01; // sign=0, low=1
        mem_sig[1] = 8'h00; // 8 bit 0
        mem_sig[2] = 8'h00; // 8 bit 0 tiep -> k=16
        mem_sig[3] = 8'h80;

        run_dut();

        $write("  Reject Trace: From "); print_reject_reason(rej_from_state); $display("");
        $display("  Snapshot    : coeff_idx=%0d | byte_idx=%0d | k_cnt=%0d (dat nguong 15 va gap them 0)",
                 rej_coeff_idx, rej_byte_idx, rej_k_cnt);

        if (!timeout_flag && valid_fmt === 1'b0 && rej_from_state == 4'd4 && rej_k_cnt == 4'd15) begin
            $display("  -> [CASE 4 PASS] Bat dung tran unary tai k=15->16 | Cycles: %0d", cyc_cnt);
        end else begin
            $display("  -> [CASE 4 FAIL] valid_fmt=%b | rej_state=%0d | k=%0d",
                     valid_fmt, rej_from_state, rej_k_cnt);
            total_fail = total_fail + 1;
        end

        // ---------------------------------------------------------------------
        // CASE 5: LỖI THIẾU BIT / UNDERRUN
        // ---------------------------------------------------------------------
        $display("\n[CASE 5] Stream Underrun (< 512 coeffs in 625 bytes)");
        for (i = 0; i < STR_BYTES; i = i + 1) begin
            case (i % 3)
                0: mem_sig[i] = 8'h01;
                1: mem_sig[i] = 8'h10;
                2: mem_sig[i] = 8'h11;
            endcase
        end

        run_dut();

        $write("  Reject Trace: From "); print_reject_reason(rej_from_state); $display("");
        $display("  Snapshot    : coeff_idx=%0d / 512 | byte_idx=%0d / %0d",
                 rej_coeff_idx, rej_byte_idx, STR_BYTES);

        if (!timeout_flag && valid_fmt === 1'b0 &&
            (rej_from_state == 4'd3 || rej_from_state == 4'd4) &&
            rej_byte_idx == STR_BYTES && rej_coeff_idx < 9'd511) begin
            $display("  -> [CASE 5 PASS] Bat dung het byte tai coeff %0d | Cycles: %0d",
                     rej_coeff_idx, cyc_cnt);
        end else begin
            $display("  -> [CASE 5 FAIL] valid_fmt=%b | rej_state=%0d | byte=%0d | coeff=%0d",
                     valid_fmt, rej_from_state, rej_byte_idx, rej_coeff_idx);
            total_fail = total_fail + 1;
        end

        // ---------------------------------------------------------------------
        // TỔNG KẾT
        // ---------------------------------------------------------------------
        $display("\n===========================================================================");
        if (total_fail == 0) begin
            $display("  VERDICT: ALL 5 TEST CASES VERIFIED & PASSED!");
        end else begin
            $display("  VERDICT: FAILED %0d / 5 TEST CASES!", total_fail);
        end
        $display("===========================================================================\n");
        $finish;
    end

endmodule