`timescale 1ns/1ps
// ============================================================================
// tb_reg_file.v - Testbench self-checking del banco de registros
//
// Prueba: reset en 0, escritura y lectura, x0 siempre 0, escritura bloqueada
// con en = 0 y con we = 0, bypass (leer el registro que WB escribe en el
// mismo ciclo), puerto de debug sin bypass, y reset que borra todo.
// ============================================================================
module tb_reg_file;
    reg         clk = 0, rst = 1, en = 1, we = 0;
    reg  [4:0]  rs1_addr = 0, rs2_addr = 0, rd_addr = 0, dbg_addr = 0;
    reg  [31:0] rd_data = 0;
    wire [31:0] rs1_data, rs2_data, dbg_data;
    integer fallas = 0, total = 0, i;

    reg_file dut (
        .clk(clk), .rst(rst), .en(en),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rs1_data(rs1_data), .rs2_data(rs2_data),
        .we(we), .rd_addr(rd_addr), .rd_data(rd_data),
        .dbg_addr(dbg_addr), .dbg_data(dbg_data)
    );

    always #5 clk = ~clk;

    task check(input [31:0] valor, input [31:0] esperado, input [8*40-1:0] nombre);
        begin
            total = total + 1;
            if (valor !== esperado) begin
                fallas = fallas + 1;
                $display("MAL  %0s: %h (esperado %h)", nombre, valor, esperado);
            end
        end
    endtask

    // Escribe en el proximo flanco y deja we en 0
    task escribir(input [4:0] r, input [31:0] d);
        begin
            @(negedge clk); we = 1; rd_addr = r; rd_data = d;
            @(negedge clk); we = 0;
        end
    endtask

    initial begin
        @(negedge clk); rst = 0;

        // 1) Despues del reset todo en 0
        for (i = 0; i < 32; i = i + 1) begin
            dbg_addr = i; #1;
            check(dbg_data, 0, "reset: registro en 0");
        end

        // 2) Escribir x1..x31 con un valor reconocible y leerlos por rs1 y rs2
        for (i = 1; i < 32; i = i + 1)
            escribir(i, 32'hA0000000 + i);
        for (i = 0; i < 32; i = i + 1) begin
            rs1_addr = i; rs2_addr = 31 - i; #1;
            check(rs1_data, (i == 0) ? 0 : 32'hA0000000 + i, "lectura rs1");
            check(rs2_data, (31 - i == 0) ? 0 : 32'hA0000000 + (31 - i), "lectura rs2");
        end

        // 3) x0 no se escribe
        escribir(0, 32'hFFFFFFFF);
        rs1_addr = 0; dbg_addr = 0; #1;
        check(rs1_data, 0, "x0 sigue en 0 (rs1)");
        check(dbg_data, 0, "x0 sigue en 0 (dbg)");

        // 4) Con en = 0 no escribe (procesador en pausa)
        en = 0;
        escribir(5, 32'h12345678);
        en = 1;
        dbg_addr = 5; #1;
        check(dbg_data, 32'hA0000005, "en = 0 bloquea la escritura");

        // 5) Bypass: WB escribe x7 mientras ID lee x7 en el mismo ciclo
        @(negedge clk);
        we = 1; rd_addr = 7; rd_data = 32'hCAFE0007; rs1_addr = 7; rs2_addr = 7; dbg_addr = 7; #1;
        check(rs1_data, 32'hCAFE0007, "bypass rs1");
        check(rs2_data, 32'hCAFE0007, "bypass rs2");
        check(dbg_data, 32'hA0000007, "dbg sin bypass (todavia el viejo)");
        // Sin bypass a x0: escribir x0 y leer x0 tiene que dar 0
        rd_addr = 0; rs1_addr = 0; #1;
        check(rs1_data, 0, "sin bypass hacia x0");
        rd_addr = 7; rs1_addr = 7;
        @(negedge clk); we = 0; #1;
        check(dbg_data, 32'hCAFE0007, "x7 quedo escrito");

        // 6) Bypass solo si en = 1
        en = 0; we = 1; rd_addr = 9; rd_data = 32'h99999999; rs1_addr = 9; #1;
        check(rs1_data, 32'hA0000009, "sin bypass con en = 0");
        @(negedge clk); we = 0; en = 1;

        // 7) Reset borra todo
        rst = 1; @(negedge clk); rst = 0;
        for (i = 0; i < 32; i = i + 1) begin
            dbg_addr = i; #1;
            check(dbg_data, 0, "reset borra");
        end

        if (fallas == 0) $display("tb_reg_file: OK (%0d chequeos)", total);
        else             $display("tb_reg_file: %0d de %0d chequeos fallaron", fallas, total);
        $finish;
    end
endmodule
