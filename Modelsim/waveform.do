onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TOP CONTROL}
add wave -noupdate /verify_tb/clk
add wave -noupdate /verify_tb/rst_n
add wave -noupdate /verify_tb/start
add wave -noupdate /verify_tb/uut/state
add wave -noupdate -color Red /verify_tb/done
add wave -noupdate -divider {ERROR}
add wave -noupdate -color Yellow -radix unsigned /verify_tb/err_p1
add wave -noupdate -color Yellow -radix unsigned /verify_tb/err_p2
add wave -noupdate -color Yellow -radix unsigned /verify_tb/err_p3

add wave -noupdate -divider {RAM TT (A & B)}
add wave -noupdate -radix unsigned /verify_tb/uut/ram_tt_addr_a
add wave -noupdate -color Cyan -radix hexadecimal /verify_tb/uut/ram_tt_wdata_a
add wave -noupdate -color Red /verify_tb/uut/ram_tt_we_a
add wave -noupdate -radix hexadecimal /verify_tb/uut/ram_tt_rdata_a

add wave -noupdate -divider {NORM CHECK}
add wave -noupdate -color Blue -radix hexadecimal /verify_tb/expected_norm
add wave -noupdate -color Orange -radix hexadecimal /verify_tb/norm_out_sig
add wave -noupdate -color Green /verify_tb/valid_sig_out

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
update