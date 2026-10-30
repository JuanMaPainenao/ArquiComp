// ============================================================================
// riscv_defs.vh - Constantes compartidas del procesador
//
// En Vivado: agregarlo como fuente (Add Sources) junto con los .v. Lo incluyen
// control_unit.v, imm_gen.v, if_id.v y cpu.v (y despues la ALU de EX).
// ============================================================================
`ifndef RISCV_DEFS_VH
`define RISCV_DEFS_VH

// ---- Opcodes (instr[6:0]) ----
`define OP_R       7'b0110011
`define OP_I_ARIT  7'b0010011
`define OP_LOAD    7'b0000011
`define OP_STORE   7'b0100011
`define OP_BRANCH  7'b1100011
`define OP_LUI     7'b0110111
`define OP_JAL     7'b1101111
`define OP_JALR    7'b1100111

// ---- Instrucciones especiales ----
`define INSTR_HALT 32'h00000000   // decision de diseno: 0 = HALT
`define INSTR_NOP  32'h00000013   // addi x0, x0, 0

// ---- Operaciones de la ALU (alu_op) ----
// Codigo = {bit 30 de la instruccion, funct3}. Asi en tipo R sale directo de la
// instruccion y la ALU de EX solo tiene que hacer un case sobre estos 10 valores.
`define ALU_ADD  4'b0000
`define ALU_SLL  4'b0001
`define ALU_SLT  4'b0010
`define ALU_SLTU 4'b0011
`define ALU_XOR  4'b0100
`define ALU_SRL  4'b0101
`define ALU_OR   4'b0110
`define ALU_AND  4'b0111
`define ALU_SUB  4'b1000
`define ALU_SRA  4'b1101

// ---- Que se escribe en rd (wb_sel) ----
`define WB_ALU 2'b00
`define WB_MEM 2'b01
`define WB_PC4 2'b10

`endif
