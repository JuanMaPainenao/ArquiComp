`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench autoverificante para top_uart_alu.
//  - Manda A, B y OP por i_rx (bit-banging de una trama UART 8N1).
//  - Recibe el resultado por o_tx (decodifica la trama serie).
//  - Compara contra un modelo de referencia (mismo golden model que tb_alu.v).
//////////////////////////////////////////////////////////////////////////////////
module tb_top_uart_alu;

    localparam NB_DATA    = 8;
    localparam NB_OP      = 6;
    localparam SB_TICK    = 16;
    localparam BR_PERIOD  = 164;              // ciclos de clk por tick de i_br (br_generator)
    localparam BIT_CYCLES = SB_TICK*BR_PERIOD; // ciclos de clk por bit de UART

    localparam N_VECTORES = 8;

    localparam OP_ADD = 6'b100000;
    localparam OP_SUB = 6'b100010;
    localparam OP_AND = 6'b100100;
    localparam OP_OR  = 6'b100101;
    localparam OP_XOR = 6'b100110;
    localparam OP_SRA = 6'b000011;
    localparam OP_SRL = 6'b000010;
    localparam OP_NOR = 6'b100111;

    reg clk, i_reset, i_rx;
    wire o_tx;

    reg [NB_DATA-1:0] A, B, esperado, recibido;
    reg [NB_OP-1:0]   OP;
    reg [2:0]         op_sel;
    integer i;
    integer errores;

    top_uart_alu #(
        .NB_DATA    (NB_DATA),
        .NB_OP_CODE (NB_OP),
        .SB_TICK    (SB_TICK)
    ) dut (
        .clk     (clk),
        .i_reset (i_reset),
        .i_rx    (i_rx),
        .o_tx    (o_tx)
    );

    always #5 clk = ~clk;

    function [NB_DATA-1:0] modelo;
        input [NB_DATA-1:0] a;
        input [NB_DATA-1:0] b;
        input [NB_OP-1:0]   op;
        begin
            case (op)
                OP_ADD: modelo = a + b;
                OP_SUB: modelo = a - b;
                OP_AND: modelo = a & b;
                OP_OR : modelo = a | b;
                OP_XOR: modelo = a ^ b;
                OP_SRL: modelo = a >> b;
                OP_SRA: modelo = $signed(a) >>> b;
                OP_NOR: modelo = ~(a | b);
                default: modelo = {NB_DATA{1'b0}};
            endcase
        end
    endfunction

    task uart_send_byte(input [NB_DATA-1:0] data);
        integer k;
        begin
            i_rx = 1'b0;                    // start bit
            repeat (BIT_CYCLES) @(posedge clk);
            for (k = 0; k < NB_DATA; k = k + 1) begin
                i_rx = data[k];
                repeat (BIT_CYCLES) @(posedge clk);
            end
            i_rx = 1'b1;                    // stop bit
            repeat (BIT_CYCLES) @(posedge clk);
        end
    endtask

    task uart_recv_byte(output [NB_DATA-1:0] data);
        integer k;
        begin
            @(negedge o_tx);                          // flanco de bajada del start bit
            repeat (BIT_CYCLES + BIT_CYCLES/2) @(posedge clk); // centro del bit 0
            for (k = 0; k < NB_DATA; k = k + 1) begin
                data[k] = o_tx;
                if (k != NB_DATA-1)
                    repeat (BIT_CYCLES) @(posedge clk);
            end
        end
    endtask

    initial begin
        $dumpfile("top_uart_alu.vcd");
        $dumpvars(0, tb_top_uart_alu);
    end

    initial begin
        clk = 1'b0;
        i_rx = 1'b1;                        // linea idle en alto
        i_reset = 1'b1;
        errores = 0;
        repeat (5) @(posedge clk);
        i_reset = 1'b0;

        for (i = 0; i < N_VECTORES; i = i + 1) begin
            A      = $random;
            B      = $random;
            op_sel = $random;
            case (op_sel)
                3'd0: OP = OP_ADD;
                3'd1: OP = OP_SUB;
                3'd2: OP = OP_AND;
                3'd3: OP = OP_OR;
                3'd4: OP = OP_XOR;
                3'd5: OP = OP_SRL;
                3'd6: OP = OP_SRA;
                3'd7: OP = OP_NOR;
            endcase

            fork
                begin
                    uart_send_byte(A);
                    uart_send_byte(B);
                    uart_send_byte({2'b00, OP});
                end
                uart_recv_byte(recibido);
            join

            esperado = modelo(A, B, OP);
            if (recibido !== esperado) begin
                $display("ERROR [t=%0t] A=%b B=%b OP=%b | RES=%b esperado=%b",
                          $time, A, B, OP, recibido, esperado);
                errores = errores + 1;
            end
            else begin
                $display("OK    [t=%0t] A=%b B=%b OP=%b | RES=%b",
                          $time, A, B, OP, recibido);
            end
        end

        if (errores == 0)
            $display("TEST OK: %0d vectores sin errores.", N_VECTORES);
        else
            $display("TEST FALLIDO: %0d errores sobre %0d vectores.", errores, N_VECTORES);

        $finish;
    end

endmodule