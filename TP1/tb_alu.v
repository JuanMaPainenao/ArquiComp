`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench autoverificante para la ALU
//  - Genera entradas aleatorias (A, B, OP)
//  - Calcula el resultado esperado con un modelo de referencia (golden model)
//  - Compara automaticamente y lleva la cuenta de errores
//////////////////////////////////////////////////////////////////////////////////
module Alu_tb;

    // Parametros del DUT (deben coincidir con los de la ALU)
    localparam NB_DATA = 8;
    localparam NB_OP   = 6;

    // Cantidad de vectores aleatorios a probar
    localparam N_VECTORES = 1000;

    // Codigos de operacion (iguales a los de la ALU)
    localparam OP_ADD = 6'b100000;
    localparam OP_SUB = 6'b100010;
    localparam OP_AND = 6'b100100;
    localparam OP_OR  = 6'b100101;
    localparam OP_XOR = 6'b100110;
    localparam OP_SRA = 6'b000011;
    localparam OP_SRL = 6'b000010;
    localparam OP_NOR = 6'b100111;

    // Senales hacia/desde el DUT
    reg  [NB_DATA-1:0] A;
    reg  [NB_DATA-1:0] B;
    reg  [NB_OP-1:0]   OP;
    wire [NB_DATA-1:0] RES;

    // Auxiliares del testbench
    reg  [NB_DATA-1:0] esperado;
    reg  [2:0]         op_sel;
    integer            i;
    integer            errores;

    // Instancia del modulo bajo prueba (DUT = Device Under Test)
    Alu #(
        .NB_DATA    (NB_DATA),
        .NB_OP_CODE (NB_OP)
    ) dut (
        .A     (A),
        .B     (B),
        .OP    (OP),
        .RES   (RES),
        .CARRY (),   // sin conectar por ahora
        .OVF   ()    // (se agregan cuando implementes carry/overflow)
    );

    // Modelo de referencia (golden model): calcula el resultado ESPERADO
    // de forma independiente al DUT. Si el DUT tiene un bug, los dos difieren.
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

    initial begin
        errores = 0;

        for (i = 0; i < N_VECTORES; i = i + 1) begin
            // 1) Generar entradas aleatorias
            A      = $random;   // se trunca a NB_DATA bits
            B      = $random;
            op_sel = $random;   // uso los 3 bits bajos: 0..7

            // 2) Elegir una operacion VALIDA a partir de op_sel
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

            // 3) Esperar a que la logica combinacional se estabilice
            #10;

            // 4) Calcular el esperado y comparar (chequeo automatico)
            esperado = modelo(A, B, OP);
            if (RES !== esperado) begin
                $display("ERROR [t=%0t] A=%b B=%b OP=%b | RES=%b esperado=%b",
                         $time, A, B, OP, RES, esperado);
                errores = errores + 1;
            end
        end

        // 5) Reporte final
        if (errores == 0)
            $display("TEST OK: %0d vectores sin errores.", N_VECTORES);
        else
            $display("TEST FALLIDO: %0d errores sobre %0d vectores.", errores, N_VECTORES);

        $finish;
    end

endmodule