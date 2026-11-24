`timescale 1ns / 1ps
// tb_top.v - Hace de PC por UART: carga, dump, paso, continuo, reprogramacion,
// comando invalido y lectura de imem. Se simula en Vivado (usa el MMCM).
module tb_top;

    // clk del tb = 100 MHz (placa). El DUT corre a 80 MHz (MMCM) con un tick
    // cada 130 ciclos: 1 bit = 16*130/80 MHz = 26 us = 2600 ciclos de 100 MHz.
    // Simular con la libreria unisim: xelab -L unisims_ver tb_top glbl
    localparam BIT_CYCLES = 2600;           // ciclos de clk (100 MHz) por bit

    reg  clk, i_reset, i_rx;
    wire o_tx;

    integer errores = 0;

    reg [31:0] prog [0:3];
    reg [7:0]  rsp [0:255];

    top dut (
        .clk_100 (clk),
        .i_reset (i_reset),
        .i_rx    (i_rx),
        .o_tx    (o_tx)
    );

    always #5 clk = ~clk;

    task uart_send_byte(input [7:0] data);
        integer k;
        begin
            i_rx = 1'b0;
            repeat (BIT_CYCLES) @(posedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                i_rx = data[k];
                repeat (BIT_CYCLES) @(posedge clk);
            end
            i_rx = 1'b1;
            repeat (BIT_CYCLES) @(posedge clk);
        end
    endtask

    task uart_send_word(input [31:0] w);
        begin
            uart_send_byte(w[7:0]);
            uart_send_byte(w[15:8]);
            uart_send_byte(w[23:16]);
            uart_send_byte(w[31:24]);
        end
    endtask

    task uart_recv_byte(output [7:0] data);
        integer k;
        begin
            @(negedge o_tx);
            repeat (BIT_CYCLES + BIT_CYCLES/2) @(posedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                data[k] = o_tx;
                if (k != 7)
                    repeat (BIT_CYCLES) @(posedge clk);
            end
        end
    endtask

    task uart_recv_n(input integer n);
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                uart_recv_byte(rsp[k]);
        end
    endtask

    task check(input [255:0] nombre, input [31:0] got, input [31:0] exp);
        begin
            if (got !== exp) begin
                $display("ERROR %0s: got=%h esperado=%h", nombre, got, exp);
                errores = errores + 1;
            end
            else
                $display("OK    %0s = %h", nombre, got);
        end
    endtask

    // Dump (ver top.v): rsp[0] = estado, despues palabras de 32 bits:
    //   0 PC, 1 M, 2..21 latches (2 = instr en IF, 3 = IF/ID instr),
    //   22..53 x0..x31, 54.. M palabras de dmem. Estos programas no hacen
    //   stores, asi que M = 1.
    localparam DUMP_LEN = 1 + 4*(54 + 1);
    function [31:0] w(input integer k);
        w = {rsp[4*k+4], rsp[4*k+3], rsp[4*k+2], rsp[4*k+1]};
    endfunction
    task check_dump(input [7:0] halted, input [31:0] pc, input [31:0] instr);
        begin
            check("halted", rsp[0], halted);
            check("PC",     w(0), pc);
            check("M",      w(1), 32'd1);
            check("instr",  w(2), instr);
        end
    endtask

    integer j;

    initial begin
        prog[0] = 32'h00500093;  // addi x1, x0, 5
        prog[1] = 32'h00a00113;  // addi x2, x0, 10
        prog[2] = 32'h002081b3;  // add  x3, x1, x2
        prog[3] = 32'h40208233;  // sub  x4, x1, x2

        clk = 0; i_rx = 1; i_reset = 1;
        repeat (5) @(posedge clk);
        wait (dut.locked);                  // el MMCM tarda unos us en enganchar
        i_reset = 0;
        repeat (10) @(posedge clk);

        $display("--- 1. Carga de programa");
        fork
            begin
                uart_send_byte("L");
                uart_send_byte(8'd4);
                uart_send_byte(8'd0);
                for (j = 0; j < 4; j = j + 1)
                    uart_send_word(prog[j]);
            end
            uart_recv_n(1);
        join
        check("ack load", rsp[0], "K");

        $display("--- 2. Dump");
        fork uart_send_byte("D"); uart_recv_n(DUMP_LEN); join
        check_dump(0, 32'd0, prog[0]);

        $display("--- 3. Paso a paso");
        fork uart_send_byte("S"); uart_recv_n(DUMP_LEN); join
        check_dump(0, 32'd4, prog[1]);

        $display("--- 4. Continuo");
        fork uart_send_byte("R"); uart_recv_n(DUMP_LEN); join
        // HALT (memoria en 0) en 0x10 -> el PC queda en 0x14
        check_dump(1, 32'd20, 32'h0);
        check("x1", w(22+1), 32'd5);
        check("x2", w(22+2), 32'd10);
        check("x3", w(22+3), 32'd15);
        check("x4", w(22+4), 32'hFFFFFFFB);

        $display("--- 5. Reprogramacion");
        fork
            begin
                uart_send_byte("L");
                uart_send_byte(8'd1);
                uart_send_byte(8'd0);
                uart_send_word(32'h00100093);  // addi x1, x0, 1
            end
            uart_recv_n(1);
        join
        check("ack reload", rsp[0], "K");
        fork uart_send_byte("D"); uart_recv_n(DUMP_LEN); join
        check_dump(0, 32'd0, 32'h00100093);
        check("x1 (reset)", w(22+1), 32'd0);

        $display("--- 6. Comando invalido");
        fork uart_send_byte("Z"); uart_recv_n(1); join
        check("nak", rsp[0], "?");

        $display("--- 7. Lectura de memoria de programa");
        fork
            begin
                uart_send_byte("P");
                uart_send_byte(8'd4);
                uart_send_byte(8'd0);
            end
            uart_recv_n(16);
        join
        // La reprogramacion solo piso la palabra 0; las demas son de la carga 1
        check("imem[0]", {rsp[3],  rsp[2],  rsp[1],  rsp[0]},  32'h00100093);
        check("imem[1]", {rsp[7],  rsp[6],  rsp[5],  rsp[4]},  prog[1]);
        check("imem[2]", {rsp[11], rsp[10], rsp[9],  rsp[8]},  prog[2]);
        check("imem[3]", {rsp[15], rsp[14], rsp[13], rsp[12]}, prog[3]);

        if (errores == 0)
            $display("TEST OK");
        else
            $display("TEST FALLIDO: %0d errores", errores);
        $finish;
    end

    // Por si algo se cuelga esperando una respuesta
    initial begin
        #500_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
