`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/26/2026 09:37:21 PM
// Design Name: 
// Module Name: top_ALU
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


module top_ALU #(
    parameter NB_DATA = 8,
)
(
    input [NB_DATA-1: 0]switch;
    input [0:0] clock_a;
    input [0:0] clock_b;
    input [0:0] clock_op;
    output reg [0:0] reg_res;
    );
    
    reg [NB_DATA-1:0]reg_a;
    reg [NB_DATA-1:0]reg_b;
    reg [6-1:0]reg_op;
    Alu mi_alu(
        .a (reg_a),
        .b (reg_b),
        .alu_op (OP),
        .result ()
    );
    
    always @(posedge clock_a)begin
        reg_a = switch;
    end
    
    always @(posedge clock_b)begin
        reg_b = switch;
    end
    
    always @(posedge clock_op)begin
        reg_op = switch;
    end
    
    
endmodule
