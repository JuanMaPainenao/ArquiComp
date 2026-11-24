`timescale 1ns/1ps
// tb_control_unit.v - Chequea todas las senales de control de cada opcode.
// Un opcode que no esta en el set tiene que dar todo en 0 (burbuja).
module tb_control_unit;

    reg  [6:0] opcode;
    wire       reg_write;
    wire       alu_src;
    wire [1:0] alu_op;
    wire       mem_read;
    wire       mem_write;
    wire [1:0] wb_sel;
    wire       branch;
    wire       jump;
    wire       jalr;
    wire       halt;
    wire       uses_rs1;
    wire       uses_rs2;

    integer errores = 0;

    control_unit dut (
        .opcode    (opcode),
        .reg_write (reg_write),
        .alu_src   (alu_src),
        .alu_op    (alu_op),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .wb_sel    (wb_sel),
        .branch    (branch),
        .jump      (jump),
        .jalr      (jalr),
        .halt      (halt),
        .uses_rs1  (uses_rs1),
        .uses_rs2  (uses_rs2)
    );

    // Todas las salidas juntas, en el orden de la tabla de abajo
    wire [13:0] salidas;
    assign salidas = {reg_write, alu_src, alu_op, mem_read, mem_write, wb_sel,
                      branch, jump, jalr, halt, uses_rs1, uses_rs2};

    task chk(input [6:0] op, input [13:0] exp, input [255:0] nombre);
        begin
            opcode = op;
            #1;
            if (salidas !== exp) begin
                $display("ERROR %0s: %b (esperado %b)", nombre, salidas, exp);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        //                rw as op  mr mw wb  br j jr h  u1 u2
        chk(7'b0110011, 14'b1_0_01_0_0_00_0_0_0_0_1_1, "tipo R");
        chk(7'b0010011, 14'b1_1_10_0_0_00_0_0_0_0_1_0, "tipo I");
        chk(7'b0000011, 14'b1_1_00_1_0_01_0_0_0_0_1_0, "load");
        chk(7'b0100011, 14'b0_1_00_0_1_00_0_0_0_0_1_1, "store");
        chk(7'b1100011, 14'b0_0_00_0_0_00_1_0_0_0_1_1, "branch");
        chk(7'b1101111, 14'b1_0_00_0_0_10_0_1_0_0_0_0, "jal");
        chk(7'b1100111, 14'b1_1_00_0_0_10_0_0_1_0_1_0, "jalr");
        chk(7'b0110111, 14'b1_1_11_0_0_00_0_0_0_0_0_0, "lui");
        chk(7'b0000000, 14'b0_0_00_0_0_00_0_0_0_1_0_0, "HALT 0000000");
        chk(7'b1111111, 14'b0_0_00_0_0_00_0_0_0_1_0_0, "HALT 1111111");
        chk(7'b0010111, 14'b0_0_00_0_0_00_0_0_0_0_0_0, "auipc (no esta en el set)");
        chk(7'b1110011, 14'b0_0_00_0_0_00_0_0_0_0_0_0, "ecall (no esta en el set)");

        if (errores == 0) begin
            $display("TEST OK");
        end
        else begin
            $display("TEST FALLIDO: %0d errores", errores);
        end
        $finish;
    end

endmodule
