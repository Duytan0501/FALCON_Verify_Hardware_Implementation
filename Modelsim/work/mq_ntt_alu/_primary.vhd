library verilog;
use verilog.vl_types.all;
entity mq_ntt_alu is
    port(
        u_in            : in     vl_logic_vector(15 downto 0);
        v_in            : in     vl_logic_vector(15 downto 0);
        w_in            : in     vl_logic_vector(15 downto 0);
        u_out           : out    vl_logic_vector(15 downto 0);
        v_out           : out    vl_logic_vector(15 downto 0)
    );
end mq_ntt_alu;
