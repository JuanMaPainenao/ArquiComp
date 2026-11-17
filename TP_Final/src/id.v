`timescale 1ns/1ps

module id_stage(

    // Basics
    input  wire clk,
    input  wire rst,
    input  wire en, 
    
    // WB inputs
    input wire wb_we,
    input wire [4:0] wb_rd,
    input wire [31:0] wb_data,

    // Decoding
    input wire [31:0] instr,
    output wire [4:0] rd,
    output wire [2:0] funct3,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [6:0] funct7,

    // Output data source register
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data, 

    // Debug ports
    input  wire [4:0]  dbg_reg_addr,
    output wire [31:0] dbg_reg_data,

    //immgen
    output wire [31:0] imm,

    //control unit
    output wire reg_write,
    output wire alu_src,
    output wire [1:0] alu_op,
    output wire mem_read,
    output wire mem_write,
    output wire [1:0] wb_sel,
    output wire branch,
    output wire jump,
    output wire jalr,
    output wire halt,
    output wire uses_rs1,
    output wire uses_rs2

);
    wire [6:0] opcode;

    reg_file u_reg_file(
        .clk(clk),
        .rst(rst),
        .en(en),

        .rs1(rs1),
        .rs2(rs2),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),

        .rd(wb_rd),
        .we(wb_we),
        .rd_data(wb_data),

        .dbg_addr(dbg_reg_addr),
        .dbg_data(dbg_reg_data)

    );

    imm_gen u_imm_gen(
        .instr(instr),
        .imm(imm)
    );

    control_unit u_control_unit(
        .opcode(opcode),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .wb_sel(wb_sel),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .halt(halt),
        .uses_rs1(uses_rs1),
        .uses_rs2(uses_rs2)
    );




    assign opcode = instr[6:0];
    assign rd = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign funct7 = instr[31:25];


endmodule