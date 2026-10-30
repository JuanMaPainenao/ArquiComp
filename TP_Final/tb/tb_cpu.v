`timescale 1ns/1ps
// ============================================================================
// tb_cpu.v - Testbench self-checking de cpu.v (IF + ID) sin UART
//
// Carga ejemplo.s en la memoria de programa por el puerto de debug, resetea y
// ejecuta ciclo a ciclo como hace la Debug Unit en paso a paso (en = 1 durante
// un solo ciclo). Despues de cada ciclo lee el dump y verifica:
//   - PC = 4k                       (sin EX todavia, los saltos no se toman)
//   - IF/ID = instruccion k-1
//   - ID/EX = instruccion k-2 decodificada (rd, rs1, rs2, funct3, imm, control)
//   - El HALT (palabra 12) frena el fetch en ID y llega a ID/EX en el ciclo 14
// Ademas: con en = 0 nada cambia, con halted = 1 tampoco, y rst vuelve a cero.
// ============================================================================
module tb_cpu;
    reg         clk = 0, rst = 1, en = 0;
    reg         imem_we = 0;
    reg  [7:0]  imem_addr = 0;
    reg  [31:0] imem_wdata = 0;
    reg  [7:0]  dump_idx = 0;
    wire [31:0] dump_data;
    wire        halted;

    cpu #(.ADDR_W(8)) dut (
        .clk(clk), .rst(rst), .en(en),
        .imem_we(imem_we), .imem_addr(imem_addr), .imem_wdata(imem_wdata),
        .halted(halted), .dump_idx(dump_idx), .dump_data(dump_data)
    );

    always #5 clk = ~clk;

    reg [31:0] prog     [0:15];
    reg [31:0] exp_regs [0:12];
    reg [31:0] exp_imm  [0:12];
    reg [31:0] exp_ctrl [0:12];
    integer fallas = 0, total = 0, k, i;

    localparam NOP = 32'h00000013;

    // Lee la palabra idx del dump y la compara
    task cd(input [7:0] idx, input [31:0] esperado, input [8*28-1:0] que);
        begin
            dump_idx = idx; #1;
            check(dump_data, esperado, que);
        end
    endtask

    // Lee un bit de la palabra idx del dump y lo compara
    task cdb(input [7:0] idx, input integer b, input esperado, input [8*28-1:0] que);
        begin
            dump_idx = idx; #1;
            check(dump_data[b], esperado, que);
        end
    endtask

    task check(input [31:0] valor, input [31:0] esperado, input [8*28-1:0] que);
        begin
            total = total + 1;
            if (valor !== esperado) begin
                fallas = fallas + 1;
                $display("MAL  ciclo %0d, %0s: %h (esperado %h)", k, que, valor, esperado);
            end
        end
    endtask

    // Un ciclo de clock habilitado, como el comando 'S'
    task step;
        begin
            @(negedge clk); en = 1;
            @(negedge clk); en = 0;
            repeat (3) @(negedge clk);       // ciclos en pausa: no tiene que cambiar nada
        end
    endtask

    task check_estado;
        integer j;
        begin
            // IF
            cd(0, (k <= 13) ? 4 * k : 32'h34, "PC");
            // IF/ID
            if (k >= 1 && k <= 13) begin
                cd(2, 4 * (k - 1), "IF/ID.pc");
                cd(3, prog[k - 1], "IF/ID.instr");
                cdb(4, 0, 1, "IF/ID.valid");
            end
            else begin
                cd(3, NOP, "IF/ID.instr (burbuja)");
                cdb(4, 0, 0, "IF/ID.valid (burbuja)");
            end
            // ID/EX
            j = k - 2;
            if (j >= 0 && j <= 12) begin
                cd(5, 4 * j, "ID/EX.pc");
                cd(8, exp_imm[j], "ID/EX.imm");
                cd(9, exp_regs[j], "ID/EX rs1/rs2/rd/funct3");
                cd(10, exp_ctrl[j], "ID/EX control");
                cd(6, 0, "ID/EX.rs1_data (sin WB)");
            end
            // HALT
            check(halted, (k >= 14), "halted");
            cdb(4, 1, (k >= 14), "fetch_stopped");
        end
    endtask

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

        exp_regs[ 0] = 32'h00001400;
        exp_regs[ 1] = 32'h00001800;
        exp_regs[ 2] = 32'h00001C00;
        exp_regs[ 3] = 32'h000014C5;
        exp_regs[ 4] = 32'h00001806;
        exp_regs[ 5] = 32'h000080E6;
        exp_regs[ 6] = 32'h000100A0;
        exp_regs[ 7] = 32'h00012800;
        exp_regs[ 8] = 32'h00002D4A;
        exp_regs[ 9] = 32'h0002A000;
        exp_regs[10] = 32'h00002008;
        exp_regs[11] = 32'h00000400;
        exp_regs[12] = 32'h00000000;

        exp_imm[ 0]  = 32'h00000000;
        exp_imm[ 1]  = 32'h00000001;
        exp_imm[ 2]  = 32'h0000000B;
        exp_imm[ 3]  = 32'h00000000;
        exp_imm[ 4]  = 32'h00000001;
        exp_imm[ 5]  = 32'hFFFFFFF8;
        exp_imm[ 6]  = 32'h00000000;
        exp_imm[ 7]  = 32'h00000000;
        exp_imm[ 8]  = 32'h00000000;
        exp_imm[ 9]  = 32'h12345000;
        exp_imm[10]  = 32'h00000678;
        exp_imm[11]  = 32'h00000008;
        exp_imm[12]  = 32'h00000000;

        exp_ctrl[ 0] = 32'h00008810;
        exp_ctrl[ 1] = 32'h00008810;
        exp_ctrl[ 2] = 32'h00008810;
        exp_ctrl[ 3] = 32'h00008800;
        exp_ctrl[ 4] = 32'h00008810;
        exp_ctrl[ 5] = 32'h00008048;
        exp_ctrl[ 6] = 32'h00008410;
        exp_ctrl[ 7] = 32'h00009A10;
        exp_ctrl[ 8] = 32'h00008800;
        exp_ctrl[ 9] = 32'h00008830;
        exp_ctrl[10] = 32'h00008810;
        exp_ctrl[11] = 32'h0000A880;
        exp_ctrl[12] = 32'h0000C000;

        // Carga del programa (como el comando 'L')
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge clk); imem_we = 1; imem_addr = i; imem_wdata = prog[i];
        end
        @(negedge clk); imem_we = 0;
        @(negedge clk); rst = 0;

        // Estado inicial: todo vacio
        k = 0;
        check_estado;
        for (i = 0; i < 32; i = i + 1)
            cd(11 + i, 0, "registros en 0");

        // 14 pasos hasta que el HALT llega a ID/EX
        for (k = 1; k <= 14; k = k + 1) begin
            step;
            check_estado;
        end

        // Con halted = 1 el procesador no se mueve aunque en = 1
        @(negedge clk); en = 1;
        repeat (5) @(negedge clk);
        en = 0;
        k = 14;
        check_estado;

        // Reset: vuelve a PC = 0, sin halt, y el programa sigue cargado
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        k = 0;
        check_estado;
        k = 1; step; check_estado;
        k = 2; step; check_estado;

        if (fallas == 0) $display("tb_cpu: OK (%0d chequeos)", total);
        else             $display("tb_cpu: %0d de %0d chequeos fallaron", fallas, total);
        $finish;
    end
endmodule
