library verilog;
use verilog.vl_types.all;
entity poly_sub_norm is
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        start           : in     vl_logic;
        ram_tt_addr     : out    vl_logic_vector(8 downto 0);
        ram_tt_rdata    : in     vl_logic_vector(15 downto 0);
        ram_c0_addr     : out    vl_logic_vector(8 downto 0);
        ram_c0_rdata    : in     vl_logic_vector(15 downto 0);
        ram_s1_addr     : out    vl_logic_vector(8 downto 0);
        ram_s1_wdata    : out    vl_logic_vector(15 downto 0);
        ram_s1_we       : out    vl_logic;
        done            : out    vl_logic
    );
end poly_sub_norm;
