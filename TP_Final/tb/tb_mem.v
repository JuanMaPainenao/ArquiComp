`timescale 1ns/1ps
// tb_mem.v - Prueba mem.v con 1 KB: stores, loads con y sin signo, max_addr,
// puerto de debug, en = 0, direcciones fuera de rango y rst.
module tb_mem;

    reg         clk;
    reg         rst;
    reg         en;
    reg  [31:0] addr;
    reg  [31:0] store_data;
    reg  [2:0]  funct3;
    reg         mem_read;
    reg         mem_write;
    reg  [7:0]  dbg_addr;
    wire [31:0] load_data;
    wire [31:0] dbg_data;
    wire [9:0]  max_addr;

    integer errores = 0;

    mem #(.ADDR_W(10)) dut (
        .clk        (clk),
        .rst        (rst),
        .en         (en),
        .addr       (addr),
        .store_data (store_data),
        .funct3     (funct3),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .load_data  (load_data),
        .dbg_addr   (dbg_addr),
        .dbg_data   (dbg_data),
        .max_addr   (max_addr)
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

    // Store: mem_write en 1 durante un flanco
    task store(input [2:0] f3, input [31:0] a, input [31:0] d);
        begin
            @(negedge clk);
            funct3     = f3;
            addr       = a;
            store_data = d;
            mem_write  = 1;
            @(negedge clk);
            mem_write  = 0;
        end
    endtask

    // Load: la lectura es combinacional, no hace falta esperar un flanco
    task load(input [2:0] f3, input [31:0] a, input [31:0] exp, input [255:0] nombre);
        begin
            funct3   = f3;
            addr     = a;
            mem_read = 1;
            #1;
            check(nombre, load_data, exp);
            mem_read = 0;
        end
    endtask

    // Lee una palabra por el puerto de debug
    task debug(input [7:0] palabra, input [31:0] exp, input [255:0] nombre);
        begin
            dbg_addr = palabra;
            #1;
            check(nombre, dbg_data, exp);
        end
    endtask

    // Los valores iniciales se ponen aca y no en la declaracion, para que
    // generen un cambio en t = 0 y el always @(*) de las direcciones se evalue.
    initial begin
        clk        = 0;
        rst        = 1;
        en         = 1;
        addr       = 0;
        store_data = 0;
        funct3     = 0;
        mem_read   = 0;
        mem_write  = 0;
        dbg_addr   = 0;
        @(negedge clk);
        rst = 0;

        // funct3: 000 byte, 001 half, 010 word, 100 byte sin signo, 101 half sin signo
        $display("--- 1. Stores");
        store(3'b010, 0, 32'h12345680);    // sw
        store(3'b010, 4, 32'hFFFFFFFF);    // sw
        store(3'b000, 4, 32'h000000AB);    // sb: solo el byte 4
        store(3'b001, 6, 32'h00008001);    // sh: bytes 6 y 7
        load(3'b010, 0, 32'h12345680, "sw little endian");
        load(3'b010, 4, 32'h8001FFAB, "sb y sh no pisan de mas");

        $display("--- 2. Loads");
        load(3'b000, 0, 32'hFFFFFF80, "lb 0x80");
        load(3'b100, 0, 32'h00000080, "lbu 0x80");
        load(3'b000, 1, 32'h00000056, "lb 0x56");
        load(3'b001, 6, 32'hFFFF8001, "lh 0x8001");
        load(3'b101, 6, 32'h00008001, "lhu 0x8001");
        load(3'b001, 2, 32'h00001234, "lh 0x1234");

        $display("--- 3. max_addr");
        check("max_addr", max_addr, 7);
        store(3'b000, 2, 32'h00000077);    // mas abajo: no baja
        check("no baja", max_addr, 7);
        store(3'b001, 20, 32'h0000BEEF);   // ultimo byte: 21
        check("sube con sh", max_addr, 21);
        store(3'b010, 24, 32'h0BADF00D);   // ultimo byte: 27
        check("sube con sw", max_addr, 27);

        $display("--- 4. Puerto de debug");
        debug(0, 32'h12775680, "palabra 0");
        debug(1, 32'h8001FFAB, "palabra 1");
        debug(5, 32'h0000BEEF, "palabra 5");

        $display("--- 5. en = 0");
        en = 0;
        store(3'b010, 0, 32'hDEADDEAD);
        en = 1;
        load(3'b010, 0, 32'h12775680, "con en = 0 no escribe");

        $display("--- 6. Fuera de rango");
        store(3'b010, 1032, 32'hCAFECAFE);
        load(3'b010, 8, 32'hCAFECAFE, "1032 escribe en 8");

        $display("--- 7. rst");
        @(negedge clk);
        rst = 1;
        @(negedge clk);
        rst = 0;
        load(3'b010, 0, 32'h00000000, "rst borra la palabra 0");
        load(3'b010, 8, 32'h00000000, "rst borra la palabra 8");
        check("rst borra max_addr", max_addr, 0);

        if (errores == 0) begin
            $display("TEST OK");
        end
        else begin
            $display("TEST FALLIDO: %0d errores", errores);
        end
        $finish;
    end

endmodule
