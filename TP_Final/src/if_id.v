`timescale 1ns/1ps
`include "riscv_defs.vh"
// ============================================================================
// if_id.v - Latch entre IF e ID
//
// Prioridad: rst > !en (pausa) > flush > stall > cargar
//   - flush: descarta la instruccion (salto tomado en EX, o fetch detenido por
//     HALT). Carga un NOP con valid = 0 (burbuja).
//   - stall: mantiene el valor (riesgo load-use: la instruccion repite ID).
//   - flush le gana a stall: si hay que descartarla, no importa que este frenada.
//
// IMPORTANTE: en reset y flush se carga NOP (0x00000013), NUNCA 0x00000000,
// porque 0 = HALT y el procesador se frenaria en el primer ciclo.
// valid = 0 marca burbujas, para que el dump distinga un NOP real de un hueco.
// ============================================================================
module if_id (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire        stall,
    input  wire        flush,

    input  wire [31:0] if_pc,
    input  wire [31:0] if_instr,

    output reg  [31:0] id_pc,
    output reg  [31:0] id_instr,
    output reg         id_valid
);

    always @(posedge clk) begin
        if (rst) begin
            id_pc    <= 32'd0;
            id_instr <= `INSTR_NOP;
            id_valid <= 1'b0;
        end
        else if (en) begin
            if (flush) begin
                id_pc    <= 32'd0;
                id_instr <= `INSTR_NOP;
                id_valid <= 1'b0;
            end
            else if (!stall) begin
                id_pc    <= if_pc;
                id_instr <= if_instr;
                id_valid <= 1'b1;
            end
        end
    end

endmodule
