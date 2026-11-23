library verilog;
use verilog.vl_types.all;
entity ntt_engine is
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        start           : in     vl_logic;
        ram_addr_a      : out    vl_logic_vector(8 downto 0);
        ram_addr_b      : out    vl_logic_vector(8 downto 0);
        ram_rdata_a     : in     vl_logic_vector(15 downto 0);
        ram_rdata_b     : in     vl_logic_vector(15 downto 0);
        ram_wdata_a     : out    vl_logic_vector(15 downto 0);
        ram_wdata_b     : out    vl_logic_vector(15 downto 0);
        ram_we_a        : out    vl_logic;
        ram_we_b        : out    vl_logic;
        ram_h_addr      : out    vl_logic_vector(8 downto 0);
        ram_h_rdata     : in     vl_logic_vector(15 downto 0);
        done            : out    vl_logic
    );
end ntt_engine;
