`timescale 1ns/1ps
// ============================================================================
// ex.v - Etapa EX (Execute)
//
// Que hace:
//   Toma lo que preparo ID (guardado en el latch ID/EX) y CALCULA:
//     - el resultado de la operacion (add, sub, and, shifts, slt...)
//     - la direccion de memoria en loads/stores (rs1 + imm)
//     - si hay que saltar (beq/bne/jal/jalr) y a donde
//   Es combinacional: lo que sale se guarda en el latch EX/MEM (ex_mem.v,
//   modulo aparte) en el flanco siguiente.
//
// Decisiones de diseno (a confirmar y documentar en el informe):
//   - Los saltos se resuelven en EX -> penalidad de 2 ciclos (flush de IF/ID
//     e ID/EX cuando el salto se toma).
//   - Codificacion de alu_ctrl: acordar con quien hace la control_unit (ID).
//     Propuesta: alu_ctrl = {instr[30], funct3}, PASS_B (lui) = 4'b1111.
//   - El forwarding se agrega despues; al principio A = rs1_data, B = rs2_data.
//   - EX solo declara las senales que USA. Las que solo necesitan MEM y WB
//     (rd, pc4, reg_write, mem_read, mem_write, wb_sel, halt) van directo del
//     latch ID/EX al latch EX/MEM en el modulo que conecta todo, sin pasar
//     por aca. rs1/rs2 (numeros de registro) van a la unidad de forwarding.
// ============================================================================

module ex #(
    parameter NB_DATA = 32
)(
    // ---------------- Desde ID/EX: datos ----------------
    input  wire [NB_DATA-1:0] pc,               // PC de esta instruccion (destino = pc + imm)
    input  wire [NB_DATA-1:0] rs1_data,         // valor de rs1 -> operando A
    input  wire [NB_DATA-1:0] rs2_data,         // valor de rs2 -> operando B o dato del store
    input  wire [NB_DATA-1:0] imm,              // inmediato ya armado por imm_gen
    input  wire [2:0]         funct3,           // beq (000) / bne (001)

    // ---------------- Desde ID/EX: control ----------------
    input  wire               alu_src,          // B: 0 = rs2, 1 = imm
    input  wire [3:0]         alu_ctrl,         // operacion de la ALU
    input  wire               branch,           // beq/bne
    input  wire               jump,             // jal
    input  wire               jalr,             // jalr

    // ---------------- Forwarding (usar mas adelante) ----------------
    input  wire [NB_DATA-1:0] ex_mem_result,    // resultado de la instr. que esta en MEM
    input  wire [NB_DATA-1:0] mem_wb_data,      // dato de la instr. que esta en WB
    input  wire [1:0]         fwd_a,            // 00 rs1_data, 01 ex_mem_result, 10 mem_wb_data
    input  wire [1:0]         fwd_b,            // idem para rs2

    // ---------------- Hacia EX/MEM ----------------
    output wire [NB_DATA-1:0] alu_result,       // resultado o direccion de memoria
    output wire [NB_DATA-1:0] store_data,       // dato de sw/sh/sb (rs2 ya forwardeado)

    // ---------------- Hacia IF (saltos) ----------------
    output wire               redirect,         // salto tomado -> pc_unit
    output wire [NB_DATA-1:0] redirect_target,  // destino del salto -> pc_unit
    output wire               flush             // burbuja en IF/ID e ID/EX
);


// ----------------------------------------------------------------------------
// 1. FORWARDING: elegir el operando A y el valor de rs2
// ----------------------------------------------------------------------------
// A  = rs1_data | ex_mem_result | mem_wb_data   (segun fwd_a)
// B' = rs2_data | ex_mem_result | mem_wb_data   (segun fwd_b)
// Primera version: A = rs1_data, B' = rs2_data (sin forwarding).
//
wire [NB_DATA-1:0] A;
wire [NB_DATA-1:0] B_;
reg  [NB_DATA-1:0] B;          // reg: se asigna en un always

assign A = rs1_data;
assign B_ = rs2_data;

// ----------------------------------------------------------------------------
// 2. MUX DEL OPERANDO B
// ----------------------------------------------------------------------------
// B = alu_src ? imm : B'
//   alu_src = 0 -> instrucciones R y branches (usan rs2)
//   alu_src = 1 -> addi..., loads, stores, jalr, lui (usan imm)
//

always @(*)begin
    if (alu_src) begin
        B = imm;
    end else begin
        B = B_;
    end
end

// ----------------------------------------------------------------------------
// 3. ALU   (se puede hacer como modulo aparte: alu.v + tb_alu.v)
// ----------------------------------------------------------------------------
// alu_result = A <op> B segun alu_ctrl:
//   ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND, PASS_B (lui)
// Ojo:
//   - SRA y SLT son CON signo -> $signed(...)
//   - Los shifts usan solo B[4:0]
//   - Poner default para no inferir latches
//

alu #(
    .NB_DATA    (NB_DATA),     // 32: pisa el 8 que tiene por defecto
    .NB_OP_CODE (4)            // 4 bits de alu_ctrl
) u_alu (
    .A   (A),
    .B   (B),
    .OP  (alu_ctrl),
    .RES (alu_result)
);


// ----------------------------------------------------------------------------
// 4. DECISION DE SALTO
// ----------------------------------------------------------------------------
// iguales = (A == B')
// taken   = (branch && funct3 == beq && iguales)
//         | (branch && funct3 == bne && !iguales)
//         | jump | jalr
//
localparam F3_BEQ = 3'b000;
localparam F3_BNE = 3'b001;

wire iguales = (A == B_);       // se compara rs1 con rs2 (B_, no B)
reg  taken;                     // 1 = el salto se toma

always @(*) begin
    taken = 1'b0;               // valor por defecto: no salta (evita latch)

    if (branch && funct3 == F3_BEQ && iguales)       // beq: salta si son iguales
        taken = 1'b1;
    else if (branch && funct3 == F3_BNE && !iguales) // bne: salta si son distintos
        taken = 1'b1;
    else if (jump || jalr)                           // jal / jalr: siempre
        taken = 1'b1;
end

// ----------------------------------------------------------------------------
// 5. DESTINO DEL SALTO
// ----------------------------------------------------------------------------
// beq/bne/jal : redirect_target = pc + imm
// jalr        : redirect_target = (A + imm) & ~1      (se limpia el bit 0)
// redirect = taken, flush = taken
//


// ----------------------------------------------------------------------------
// 6. SALIDAS HACIA EX/MEM
// ----------------------------------------------------------------------------
// alu_result = resultado de la ALU
// store_data = B' (rs2 despues del forwarding, ANTES del mux de alu_src)
//


endmodule
