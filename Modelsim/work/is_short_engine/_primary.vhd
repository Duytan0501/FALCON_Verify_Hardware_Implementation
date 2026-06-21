library verilog;
use verilog.vl_types.all;
entity is_short_engine is
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        start           : in     vl_logic;
        ram_s1_addr     : out    vl_logic_vector(8 downto 0);
        ram_s1_rdata    : in     vl_logic_vector(15 downto 0);
        ram_s2_addr     : out    vl_logic_vector(8 downto 0);
        ram_s2_rdata    : in     vl_logic_vector(15 downto 0);
        norm_out        : out    vl_logic_vector(31 downto 0);
        valid_sig       : out    vl_logic;
        done            : out    vl_logic
    );
end is_short_engine;
