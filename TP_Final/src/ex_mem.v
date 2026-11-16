`timescale 1ns/1ps
// ============================================================================
// ex_mem.v - Latch EX/MEM
//
// Guarda lo que sale de EX (alu_result, store_data) y lo que viene directo
// de ID/EX sin pasar por EX (rd, funct3, pc4 y el control de MEM y WB).
//
//   rst  -> burbuja: todo en 0 (reg_write = mem_write = 0, no hace nada)
//   !en  -> se mantiene (Debug Unit pausada)
//   en   -> avanza
//
// No tiene flush ni stall: los saltos solo descartan IF/ID e ID/EX, y en un
// load-use la burbuja se mete en ID/EX, asi que EX/MEM siempre avanza.
// ============================================================================
module ex_mem #(
    parameter NB_DATA = 32
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               en,

    // ---------------- Desde EX ----------------
    input  wire [NB_DATA-1:0] alu_result_in,    // resultado o direccion de memoria
    input  wire [NB_DATA-1:0] store_data_in,    // dato de sw/sh/sb

    // ---------------- Desde ID/EX (directo) ----------------
    input  wire [4:0]         rd_in,            // registro destino
    input  wire [2:0]         funct3_in,        // tamano/signo del load/store
    input  wire [NB_DATA-1:0] pc4_in,           // retorno de jal/jalr
    input  wire               reg_write_in,     // WB: escribe rd
    input  wire               mem_read_in,      // MEM: load
    input  wire               mem_write_in,     // MEM: store
    input  wire [1:0]         wb_sel_in,        // WB: 00 ALU, 01 memoria, 10 PC+4
    input  wire               halt_in,          // HALT viajando hacia WB

    // ---------------- Hacia MEM ----------------
    output reg  [NB_DATA-1:0] alu_result_out,
    output reg  [NB_DATA-1:0] store_data_out,
    output reg  [4:0]         rd_out,
    output reg  [2:0]         funct3_out,
    output reg  [NB_DATA-1:0] pc4_out,
    output reg                reg_write_out,
    output reg                mem_read_out,
    output reg                mem_write_out,
    output reg  [1:0]         wb_sel_out,
    output reg                halt_out
);

    always @(posedge clk) begin
        if (rst) begin
            alu_result_out <= {NB_DATA{1'b0}};
            store_data_out <= {NB_DATA{1'b0}};
            rd_out         <= 5'd0;
            funct3_out     <= 3'd0;
            pc4_out        <= {NB_DATA{1'b0}};
            reg_write_out  <= 1'b0;
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            wb_sel_out     <= 2'b00;
            halt_out       <= 1'b0;
        end
        else if (en) begin
            alu_result_out <= alu_result_in;
            store_data_out <= store_data_in;
            rd_out         <= rd_in;
            funct3_out     <= funct3_in;
            pc4_out        <= pc4_in;
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            wb_sel_out     <= wb_sel_in;
            halt_out       <= halt_in;
        end
        // si !en no se asigna nada -> los registros mantienen su valor
    end

endmodule
