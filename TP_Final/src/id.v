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
    output wire [31:0] dbg_reg_data

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



    assign opcode = instr[6:0];
    assign rd = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign funct7 = instr[31:25];


endmodule