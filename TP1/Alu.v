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


module Alu #(
    parameter NB_DATA = 8,
    parameter NB_OP_CODE = 6
)
(
    input [NB_DATA-1:0] A,
    input [NB_DATA-1:0] B,
    input [NB_OP_CODE-1:0] OP,
    output reg [NB_DATA-1:0] RES,
    output [0:0] CARRY,
    output [0:0] OVF
    );
    localparam OP_ADD = 6'b100000;
    localparam OP_SUB = 6'b100010;
    localparam OP_AND = 6'b100100;
    localparam OP_OR = 6'b100101;
    localparam OP_XOR = 6'b100110;
    localparam OP_SRA = 6'b000011;
    localparam OP_SRL = 6'b000010;
    localparam OP_NOR = 6'b100111;
    
    always @(*)begin
        case (OP)
            OP_ADD: RES = A+B;
            OP_SUB: RES = A-B;
            OP_AND: RES = A&B;
            OP_OR:  RES = A|B;
            OP_XOR: RES = A^B;
            OP_SRL: RES = A>>B;
            OP_SRA: RES = $signed(A) >>> B;
            OP_NOR: RES = ~(A|B);
            default: RES = 8'b0;
         endcase
    end

endmodule
