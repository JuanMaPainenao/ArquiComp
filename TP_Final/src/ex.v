`timescale 1ns/1ps

module ex #(
    parameter NB_DATA = 32
)(
    // Desde ID/EX
    input  wire [NB_DATA-1:0] pc,
    input  wire [NB_DATA-1:0] rs1_data,
    input  wire [NB_DATA-1:0] rs2_data,
    input  wire [NB_DATA-1:0] imm,
    input  wire [2:0]         funct3,
    input  wire               alu_src,
    input  wire [3:0]         alu_ctrl,
    input  wire               branch,
    input  wire               jump,
    input  wire               jalr,

    // Forwarding
    input  wire [NB_DATA-1:0] ex_mem_result,
    input  wire [NB_DATA-1:0] mem_wb_data,
    input  wire [1:0]         fwd_a,
    input  wire [1:0]         fwd_b,

    // Hacia EX/MEM
    output wire [NB_DATA-1:0] alu_result,
    output wire [NB_DATA-1:0] store_data,

    // Saltos
    output wire               redirect,
    output reg  [NB_DATA-1:0] redirect_target,
    output wire               flush
);

    localparam F3_BEQ  = 3'b000;
    localparam F3_BNE  = 3'b001;

    localparam FWD_ID  = 2'b00;
    localparam FWD_MEM = 2'b01;
    localparam FWD_WB  = 2'b10;

    reg  [NB_DATA-1:0] A;
    reg  [NB_DATA-1:0] B_;
    reg  [NB_DATA-1:0] B;
    reg                taken;

    // 1. Operandos con forwarding (00 dato de ID, 01 desde MEM, 10 desde WB)
    always @(*) begin
        case (fwd_a)
            FWD_MEM: begin
                A = ex_mem_result;
            end
            FWD_WB: begin
                A = mem_wb_data;
            end
            default: begin
                A = rs1_data;
            end
        endcase
    end

    always @(*) begin
        case (fwd_b)
            FWD_MEM: begin
                B_ = ex_mem_result;
            end
            FWD_WB: begin
                B_ = mem_wb_data;
            end
            default: begin
                B_ = rs2_data;
            end
        endcase
    end

    // 2. Mux del operando B
    always @(*) begin
        if (alu_src)
            B = imm;
        else
            B = B_;
    end

    // 3. ALU
    alu #(
        .NB_DATA    (NB_DATA),
        .NB_OP_CODE (4)
    ) u_alu (
        .A   (A),
        .B   (B),
        .OP  (alu_ctrl),
        .RES (alu_result)
    );

    // 4. Decision de salto
    wire iguales = (A == B_);

    always @(*) begin
        taken = 1'b0;
        if (branch && funct3 == F3_BEQ && iguales)
            taken = 1'b1;
        else if (branch && funct3 == F3_BNE && !iguales)
            taken = 1'b1;
        else if (jump || jalr)
            taken = 1'b1;
    end

    // 5. Destino del salto
    always @(*) begin
        if (jalr)
            redirect_target = (A + imm) & ~32'b1;
        else
            redirect_target = pc + imm;
    end

    assign redirect = taken;
    assign flush    = taken;

    // 6. Salidas hacia EX/MEM
    assign store_data = B_;

endmodule
