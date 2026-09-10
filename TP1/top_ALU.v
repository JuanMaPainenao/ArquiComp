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
    parameter NB_DATA = 8
)
(
    input [NB_DATA-1: 0]switch,
    input [0:0] clock,
    input en_a,
    input en_b,
    input en_op,
    output [NB_DATA-1:0] reg_res
    );
    
    reg [NB_DATA-1:0]reg_a;
    reg [NB_DATA-1:0]reg_b;
    reg [6-1:0]reg_op;

    
    Alu mi_alu(
        .A (reg_a),
        .B (reg_b),
        .OP (reg_op),
        .RES (reg_res)
    );
    
    always @(posedge clock)begin
        if (en_a)
            reg_a <= switch;
    end
    
    always @(posedge clock)begin
        if (en_b)
            reg_b <= switch;
    end
    
    always @(posedge clock)begin
        if (en_op)
            reg_op <= switch;
    end
    
    
endmodule
