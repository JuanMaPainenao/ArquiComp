`timescale 1ns/1ps
`include "riscv_defs.vh"
// ============================================================================
// cpu.v - Procesador RISC-V segmentado (por ahora: IF + ID)
//
// Separado del top para poder probarlo sin la UART: el testbench maneja
// directo los puertos de carga, el enable y el dump.
//
//   IF : pc_unit + instr_mem
//   ID : control_unit + imm_gen + reg_file
//   Latches: IF/ID, ID/EX
//
// Senales de etapas que todavia no existen (quedan en 0, ver "PENDIENTES"):
//   flush_branch / branch_target  -> EX (salto tomado)
//   stall_load_use                -> hazard detection unit
//   wb_reg_write / wb_rd / wb_data -> WB
//
// HALT:
//   - Cuando ID decodifica el HALT, se congela el PC, IF/ID carga burbujas y se
//     activa fetch_stopped, que queda en 1 hasta el reset. Si solo se frenara
//     el PC mientras el HALT esta en ID, al ciclo siguiente (con un NOP en ID)
//     el PC volveria a avanzar.
//   - Un salto tomado le gana: el HALT era del camino equivocado.
//   - El HALT sigue bajando por los latches. "halted" = el HALT llego al ultimo
//     latch que existe. Hoy es ID/EX; cuando este WB pasa a ser MEM/WB.
//   - Con halted = 1 el procesador se congela solo (run = en & ~halted), aunque
//     la Debug Unit ya corta cpu_en por su lado.
//
// Dump (dump_idx -> dump_data), N_DUMP = 43 palabras:
//    0  PC (IF)
//    1  instruccion leida en IF
//    2  IF/ID.pc
//    3  IF/ID.instr
//    4  flags: {29'b0, halted, fetch_stopped, IF/ID.valid}
//    5  ID/EX.pc
//    6  ID/EX.rs1_data
//    7  ID/EX.rs2_data
//    8  ID/EX.imm
//    9  ID/EX campos: {14'b0, funct3[17:15], rd[14:10], rs2[9:5], rs1[4:0]}
//   10  ID/EX control, bit a bit:
//         [3:0] alu_op  [4] alu_src  [5] a_zero  [6] branch  [7] jal
//         [8] jalr  [9] mem_read  [10] mem_write  [11] reg_write
//         [13:12] wb_sel  [14] halt  [15] valid  [16] illegal
//   11..42  x0..x31
// ============================================================================
module cpu #(
    parameter ADDR_W = 8
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              en,           // enable de la Debug Unit

    // Carga de programa (Debug Unit)
    input  wire              imem_we,
    input  wire [ADDR_W-1:0] imem_addr,
    input  wire [31:0]       imem_wdata,

    output wire              halted,

    // Dump
    input  wire [7:0]        dump_idx,
    output reg  [31:0]       dump_data
);

    localparam DUMP_REG0 = 8'd11;          // indice del dump donde arranca x0

    // ======================= PENDIENTES (etapas futuras) ====================
    wire        flush_branch   = 1'b0;     // EX: salto tomado
    wire [31:0] branch_target  = 32'd0;    // EX: destino del salto
    wire        stall_load_use = 1'b0;     // hazard detection unit
    wire        wb_reg_write   = 1'b0;     // WB
    wire [4:0]  wb_rd          = 5'd0;
    wire [31:0] wb_data        = 32'd0;

    // Enable efectivo: con el HALT al final del pipeline no se mueve nada mas
    wire run = en & ~halted;

    // ================================ IF ====================================
    wire [31:0] if_pc;
    wire [31:0] if_pc_plus4;
    wire [31:0] if_instr;

    wire        id_halt;                   // HALT decodificado en ID
    reg         fetch_stopped;
    wire        stop_fetch = id_halt | fetch_stopped;

    pc_unit u_pc (
        .clk             (clk),
        .rst             (rst),
        .en              (run),
        .stall           (stall_load_use),
        .halt            (stop_fetch),
        .redirect        (flush_branch),
        .redirect_target (branch_target),
        .pc              (if_pc),
        .pc_plus4        (if_pc_plus4)
    );

    instr_mem #(.ADDR_W(ADDR_W)) u_imem (
        .clk       (clk),
        .pc        (if_pc),
        .instr     (if_instr),
        .dbg_we    (imem_we),
        .dbg_addr  (imem_addr),
        .dbg_wdata (imem_wdata),
        .dbg_rdata ()
    );

    // Se activa cuando el HALT pasa por ID (y no lo descarta un salto)
    always @(posedge clk) begin
        if (rst)
            fetch_stopped <= 1'b0;
        else if (run && id_halt && !flush_branch)
            fetch_stopped <= 1'b1;
    end

    // =============================== IF/ID ==================================
    wire [31:0] id_pc;
    wire [31:0] id_instr;
    wire        id_valid;

    if_id u_if_id (
        .clk      (clk),
        .rst      (rst),
        .en       (run),
        .stall    (stall_load_use),
        .flush    (flush_branch | stop_fetch),
        .if_pc    (if_pc),
        .if_instr (if_instr),
        .id_pc    (id_pc),
        .id_instr (id_instr),
        .id_valid (id_valid)
    );

    // ================================ ID ====================================
    wire        c_reg_write, c_alu_src, c_a_zero, c_mem_read, c_mem_write;
    wire        c_branch, c_jal, c_jalr, c_use_rs1, c_use_rs2, c_illegal;
    wire [3:0]  c_alu_op;
    wire [1:0]  c_wb_sel;

    control_unit u_ctrl (
        .instr     (id_instr),
        .reg_write (c_reg_write),
        .alu_src   (c_alu_src),
        .a_zero    (c_a_zero),
        .alu_op    (c_alu_op),
        .mem_read  (c_mem_read),
        .mem_write (c_mem_write),
        .wb_sel    (c_wb_sel),
        .branch    (c_branch),
        .jal       (c_jal),
        .jalr      (c_jalr),
        .halt      (id_halt),
        .use_rs1   (c_use_rs1),
        .use_rs2   (c_use_rs2),
        .illegal   (c_illegal)
    );

    wire [31:0] id_imm;
    imm_gen u_imm (
        .instr (id_instr),
        .imm   (id_imm)
    );

    // Campos de registro: en 0 si la instruccion no los usa, asi el forwarding
    // y la hazard unit nunca comparan bits que en realidad son inmediato.
    wire [4:0] id_rs1 = c_use_rs1   ? id_instr[19:15] : 5'd0;
    wire [4:0] id_rs2 = c_use_rs2   ? id_instr[24:20] : 5'd0;
    wire [4:0] id_rd  = c_reg_write ? id_instr[11:7]  : 5'd0;

    wire [31:0] id_rs1_data, id_rs2_data;
    wire [4:0]  rf_dbg_addr;
    wire [31:0] rf_dbg_data;

    reg_file u_rf (
        .clk      (clk),
        .rst      (rst),
        .en       (run),
        .rs1_addr (id_rs1),
        .rs2_addr (id_rs2),
        .rs1_data (id_rs1_data),
        .rs2_data (id_rs2_data),
        .we       (wb_reg_write),
        .rd_addr  (wb_rd),
        .rd_data  (wb_data),
        .dbg_addr (rf_dbg_addr),
        .dbg_data (rf_dbg_data)
    );

    // =============================== ID/EX ==================================
    wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire [2:0]  ex_funct3;
    wire [3:0]  ex_alu_op;
    wire [1:0]  ex_wb_sel;
    wire        ex_alu_src, ex_a_zero, ex_branch, ex_jal, ex_jalr;
    wire        ex_mem_read, ex_mem_write, ex_reg_write;
    wire        ex_halt, ex_valid, ex_illegal;

    id_ex u_id_ex (
        .clk          (clk),
        .rst          (rst),
        .en           (run),
        .flush        (flush_branch | stall_load_use),

        .id_pc        (id_pc),
        .id_rs1_data  (id_rs1_data),
        .id_rs2_data  (id_rs2_data),
        .id_imm       (id_imm),
        .id_rs1       (id_rs1),
        .id_rs2       (id_rs2),
        .id_rd        (id_rd),
        .id_funct3    (id_instr[14:12]),
        .id_alu_op    (c_alu_op),
        .id_alu_src   (c_alu_src),
        .id_a_zero    (c_a_zero),
        .id_branch    (c_branch),
        .id_jal       (c_jal),
        .id_jalr      (c_jalr),
        .id_mem_read  (c_mem_read),
        .id_mem_write (c_mem_write),
        .id_reg_write (c_reg_write),
        .id_wb_sel    (c_wb_sel),
        .id_halt      (id_halt),
        .id_valid     (id_valid),
        .id_illegal   (c_illegal),

        .ex_pc        (ex_pc),
        .ex_rs1_data  (ex_rs1_data),
        .ex_rs2_data  (ex_rs2_data),
        .ex_imm       (ex_imm),
        .ex_rs1       (ex_rs1),
        .ex_rs2       (ex_rs2),
        .ex_rd        (ex_rd),
        .ex_funct3    (ex_funct3),
        .ex_alu_op    (ex_alu_op),
        .ex_alu_src   (ex_alu_src),
        .ex_a_zero    (ex_a_zero),
        .ex_branch    (ex_branch),
        .ex_jal       (ex_jal),
        .ex_jalr      (ex_jalr),
        .ex_mem_read  (ex_mem_read),
        .ex_mem_write (ex_mem_write),
        .ex_reg_write (ex_reg_write),
        .ex_wb_sel    (ex_wb_sel),
        .ex_halt      (ex_halt),
        .ex_valid     (ex_valid),
        .ex_illegal   (ex_illegal)
    );

    // Provisorio: el ultimo latch que existe es ID/EX
    assign halted = ex_halt;

    // =============================== Dump ===================================
    wire [7:0] reg_idx = dump_idx - DUMP_REG0;
    assign rf_dbg_addr = reg_idx[4:0];

    always @(*) begin
        case (dump_idx)
            8'd0:  dump_data = if_pc;
            8'd1:  dump_data = if_instr;
            8'd2:  dump_data = id_pc;
            8'd3:  dump_data = id_instr;
            8'd4:  dump_data = {29'd0, halted, fetch_stopped, id_valid};
            8'd5:  dump_data = ex_pc;
            8'd6:  dump_data = ex_rs1_data;
            8'd7:  dump_data = ex_rs2_data;
            8'd8:  dump_data = ex_imm;
            8'd9:  dump_data = {14'd0, ex_funct3, ex_rd, ex_rs2, ex_rs1};
            8'd10: dump_data = {15'd0, ex_illegal, ex_valid, ex_halt, ex_wb_sel,
                                ex_reg_write, ex_mem_write, ex_mem_read, ex_jalr,
                                ex_jal, ex_branch, ex_a_zero, ex_alu_src, ex_alu_op};
            default: begin
                if (dump_idx >= DUMP_REG0 && dump_idx < DUMP_REG0 + 8'd32)
                    dump_data = rf_dbg_data;
                else
                    dump_data = 32'hDEADBEEF;
            end
        endcase
    end

endmodule
