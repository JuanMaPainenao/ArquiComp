`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/26/2026 08:51:24 PM
// Design Name: 
// Module Name: Alu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module alu #(
    parameter NB_DATA = 8,
    parameter NB_OP_CODE = 4
)
(
    input [NB_DATA-1:0] A,
    input [NB_DATA-1:0] B,
    input [NB_OP_CODE-1:0] OP,
    output reg [NB_DATA-1:0] RES
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
        case (OP)
            OP_ADD: RES = A+B;
            OP_SUB: RES = A-B;
            OP_AND: RES = A&B;
            OP_OR:  RES = A|B;
            OP_XOR: RES = A^B;
            OP_SRL: RES = A >> B[4:0];
            OP_SRA: RES = $signed(A) >>> B[4:0];
            OP_SLL: RES = A << B[4:0];
            OP_SLT: RES = ($signed(A) < $signed(B)) ? 1 : 0;
            OP_SLTU: RES = (A < B) ? 1 : 0;
            OP_PASS: RES = B;
            default: RES = {NB_DATA{1'b0}};
         endcase
    end

endmodule
