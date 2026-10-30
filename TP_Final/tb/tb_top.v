`timescale 1ns/1ps
// ============================================================================
// tb_top.v - Prueba del sistema completo por la UART (como desde la PC)
//
// El testbench hace de PC: manda bytes por i_rx a 38400 baud y decodifica lo
// que sale por o_tx. Secuencia:
//   'L' + ejemplo.s  -> espera 'K'
//   'D'              -> dump de 1 + 4*43 bytes: PC = 0, IF/ID vacio
//   'S' 'S'          -> PC = 8, IF/ID = palabra 1, ID/EX = palabra 0
//   'R'              -> corre hasta el HALT: estado halted, PC = 0x34
// Simula ~200 ms de tiempo real: cada dump son 173 bytes (~45 ms). Tarda un par de minutos.
// ============================================================================
module tb_top;
    reg  clk = 0, i_reset = 1, i_rx = 1;
    wire o_tx;

    top dut (.clk(clk), .i_reset(i_reset), .i_rx(i_rx), .o_tx(o_tx));

    always #5 clk = ~clk;                       // 100 MHz

    localparam real BIT_PC   = 1.0e9 / 38400;   // la PC transmite a 38400
    localparam real BIT_FPGA = 164 * 16 * 10;   // la FPGA a ~38110 baud
    localparam N_DUMP = 43;

    reg [31:0] prog [0:15];
    reg [7:0]  rx_buf [0:1 + 4 * N_DUMP - 1];
    integer fallas = 0, total = 0, i;

    task uart_send(input [7:0] b);
        integer n;
        begin
            i_rx = 0; #(BIT_PC);
            for (n = 0; n < 8; n = n + 1) begin i_rx = b[n]; #(BIT_PC); end
            i_rx = 1; #(BIT_PC);
        end
    endtask

    task uart_recv(output [7:0] b);
        integer n;
        begin
            @(negedge o_tx);
            #(BIT_FPGA * 1.5);
            for (n = 0; n < 8; n = n + 1) begin b[n] = o_tx; #(BIT_FPGA); end
        end
    endtask

    task recv_dump;
        integer n;
        begin
            for (n = 0; n < 1 + 4 * N_DUMP; n = n + 1) uart_recv(rx_buf[n]);
        end
    endtask

    function [31:0] palabra(input integer idx);
        palabra = {rx_buf[1 + 4*idx + 3], rx_buf[1 + 4*idx + 2],
                   rx_buf[1 + 4*idx + 1], rx_buf[1 + 4*idx]};
    endfunction

    task check(input [31:0] valor, input [31:0] esperado, input [8*28-1:0] que);
        begin
            total = total + 1;
            if (valor !== esperado) begin
                fallas = fallas + 1;
                $display("MAL  %0s: %h (esperado %h)", que, valor, esperado);
            end
        end
    endtask

    reg [7:0] r;
    initial begin
        prog[ 0] = 32'h00000293;
        prog[ 1] = 32'h00100313;
        prog[ 2] = 32'h00B00393;
        prog[ 3] = 32'h006282B3;
        prog[ 4] = 32'h00130313;
        prog[ 5] = 32'hFE731CE3;
        prog[ 6] = 32'h00502023;
        prog[ 7] = 32'h00002503;
        prog[ 8] = 32'h00A505B3;
        prog[ 9] = 32'h12345437;
        prog[10] = 32'h67840413;
        prog[11] = 32'h008000EF;
        prog[12] = 32'h00000000;
        prog[13] = 32'h00800223;
        prog[14] = 32'h00404603;
        prog[15] = 32'h00008067;

        #1000 i_reset = 0;
        #1000;

        // ---- Carga ----
        // Se escucha en paralelo: la FPGA responde 'K' antes de que termine
        // el bit de stop del ultimo byte (lo recibe a mitad del stop).
        fork
            begin
                uart_send(8'h4C); uart_send(8'd16); uart_send(8'd0);
                for (i = 0; i < 16; i = i + 1) begin
                    uart_send(prog[i][7:0]);   uart_send(prog[i][15:8]);
                    uart_send(prog[i][23:16]); uart_send(prog[i][31:24]);
                end
            end
            uart_recv(r);
        join
        check(r, "K", "respuesta a L");

        // ---- Dump sin ejecutar ----
        fork uart_send("D"); recv_dump; join
        check(rx_buf[0], 0, "D: estado");
        check(palabra(0), 0, "D: PC");
        check(palabra(1), prog[0], "D: instr en IF");
        check(palabra(3), 32'h00000013, "D: IF/ID vacio (NOP)");
        check(palabra(42), 0, "D: x31");

        // ---- Dos pasos ----
        fork uart_send("S"); recv_dump; join
        fork uart_send("S"); recv_dump; join
        check(palabra(0), 8, "S S: PC");
        check(palabra(3), prog[1], "S S: IF/ID.instr");
        check(palabra(5), 0, "S S: ID/EX.pc");
        check(palabra(9), 32'h00001400, "S S: ID/EX rd=5");   // addi t0, zero, 0

        // ---- Continuo ----
        fork uart_send("R"); recv_dump; join
        check(rx_buf[0], 1, "R: estado halted");
        check(palabra(0), 32'h34, "R: PC final");
        check(palabra(10) >> 14 & 1, 1, "R: HALT en ID/EX");

        if (fallas == 0) $display("tb_top: OK (%0d chequeos)", total);
        else             $display("tb_top: %0d de %0d chequeos fallaron", fallas, total);
        $finish;
    end

    initial begin
        #400_000_000;
        $display("tb_top: TIMEOUT");
        $finish;
    end
endmodule
