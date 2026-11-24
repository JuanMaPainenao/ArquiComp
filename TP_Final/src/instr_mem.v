`timescale 1ns/1ps
// instr_mem.v - Memoria de programa: lectura asincronica para IF y puerto de
// debug para cargarla por UART. Fuera de rango lee 0 (HALT). Ver docs/if.md.
module instr_mem #(
    parameter ADDR_W = 8                   // 2^8 = 256 instrucciones
)(
    input  wire              clk,

    // Puerto del pipeline (IF)
    input  wire [31:0]       pc,
    output wire [31:0]       instr,

    // Puerto de debug
    input  wire              dbg_we,
    input  wire [ADDR_W-1:0] dbg_addr,     // indice de palabra
    input  wire [31:0]       dbg_wdata,
    output wire [31:0]       dbg_rdata
);

    localparam DEPTH = 1 << ADDR_W;

    reg [31:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h00000000;
    end

    always @(posedge clk) begin
        if (dbg_we)
            mem[dbg_addr] <= dbg_wdata;
    end

    // Si el PC se sale del rango, se lee 0 (= HALT) en vez de dar la vuelta
    wire in_range = (pc[31:ADDR_W+2] == 0);

    assign instr     = in_range ? mem[pc[ADDR_W+1:2]] : 32'h00000000;
    assign dbg_rdata = mem[dbg_addr];

endmodule
