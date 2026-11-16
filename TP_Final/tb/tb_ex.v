`timescale 1ns / 1ps
// ============================================================================
// tb_ex.v - Testbench autoverificante de la etapa EX (ex.v + alu.v)
//
// EX es combinacional: se cargan las entradas, se espera 1 ns y se comparan
// las salidas con lo esperado. Sin forwarding (fwd_a = fwd_b = 00).
//   1. ALU: las 11 operaciones, incluidos los casos de signo y de shifts.
//   2. Mux de B (alu_src): rs2 vs imm.
//   3. Stores: alu_result = direccion, store_data = rs2.
//   4. Saltos: beq/bne tomados y no tomados, jal, jalr, y no-saltos.
// ============================================================================
module tb_ex;

    // Codigos de alu_ctrl ({instr[30], funct3}) - iguales a los de alu.v
    localparam ADD  = 4'b0000, SUB = 4'b1000, SLL = 4'b0001, SLT  = 4'b0010,
               SLTU = 4'b0011, XOR = 4'b0100, SRL = 4'b0101, SRA  = 4'b1101,
               OR   = 4'b0110, AND = 4'b0111, PASS = 4'b1111;

    reg  [31:0] pc, rs1_data, rs2_data, imm;
    reg  [2:0]  funct3;
    reg         alu_src, branch, jump, jalr;
    reg  [3:0]  alu_ctrl;

    wire [31:0] alu_result, store_data, redirect_target;
    wire        redirect, flush;

    integer errores = 0;
    integer casos   = 0;

    ex dut (
        .pc              (pc),
        .rs1_data        (rs1_data),
        .rs2_data        (rs2_data),
        .imm             (imm),
        .funct3          (funct3),
        .alu_src         (alu_src),
        .alu_ctrl        (alu_ctrl),
        .branch          (branch),
        .jump            (jump),
        .jalr            (jalr),
        .ex_mem_result   (32'd0),
        .mem_wb_data     (32'd0),
        .fwd_a           (2'b00),
        .fwd_b           (2'b00),
        .alu_result      (alu_result),
        .store_data      (store_data),
        .redirect        (redirect),
        .redirect_target (redirect_target),
        .flush           (flush)
    );

    // Pone todas las entradas en un estado neutro (instruccion que no salta)
    task reset_entradas;
        begin
            pc = 0; rs1_data = 0; rs2_data = 0; imm = 0; funct3 = 0;
            alu_src = 0; alu_ctrl = ADD; branch = 0; jump = 0; jalr = 0;
        end
    endtask

    // ---------------- Chequeo de la ALU (operacion R: B = rs2) ----------------
    task chk_alu(input [3:0] op, input [31:0] a, input [31:0] b,
                 input [31:0] esperado, input [8*24-1:0] nombre);
        begin
            reset_entradas;
            alu_ctrl = op; rs1_data = a; rs2_data = b;
            #1;
            casos = casos + 1;
            if (alu_result !== esperado || redirect !== 1'b0) begin
                errores = errores + 1;
                $display("FALLA %0s: A=%h B=%h -> %h (esperado %h), redirect=%b",
                         nombre, a, b, alu_result, esperado, redirect);
            end
        end
    endtask

    // ---------------- Chequeo de saltos ----------------
    // Si esp_taken = 0 no se mira el destino.
    task chk_salto(input [31:0] p, input [31:0] a, input [31:0] b, input [31:0] im,
                   input [2:0] f3, input br, input j, input jr,
                   input esp_taken, input [31:0] esp_target, input [8*24-1:0] nombre);
        begin
            reset_entradas;
            pc = p; rs1_data = a; rs2_data = b; imm = im; funct3 = f3;
            branch = br; jump = j; jalr = jr;
            alu_src = jr;                   // jalr usa imm en la ALU, como lo pone ID
            #1;
            casos = casos + 1;
            if (redirect !== esp_taken || flush !== esp_taken ||
                (esp_taken && redirect_target !== esp_target)) begin
                errores = errores + 1;
                $display("FALLA %0s: redirect=%b flush=%b target=%0d (esperado %b, %0d)",
                         nombre, redirect, flush, redirect_target, esp_taken, esp_target);
            end
        end
    endtask

    initial begin
        // ---------------- 1. ALU ----------------
        chk_alu(ADD,  5,            10,           15,           "add");
        chk_alu(SUB,  5,            10,           32'hFFFFFFFB, "sub negativo");
        chk_alu(AND,  32'hF0F0F0F0, 32'hFF00FF00, 32'hF000F000, "and");
        chk_alu(OR,   32'hF0F0F0F0, 32'h0F000000, 32'hFFF0F0F0, "or");
        chk_alu(XOR,  32'hFFFF0000, 32'hFF00FF00, 32'h00FFFF00, "xor");
        chk_alu(SLL,  5,            2,            20,           "sll");
        chk_alu(SLL,  1,            33,           2,            "sll usa B[4:0]");
        chk_alu(SRL,  32'hF0000000, 4,            32'h0F000000, "srl");
        chk_alu(SRA,  32'hF0000000, 4,            32'hFF000000, "sra negativo");
        chk_alu(SRA,  32'h70000000, 4,            32'h07000000, "sra positivo");
        chk_alu(SRL,  32'h80000000, 36,           32'h08000000, "srl usa B[4:0]");
        chk_alu(SLT,  3,            7,            1,            "slt 3<7");
        chk_alu(SLT,  5,            5,            0,            "slt iguales");
        chk_alu(SLT,  32'hFFFFFFFF, 1,            1,            "slt -1<1");
        chk_alu(SLTU, 32'hFFFFFFFF, 1,            0,            "sltu max>1");
        chk_alu(SLT,  32'h80000000, 0,            1,            "slt minimo<0");
        chk_alu(SLTU, 32'h80000000, 0,            0,            "sltu");
        chk_alu(SLTU, 1,            32'hFFFFFFFF, 1,            "sltu 1<max");
        chk_alu(PASS, 32'hDEADBEEF, 32'h12345000, 32'h12345000, "pass (lui)");

        // ---------------- 2. Mux de B ----------------
        // addi x1, x2, -5  con x2 = 100 -> 95 (B = imm, rs2 se ignora)
        reset_entradas;
        alu_ctrl = ADD; alu_src = 1; rs1_data = 100; rs2_data = 999; imm = -5;
        #1; casos = casos + 1;
        if (alu_result !== 95) begin
            errores = errores + 1;
            $display("FALLA addi: %0d (esperado 95)", alu_result);
        end

        // addi x1, x2, 0 (mv): imm = 0 igual tiene que usar imm, no rs2
        imm = 0;
        #1; casos = casos + 1;
        if (alu_result !== 100) begin
            errores = errores + 1;
            $display("FALLA addi imm=0: %0d (esperado 100)", alu_result);
        end

        // ---------------- 3. Store ----------------
        // sw x5, 8(x2) con x2 = 100, x5 = 0xCAFE -> direccion 108, dato 0xCAFE
        reset_entradas;
        alu_ctrl = ADD; alu_src = 1; rs1_data = 100; rs2_data = 32'hCAFE; imm = 8;
        #1; casos = casos + 1;
        if (alu_result !== 108 || store_data !== 32'hCAFE || redirect !== 0) begin
            errores = errores + 1;
            $display("FALLA sw: dir=%0d dato=%h (esperado 108, cafe)", alu_result, store_data);
        end

        // ---------------- 4. Saltos ----------------
        //        pc  A  B  imm  f3  br j jr  taken target
        chk_salto( 8, 5, 5, -8, 3'b000, 1,0,0, 1, 0,  "beq tomado");
        chk_salto( 8, 5, 6, -8, 3'b000, 1,0,0, 0, 0,  "beq no tomado");
        chk_salto(12, 2, 0, -8, 3'b001, 1,0,0, 1, 4,  "bne tomado");
        chk_salto(12, 0, 0, -8, 3'b001, 1,0,0, 0, 0,  "bne no tomado");
        chk_salto( 4, 0, 0, 40, 3'b000, 1,0,0, 1, 44, "beq hacia adelante");
        chk_salto( 0, 0, 0, 12, 3'b000, 0,1,0, 1, 12, "jal");
        chk_salto(16, 4, 0,  0, 3'b000, 0,0,1, 1, 4,  "jalr");
        chk_salto( 0, 7, 0,  2, 3'b000, 0,0,1, 1, 8,  "jalr limpia bit 0");
        chk_salto( 0, 7, 7,  0, 3'b000, 0,0,0, 0, 0,  "no salto con A==B");

        // ---------------- Resultado ----------------
        if (errores == 0)
            $display("tb_ex: OK (%0d casos)", casos);
        else
            $display("tb_ex: %0d ERRORES de %0d casos", errores, casos);
        $finish;
    end

endmodule
