`timescale 1ns / 1ps
module tb_fpr();
    reg clk;
    always #5 clk = ~clk; 
    reg  [63:0] lt_x;
    reg  [63:0] lt_y;
    wire        lt_z_out;
    reg         lt_z_exp;

    fpr_lt dut_lt (
        .x(lt_x),
        .y(lt_y),
        .z(lt_z_out)
    );
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
    integer file_lt, file_pack, r1, r2;
    integer err_lt = 0, err_pack = 0;
    integer test_cnt_lt = 0, test_cnt_pack = 0;
    initial begin
        clk = 0;
        file_lt = $fopen("test_lt.txt", "r");
        file_pack = $fopen("test_pack.txt", "r");

        if (file_lt == 0 || file_pack == 0) begin
            $display("LOI: Khong tim thay file text. Kiem tra lai duong dan!");
            $finish;
        end
        @(posedge clk);
        @(posedge clk);
        $display("--- BAT DAU TEST FPR_LT ---");
        while (!$feof(file_lt)) begin
            r1 = $fscanf(file_lt, "%h %h %h\n", lt_x, lt_y, lt_z_exp);
            @(posedge clk); 
            #1; 
            if (lt_z_out !== lt_z_exp) begin
                $display("LT FAIL case %0d: X=%h, Y=%h | EXP=%h, OUT=%h", test_cnt_lt, lt_x, lt_y, lt_z_exp, lt_z_out);
                err_lt = err_lt + 1;
            end
            test_cnt_lt = test_cnt_lt + 1;
        end
        $display("KET QUA FPR_LT: Chay %0d case, Loi %0d case.", test_cnt_lt, err_lt);
        $display("--- BAT DAU TEST FPR_PACK ---");
        while (!$feof(file_pack)) begin
            r2 = $fscanf(file_pack, "%h %h %h %h\n", pack_s, pack_e, pack_m, pack_z_exp);
            @(posedge clk);
            
            #1;
            if (pack_z_out !== pack_z_exp) begin
                $display("PACK FAIL case %0d: S=%h, E=%h, M=%h | EXP=%h, OUT=%h", test_cnt_pack, pack_s, pack_e, pack_m, pack_z_exp, pack_z_out);
                err_pack = err_pack + 1;
            end
            test_cnt_pack = test_cnt_pack + 1;
        end
        $display("KET QUA FPR_PACK: Chay %0d case, Loi %0d case.", test_cnt_pack, err_pack);
        $fclose(file_lt);
        $fclose(file_pack);
        $display("--- HOAN THANH TESTBENCH ---");
        $finish;
    end
endmodule