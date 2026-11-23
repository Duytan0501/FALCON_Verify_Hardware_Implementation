`timescale 1ns / 1ps

module pk_unpack_tb();

    localparam N        = 512;
    localparam PK_BYTES = 897;

    reg         clk;
    reg         rst_n;
    reg         start;

    wire [9:0]  ram_pk_addr;
    reg  [7:0]  ram_pk_rdata;

    wire [8:0]  ram_h_addr;
    wire [15:0] ram_h_wdata;
    wire        ram_h_we;

    wire        valid_pk;
    wire        done;
    reg [7:0]  mem_pk     [0:PK_BYTES-1];
    reg [7:0]  mem_pk_ref [0:PK_BYTES-1];
    reg [15:0] mem_h      [0:N-1];
    reg [15:0] exp_h      [0:N-1];

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        ram_pk_rdata <= mem_pk[ram_pk_addr];
        if (ram_h_we) begin
            mem_h[ram_h_addr] <= ram_h_wdata;
        end
    end
    unpack #(
        .N(N),
        .PK_BYTES(PK_BYTES)
    ) uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .ram_pk_addr  (ram_pk_addr),
        .ram_pk_rdata (ram_pk_rdata),
        .ram_h_addr   (ram_h_addr),
        .ram_h_wdata  (ram_h_wdata),
        .ram_h_we     (ram_h_we),
        .valid_pk     (valid_pk),
        .done         (done)
    );
    reg [2:0]  prev_state;
    reg [2:0]  rej_from_state;
    reg [8:0]  rej_coeff_idx;
    reg [13:0] rej_h_val;
    reg [7:0]  rej_hdr_byte;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_state     <= 3'd0;
            rej_from_state <= 3'd0;
            rej_coeff_idx  <= 9'd0;
            rej_h_val      <= 14'd0;
            rej_hdr_byte   <= 8'd0;
        end else begin
            prev_state <= uut.state;
            if (start) begin
                rej_from_state <= 3'd0;
            end else if (uut.state == 3'd7 && prev_state != 3'd7) begin
                rej_from_state <= prev_state;
                rej_coeff_idx  <= uut.coeff_idx;
                rej_h_val      <= uut.curr_h;
                rej_hdr_byte   <= ram_pk_rdata;
            end
        end
    end
    integer cyc_cnt, total_fail, i, err_cnt, x_cnt;
    reg [15:0] min_h, max_h;
    reg        timeout_flag;
    task run_dut;
        begin
            cyc_cnt      = 0;
            timeout_flag = 1'b0;

            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            while (done !== 1'b1 && cyc_cnt < 10000) begin
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

    task clear_h_ram;
        integer idx;
        begin
            for (idx = 0; idx < N; idx = idx + 1) mem_h[idx] = 16'hBEEF;
        end
    endtask
    initial begin
        rst_n      = 1'b0;
        start      = 1'b0;
        total_fail = 0;

        $readmemh("tb_pk.txt",        mem_pk_ref);
        $readmemh("tb_h_raw_exp.txt", exp_h);

        if (^mem_pk_ref[0] === 1'bx || ^exp_h[0] === 1'bx) begin
            $display("[FATAL] Khong doc duoc tb_pk.txt hoac tb_h_raw_exp.txt (du lieu la X)!");
            $finish;
        end

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("\n===========================================================================");
        $display("  STANDALONE TESTBENCH (VERBOSE PROOF): pk_unpack (FALCON-512)");
        $display("===========================================================================");
        $display("\n[CASE 1] Valid Public Key from C Reference (897 bytes)");
        $write("  Header + First 15 bytes (tb_pk.txt): ");
        for (i = 0; i < 16; i = i + 1) $write("%02X ", mem_pk_ref[i]);
        $display("\n");

        clear_h_ram();
        for (i = 0; i < PK_BYTES; i = i + 1) mem_pk[i] = mem_pk_ref[i];

        run_dut();

        $display("---------------------------------------------------------------------------");
        $display("| Idx |   HW Out (Hex / Unsigned) |  EXP C (Hex / Unsigned)  |   Status   |");
        $display("---------------------------------------------------------------------------");
        err_cnt = 0;
        x_cnt   = 0;
        min_h   = 16'hFFFF;
        max_h   = 16'd0;
        for (i = 0; i < N; i = i + 1) begin
            if (^mem_h[i] === 1'bx || ^exp_h[i] === 1'bx) begin
                x_cnt   = x_cnt + 1;
                err_cnt = err_cnt + 1;
            end else if (mem_h[i] !== exp_h[i]) begin
                err_cnt = err_cnt + 1;
            end

            if (mem_h[i] < min_h) min_h = mem_h[i];
            if (mem_h[i] > max_h) max_h = mem_h[i];

            $display("| %03d |  0x%04X  (%5d)          |  0x%04X  (%5d)         |    [%2s]    |",
                     i,
                     mem_h[i], mem_h[i],
                     exp_h[i], exp_h[i],
                     ((^mem_h[i] !== 1'bx) && (mem_h[i] === exp_h[i])) ? "OK" : "ER"
            );
        end
        $display("---------------------------------------------------------------------------");
        $display("  Range      : min(h) = %0d | max(h) = %0d (must be < 12289)", min_h, max_h);
        $display("  Final Addr : %0d / %0d | X/Z count: %0d | Mismatches: %0d / 512",
                 ram_pk_addr, PK_BYTES - 1, x_cnt, err_cnt);
        if (!timeout_flag && valid_pk === 1'b1 && err_cnt == 0 && x_cnt == 0) begin
            $display("  -> [CASE 1 PASS] valid_pk=1 | 512/512 MATCH | Cycles: %0d", cyc_cnt);
        end else begin
            $display("  -> [CASE 1 FAIL] valid_pk=%b | Errors: %0d/512 | Cycles: %0d",
                     valid_pk, err_cnt, cyc_cnt);
            total_fail = total_fail + 1;
        end
        $display("\n[CASE 2] Invalid Header Byte (0x0A instead of 0x09)");
        for (i = 0; i < PK_BYTES; i = i + 1) mem_pk[i] = mem_pk_ref[i];
        mem_pk[0] = 8'h0A; // Sai bậc n (1024 thay vì 512)

        run_dut();

        $display("  Reject Trace: from_state=%0d (expect 2=S_HDR_CHECK) | header_read=0x%02X",
                 rej_from_state, rej_hdr_byte);
        if (!timeout_flag && valid_pk === 1'b0 && rej_from_state == 3'd2) begin
            $display("  -> [CASE 2 PASS] Bat dung loi Header | Cycles: %0d", cyc_cnt);
        end else begin
            $display("  -> [CASE 2 FAIL] valid_pk=%b | rej_state=%0d", valid_pk, rej_from_state);
            total_fail = total_fail + 1;
        end
        $display("\n[CASE 3] Boundary Violation: h[0] == 12289 (0x3001)");
        for (i = 0; i < PK_BYTES; i = i + 1) mem_pk[i] = mem_pk_ref[i];
        mem_pk[1] = 8'hC0;                      // 8 bit cao của 14'b11_0000_0000_0001
        mem_pk[2] = (mem_pk[2] & 8'h03) | 8'h04; // 6 bit thấp = 000001 -> h[0] = 12289

        run_dut();

        $display("  Reject Trace: from_state=%0d (expect 5=S_WRITE_COEFFS) | coeff_idx=%0d | h_val=%0d",
                 rej_from_state, rej_coeff_idx, rej_h_val);
        if (!timeout_flag && valid_pk === 1'b0 && rej_from_state == 3'd5 &&
            rej_coeff_idx == 9'd0 && rej_h_val == 14'd12289) begin
            $display("  -> [CASE 3 PASS] Bat dung bien h[0]=12289 | Cycles: %0d", cyc_cnt);
        end else begin
            $display("  -> [CASE 3 FAIL] valid_pk=%b | idx=%0d | val=%0d",
                     valid_pk, rej_coeff_idx, rej_h_val);
            total_fail = total_fail + 1;
        end
        $display("\n[CASE 4] Last Coefficient Overflow: h[511] == 16383 (0x3FFF)");
        for (i = 0; i < PK_BYTES; i = i + 1) mem_pk[i] = mem_pk_ref[i];
        mem_pk[895] = (mem_pk[895] & 8'hC0) | 8'h3F; // Giữ nguyên 2 bit cuối của h[510], set 6 bit đầu h[511]=1
        mem_pk[896] = 8'hFF;                         // Set 8 bit cuối h[511]=1 -> h[511] = 16383

        run_dut();

        $display("  Reject Trace: from_state=%0d (expect 5=S_WRITE_COEFFS) | coeff_idx=%0d | h_val=%0d",
                 rej_from_state, rej_coeff_idx, rej_h_val);
        if (!timeout_flag && valid_pk === 1'b0 && rej_from_state == 3'd5 &&
            rej_coeff_idx == 9'd511 && rej_h_val == 14'd16383) begin
            $display("  -> [CASE 4 PASS] Kiem tra toi tan phan tu cuoi h[511]=16383 | Cycles: %0d", cyc_cnt);
        end else begin
            $display("  -> [CASE 4 FAIL] valid_pk=%b | idx=%0d | val=%0d",
                     valid_pk, rej_coeff_idx, rej_h_val);
            total_fail = total_fail + 1;
        end

        // ---------------------------------------------------------------------
        $display("\n===========================================================================");
        if (total_fail == 0) begin
            $display("  VERDICT: ALL 4 TEST CASES VERIFIED & PASSED!");
        end else begin
            $display("  VERDICT: FAILED %0d / 4 TEST CASES!", total_fail);
        end
        $display("===========================================================================\n");
        $finish;
    end

endmodule