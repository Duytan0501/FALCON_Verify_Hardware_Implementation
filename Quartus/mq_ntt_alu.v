module mq_ntt_alu (
    input  wire [15:0] u_in,
    input  wire [15:0] v_in,
    input  wire [15:0] w_in,
    output wire [15:0] u_out,
    output wire [15:0] v_out
);
    wire [15:0] v_mul_w;
    mq_montymul mul_inst (
        .x(v_in),
        .y(w_in),
        .z(v_mul_w)
    );
    mq_add add_inst (
        .x(u_in),
        .y(v_mul_w),
        .z(u_out)
    );
    mq_sub sub_inst (
        .x(u_in),
        .y(v_mul_w),
        .z(v_out)
    );
endmodule