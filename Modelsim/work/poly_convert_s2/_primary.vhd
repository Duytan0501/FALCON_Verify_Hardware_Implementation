library verilog;
use verilog.vl_types.all;
entity poly_convert_s2 is
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        start           : in     vl_logic;
        ram_s2_addr     : out    vl_logic_vector(8 downto 0);
        ram_s2_rdata    : in     vl_logic_vector(15 downto 0);
        ram_tt_addr     : out    vl_logic_vector(8 downto 0);
        ram_tt_wdata    : out    vl_logic_vector(15 downto 0);
        ram_tt_we       : out    vl_logic;
        done            : out    vl_logic
    );
end poly_convert_s2;
