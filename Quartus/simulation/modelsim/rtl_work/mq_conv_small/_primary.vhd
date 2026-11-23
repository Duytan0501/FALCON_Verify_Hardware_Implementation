library verilog;
use verilog.vl_types.all;
entity mq_conv_small is
    port(
        x_in            : in     vl_logic_vector(15 downto 0);
        z_out           : out    vl_logic_vector(15 downto 0)
    );
end mq_conv_small;
