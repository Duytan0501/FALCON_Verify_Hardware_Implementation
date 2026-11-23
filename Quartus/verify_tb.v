`timescale 1ns / 1ps
module verify_tb();
    reg         clk;
    reg         rst_n;
    reg         start;
    wire        done;
    wire        valid_sig_out;
    wire [31:0] norm_out_sig;
    wire [8:0]  ram_s2_addr;
    reg  [15:0] ram_s2_rdata;
    wire [8:0]  ram_h_addr;
    reg  [15:0] ram_h_rdata;
    wire [8:0]  ram_c0_addr;
    reg  [15:0] ram_c0_rdata;
    wire [8:0]  ram_tt_addr_a;
    wire [8:0]  ram_tt_addr_b;
    reg  [15:0] ram_tt_rdata_a;
    reg  [15:0] ram_tt_rdata_b;
    wire [15:0] ram_tt_wdata_a;
    wire [15:0] ram_tt_wdata_b;
    wire        ram_tt_we_a;
    wire        ram_tt_we_b;
    wire [8:0]  ram_s1_addr;
    reg  [15:0] ram_s1_rdata;
    wire [15:0] ram_s1_wdata;
    wire        ram_s1_we;
    reg [15:0] mem_s2   [0:511];
    reg [15:0] mem_h    [0:511];
    reg [15:0] mem_c0   [0:511];
    reg [15:0] mem_tt   [0:511]; 
    reg [15:0] mem_s1   [0:511];
    reg [31:0] expected_norm;
    verify uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .valid_sig_out(valid_sig_out),
        .norm_out_sig(norm_out_sig),
        .ram_s2_addr(ram_s2_addr),
        .ram_s2_rdata(ram_s2_rdata),
        .ram_h_addr(ram_h_addr),
        .ram_h_rdata(ram_h_rdata),
        .ram_c0_addr(ram_c0_addr),
        .ram_c0_rdata(ram_c0_rdata),
        .ram_tt_addr_a(ram_tt_addr_a),
        .ram_tt_addr_b(ram_tt_addr_b),
        .ram_tt_rdata_a(ram_tt_rdata_a),
        .ram_tt_rdata_b(ram_tt_rdata_b),
        .ram_tt_wdata_a(ram_tt_wdata_a),
        .ram_tt_wdata_b(ram_tt_wdata_b),
        .ram_tt_we_a(ram_tt_we_a),
        .ram_tt_we_b(ram_tt_we_b),
        .ram_s1_addr(ram_s1_addr),
        .ram_s1_rdata(ram_s1_rdata),
        .ram_s1_wdata(ram_s1_wdata),
        .ram_s1_we(ram_s1_we)
    );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    always @(posedge clk) begin
        ram_s2_rdata   <= mem_s2[ram_s2_addr];
        ram_h_rdata    <= mem_h[ram_h_addr];
        ram_c0_rdata   <= mem_c0[ram_c0_addr];
        ram_tt_rdata_a <= mem_tt[ram_tt_addr_a];
        ram_tt_rdata_b <= mem_tt[ram_tt_addr_b];
        ram_s1_rdata   <= mem_s1[ram_s1_addr];
    end
    always @(posedge clk) begin
        if (ram_tt_we_a) mem_tt[ram_tt_addr_a] <= ram_tt_wdata_a;
        if (ram_tt_we_b) mem_tt[ram_tt_addr_b] <= ram_tt_wdata_b;
        if (ram_s1_we)   mem_s1[ram_s1_addr]   <= ram_s1_wdata;
    end
    integer total_cycles;
    reg     count_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_cycles <= 0;
            count_en     <= 1'b0;
        end else begin
            if (start) count_en <= 1'b1;
            else if (done) count_en <= 1'b0;

            if (count_en && !done) total_cycles <= total_cycles + 1;
        end
    end
    integer file_desc;
    integer dummy;
    initial begin
        $readmemh("sys_tb_s2.txt", mem_s2);
        $readmemh("sys_tb_h.txt", mem_h);
        $readmemh("sys_tb_c0.txt", mem_c0);
        rst_n = 1'b0;
        start = 1'b0;
        #100;
        rst_n = 1'b1;
        #20;
        $display("[SYSTEM] Kich hoat vi mạch Falcon Verifier Top Engine...");
        start = 1'b1;
        #10;
        start = 1'b0;
        wait(done == 1'b1);
        #10;
        file_desc = $fopen("sys_tb_norm.txt", "r");
        if (file_desc) begin
            dummy = $fscanf(file_desc, "%h", expected_norm);
            $fclose(file_desc);
        end
        $display("\n=========================================================");
        $display("[FALCON BLACK-BOX SYSTEM-LEVEL VERIFICATION REPORT]");
        $display("---------------------------------------------------------");
        $display(" Thoi gian thuc thi tinh toan : %0d xuy xung (Cycles)", total_cycles);
        $display(" Ket qua Norm tu Model C      : %08h", expected_norm);
        $display(" Ket qua Norm tu Hardware RTL : %08h", norm_out_sig);
        $display(" Trang thai chu ky Verifier   : %s", valid_sig_out ? "CHU KY HOP LE (VALID)" : "CHU KY KHONG HOP LE (INVALID)");
        $display("=========================================================");

        if (norm_out_sig === expected_norm) begin
            $display(">>> [SUCCESS] SYSTEM VERIFICATION PERFECT MATCH! <<<");
            $display(">>> Toan bo thiet ke Falcon Verifier Core hoan toan chinh xac! <<<");
        end else begin
            $display(">>> [CRITICAL FAIL] SYSTEM MISMATCH DETECTED! <<<");
            $display(">>> Kiem tra lai cac dường truyen du lieu va MUX RAM o Top! <<<");
        end
        $display("=========================================================\n");

        $finish;
    end
endmodule