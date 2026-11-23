transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/verify.v}
vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/poly_sub_norm.v}
vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/poly_convert_s2.v}
vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/mq_sub.v}
vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/mq_ntt.v}
vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/mq_normalize.v}
vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/mq_monty_mul.v}
vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/mq_conv_small.v}
vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/mq_add.v}
vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/is_short.v}

vlog -vlog01compat -work work +incdir+K:/HK6/CE201/FALCON/Quartus {K:/HK6/CE201/FALCON/Quartus/verify_tb.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneii_ver -L rtl_work -L work -voptargs="+acc"  verify_tb

add wave *
view structure
view signals
run -all
