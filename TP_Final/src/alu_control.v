`timescale 1ns/1ps
module alu_control(
    input wire [1:0] alu_op,
    input wire [6:0] funct7,
    input wire [2:0] funct3,

    output reg [3:0] alu_ctrl
);

always @(*) begin
    case(alu_op)
        2'b00: begin 
            alu_ctrl = 4'b0000;
        end

        2'b01: begin 
            alu_ctrl = {funct7[5], funct3};
        end

        2'b10: begin 
            if (funct3 == 3'b101) begin
                alu_ctrl = {funct7[5], funct3};
            end 
            else begin
                alu_ctrl = {1'b0, funct3};
            end

        end

        2'b11: begin 
             alu_ctrl = 4'b1111;
        end
    endcase
end

endmodule