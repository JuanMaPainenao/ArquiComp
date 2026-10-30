`timescale 1ns/1ps
// ============================================================================
// tb_imm_gen.v - Testbench self-checking del generador de inmediatos
// Casos positivos y negativos de cada formato, incluyendo los extremos de rango.
// ============================================================================
module tb_imm_gen;
    reg  [31:0] instr;
    wire [31:0] imm;
    integer fallas = 0, total = 0;

    imm_gen dut (.instr(instr), .imm(imm));

    task check(input [31:0] ins, input [31:0] esperado, input [8*24-1:0] nombre);
        begin
            instr = ins; #1;
            total = total + 1;
            if (imm !== esperado) begin
                fallas = fallas + 1;
                $display("MAL  %0s: instr=%h imm=%h esperado=%h", nombre, ins, imm, esperado);
            end
        end
    endtask

    initial begin
        check(32'h003100B3, 32'h00000000, "add x1, x2, x3");
        check(32'hFFB00093, 32'hFFFFFFFB, "addi x1, x0, -5");
        check(32'h7FF00093, 32'h000007FF, "addi x1, x0, 2047");
        check(32'h80012283, 32'hFFFFF800, "lw x5, -2048(x2)");
        check(32'hFFC08067, 32'hFFFFFFFC, "jalr x0, -4(x1)");
        check(32'h01F09093, 32'h0000001F, "slli x1, x1, 31");
        check(32'h4030D093, 32'h00000403, "srai x1, x1, 3");
        check(32'hFE512FA3, 32'hFFFFFFFF, "sw x5, -1(x2)");
        check(32'h7E951FA3, 32'h000007FF, "sh x9, 2047(x10)");
        check(32'h80110023, 32'hFFFFF800, "sb x1, -2048(x2)");
        check(32'h00208463, 32'h00000008, "beq x1, x2, 8");
        check(32'hFE209EE3, 32'hFFFFFFFC, "bne x1, x2, -4");
        check(32'h7E000FE3, 32'h00000FFE, "beq x0, x0, 4094");
        check(32'h80001063, 32'hFFFFF000, "bne x0, x0, -4096");
        check(32'h123452B7, 32'h12345000, "lui x5, 0x12345");
        check(32'hFFFFF2B7, 32'hFFFFF000, "lui x5, 0xFFFFF");
        check(32'h010000EF, 32'h00000010, "jal x1, 16");
        check(32'hFF9FF06F, 32'hFFFFFFF8, "jal x0, -8");
        check(32'h7FFFF06F, 32'h000FFFFE, "jal x0, 1048574");
        check(32'h8000006F, 32'hFFF00000, "jal x0, -1048576");
        if (fallas == 0) $display("tb_imm_gen: OK (%0d casos)", total);
        else             $display("tb_imm_gen: %0d de %0d casos fallaron", fallas, total);
        $finish;
    end
endmodule
