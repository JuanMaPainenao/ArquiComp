`timescale 1ns/1ps
// tb_hazard_unit.v - Chequea stall, fetch_stop y los dos flush en cada caso:
// load use, saltos, HALT y las prioridades entre ellos.
module tb_hazard_unit;

    reg        clk;
    reg        rst;
    reg        en;
    reg  [4:0] rs1_id;
    reg  [4:0] rs2_id;
    reg        uses_rs1_id;
    reg        uses_rs2_id;
    reg        halt_id;
    reg        mem_read_ex;
    reg  [4:0] rd_ex;
    reg        redirect;
    wire       stall;
    wire       fetch_stop;
    wire       flush_if_id;
    wire       flush_id_ex;

    integer errores = 0;

    hazard_unit dut (
        .clk         (clk),
        .rst         (rst),
        .en          (en),
        .rs1_id      (rs1_id),
        .rs2_id      (rs2_id),
        .uses_rs1_id (uses_rs1_id),
        .uses_rs2_id (uses_rs2_id),
        .halt_id     (halt_id),
        .mem_read_ex (mem_read_ex),
        .rd_ex       (rd_ex),
        .redirect    (redirect),
        .stall       (stall),
        .fetch_stop  (fetch_stop),
        .flush_if_id (flush_if_id),
        .flush_id_ex (flush_id_ex)
    );

    always #5 clk = ~clk;

    // Compara las 4 salidas, en orden: stall fetch_stop flush_if_id flush_id_ex
    task chk(input [3:0] exp, input [255:0] nombre);
        begin
            #1;
            if ({stall, fetch_stop, flush_if_id, flush_id_ex} !== exp) begin
                $display("ERROR %0s: %b%b%b%b (esperado %b)", nombre,
                         stall, fetch_stop, flush_if_id, flush_id_ex, exp);
                errores = errores + 1;
            end
        end
    endtask

    // Deja todas las entradas en un caso sin riesgos
    task limpiar;
        begin
            rs1_id      = 1;
            rs2_id      = 2;
            uses_rs1_id = 1;
            uses_rs2_id = 1;
            halt_id     = 0;
            mem_read_ex = 0;
            rd_ex       = 5;
            redirect    = 0;
        end
    endtask

    // Espera un flanco de subida (el registro fetch_stopped se actualiza)
    task flanco;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        en  = 1;
        limpiar;
        flanco;
        rst = 0;

        $display("--- 1. Sin riesgos");
        chk(4'b0000, "normal");

        $display("--- 2. Load use");
        mem_read_ex = 1;
        rd_ex       = 1;
        chk(4'b1001, "load use por rs1");
        rd_ex = 2;
        chk(4'b1001, "load use por rs2");

        $display("--- 3. No es load use");
        rd_ex  = 0;
        rs1_id = 0;
        chk(4'b0000, "rd = x0");
        rs1_id      = 1;
        rd_ex       = 2;
        uses_rs2_id = 0;
        chk(4'b0000, "no usa rs2");
        uses_rs2_id = 1;
        mem_read_ex = 0;
        chk(4'b0000, "no es load");

        $display("--- 4. Salto tomado");
        limpiar;
        redirect = 1;
        chk(4'b0011, "salto");
        mem_read_ex = 1;
        rd_ex       = 1;
        chk(4'b0011, "el salto le gana al stall");

        $display("--- 5. HALT en ID");
        limpiar;
        halt_id = 1;
        chk(4'b0110, "halt en ID");

        $display("--- 6. Fetch frenado");
        flanco;
        halt_id = 0;
        chk(4'b0110, "sigue frenado con el HALT en EX");
        flanco;
        chk(4'b0110, "sigue frenado un ciclo despues");

        $display("--- 7. rst");
        rst = 1;
        flanco;
        rst = 0;
        chk(4'b0000, "rst libera el fetch");

        $display("--- 8. HALT descartado");
        halt_id  = 1;
        redirect = 1;
        chk(4'b0111, "halt y salto en el mismo ciclo");
        flanco;
        halt_id  = 0;
        redirect = 0;
        chk(4'b0000, "no quedo frenado");
        en      = 0;
        halt_id = 1;
        flanco;
        halt_id = 0;
        en      = 1;
        chk(4'b0000, "con en = 0 no se frena");

        $display("--- 9. Stall con el fetch frenado");
        halt_id = 1;
        flanco;
        halt_id     = 0;
        mem_read_ex = 1;
        rd_ex       = 1;
        chk(4'b1101, "IF/ID se mantiene");

        if (errores == 0) begin
            $display("TEST OK");
        end
        else begin
            $display("TEST FALLIDO: %0d errores", errores);
        end
        $finish;
    end

endmodule
