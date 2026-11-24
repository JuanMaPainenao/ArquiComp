`timescale 1ns/1ps
// tb_forwarding_unit.v - Chequea fwd_a y fwd_b: cada camino, la prioridad,
// x0 y el caso sin reg_write.
module tb_forwarding_unit;

    reg  [4:0] rs1_ex;
    reg  [4:0] rs2_ex;
    reg  [4:0] rd_mem;
    reg  [4:0] rd_wb;
    reg        reg_write_mem;
    reg        reg_write_wb;
    wire [1:0] fwd_a;
    wire [1:0] fwd_b;

    integer errores = 0;

    forwarding_unit dut (
        .rs1_ex        (rs1_ex),
        .rs2_ex        (rs2_ex),
        .rd_mem        (rd_mem),
        .reg_write_mem (reg_write_mem),
        .rd_wb         (rd_wb),
        .reg_write_wb  (reg_write_wb),
        .fwd_a         (fwd_a),
        .fwd_b         (fwd_b)
    );

    // Pone las entradas, espera 1 ns y compara fwd_a y fwd_b
    task chk(input [4:0] r1, input [4:0] r2,
             input [4:0] rdm, input wm, input [4:0] rdw, input ww,
             input [1:0] exp_a, input [1:0] exp_b, input [255:0] nombre);
        begin
            rs1_ex        = r1;
            rs2_ex        = r2;
            rd_mem        = rdm;
            reg_write_mem = wm;
            rd_wb         = rdw;
            reg_write_wb  = ww;
            #1;
            if (fwd_a !== exp_a || fwd_b !== exp_b) begin
                $display("ERROR %0s: fwd_a=%b fwd_b=%b (esperado %b %b)",
                         nombre, fwd_a, fwd_b, exp_a, exp_b);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        //  rs1 rs2  rd_mem wr  rd_wb wr  fwd_a  fwd_b
        $display("--- 1. Sin dependencias");
        chk(1, 2,    3, 1,    4, 1,     2'b00, 2'b00, "rd distintos");

        $display("--- 2. Desde EX/MEM");
        chk(3, 2,    3, 1,    4, 1,     2'b01, 2'b00, "rs1 = rd_mem");
        chk(1, 3,    3, 1,    4, 1,     2'b00, 2'b01, "rs2 = rd_mem");
        chk(3, 3,    3, 1,    4, 1,     2'b01, 2'b01, "rs1 = rs2 = rd_mem");

        $display("--- 3. Desde MEM/WB");
        chk(4, 2,    3, 1,    4, 1,     2'b10, 2'b00, "rs1 = rd_wb");
        chk(1, 4,    3, 1,    4, 1,     2'b00, 2'b10, "rs2 = rd_wb");
        chk(3, 4,    3, 1,    4, 1,     2'b01, 2'b10, "rs1 de MEM, rs2 de WB");

        $display("--- 4. Prioridad");
        chk(5, 5,    5, 1,    5, 1,     2'b01, 2'b01, "MEM le gana a WB");
        chk(5, 5,    5, 0,    5, 1,     2'b10, 2'b10, "MEM no escribe -> WB");

        $display("--- 5. x0");
        chk(0, 0,    0, 1,    0, 1,     2'b00, 2'b00, "rd = x0");

        $display("--- 6. Sin reg_write");
        chk(3, 4,    3, 0,    4, 0,     2'b00, 2'b00, "store o branch adelante");

        if (errores == 0) begin
            $display("TEST OK");
        end
        else begin
            $display("TEST FALLIDO: %0d errores", errores);
        end
        $finish;
    end

endmodule
