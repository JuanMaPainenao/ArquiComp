`timescale 1ns/1ps
`include "riscv_defs.vh"
// ============================================================================
// imm_gen.v - Generador de inmediatos (etapa ID)
//
// Arma el inmediato de 32 bits con extension de signo segun el formato, que
// se deduce del opcode:
//   I (aritm. I, loads, jalr): {{20{i[31]}}, i[31:20]}
//   S (stores)               : {{20{i[31]}}, i[31:25], i[11:7]}
//   B (beq, bne)             : {{19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 0}
//   U (lui)                  : {i[31:12], 12'b0}
//   J (jal)                  : {{11{i[31]}}, i[31], i[19:12], i[20], i[30:21], 0}
//
// En B y J el bit 0 siempre es 0 (los saltos son a direcciones pares), por eso
// la instruccion no lo guarda y los bits estan mezclados.
// En los shifts (slli/srli/srai) el shamt es imm[4:0]; la ALU usa solo esos bits.
// ============================================================================
module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);

    always @(*) begin
        case (instr[6:0])
            `OP_I_ARIT, `OP_LOAD, `OP_JALR:
                imm = {{20{instr[31]}}, instr[31:20]};
            `OP_STORE:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            `OP_BRANCH:
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            `OP_LUI:
                imm = {instr[31:12], 12'b0};
            `OP_JAL:
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            default:
                imm = 32'd0;
        endcase
    end

endmodule
