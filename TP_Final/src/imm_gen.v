`timescale 1ns/1ps

// Arma el inmediato de 32 bits (con extension de signo) segun el formato
module imm_gen(
    input  wire [31:0] instr,
    output reg  [31:0] imm
);

    wire [6:0] opcode;

    assign opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            7'b0000011,
            7'b0010011,
            7'b1100111: begin   // Tipo I: loads, aritmeticas con inmediato, jalr
                imm = {{20{instr[31]}}, instr[31:20]};
            end
            7'b0100011: begin   // Tipo S: stores
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end
            7'b1100011: begin   // Tipo B: branches
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            end
            7'b0110111: begin   // Tipo U: lui
                imm = {instr[31:12], 12'b0};
            end
            7'b1101111: begin   // Tipo J: jal
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            end
            default: begin
                imm = 32'b0;
            end
        endcase
    end

endmodule
