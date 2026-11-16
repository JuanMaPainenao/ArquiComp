`timescale 1ns/1ps
// ============================================================================
// tb_reg_file.v - Testbench autoverificante del banco de registros
//   1. Despues del reset todo vale 0
//   2. Escritura y lectura por rs1, rs2 y debug
//   3. x0 no se escribe
//   4. Bypass: leer el registro que se esta escribiendo devuelve el dato nuevo
//   5. Con en = 0 no se escribe
//   6. rst vuelve todo a 0
// ============================================================================
module tb_reg_file;

    reg         clk = 0, rst = 1, en = 1, we = 0;
    reg  [4:0]  rs1 = 0, rs2 = 0, rd = 0, dbg_addr = 0;
    reg  [31:0] rd_data = 0;
    wire [31:0] rs1_data, rs2_data, dbg_data;

    integer errores = 0;
    integer k;

    reg_file dut (
        .clk(clk), .rst(rst), .en(en),
        .rs1(rs1), .rs2(rs2), .rs1_data(rs1_data), .rs2_data(rs2_data),
        .we(we), .rd(rd), .rd_data(rd_data),
        .dbg_addr(dbg_addr), .dbg_data(dbg_data)
    );

    always #5 clk = ~clk;

    task check(input [255:0] nombre, input [31:0] got, input [31:0] exp);
        begin
            if (got !== exp) begin
                $display("ERROR %0s: got=%h esperado=%h", nombre, got, exp);
                errores = errores + 1;
            end
        end
    endtask

    task write(input [4:0] r, input [31:0] d);
        begin
            @(negedge clk); we = 1; rd = r; rd_data = d;
            @(negedge clk); we = 0;
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk) rst = 0;

        $display("--- 1. Reset");
        for (k = 0; k < 32; k = k + 1) begin
            dbg_addr = k; #1;
            check("reset", dbg_data, 0);
        end

        $display("--- 2. Escritura / lectura");
        for (k = 1; k < 32; k = k + 1)
            write(k, 32'hA000_0000 + k);
        for (k = 1; k < 32; k = k + 1) begin
            rs1 = k; rs2 = 32 - k; dbg_addr = k; #1;
            check("rs1", rs1_data, 32'hA000_0000 + k);
            check("rs2", rs2_data, 32'hA000_0000 + (32 - k));
            check("dbg", dbg_data, 32'hA000_0000 + k);
        end

        $display("--- 3. x0");
        write(0, 32'hFFFF_FFFF);
        rs1 = 0; dbg_addr = 0; #1;
        check("x0 rs1", rs1_data, 0);
        check("x0 dbg", dbg_data, 0);
        @(negedge clk); we = 1; rd = 0; rd_data = 32'h1234; rs1 = 0; #1;
        check("x0 bypass", rs1_data, 0);
        @(negedge clk); we = 0;

        $display("--- 4. Bypass");
        @(negedge clk); we = 1; rd = 5; rd_data = 32'hCAFE_0005; rs1 = 5; rs2 = 5; #1;
        check("bypass rs1", rs1_data, 32'hCAFE_0005);
        check("bypass rs2", rs2_data, 32'hCAFE_0005);
        @(negedge clk); we = 0; #1;
        check("post bypass", rs1_data, 32'hCAFE_0005);

        $display("--- 5. en = 0");
        en = 0;
        write(6, 32'hDEAD_0006);
        rs1 = 6; #1;
        check("en=0", rs1_data, 32'hA000_0006);
        @(negedge clk); we = 1; rd = 6; rd_data = 32'hDEAD_0006; rs1 = 6; #1;
        check("en=0 sin bypass", rs1_data, 32'hA000_0006);
        @(negedge clk); we = 0; en = 1;

        $display("--- 6. rst");
        @(negedge clk) rst = 1;
        @(negedge clk) rst = 0;
        for (k = 0; k < 32; k = k + 1) begin
            dbg_addr = k; #1;
            check("rst", dbg_data, 0);
        end

        if (errores == 0) $display("TEST OK");
        else              $display("TEST FALLIDO: %0d errores", errores);
        $finish;
    end

endmodule
