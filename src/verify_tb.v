`timescale 1ns / 1ps
module verify_tb();
    reg clk, rst_n, start;
    wire done, valid_sig_out;
    wire [31:0] norm_out_sig;
    wire [8:0] ram_s2_addr, ram_h_addr, ram_c0_addr, ram_s1_addr;
    reg [15:0] ram_s2_rdata, ram_h_rdata, ram_c0_rdata, ram_s1_rdata;
    wire [15:0] ram_s1_wdata;
    wire ram_s1_we;
    wire [8:0] ram_tt_addr_a, ram_tt_addr_b;
    reg [15:0] ram_tt_rdata_a, ram_tt_rdata_b;
    wire [15:0] ram_tt_wdata_a, ram_tt_wdata_b;
    wire ram_tt_we_a, ram_tt_we_b;
    reg [15:0] mem_s2 [0:511], mem_h  [0:511], mem_c0 [0:511];
    reg [15:0] mem_tt [0:511], mem_s1 [0:511];
    reg [15:0] exp_p1 [0:511], exp_p2 [0:511], exp_p3 [0:511];
    reg [15:0] snap_p1 [0:511], snap_p2 [0:511];
    reg [31:0] expected_norm;
    verify uut (
        .clk(clk), .rst_n(rst_n), .start(start), 
        .done(done), .valid_sig_out(valid_sig_out), .norm_out_sig(norm_out_sig),
        .ram_s2_addr(ram_s2_addr), .ram_s2_rdata(ram_s2_rdata),
        .ram_h_addr(ram_h_addr), .ram_h_rdata(ram_h_rdata),
        .ram_c0_addr(ram_c0_addr), .ram_c0_rdata(ram_c0_rdata),
        .ram_tt_addr_a(ram_tt_addr_a), .ram_tt_addr_b(ram_tt_addr_b),
        .ram_tt_rdata_a(ram_tt_rdata_a), .ram_tt_rdata_b(ram_tt_rdata_b),
        .ram_tt_wdata_a(ram_tt_wdata_a), .ram_tt_wdata_b(ram_tt_wdata_b),
        .ram_tt_we_a(ram_tt_we_a), .ram_tt_we_b(ram_tt_we_b),
        .ram_s1_addr(ram_s1_addr), .ram_s1_rdata(ram_s1_rdata),
        .ram_s1_wdata(ram_s1_wdata), .ram_s1_we(ram_s1_we)
    );
    initial begin clk = 0; forever #5 clk = ~clk; end
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
    integer i;
    always @(posedge clk) begin
        if (uut.conv_done) for (i=0; i<512; i=i+1) snap_p1[i] = mem_tt[i];
        if (uut.ntt_done)  for (i=0; i<512; i=i+1) snap_p2[i] = mem_tt[i];
    end
    integer fd, k;
    integer err_p1, err_p2, err_p3;
    reg [2:0] stat_p1, stat_p2, stat_p3;
    integer cycle_count; 
    reg is_running; 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_running  <= 1'b0;
            cycle_count <= 0;
        end else begin
            if (start) begin
                is_running  <= 1'b1;
                cycle_count <= 0;
            end 
            else if (done)  is_running  <= 1'b0;
            if (is_running) cycle_count <= cycle_count + 1;
        end
    end     
    initial begin
        $readmemh("tb_s2.txt", mem_s2);
        $readmemh("tb_h.txt",  mem_h);
        $readmemh("tb_c0.txt", mem_c0);
        $readmemh("tb_exp_p1.txt", exp_p1);
        $readmemh("tb_exp_p2.txt", exp_p2);
        $readmemh("tb_exp_p3.txt", exp_p3);
        err_p1 = 0; err_p2 = 0; err_p3 = 0;
        rst_n = 0; start = 0;
        #100; rst_n = 1; #20;
        start = 1; #10; start = 0;
        wait(done == 1'b1);
        #10;
        fd = $fopen("tb_norm.txt", "r");
        if (fd) begin
            $fscanf(fd, "%h", expected_norm);
            $fclose(fd);
        end
        $display("");
        $display("=====================================================================================");
        $display("Idx |    Phase 1 (Convert)    |      Phase 2 (NTT)      |    Phase 3 (-s1 Norm)   ");
        $display("    | HW Output vs C Expected | HW Output vs C Expected | HW Output vs C Expected ");
        $display("=====================================================================================");

        for (k = 0; k < 512; k = k + 1) begin
            if (snap_p1[k] !== exp_p1[k]) err_p1 = err_p1 + 1;
            if (snap_p2[k] !== exp_p2[k]) err_p2 = err_p2 + 1;
            if (mem_s1[k]  !== exp_p3[k]) err_p3 = err_p3 + 1;
            $display("[%03d] |  %04h == %04h [%2s]   |  %04h == %04h [%2s]   |  %04h == %04h [%2s]  ",
                     k,
                     snap_p1[k], exp_p1[k], (snap_p1[k] === exp_p1[k]) ? "OK" : "ER",
                     snap_p2[k], exp_p2[k], (snap_p2[k] === exp_p2[k]) ? "OK" : "ER",
                     mem_s1[k],  exp_p3[k], (mem_s1[k]  === exp_p3[k]) ? "OK" : "ER"
            );
        end
        $display("Phase 1 (Convert) : %0d / 512", err_p1);
        $display("Phase 2 (NTT/iNTT): %0d / 512", err_p2);
        $display("Phase 3 (-s1)     : %0d / 512", err_p3);
        $display("-------------------------");
        $display("Expected Norm (C)     : %08h", expected_norm);
        $display("Hardware Norm (RTL)   : %08h", norm_out_sig);
        $display("Check Norm (Phase 4)  : %s", (norm_out_sig === expected_norm) ? "OK" : "ERROR");
        $display("Valid Status (0/1)    : %0b", valid_sig_out);
        $display("Total Cycle Count     : %0d cycles", cycle_count);
        $display("-------------------------");
        if (err_p1 == 0 && err_p2 == 0 && err_p3 == 0 && norm_out_sig === expected_norm) begin
            $display("PASS");
        end else begin
            $display("FAIL");
        end
        $finish;
    end
endmodule