`timescale 1ns / 1ps

module tb_fpr();

    reg clk;
    always #5 clk = ~clk; 

    // ==========================================
    // 1. DUT: FPR_LT
    // ==========================================
    reg  [63:0] lt_x;
    reg  [63:0] lt_y;
    wire        lt_z_out;
    reg         lt_z_exp;

    fpr_lt dut_lt (
        .x(lt_x),
        .y(lt_y),
        .z(lt_z_out)
    );

    // ==========================================
    // 2. DUT: FPR_PACK
    // ==========================================
    reg         pack_s;
    reg  [31:0] pack_e;
    reg  [63:0] pack_m;
    wire [63:0] pack_z_out;
    reg  [63:0] pack_z_exp;

    fpr_pack dut_pack (
        .s(pack_s),
        .e(pack_e),
        .m(pack_m),
        .z(pack_z_out)
    );

    // ==========================================
    // 3. DUT: FPR_TRUNC, FPR_FLOOR, FPR_RINT
    // ==========================================
    reg  [63:0] round_x;
    wire [63:0] trunc_z_out;
    wire [63:0] floor_z_out;
    wire [63:0] rint_z_out;

    reg  [63:0] trunc_z_exp;
    reg  [63:0] floor_z_exp;
    reg  [63:0] rint_z_exp;

    fpr_trunc dut_trunc (
        .x(round_x),
        .z(trunc_z_out)
    );

    fpr_floor dut_floor (
        .x(round_x),
        .z(floor_z_out)
    );

    fpr_rint dut_rint (
        .x(round_x),
        .z(rint_z_out)
    );

    // ==========================================
    // QUẢN LÝ TẬP TIN & THỐNG KÊ LỖI
    // ==========================================
    integer file_lt, file_pack, file_round;
    integer r1, r2, r3;
    integer err_lt = 0, err_pack = 0;
    integer err_trunc = 0, err_floor = 0, err_rint = 0;
    integer test_cnt_lt = 0, test_cnt_pack = 0, test_cnt_round = 0;

    initial begin
        clk = 0;
        
        file_lt    = $fopen("test_lt.txt", "r");
        file_pack  = $fopen("test_pack.txt", "r");
        file_round = $fopen("test_round.txt", "r");

        if (file_lt == 0 || file_pack == 0 || file_round == 0) begin
            $display("LOI: Khong tim thay du cac file test (.txt). Kiem tra thu muc!");
            $finish;
        end

        @(posedge clk);
        @(posedge clk);

        // --- TEST FPR_LT ---
        $display("--- BAT DAU TEST FPR_LT ---");
        while (!$feof(file_lt)) begin
            r1 = $fscanf(file_lt, "%h %h %h\n", lt_x, lt_y, lt_z_exp);
            @(posedge clk); 
            #1; 
            if (lt_z_out !== lt_z_exp) begin
                $display("LT FAIL [%0d]: X=%h, Y=%h | EXP=%h, OUT=%h", test_cnt_lt, lt_x, lt_y, lt_z_exp, lt_z_out);
                err_lt = err_lt + 1;
            end
            test_cnt_lt = test_cnt_lt + 1;
        end
        $display("KET QUA FPR_LT: Chay %0d case, Loi %0d case.", test_cnt_lt, err_lt);

        // --- TEST FPR_PACK ---
        $display("--- BAT DAU TEST FPR_PACK ---");
        while (!$feof(file_pack)) begin
            r2 = $fscanf(file_pack, "%h %h %h %h\n", pack_s, pack_e, pack_m, pack_z_exp);
            @(posedge clk);
            #1;
            if (pack_z_out !== pack_z_exp) begin
                $display("PACK FAIL [%0d]: S=%h, E=%h, M=%h | EXP=%h, OUT=%h", test_cnt_pack, pack_s, pack_e, pack_m, pack_z_exp, pack_z_out);
                err_pack = err_pack + 1;
            end
            test_cnt_pack = test_cnt_pack + 1;
        end
        $display("KET QUA FPR_PACK: Chay %0d case, Loi %0d case.", test_cnt_pack, err_pack);

        // --- TEST FPR_TRUNC, FLOOR, RINT ---
        $display("--- BAT DAU TEST ROUNDING (TRUNC, FLOOR, RINT) ---");
        while (!$feof(file_round)) begin
            r3 = $fscanf(file_round, "%h %h %h %h\n", round_x, trunc_z_exp, floor_z_exp, rint_z_exp);
            @(posedge clk);
            #1;

            if (trunc_z_out !== trunc_z_exp) begin
                $display("TRUNC FAIL [%0d]: X=%h | EXP=%h, OUT=%h", test_cnt_round, round_x, trunc_z_exp, trunc_z_out);
                err_trunc = err_trunc + 1;
            end

            if (floor_z_out !== floor_z_exp) begin
                $display("FLOOR FAIL [%0d]: X=%h | EXP=%h, OUT=%h", test_cnt_round, round_x, floor_z_exp, floor_z_out);
                err_floor = err_floor + 1;
            end

            if (rint_z_out !== rint_z_exp) begin
                $display("RINT FAIL [%0d]: X=%h | EXP=%h, OUT=%h", test_cnt_round, round_x, rint_z_exp, rint_z_out);
                err_rint = err_rint + 1;
            end

            test_cnt_round = test_cnt_round + 1;
        end
        $display("KET QUA ROUNDING (%0d cases):", test_cnt_round);
        $display(" - TRUNC errors: %0d", err_trunc);
        $display(" - FLOOR errors: %0d", err_floor);
        $display(" - RINT  errors: %0d", err_rint);

        $fclose(file_lt);
        $fclose(file_pack);
        $fclose(file_round);

        $display("--- HOAN THANH KIEM THU ---");
        $finish;
    end

endmodule