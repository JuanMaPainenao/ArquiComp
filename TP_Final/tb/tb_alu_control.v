`timescale 1ns/1ps
// tb_alu_control.v - Chequea el alu_ctrl de cada instruccion para los 4
// valores de alu_op. Los codigos estan en docs/ex.md (seccion 5).
module tb_alu_control;

    reg  [1:0] alu_op;
    reg  [6:0] funct7;
    reg  [2:0] funct3;
    wire [3:0] alu_ctrl;

    integer errores = 0;

    alu_control dut (
        .alu_op   (alu_op),
        .funct7   (funct7),
        .funct3   (funct3),
        .alu_ctrl (alu_ctrl)
    );

    task chk(input [1:0] op, input [6:0] f7, input [2:0] f3,
             input [3:0] exp, input [255:0] nombre);
        begin
            alu_op = op;
            funct7 = f7;
            funct3 = f3;
            #1;
            if (alu_ctrl !== exp) begin
                $display("ERROR %0s: alu_ctrl=%b (esperado %b)", nombre, alu_ctrl, exp);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        $display("--- alu_op 00: siempre ADD");
        chk(2'b00, 7'h00, 3'b010, 4'b0000, "lw");
        chk(2'b00, 7'h7F, 3'b001, 4'b0000, "bne");

        $display("--- alu_op 01: tipo R");
        chk(2'b01, 7'h00, 3'b000, 4'b0000, "add");
        chk(2'b01, 7'h20, 3'b000, 4'b1000, "sub");
        chk(2'b01, 7'h00, 3'b001, 4'b0001, "sll");
        chk(2'b01, 7'h00, 3'b010, 4'b0010, "slt");
        chk(2'b01, 7'h00, 3'b011, 4'b0011, "sltu");
        chk(2'b01, 7'h00, 3'b100, 4'b0100, "xor");
        chk(2'b01, 7'h00, 3'b101, 4'b0101, "srl");
        chk(2'b01, 7'h20, 3'b101, 4'b1101, "sra");
        chk(2'b01, 7'h00, 3'b110, 4'b0110, "or");
        chk(2'b01, 7'h00, 3'b111, 4'b0111, "and");

        // En tipo I funct7 es parte del inmediato: con 7'h7F el inmediato es
        // negativo y no tiene que cambiar la operacion (salvo srli / srai).
        $display("--- alu_op 10: tipo I");
        chk(2'b10, 7'h00, 3'b000, 4'b0000, "addi");
        chk(2'b10, 7'h7F, 3'b000, 4'b0000, "addi negativo no es resta");
        chk(2'b10, 7'h00, 3'b001, 4'b0001, "slli");
        chk(2'b10, 7'h7F, 3'b010, 4'b0010, "slti negativo");
        chk(2'b10, 7'h00, 3'b011, 4'b0011, "sltiu");
        chk(2'b10, 7'h20, 3'b100, 4'b0100, "xori con el bit 30 en 1");
        chk(2'b10, 7'h00, 3'b101, 4'b0101, "srli");
        chk(2'b10, 7'h20, 3'b101, 4'b1101, "srai");
        chk(2'b10, 7'h7F, 3'b110, 4'b0110, "ori negativo");
        chk(2'b10, 7'h7F, 3'b111, 4'b0111, "andi negativo");

        $display("--- alu_op 11: lui");
        chk(2'b11, 7'h12, 3'b011, 4'b1111, "PASS_B");

        if (errores == 0) begin
            $display("TEST OK");
        end
        else begin
            $display("TEST FALLIDO: %0d errores", errores);
        end
        $finish;
    end

endmodule
