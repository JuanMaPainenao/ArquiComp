`timescale 1ns/1ps
// ============================================================================
// imm_gen.v - Generador de inmediatos RV32I (etapa ID)
//
// Arma el inmediato de 32 bits segun el formato de la instruccion (lo da el
// opcode). Todos los formatos extienden el signo desde instr[31].
//   I : loads, aritmeticas con inmediato, jalr
//   S : stores
//   B : beq/bne      (offset en bytes, bit 0 = 0)
//   U : lui          (20 bits arriba, 12 ceros abajo)
//   J : jal          (offset en bytes, bit 0 = 0)
//   R / HALT / desconocida: no usan inmediato -> 0
// Combinacional, con default para no inferir latches.
// ============================================================================
module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);

    wire [6:0] opcode;
    assign opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            7'b0000011,                                                 // loads
            7'b0010011,                                                 // addi, slti, ...
            7'b1100111: imm = {{20{instr[31]}}, instr[31:20]};          // jalr       -> Tipo I

            7'b0100011: imm = {{20{instr[31]}}, instr[31:25],
                               instr[11:7]};                            // stores     -> Tipo S

            7'b1100011: imm = {{19{instr[31]}}, instr[31], instr[7],
                               instr[30:25], instr[11:8], 1'b0};        // beq, bne   -> Tipo B

            7'b0110111: imm = {instr[31:12], 12'b0};                    // lui        -> Tipo U

            7'b1101111: imm = {{11{instr[31]}}, instr[31], instr[19:12],
                               instr[20], instr[30:21], 1'b0};          // jal        -> Tipo J

            default:    imm = 32'd0;                                    // R, HALT, otras
        endcase
    end

endmodule
