`timescale 1ns / 1ps
module spram_512x16 (
    input  wire        clk,
    input  wire        we,
    input  wire [8:0]  addr,
    input  wire [15:0] wdata,
    output reg  [15:0] rdata
);
    reg [15:0] mem [0:511];

    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= wdata;
        end
        rdata <= mem[addr];
    end
endmodule
module dpram_512x16 (
    input  wire        clk,
    input  wire        we_a,
    input  wire [8:0]  addr_a,
    input  wire [15:0] wdata_a,
    output reg  [15:0] rdata_a,
    input  wire        we_b,
    input  wire [8:0]  addr_b,
    input  wire [15:0] wdata_b,
    output reg  [15:0] rdata_b
);
    reg [15:0] mem [0:511];
    always @(posedge clk) begin
        if (we_a) begin
            mem[addr_a] <= wdata_a;
        end
        rdata_a <= mem[addr_a];
    end
    always @(posedge clk) begin
        if (we_b) begin
            mem[addr_b] <= wdata_b;
        end
        rdata_b <= mem[addr_b];
    end
endmodule