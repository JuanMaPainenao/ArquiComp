`timescale 1ns/1ps

// Pipeline completo: IF -> ID -> EX -> MEM -> WB, con forwarding y hazard unit
module cpu #(
    parameter IMEM_ADDR_W = 8,          // 256 instrucciones
    parameter DMEM_ADDR_W = 10          // 1 KB de datos
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   en,
    output wire                   halted,

    // Debug: memoria de programa
    input  wire                   dbg_imem_we,
    input  wire [IMEM_ADDR_W-1:0] dbg_imem_addr,
    input  wire [31:0]            dbg_imem_wdata,
    output wire [31:0]            dbg_imem_rdata,

    // Debug: registros
    input  wire [4:0]             dbg_reg_addr,
    output wire [31:0]            dbg_reg_data,

    // Debug: memoria de datos
    input  wire [DMEM_ADDR_W-3:0] dbg_dmem_addr,
    output wire [31:0]            dbg_dmem_data,
    output wire [DMEM_ADDR_W-1:0] dmem_max_addr,

    // Debug: PC actual
    output wire [31:0]            pc,

    // Debug: latches intermedios y señales de riesgo (ver mux al final)
    input  wire [4:0]             dbg_latch_sel,
    output reg  [31:0]            dbg_latch_data
);

    // ======================= Señales =======================
    // IF
    wire [31:0] pc4;
    wire [31:0] if_instr;

    // IF/ID
    wire [31:0] ifid_instr;
    wire [31:0] ifid_pc;
    wire [31:0] ifid_pc4;

    // ID
    wire [4:0]  id_rd;
    wire [4:0]  id_rs1;
    wire [4:0]  id_rs2;
    wire [2:0]  id_funct3;
    wire [6:0]  id_funct7;
    wire [31:0] id_rs1_data;
    wire [31:0] id_rs2_data;
    wire [31:0] id_imm;
    wire        id_reg_write;
    wire        id_alu_src;
    wire [1:0]  id_alu_op;
    wire        id_mem_read;
    wire        id_mem_write;
    wire [1:0]  id_wb_sel;
    wire        id_branch;
    wire        id_jump;
    wire        id_jalr;
    wire        id_halt;
    wire        id_uses_rs1;
    wire        id_uses_rs2;

    // ID/EX
    wire [31:0] idex_rs1_data;
    wire [31:0] idex_rs2_data;
    wire [4:0]  idex_rd;
    wire [2:0]  idex_funct3;
    wire [4:0]  idex_rs1;
    wire [4:0]  idex_rs2;
    wire [6:0]  idex_funct7;
    wire [31:0] idex_pc;
    wire [31:0] idex_pc4;
    wire [31:0] idex_imm;
    wire        idex_reg_write;
    wire        idex_alu_src;
    wire [1:0]  idex_alu_op;
    wire        idex_mem_read;
    wire        idex_mem_write;
    wire [1:0]  idex_wb_sel;
    wire        idex_branch;
    wire        idex_jump;
    wire        idex_jalr;
    wire        idex_halt;
    wire        idex_uses_rs1;
    wire        idex_uses_rs2;

    // EX
    wire [3:0]  ex_alu_ctrl;
    wire [31:0] ex_alu_result;
    wire [31:0] ex_store_data;
    wire        ex_redirect;
    wire [31:0] ex_redirect_target;

    // EX/MEM
    wire [31:0] exmem_alu_result;
    wire [31:0] exmem_store_data;
    wire [4:0]  exmem_rd;
    wire [2:0]  exmem_funct3;
    wire [31:0] exmem_pc4;
    wire        exmem_reg_write;
    wire        exmem_mem_read;
    wire        exmem_mem_write;
    wire [1:0]  exmem_wb_sel;
    wire        exmem_halt;

    // MEM
    wire [31:0] mem_load_data;

    // MEM/WB
    wire [31:0] memwb_load_data;
    wire [31:0] memwb_alu_result;
    wire [31:0] memwb_pc4;
    wire [4:0]  memwb_rd;
    wire        memwb_reg_write;
    wire [1:0]  memwb_wb_sel;
    wire        memwb_halt;

    // WB
    wire [31:0] wb_write_data;
    wire [4:0]  wb_rd;
    wire        wb_reg_write;

    // Hazards
    wire [1:0]  fwd_a;
    wire [1:0]  fwd_b;
    wire        stall;
    wire        fetch_stop;
    wire        flush_if_id;
    wire        flush_id_ex;

    // ======================= Hazards =======================
    // Load-use (stall + burbuja), saltos tomados (flush) y HALT (frena el fetch)
    hazard_unit u_hazard (
        .clk         (clk),
        .rst         (rst),
        .en          (en),
        .rs1_id      (id_rs1),
        .rs2_id      (id_rs2),
        .uses_rs1_id (id_uses_rs1),
        .uses_rs2_id (id_uses_rs2),
        .halt_id     (id_halt),
        .mem_read_ex (idex_mem_read),
        .rd_ex       (idex_rd),
        .redirect    (ex_redirect),
        .stall       (stall),
        .fetch_stop  (fetch_stop),
        .flush_if_id (flush_if_id),
        .flush_id_ex (flush_id_ex)
    );

    // Adelanta a EX el resultado de la instruccion que esta en MEM o en WB
    forwarding_unit u_fwd (
        .rs1_ex        (idex_rs1),
        .rs2_ex        (idex_rs2),
        .rd_mem        (exmem_rd),
        .reg_write_mem (exmem_reg_write),
        .rd_wb         (memwb_rd),
        .reg_write_wb  (memwb_reg_write),
        .fwd_a         (fwd_a),
        .fwd_b         (fwd_b)
    );

    // ======================= IF =======================
    pc_unit u_pc (
        .clk             (clk),
        .rst             (rst),
        .en              (en),
        .stall           (stall),
        .fetch_stop            (fetch_stop),
        .redirect        (ex_redirect),
        .redirect_target (ex_redirect_target),
        .pc              (pc),
        .pc4             (pc4)
    );

    instr_mem #(
        .ADDR_W (IMEM_ADDR_W)
    ) u_imem (
        .clk       (clk),
        .pc        (pc),
        .instr     (if_instr),
        .dbg_we    (dbg_imem_we),
        .dbg_addr  (dbg_imem_addr),
        .dbg_wdata (dbg_imem_wdata),
        .dbg_rdata (dbg_imem_rdata)
    );

    // ======================= IF/ID =======================
    if_id u_if_id (
        .clk       (clk),
        .rst       (rst),
        .en        (en),
        .stall     (stall),
        .flush     (flush_if_id),
        .instr_in  (if_instr),
        .pc_in     (pc),
        .pc4_in    (pc4),
        .instr_out (ifid_instr),
        .pc_out    (ifid_pc),
        .pc4_out   (ifid_pc4)
    );

    // ======================= ID =======================
    id_stage u_id (
        .clk          (clk),
        .rst          (rst),
        .en           (en),
        .wb_reg_write        (wb_reg_write),
        .wb_rd        (wb_rd),
        .wb_write_data      (wb_write_data),
        .instr        (ifid_instr),
        .rd           (id_rd),
        .funct3       (id_funct3),
        .rs1          (id_rs1),
        .rs2          (id_rs2),
        .funct7       (id_funct7),
        .rs1_data     (id_rs1_data),
        .rs2_data     (id_rs2_data),
        .dbg_reg_addr (dbg_reg_addr),
        .dbg_reg_data (dbg_reg_data),
        .imm          (id_imm),
        .reg_write    (id_reg_write),
        .alu_src      (id_alu_src),
        .alu_op       (id_alu_op),
        .mem_read     (id_mem_read),
        .mem_write    (id_mem_write),
        .wb_sel       (id_wb_sel),
        .branch       (id_branch),
        .jump         (id_jump),
        .jalr         (id_jalr),
        .halt         (id_halt),
        .uses_rs1     (id_uses_rs1),
        .uses_rs2     (id_uses_rs2)
    );

    // ======================= ID/EX =======================
    id_ex u_id_ex (
        .clk           (clk),
        .rst           (rst),
        .en            (en),
        .flush         (flush_id_ex),
        .rs1_data_in   (id_rs1_data),
        .rs2_data_in   (id_rs2_data),
        .rs1_data_out  (idex_rs1_data),
        .rs2_data_out  (idex_rs2_data),
        .rd_in         (id_rd),
        .funct3_in     (id_funct3),
        .rs1_in        (id_rs1),
        .rs2_in        (id_rs2),
        .funct7_in     (id_funct7),
        .rd_out        (idex_rd),
        .funct3_out    (idex_funct3),
        .rs1_out       (idex_rs1),
        .rs2_out       (idex_rs2),
        .funct7_out    (idex_funct7),
        .pc_in         (ifid_pc),
        .pc4_in        (ifid_pc4),
        .pc_out        (idex_pc),
        .pc4_out       (idex_pc4),
        .imm_in        (id_imm),
        .imm_out       (idex_imm),
        .reg_write_in  (id_reg_write),
        .alu_src_in    (id_alu_src),
        .alu_op_in     (id_alu_op),
        .mem_read_in   (id_mem_read),
        .mem_write_in  (id_mem_write),
        .wb_sel_in     (id_wb_sel),
        .branch_in     (id_branch),
        .jump_in       (id_jump),
        .jalr_in       (id_jalr),
        .halt_in       (id_halt),
        .uses_rs1_in   (id_uses_rs1),
        .uses_rs2_in   (id_uses_rs2),
        .reg_write_out (idex_reg_write),
        .alu_src_out   (idex_alu_src),
        .alu_op_out    (idex_alu_op),
        .mem_read_out  (idex_mem_read),
        .mem_write_out (idex_mem_write),
        .wb_sel_out    (idex_wb_sel),
        .branch_out    (idex_branch),
        .jump_out      (idex_jump),
        .jalr_out      (idex_jalr),
        .halt_out      (idex_halt),
        .uses_rs1_out  (idex_uses_rs1),
        .uses_rs2_out  (idex_uses_rs2)
    );

    // ======================= EX =======================
    alu_control u_alu_control (
        .alu_op   (idex_alu_op),
        .funct7   (idex_funct7),
        .funct3   (idex_funct3),
        .alu_ctrl (ex_alu_ctrl)
    );

    ex u_ex (
        .pc              (idex_pc),
        .rs1_data        (idex_rs1_data),
        .rs2_data        (idex_rs2_data),
        .imm             (idex_imm),
        .funct3          (idex_funct3),
        .alu_src         (idex_alu_src),
        .alu_ctrl        (ex_alu_ctrl),
        .branch          (idex_branch),
        .jump            (idex_jump),
        .jalr            (idex_jalr),
        .exmem_alu_result   (exmem_alu_result),
        .wb_write_data     (wb_write_data),
        .fwd_a           (fwd_a),
        .fwd_b           (fwd_b),
        .alu_result      (ex_alu_result),
        .store_data      (ex_store_data),
        .redirect        (ex_redirect),
        .redirect_target (ex_redirect_target)
    );

    // ======================= EX/MEM =======================
    ex_mem u_ex_mem (
        .clk            (clk),
        .rst            (rst),
        .en             (en),
        .alu_result_in  (ex_alu_result),
        .store_data_in  (ex_store_data),
        .rd_in          (idex_rd),
        .funct3_in      (idex_funct3),
        .pc4_in         (idex_pc4),
        .reg_write_in   (idex_reg_write),
        .mem_read_in    (idex_mem_read),
        .mem_write_in   (idex_mem_write),
        .wb_sel_in      (idex_wb_sel),
        .halt_in        (idex_halt),
        .alu_result_out (exmem_alu_result),
        .store_data_out (exmem_store_data),
        .rd_out         (exmem_rd),
        .funct3_out     (exmem_funct3),
        .pc4_out        (exmem_pc4),
        .reg_write_out  (exmem_reg_write),
        .mem_read_out   (exmem_mem_read),
        .mem_write_out  (exmem_mem_write),
        .wb_sel_out     (exmem_wb_sel),
        .halt_out       (exmem_halt)
    );

    // ======================= MEM =======================
    mem #(
        .ADDR_W (DMEM_ADDR_W)
    ) u_mem (
        .clk        (clk),
        .rst        (rst),
        .en         (en),
        .addr       (exmem_alu_result),
        .store_data (exmem_store_data),
        .funct3     (exmem_funct3),
        .mem_read   (exmem_mem_read),
        .mem_write  (exmem_mem_write),
        .load_data  (mem_load_data),
        .dbg_addr   (dbg_dmem_addr),
        .dbg_data   (dbg_dmem_data),
        .max_addr   (dmem_max_addr)
    );

    // ======================= MEM/WB =======================
    mem_wb u_mem_wb (
        .clk            (clk),
        .rst            (rst),
        .en             (en),
        .load_data_in   (mem_load_data),
        .alu_result_in  (exmem_alu_result),
        .pc4_in         (exmem_pc4),
        .rd_in          (exmem_rd),
        .reg_write_in   (exmem_reg_write),
        .wb_sel_in      (exmem_wb_sel),
        .halt_in        (exmem_halt),
        .load_data_out  (memwb_load_data),
        .alu_result_out (memwb_alu_result),
        .pc4_out        (memwb_pc4),
        .rd_out         (memwb_rd),
        .reg_write_out  (memwb_reg_write),
        .wb_sel_out     (memwb_wb_sel),
        .halt_out       (memwb_halt)
    );

    // ======================= WB =======================
    wb u_wb (
        .clk            (clk),
        .rst            (rst),
        .en             (en),
        .load_data_in   (memwb_load_data),
        .alu_result_in  (memwb_alu_result),
        .pc4_in         (memwb_pc4),
        .rd_in          (memwb_rd),
        .reg_write_in   (memwb_reg_write),
        .wb_sel_in      (memwb_wb_sel),
        .halt_in        (memwb_halt),
        .write_data_out (wb_write_data),
        .rd_out         (wb_rd),
        .reg_write_out  (wb_reg_write),
        .halted         (halted)
    );

    // ======================= Debug: latches =======================
    // Elige que latch o senal de riesgo se manda en el dump. La tabla de
    // indices y de bits esta en docs/debug_unit.md (seccion 7).
    always @(*) begin
        case (dbg_latch_sel)
            5'd0: begin
                dbg_latch_data = if_instr;
            end
            5'd1: begin
                dbg_latch_data = ifid_instr;
            end
            5'd2: begin
                dbg_latch_data = ifid_pc4;
            end
            5'd3: begin
                dbg_latch_data = idex_pc4;
            end
            5'd4: begin
                dbg_latch_data = idex_rs1_data;
            end
            5'd5: begin
                dbg_latch_data = idex_rs2_data;
            end
            5'd6: begin
                dbg_latch_data = idex_imm;
            end
            5'd7: begin
                dbg_latch_data = {idex_rd, idex_rs1, idex_rs2, idex_funct3,
                                  idex_funct7[5], idex_reg_write, idex_alu_src,
                                  idex_alu_op, idex_mem_read, idex_mem_write,
                                  idex_wb_sel, idex_branch, idex_jump,
                                  idex_jalr, idex_halt, 1'b0};
            end
            5'd8: begin
                dbg_latch_data = exmem_pc4;
            end
            5'd9: begin
                dbg_latch_data = exmem_alu_result;
            end
            5'd10: begin
                dbg_latch_data = {exmem_rd, exmem_funct3, exmem_reg_write,
                                  exmem_mem_read, exmem_mem_write,
                                  exmem_wb_sel, exmem_halt, 18'd0};
            end
            5'd11: begin
                dbg_latch_data = memwb_pc4;
            end
            5'd12: begin
                dbg_latch_data = memwb_alu_result;
            end
            5'd13: begin
                dbg_latch_data = memwb_load_data;
            end
            5'd14: begin
                dbg_latch_data = {memwb_rd, 3'd0, memwb_reg_write,
                                  2'b00, memwb_wb_sel, memwb_halt, 18'd0};
            end
            5'd15: begin
                dbg_latch_data = {22'd0, halted, fwd_b, fwd_a, fetch_stop,
                                  ex_redirect, flush_id_ex, flush_if_id,
                                  stall};
            end
            5'd16: begin
                dbg_latch_data = ex_alu_result;
            end
            5'd17: begin
                dbg_latch_data = ex_redirect_target;
            end
            5'd18: begin
                dbg_latch_data = wb_write_data;
            end
            5'd19: begin
                dbg_latch_data = exmem_store_data;
            end
            default: begin
                dbg_latch_data = 32'hDEADBEEF;
            end
        endcase
    end

endmodule
