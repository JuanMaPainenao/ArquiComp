`timescale 1ns / 1ps
// alu.v - ALU del TP1 adaptada a RV32I: hace la operacion que indica alu_ctrl
// (codigos en docs/ex.md). Los shifts usan solo B[4:0].


module alu #(
    parameter NB_DATA = 8,
    parameter NB_OP_CODE = 4
)
(
    input [NB_DATA-1:0] A,
    input [NB_DATA-1:0] B,
    input [NB_OP_CODE-1:0] alu_ctrl,
    output reg [NB_DATA-1:0] alu_result
    );
    localparam OP_ADD  = 4'b0000;
    localparam OP_SUB  = 4'b1000;
    localparam OP_SLL  = 4'b0001;
    localparam OP_SLT  = 4'b0010;
    localparam OP_SLTU = 4'b0011;
    localparam OP_XOR  = 4'b0100;
    localparam OP_SRL  = 4'b0101;
    localparam OP_SRA  = 4'b1101;
    localparam OP_OR   = 4'b0110;
    localparam OP_AND  = 4'b0111;
    localparam OP_PASS = 4'b1111;

    
    always @(*)begin
        case (alu_ctrl)
            OP_ADD: alu_result = A+B;
            OP_SUB: alu_result = A-B;
            OP_AND: alu_result = A&B;
            OP_OR:  alu_result = A|B;
            OP_XOR: alu_result = A^B;
            OP_SRL: alu_result = A >> B[4:0];
            OP_SRA: alu_result = $signed(A) >>> B[4:0];
            OP_SLL: alu_result = A << B[4:0];
            OP_SLT: alu_result = ($signed(A) < $signed(B)) ? 1 : 0;
            OP_SLTU: alu_result = (A < B) ? 1 : 0;
            OP_PASS: alu_result = B;
            default: alu_result = {NB_DATA{1'b0}};
         endcase
    end

endmodule
