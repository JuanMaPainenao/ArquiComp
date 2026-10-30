`timescale 1ns/1ps
// ============================================================================
// id_ex.v - Latch entre ID y EX
//
// Prioridad: rst > !en (pausa) > flush/burbuja > cargar
//   - flush: pone en 0 SOLO las senales de control (y valid). Sin control la
//     instruccion no escribe registros ni memoria ni salta: es una burbuja.
//     Se usa para un salto tomado en EX y para la burbuja del load-use.
//   - Los datos se cargan igual: con el control en 0 no tienen efecto.
//
// Contenido (163 bits):
//   datos  : pc, rs1_data, rs2_data, imm                      128
//   campos : rs1, rs2, rd (en 0 si la instruccion no los usa)   15
//            funct3 (tamano del load/store, tipo de branch)      3
//   control: alu_op(4) alu_src a_zero branch jal jalr             9
//            mem_read mem_write                                  2
//            reg_write wb_sel(2)                                 3
//            halt valid illegal                                  3
// ============================================================================
module id_ex (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire        flush,

    // ---- Desde ID ----
    input  wire [31:0] id_pc,
    input  wire [31:0] id_rs1_data,
    input  wire [31:0] id_rs2_data,
    input  wire [31:0] id_imm,
    input  wire [4:0]  id_rs1,
    input  wire [4:0]  id_rs2,
    input  wire [4:0]  id_rd,
    input  wire [2:0]  id_funct3,

    input  wire [3:0]  id_alu_op,
    input  wire        id_alu_src,
    input  wire        id_a_zero,
    input  wire        id_branch,
    input  wire        id_jal,
    input  wire        id_jalr,
    input  wire        id_mem_read,
    input  wire        id_mem_write,
    input  wire        id_reg_write,
    input  wire [1:0]  id_wb_sel,
    input  wire        id_halt,
    input  wire        id_valid,
    input  wire        id_illegal,

    // ---- Hacia EX ----
    output reg  [31:0] ex_pc,
    output reg  [31:0] ex_rs1_data,
    output reg  [31:0] ex_rs2_data,
    output reg  [31:0] ex_imm,
    output reg  [4:0]  ex_rs1,
    output reg  [4:0]  ex_rs2,
    output reg  [4:0]  ex_rd,
    output reg  [2:0]  ex_funct3,

    output reg  [3:0]  ex_alu_op,
    output reg         ex_alu_src,
    output reg         ex_a_zero,
    output reg         ex_branch,
    output reg         ex_jal,
    output reg         ex_jalr,
    output reg         ex_mem_read,
    output reg         ex_mem_write,
    output reg         ex_reg_write,
    output reg  [1:0]  ex_wb_sel,
    output reg         ex_halt,
    output reg         ex_valid,
    output reg         ex_illegal
);

    always @(posedge clk) begin
        if (rst) begin
            ex_pc        <= 32'd0;
            ex_rs1_data  <= 32'd0;
            ex_rs2_data  <= 32'd0;
            ex_imm       <= 32'd0;
            ex_rs1       <= 5'd0;
            ex_rs2       <= 5'd0;
            ex_rd        <= 5'd0;
            ex_funct3    <= 3'd0;
        end
        else if (en) begin
            ex_pc        <= id_pc;
            ex_rs1_data  <= id_rs1_data;
            ex_rs2_data  <= id_rs2_data;
            ex_imm       <= id_imm;
            ex_rs1       <= id_rs1;
            ex_rs2       <= id_rs2;
            ex_rd        <= id_rd;
            ex_funct3    <= id_funct3;
        end
    end

    // Control: se pone en 0 con rst o con flush (burbuja)
    always @(posedge clk) begin
        if (rst || (en && flush)) begin
            ex_alu_op    <= 4'd0;
            ex_alu_src   <= 1'b0;
            ex_a_zero    <= 1'b0;
            ex_branch    <= 1'b0;
            ex_jal       <= 1'b0;
            ex_jalr      <= 1'b0;
            ex_mem_read  <= 1'b0;
            ex_mem_write <= 1'b0;
            ex_reg_write <= 1'b0;
            ex_wb_sel    <= 2'd0;
            ex_halt      <= 1'b0;
            ex_valid     <= 1'b0;
            ex_illegal   <= 1'b0;
        end
        else if (en) begin
            ex_alu_op    <= id_alu_op;
            ex_alu_src   <= id_alu_src;
            ex_a_zero    <= id_a_zero;
            ex_branch    <= id_branch;
            ex_jal       <= id_jal;
            ex_jalr      <= id_jalr;
            ex_mem_read  <= id_mem_read;
            ex_mem_write <= id_mem_write;
            ex_reg_write <= id_reg_write;
            ex_wb_sel    <= id_wb_sel;
            ex_halt      <= id_halt;
            ex_valid     <= id_valid;
            ex_illegal   <= id_illegal;
        end
    end

endmodule
