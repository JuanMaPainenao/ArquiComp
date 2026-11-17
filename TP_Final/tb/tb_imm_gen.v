`timescale 1ns / 1ps
// ============================================================================
// tb_imm_gen.v - Testbench autoverificante de imm_gen.v
//
// Instrucciones reales (codificadas segun la spec RV32I) y el inmediato que
// tiene que salir. Incluye valores positivos, negativos y los extremos de
// cada formato.
// ============================================================================
module tb_imm_gen;

    reg  [31:0] instr;
    wire [31:0] imm;

    integer errores = 0;
    integer casos   = 0;

    imm_gen dut (
        .instr (instr),
        .imm   (imm)
    );

    task chk(input [31:0] ins, input [31:0] esperado, input [8*24-1:0] nombre);
        begin
            instr = ins;
            #1;
            casos = casos + 1;
            if (imm !== esperado) begin
                errores = errores + 1;
                $display("FALLA %0s: instr=%h -> imm=%h (esperado %h)",
                         nombre, ins, imm, esperado);
            end
        end
    endtask

    initial begin
        // ---------------- Tipo I ----------------
        chk(32'h00500093, 32'h00000005, "addi x1,x0,5");
        chk(32'hFFB00093, 32'hFFFFFFFB, "addi x1,x0,-5");
        chk(32'h7FF00093, 32'h000007FF, "addi imm max 2047");
        chk(32'h80000093, 32'hFFFFF800, "addi imm min -2048");
        chk(32'h00812283, 32'h00000008, "lw x5,8(x2)");
        chk(32'hFFC12283, 32'hFFFFFFFC, "lw x5,-4(x2)");
        chk(32'h00008067, 32'h00000000, "jalr x0,0(x1)");
        chk(32'h40415093, 32'h00000404, "srai x1,x2,4");       // imm crudo: funct7|shamt

        // ---------------- Tipo S ----------------
        chk(32'h00512423, 32'h00000008, "sw x5,8(x2)");
        chk(32'hFE512E23, 32'hFFFFFFFC, "sw x5,-4(x2)");
        chk(32'h7E512FA3, 32'h000007FF, "sw imm max 2047");

        // ---------------- Tipo B ----------------
        chk(32'hFE009CE3, 32'hFFFFFFF8, "bne x1,x0,-8");
        chk(32'h00208463, 32'h00000008, "beq x1,x2,+8");
        chk(32'h7E000FE3, 32'h00000FFE, "beq imm max 4094");
        chk(32'h80000063, 32'hFFFFF000, "beq imm min -4096");

        // ---------------- Tipo U ----------------
        chk(32'h123452B7, 32'h12345000, "lui x5,0x12345");
        chk(32'hFFFFF2B7, 32'hFFFFF000, "lui x5,0xFFFFF");

        // ---------------- Tipo J ----------------
        chk(32'h00C000EF, 32'h0000000C, "jal x1,+12");
        chk(32'hFF9FF0EF, 32'hFFFFFFF8, "jal x1,-8");
        chk(32'h7FFFF0EF, 32'h000FFFFE, "jal imm max");
        chk(32'h800000EF, 32'hFFF00000, "jal imm min");

        // ---------------- Sin inmediato -> 0 ----------------
        chk(32'h002081B3, 32'h00000000, "add (tipo R)");
        chk(32'h40208233, 32'h00000000, "sub (tipo R)");
        chk(32'h00000000, 32'h00000000, "HALT");

        if (errores == 0)
            $display("tb_imm_gen: OK (%0d casos)", casos);
        else
            $display("tb_imm_gen: %0d ERRORES de %0d casos", errores, casos);
        $finish;
    end

endmodule
