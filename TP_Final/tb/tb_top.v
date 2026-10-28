`timescale 1ns / 1ps
// ============================================================================
// tb_top.v - Testbench autoverificante de top (Debug Unit + IF por UART)
//
// Hace de "PC": manda comandos por i_rx y decodifica las respuestas de o_tx.
//   1. 'L' con 4 instrucciones          -> espera 'K'
//   2. 'D'                              -> PC = 0, instr = prog[0]
//   3. 'S'                              -> PC = 4, instr = prog[1]
//   4. 'R'                              -> halted, PC = 16, instr = HALT
//   5. 'L' con 1 instruccion (reprog.)  -> 'K', y 'D' muestra PC = 0
//   6. comando invalido                 -> '?'
// ============================================================================
module tb_top;

    localparam BR_PERIOD  = 164;            // ciclos de clk por tick (br_generator)
    localparam BIT_CYCLES = 16*BR_PERIOD;   // ciclos de clk por bit

    reg  clk, i_reset, i_rx;
    wire o_tx;

    integer errores = 0;

    reg [31:0] prog [0:3];
    reg [7:0]  rsp [0:15];

    top dut (
        .clk     (clk),
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

    // Dump: rsp[0] = estado, rsp[1..4] = PC, rsp[5..8] = instr
    task check_dump(input [7:0] halted, input [31:0] pc, input [31:0] instr);
        begin
            check("halted", rsp[0], halted);
            check("PC",     {rsp[4], rsp[3], rsp[2], rsp[1]}, pc);
            check("instr",  {rsp[8], rsp[7], rsp[6], rsp[5]}, instr);
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
        fork uart_send_byte("D"); uart_recv_n(9); join
        check_dump(0, 32'd0, prog[0]);

        $display("--- 3. Paso a paso");
        fork uart_send_byte("S"); uart_recv_n(9); join
        check_dump(0, 32'd4, prog[1]);

        $display("--- 4. Continuo");
        fork uart_send_byte("R"); uart_recv_n(9); join
        check_dump(1, 32'd16, 32'h0);

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
        fork uart_send_byte("D"); uart_recv_n(9); join
        check_dump(0, 32'd0, 32'h00100093);

        $display("--- 6. Comando invalido");
        fork uart_send_byte("Z"); uart_recv_n(1); join
        check("nak", rsp[0], "?");

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
