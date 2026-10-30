`timescale 1ns/1ps
// ============================================================================
// tb_control_unit.v - Testbench self-checking de la unidad de control
//
// Cada caso compara las 18 senales empaquetadas en este orden:
//   reg_write alu_src a_zero alu_op[3:0] mem_read mem_write wb_sel[1:0]
//   branch jal jalr halt use_rs1 use_rs2 illegal
// Incluye las 32 instrucciones, HALT, NOP y varias ilegales (tienen que dar
// todo en 0 salvo illegal).
// ============================================================================
module tb_control_unit;
    reg  [31:0] instr;
    wire        reg_write, alu_src, a_zero, mem_read, mem_write;
    wire        branch, jal, jalr, halt, use_rs1, use_rs2, illegal;
    wire [3:0]  alu_op;
    wire [1:0]  wb_sel;
    integer fallas = 0, total = 0;

    control_unit dut (
        .instr(instr), .reg_write(reg_write), .alu_src(alu_src), .a_zero(a_zero),
        .alu_op(alu_op), .mem_read(mem_read), .mem_write(mem_write), .wb_sel(wb_sel),
        .branch(branch), .jal(jal), .jalr(jalr), .halt(halt),
        .use_rs1(use_rs1), .use_rs2(use_rs2), .illegal(illegal)
    );

    wire [17:0] senales = {reg_write, alu_src, a_zero, alu_op, mem_read, mem_write,
                           wb_sel, branch, jal, jalr, halt, use_rs1, use_rs2, illegal};

    task check(input [31:0] ins, input [17:0] esperado, input [8*40-1:0] nombre);
        begin
            instr = ins; #1;
            total = total + 1;
            if (senales !== esperado) begin
                fallas = fallas + 1;
                $display("MAL  %0s: instr=%h senales=%b esperado=%b", nombre, ins, senales, esperado);
            end
        end
    endtask

    initial begin
        check(32'h003100B3, 18'b100000000000000110, "add x1, x2, x3");
        check(32'h403100B3, 18'b100100000000000110, "sub x1, x2, x3");
        check(32'h003110B3, 18'b100000100000000110, "sll x1, x2, x3");
        check(32'h003120B3, 18'b100001000000000110, "slt x1, x2, x3");
        check(32'h003130B3, 18'b100001100000000110, "sltu x1, x2, x3");
        check(32'h003140B3, 18'b100010000000000110, "xor x1, x2, x3");
        check(32'h003150B3, 18'b100010100000000110, "srl x1, x2, x3");
        check(32'h403150B3, 18'b100110100000000110, "sra x1, x2, x3");
        check(32'h003160B3, 18'b100011000000000110, "or x1, x2, x3");
        check(32'h003170B3, 18'b100011100000000110, "and x1, x2, x3");
        check(32'hFFF00093, 18'b110000000000000100, "addi x1, x0, -1");
        check(32'hFFF17093, 18'b110011100000000100, "andi x1, x2, -1");
        check(32'h00516093, 18'b110011000000000100, "ori x1, x2, 5");
        check(32'h00514093, 18'b110010000000000100, "xori x1, x2, 5");
        check(32'hFFD12093, 18'b110001000000000100, "slti x1, x2, -3");
        check(32'h00313093, 18'b110001100000000100, "sltiu x1, x2, 3");
        check(32'h00411093, 18'b110000100000000100, "slli x1, x2, 4");
        check(32'h00415093, 18'b110010100000000100, "srli x1, x2, 4");
        check(32'h40415093, 18'b110110100000000100, "srai x1, x2, 4");
        check(32'h00010083, 18'b110000010010000100, "lb x1, 0(x2)");
        check(32'h00011083, 18'b110000010010000100, "lh x1, 0(x2)");
        check(32'h00012083, 18'b110000010010000100, "lw x1, 0(x2)");
        check(32'h00014083, 18'b110000010010000100, "lbu x1, 0(x2)");
        check(32'h00015083, 18'b110000010010000100, "lhu x1, 0(x2)");
        check(32'h00110023, 18'b010000001000000110, "sb x1, 0(x2)");
        check(32'h00111023, 18'b010000001000000110, "sh x1, 0(x2)");
        check(32'h00112023, 18'b010000001000000110, "sw x1, 0(x2)");
        check(32'h00208463, 18'b000100000001000110, "beq x1, x2, 8");
        check(32'h00209463, 18'b000100000001000110, "bne x1, x2, 8");
        check(32'h123450B7, 18'b111000000000000000, "lui x1, 0x12345");
        check(32'h008000EF, 18'b100000000100100000, "jal x1, 8");
        check(32'h004100E7, 18'b110000000100010100, "jalr x1, 4(x2)");
        check(32'h00000000, 18'b000000000000001000, "halt");
        check(32'h00000013, 18'b110000000000000100, "nop");
        check(32'h022081B3, 18'b000000000000000001, "mul (funct7 = 0000001)");
        check(32'h00003083, 18'b000000000000000001, "ld (funct3 = 011)");
        check(32'h00004063, 18'b000000000000000001, "blt (funct3 = 100)");
        check(32'h00003023, 18'b000000000000000001, "sd (funct3 = 011)");
        check(32'h00000097, 18'b000000000000000001, "auipc (no implementada)");
        check(32'h0220D093, 18'b000000000000000001, "srli con funct7 invalido");
        check(32'h00001067, 18'b000000000000000001, "jalr con funct3 = 001");
        check(32'h00000080, 18'b000000000000000001, "opcode 0 con bits != 0 (no es HALT)");
        if (fallas == 0) $display("tb_control_unit: OK (%0d casos)", total);
        else             $display("tb_control_unit: %0d de %0d casos fallaron", fallas, total);
        $finish;
    end
endmodule
