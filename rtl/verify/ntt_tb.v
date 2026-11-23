`timescale 1ns / 1ps

module ntt_tb();

    reg clk;
    reg rst_n;

    // --- Khai báo các khối RAM ---
    reg [15:0] mem_s2 [0:511];
    reg [15:0] mem_tt [0:511];
    reg [15:0] mem_h  [0:511];
    reg [15:0] mem_c0 [0:511];
    reg [15:0] mem_s1 [0:511]; 
    reg [15:0] mem_expected [0:511];
    reg [31:0] expected_norm;

    reg conv_start, ntt_start, sn_start, norm_start;
    
    // Wires cho khối Convert
    wire [8:0]  conv_s2_addr; wire [15:0] conv_tt_wdata;
    wire [8:0]  conv_tt_addr; wire conv_tt_we, conv_done;

    // Wires cho khối NTT
    wire [8:0]  ntt_addr_a, ntt_addr_b;
    wire [15:0] ntt_wdata_a, ntt_wdata_b;
    wire ntt_we_a, ntt_we_b, ntt_done;
    wire [8:0]  ntt_h_addr;

    // Wires cho khối SubNorm
    wire [8:0]  sn_tt_addr, sn_c0_addr, sn_s1_addr;
    wire [15:0] sn_s1_wdata;
    wire sn_s1_we, sn_done;

    // Wires cho khối IsShort (Kiểm tra Norm)
    wire [8:0]  norm_s1_addr, norm_s2_addr;
    wire [31:0] hw_norm_out;
    wire hw_valid_sig, norm_done;

    // Dữ liệu đọc từ RAM
    reg [15:0] ram_s2_rdata, ram_tt_rdata_a, ram_tt_rdata_b;
    reg [15:0] ram_h_rdata, ram_c0_rdata, ram_s1_rdata;

    // --- Khởi tạo các module ---
    poly_convert_s2 u_conv (.clk(clk), .rst_n(rst_n), .start(conv_start), .ram_s2_addr(conv_s2_addr), .ram_s2_rdata(ram_s2_rdata), .ram_tt_addr(conv_tt_addr), .ram_tt_wdata(conv_tt_wdata), .ram_tt_we(conv_tt_we), .done(conv_done));
    ntt_engine u_ntt (.clk(clk), .rst_n(rst_n), .start(ntt_start), .ram_addr_a(ntt_addr_a), .ram_addr_b(ntt_addr_b), .ram_rdata_a(ram_tt_rdata_a), .ram_rdata_b(ram_tt_rdata_b), .ram_wdata_a(ntt_wdata_a), .ram_wdata_b(ntt_wdata_b), .ram_we_a(ntt_we_a), .ram_we_b(ntt_we_b), .ram_h_addr(ntt_h_addr), .ram_h_rdata(ram_h_rdata), .done(ntt_done));
    poly_sub_norm u_sub_norm (.clk(clk), .rst_n(rst_n), .start(sn_start), .ram_tt_addr(sn_tt_addr), .ram_tt_rdata(ram_tt_rdata_a), .ram_c0_addr(sn_c0_addr), .ram_c0_rdata(ram_c0_rdata), .ram_s1_addr(sn_s1_addr), .ram_s1_wdata(sn_s1_wdata), .ram_s1_we(sn_s1_we), .done(sn_done));
    is_short_engine u_norm (.clk(clk), .rst_n(rst_n), .start(norm_start), .ram_s1_addr(norm_s1_addr), .ram_s1_rdata(ram_s1_rdata), .ram_s2_addr(norm_s2_addr), .ram_s2_rdata(ram_s2_rdata), .norm_out(hw_norm_out), .valid_sig(hw_valid_sig), .done(norm_done));

    initial begin
        clk = 0; forever #5 clk = ~clk;
    end

    reg is_conv_running, is_sn_running, is_norm_running;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_conv_running <= 0; is_sn_running <= 0; is_norm_running <= 0;
        end else begin
            if (conv_start) is_conv_running <= 1; else if (conv_done) is_conv_running <= 0;
            if (sn_start) is_sn_running <= 1; else if (sn_done) is_sn_running <= 0;
            if (norm_start) is_norm_running <= 1; else if (norm_done) is_norm_running <= 0;
        end
    end

    wire [8:0] tt_read_addr_a = is_sn_running ? sn_tt_addr : ntt_addr_a;
    wire [8:0] s2_read_addr   = is_norm_running ? norm_s2_addr : conv_s2_addr;

    always @(posedge clk) begin
        ram_s2_rdata   <= mem_s2[s2_read_addr];
        ram_tt_rdata_a <= mem_tt[tt_read_addr_a];
        ram_tt_rdata_b <= mem_tt[ntt_addr_b];
        ram_h_rdata    <= mem_h[ntt_h_addr];
        ram_c0_rdata   <= mem_c0[sn_c0_addr];
        ram_s1_rdata   <= mem_s1[norm_s1_addr];
    end

    always @(posedge clk) begin
        if (is_conv_running) begin
            if (conv_tt_we) mem_tt[conv_tt_addr] <= conv_tt_wdata;
        end else begin
            if (ntt_we_a) mem_tt[ntt_addr_a] <= ntt_wdata_a;
            if (ntt_we_b) mem_tt[ntt_addr_b] <= ntt_wdata_b;
        end
        if (sn_s1_we) mem_s1[sn_s1_addr] <= sn_s1_wdata;
    end

    integer cycle_count;
    always @(posedge clk) begin
        if (conv_start || ntt_start || sn_start || norm_start) cycle_count <= cycle_count + 1;
        else if (is_conv_running || is_sn_running || is_norm_running || (ntt_start || !ntt_done && !is_conv_running && !is_sn_running && !is_norm_running)) cycle_count <= cycle_count + 1;
    end

    integer fd, k, errors;

    initial begin
        $readmemh("ntt_tb_s2.txt", mem_s2);
        $readmemh("ntt_tb_h.txt", mem_h);
        $readmemh("ntt_tb_c0.txt", mem_c0);
        $readmemh("ntt_tb_expected.txt", mem_expected);
        
        rst_n = 0; conv_start = 0; ntt_start = 0; sn_start = 0; norm_start = 0; cycle_count = 0; errors = 0;
        #100; rst_n = 1; #20;
        
        // Chạy ngầm không in log các Phase để giữ sạch Console
        conv_start = 1; #10; conv_start = 0; wait(conv_done == 1'b1); #20;
        ntt_start = 1; #10; ntt_start = 0; wait(ntt_done == 1'b1); #20;
        sn_start = 1; #10; sn_start = 0; wait(sn_done == 1'b1); #20;
        norm_start = 1; #10; norm_start = 0; wait(norm_done == 1'b1); #20;

        // Check Phase 3 (-s1)
        for (k = 0; k < 512; k = k + 1) begin
            if(mem_s1[k] !== mem_expected[k]) errors = errors + 1;
        end

        // Đọc Norm Expected từ file
        fd = $fopen("ntt_tb_norm.txt", "r");
        if (fd) begin
            $fscanf(fd, "%h", expected_norm);
            $fclose(fd);
        end

        // --- BÁO CÁO DUY NHẤT VÀ GỌN NHẸ ---
        $display("\n=========================================================");
        $display("[FALCON VERIFIER IP CORE - FINAL VERIFICATION REPORT]");
        $display("---------------------------------------------------------");
        $display(" Phase 3 (-s1) Errors : %0d / 512", errors);
        $display(" Expected Norm (C)    : %08h", expected_norm);
        $display(" Hardware Norm (RTL)  : %08h", hw_norm_out);
        $display(" Signature Status     : %s", hw_valid_sig ? "VALID (1)" : "REJECTED (0)");
        $display(" Total Cycle Count    : %0d cycles", cycle_count);
        $display("=========================================================");
        
        if (hw_norm_out === expected_norm && errors == 0) begin
            $display(">>> [SUCCESS] PERFECT MATCH! All Datapaths are functional. <<<");
        end else begin
            $display(">>> [FAIL] MISMATCH DETECTED. Check log for details. <<<");
        end
        $display("=========================================================\n");
        $finish;
    end
endmodule