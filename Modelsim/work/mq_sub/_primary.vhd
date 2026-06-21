library verilog;
use verilog.vl_types.all;
entity mq_sub is
    port(
        x               : in     vl_logic_vector(15 downto 0);
        y               : in     vl_logic_vector(15 downto 0);
        z               : out    vl_logic_vector(15 downto 0)
    );
end mq_sub;
