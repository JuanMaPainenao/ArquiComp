`timescale 1ns/1ps
// tb_debug_unit.v - Prueba cada comando de la Debug Unit sin UART: el tb manda
// los bytes directo por rx_data / rx_done y hace de tx_uart.
module tb_debug_unit;

    localparam DUMP_WORDS = 3;                  // palabras del dump de prueba
    localparam DUMP_LEN   = 1 + 4 * DUMP_WORDS; // bytes: estado + palabras
    localparam RUN_CICLOS = 7;                  // ciclos hasta el HALT en modo R

    reg         clk;
    reg         rst;
    reg  [7:0]  rx_data;
    reg         rx_done;
    reg         tx_done;
    reg         cpu_halted;
    wire        tx_start;
    wire [7:0]  tx_data;
    wire        cpu_en;
    wire        cpu_rst;
    wire        imem_we;
    wire [7:0]  imem_addr;
    wire [31:0] imem_wdata;
    wire [31:0] imem_rdata;
    wire [7:0]  dump_idx;
    wire [31:0] dump_data;

    reg  [31:0] imem [0:255];   // memoria de programa del tb
    reg  [7:0]  rsp  [0:255];   // bytes que mando la Debug Unit
    reg  [2:0]  tx_cnt;         // ciclos que faltan para tx_done

    integer n_rsp;              // cantidad de bytes recibidos
    integer en_ciclos;          // ciclos con cpu_en = 1
    integer rst_pulsos;         // pulsos de cpu_rst
    integer errores = 0;
    integer k;

    debug_unit #(.ADDR_W(8), .DUMP_W(8)) dut (
        .clk        (clk),
        .rst        (rst),
        .rx_data    (rx_data),
        .rx_done    (rx_done),
        .br_tick    (1'b1),
        .tx_done    (tx_done),
        .tx_start   (tx_start),
        .tx_data    (tx_data),
        .cpu_en     (cpu_en),
        .cpu_rst    (cpu_rst),
        .cpu_halted (cpu_halted),
        .imem_we    (imem_we),
        .imem_addr  (imem_addr),
        .imem_wdata (imem_wdata),
        .imem_rdata (imem_rdata),
        .dump_idx   (dump_idx),
        .dump_data  (dump_data),
        .dump_words (DUMP_WORDS[13:0])
    );

    always #5 clk = ~clk;

    // Memoria de programa: escritura por el puerto de la Debug Unit
    always @(posedge clk) begin
        if (imem_we) begin
            imem[imem_addr] <= imem_wdata;
        end
    end
    assign imem_rdata = imem[imem_addr];

    // Dump de prueba: la palabra k vale D0000000 + k
    assign dump_data = 32'hD0000000 + dump_idx;

    // tx_uart falso: guarda el byte y 4 ciclos despues responde tx_done
    always @(posedge clk) begin
        tx_done <= 1'b0;
        if (tx_start) begin
            rsp[n_rsp] <= tx_data;
            n_rsp      <= n_rsp + 1;
            tx_cnt     <= 3'd4;
        end
        else if (tx_cnt != 0) begin
            tx_cnt <= tx_cnt - 1;
            if (tx_cnt == 1) begin
                tx_done <= 1'b1;
            end
        end
    end

    // Procesador falso: cuenta ciclos habilitados y en modo R levanta halted
    always @(posedge clk) begin
        if (cpu_en) begin
            en_ciclos <= en_ciclos + 1;
            if (en_ciclos == RUN_CICLOS - 1) begin
                cpu_halted <= 1'b1;
            end
        end
        if (cpu_rst) begin
            rst_pulsos <= rst_pulsos + 1;
        end
    end

    task check(input [255:0] nombre, input [31:0] got, input [31:0] exp);
        begin
            if (got !== exp) begin
                $display("ERROR %0s: got=%h esperado=%h", nombre, got, exp);
                errores = errores + 1;
            end
        end
    endtask

    // Manda un byte: rx_done en 1 durante un ciclo
    task send(input [7:0] b);
        begin
            @(negedge clk);
            rx_data = b;
            rx_done = 1;
            @(negedge clk);
            rx_done = 0;
            repeat (3) @(negedge clk);
        end
    endtask

    // Manda una palabra en little endian
    task send_word(input [31:0] w);
        begin
            send(w[7:0]);
            send(w[15:8]);
            send(w[23:16]);
            send(w[31:24]);
        end
    endtask

    // Espera la respuesta y chequea que lleguen n bytes
    task recv(input integer n);
        begin
            repeat (40 * n + 50) @(negedge clk);
            check("cantidad de bytes", n_rsp, n);
        end
    endtask

    // Palabra de 32 bits a partir del byte i de la respuesta
    function [31:0] word(input integer i);
        begin
            word = {rsp[i + 3], rsp[i + 2], rsp[i + 1], rsp[i]};
        end
    endfunction

    // Chequea el byte de estado y las palabras del dump
    task check_dump(input [7:0] estado);
        begin
            check("estado", rsp[0], estado);
            for (k = 0; k < DUMP_WORDS; k = k + 1) begin
                check("palabra del dump", word(1 + 4 * k), 32'hD0000000 + k);
            end
        end
    endtask

    initial begin
        clk        = 0;
        rst        = 1;
        rx_data    = 0;
        rx_done    = 0;
        cpu_halted = 0;
        tx_cnt     = 0;
        n_rsp      = 0;
        en_ciclos  = 0;
        rst_pulsos = 0;
        for (k = 0; k < 256; k = k + 1) begin
            imem[k] = 32'h0;
        end
        repeat (2) @(negedge clk);
        rst = 0;

        // Antes de cada comando se pone n_rsp en 0 para leer la respuesta desde rsp[0]
        $display("--- 1. Comando invalido");
        n_rsp = 0;
        send("Z");
        recv(1);
        check("responde ?", rsp[0], "?");

        $display("--- 2. Carga de 3 instrucciones");
        n_rsp      = 0;
        rst_pulsos = 0;
        send("L");
        send(8'd3);
        send(8'd0);
        send_word(32'h00500093);
        send_word(32'h00a00113);
        send_word(32'h002081b3);
        recv(1);
        check("responde K", rsp[0], "K");
        check("imem[0]", imem[0], 32'h00500093);
        check("imem[1]", imem[1], 32'h00a00113);
        check("imem[2]", imem[2], 32'h002081b3);
        check("pulsa cpu_rst", rst_pulsos, 1);
        check("no ejecuta durante la carga", en_ciclos, 0);

        $display("--- 3. Carga con N = 0");
        n_rsp = 0;
        send("L");
        send(8'd0);
        send(8'd0);
        recv(1);
        check("responde K", rsp[0], "K");

        $display("--- 4. Lectura de la memoria de programa");
        n_rsp = 0;
        send("P");
        send(8'd3);
        send(8'd0);
        recv(12);
        check("palabra 0", word(0), 32'h00500093);
        check("palabra 1", word(4), 32'h00a00113);
        check("palabra 2", word(8), 32'h002081b3);

        $display("--- 5. Dump");
        n_rsp = 0;
        send("D");
        recv(DUMP_LEN);
        check_dump(8'd0);
        check("D no ejecuta", en_ciclos, 0);

        $display("--- 6. Paso a paso");
        n_rsp = 0;
        send("S");
        recv(DUMP_LEN);
        check_dump(8'd0);
        check("S ejecuta 1 ciclo", en_ciclos, 1);

        $display("--- 7. Continuo");
        n_rsp = 0;
        send("R");
        recv(DUMP_LEN);
        check_dump(8'd1);
        check("R ejecuta hasta halted", en_ciclos, RUN_CICLOS);

        $display("--- 8. Paso despues del HALT");
        n_rsp = 0;
        send("S");
        recv(DUMP_LEN);
        check("no ejecuta", en_ciclos, RUN_CICLOS);

        $display("--- 9. Reset");
        n_rsp      = 0;
        rst_pulsos = 0;
        send("X");
        recv(1);
        check("responde K", rsp[0], "K");
        check("pulsa cpu_rst", rst_pulsos, 1);

        if (errores == 0) begin
            $display("TEST OK");
        end
        else begin
            $display("TEST FALLIDO: %0d errores", errores);
        end
        $finish;
    end

endmodule
