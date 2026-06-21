library verilog;
use verilog.vl_types.all;
entity verify is
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        start           : in     vl_logic;
        done            : out    vl_logic;
        valid_sig_out   : out    vl_logic;
        norm_out_sig    : out    vl_logic_vector(31 downto 0);
        ram_s2_addr     : out    vl_logic_vector(8 downto 0);
        ram_s2_rdata    : in     vl_logic_vector(15 downto 0);
        ram_h_addr      : out    vl_logic_vector(8 downto 0);
        ram_h_rdata     : in     vl_logic_vector(15 downto 0);
        ram_c0_addr     : out    vl_logic_vector(8 downto 0);
        ram_c0_rdata    : in     vl_logic_vector(15 downto 0);
        ram_tt_addr_a   : out    vl_logic_vector(8 downto 0);
        ram_tt_addr_b   : out    vl_logic_vector(8 downto 0);
        ram_tt_rdata_a  : in     vl_logic_vector(15 downto 0);
        ram_tt_rdata_b  : in     vl_logic_vector(15 downto 0);
        ram_tt_wdata_a  : out    vl_logic_vector(15 downto 0);
        ram_tt_wdata_b  : out    vl_logic_vector(15 downto 0);
        ram_tt_we_a     : out    vl_logic;
        ram_tt_we_b     : out    vl_logic;
        ram_s1_addr     : out    vl_logic_vector(8 downto 0);
        ram_s1_rdata    : in     vl_logic_vector(15 downto 0);
        ram_s1_wdata    : out    vl_logic_vector(15 downto 0);
        ram_s1_we       : out    vl_logic
    );
end verify;
