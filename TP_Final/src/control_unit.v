`timescale 1ns/1ps
`include "riscv_defs.vh"
// ============================================================================
// control_unit.v - Decodificador de la etapa ID
//
// Combinacional: de la instruccion saca todas las senales de control que
// despues viajan por los latches. Cada etapa consume las suyas:
//   EX : alu_op, alu_src, a_zero, branch, jal, jalr
//   MEM: mem_read, mem_write   (+ funct3, que viaja aparte, para el tamano)
//   WB : reg_write, wb_sel
//
// | opcode  | tipo     | reg_write | alu_src | alu_op           | mem | wb_sel | otros   |
// | 0110011 | R        | 1         | rs2     | {instr[30],f3}   | -   | ALU    |         |
// | 0010011 | I aritm. | 1         | imm     | {b30 si f3=101,f3}| -  | ALU    |         |
// | 0000011 | load     | 1         | imm     | ADD              | R   | MEM    |         |
// | 0100011 | store    | 0         | imm     | ADD              | W   | -      |         |
// | 1100011 | branch   | 0         | rs2     | SUB              | -   | -      | branch  |
// | 0110111 | lui      | 1         | imm     | ADD              | -   | ALU    | a_zero  |
// | 1101111 | jal      | 1         | -       | -                | -   | PC+4   | jal     |
// | 1100111 | jalr     | 1         | imm     | ADD              | -   | PC+4   | jalr    |
// | 0x0000_0000 (HALT)  | 0         |         |                  |     |        | halt    |
//
// Decisiones de diseno:
//   - Instruccion ilegal o no implementada (blt, ld, funct7 invalido, ...):
//     todas las senales en 0, se comporta como NOP. illegal = 1 para el dump.
//   - El bit 30 solo se usa en tipo R y en srli/srai (funct3 = 101). En addi,
//     andi, etc. es parte del inmediato: usarlo convertiria addi negativo en SUB.
//   - use_rs1 / use_rs2 indican si la instruccion realmente lee esos registros.
//     En lui y jal los bits [19:15] y [24:20] son inmediato, no registros; sin
//     esto la hazard unit veria dependencias falsas.
// ============================================================================
module control_unit (
    input  wire [31:0] instr,

    output reg         reg_write,
    output reg         alu_src,    // 0: operando B = rs2, 1: operando B = imm
    output reg         a_zero,     // 1: operando A = 0 (lui)
    output reg  [3:0]  alu_op,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  wb_sel,
    output reg         branch,
    output reg         jal,
    output reg         jalr,
    output reg         halt,
    output reg         use_rs1,
    output reg         use_rs2,
    output reg         illegal
);

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    always @(*) begin
        // Por defecto todo en 0: la instruccion no modifica nada (NOP)
        reg_write = 1'b0;
        alu_src   = 1'b0;
        a_zero    = 1'b0;
        alu_op    = `ALU_ADD;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        wb_sel    = `WB_ALU;
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;
        halt      = 1'b0;
        use_rs1   = 1'b0;
        use_rs2   = 1'b0;
        illegal   = 1'b0;

        if (instr == `INSTR_HALT)
            halt = 1'b1;
        else begin
            case (opcode)
                `OP_R: begin
                    if (funct7 == 7'b0000000 ||
                        (funct7 == 7'b0100000 && (funct3 == 3'b000 || funct3 == 3'b101))) begin
                        reg_write = 1'b1;
                        use_rs1   = 1'b1;
                        use_rs2   = 1'b1;
                        alu_op    = {funct7[5], funct3};
                    end
                    else
                        illegal = 1'b1;
                end

                `OP_I_ARIT: begin
                    // En los shifts, imm[11:5] (= funct7) tiene que ser valido
                    if ((funct3 == 3'b001 && funct7 != 7'b0000000) ||
                        (funct3 == 3'b101 && funct7 != 7'b0000000 && funct7 != 7'b0100000))
                        illegal = 1'b1;
                    else begin
                        reg_write = 1'b1;
                        alu_src   = 1'b1;
                        use_rs1   = 1'b1;
                        alu_op    = {(funct3 == 3'b101) ? funct7[5] : 1'b0, funct3};
                    end
                end

                `OP_LOAD: begin
                    case (funct3)
                        3'b000, 3'b001, 3'b010, 3'b100, 3'b101: begin   // lb lh lw lbu lhu
                            reg_write = 1'b1;
                            alu_src   = 1'b1;
                            mem_read  = 1'b1;
                            wb_sel    = `WB_MEM;
                            use_rs1   = 1'b1;
                        end
                        default: illegal = 1'b1;
                    endcase
                end

                `OP_STORE: begin
                    case (funct3)
                        3'b000, 3'b001, 3'b010: begin                   // sb sh sw
                            alu_src   = 1'b1;
                            mem_write = 1'b1;
                            use_rs1   = 1'b1;
                            use_rs2   = 1'b1;
                        end
                        default: illegal = 1'b1;
                    endcase
                end

                `OP_BRANCH: begin
                    case (funct3)
                        3'b000, 3'b001: begin                           // beq bne
                            branch  = 1'b1;
                            alu_op  = `ALU_SUB;
                            use_rs1 = 1'b1;
                            use_rs2 = 1'b1;
                        end
                        default: illegal = 1'b1;
                    endcase
                end

                `OP_LUI: begin
                    reg_write = 1'b1;
                    alu_src   = 1'b1;
                    a_zero    = 1'b1;                                   // 0 + imm
                end

                `OP_JAL: begin
                    reg_write = 1'b1;
                    jal       = 1'b1;
                    wb_sel    = `WB_PC4;
                end

                `OP_JALR: begin
                    if (funct3 == 3'b000) begin
                        reg_write = 1'b1;
                        alu_src   = 1'b1;
                        jalr      = 1'b1;
                        wb_sel    = `WB_PC4;
                        use_rs1   = 1'b1;
                    end
                    else
                        illegal = 1'b1;
                end

                default: illegal = 1'b1;
            endcase
        end
    end

endmodule
