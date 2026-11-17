`timescale 1ns/1ps
// ============================================================================
// hazard_unit.v - Deteccion de riesgos: stalls, flushes y HALT
//
// 1. Load-use: la instruccion en EX es un load y la de ID usa su rd.
//    El dato recien sale de memoria al final de MEM, asi que hay que esperar
//    1 ciclo: PC e IF/ID se mantienen (stall) y a ID/EX entra una burbuja.
//    Despues, la forwarding_unit adelanta el dato desde WB.
//
// 2. Salto tomado (redirect, viene de EX): las 2 instrucciones que entraron
//    detras son del camino equivocado -> flush de IF/ID y de ID/EX.
//    Le gana al stall: la instruccion frenada tambien se descarta.
//
// 3. HALT: cuando hay un HALT en ID se deja de buscar instrucciones hasta el
//    reset (fetch_stopped). El PC no avanza e IF/ID recibe burbujas; el HALT
//    sigue solo hasta WB, donde se levanta halted con el pipeline vacio.
//    Hace falta un registro porque al ciclo siguiente el HALT ya paso a EX
//    (halt_id vuelve a 0) y, sin el, el PC arrancaria de nuevo.
//
// Conexiones:
//   stall       -> pc_unit.stall, if_id.stall
//   fetch_stop  -> pc_unit.halt
//   flush_if_id -> if_id.flush
//   flush_id_ex -> id_ex.flush
// ============================================================================
module hazard_unit(
    input  wire       clk,
    input  wire       rst,
    input  wire       en,

    // Instruccion en ID
    input  wire [4:0] rs1_id,
    input  wire [4:0] rs2_id,
    input  wire       uses_rs1_id,
    input  wire       uses_rs2_id,
    input  wire       halt_id,

    // Instruccion en EX
    input  wire       mem_read_ex,
    input  wire [4:0] rd_ex,
    input  wire       redirect,

    output wire       stall,
    output wire       fetch_stop,
    output wire       flush_if_id,
    output wire       flush_id_ex
);

    // ---------------- 1. Load-use ----------------
    wire load_use;
    assign load_use = mem_read_ex && (rd_ex != 5'd0) &&
                      ( (uses_rs1_id && (rd_ex == rs1_id)) ||
                        (uses_rs2_id && (rd_ex == rs2_id)) );

    assign stall = load_use && !redirect;

    // ---------------- 2. HALT ----------------
    reg fetch_stopped;

    always @(posedge clk) begin
        if (rst)
            fetch_stopped <= 1'b0;
        else if (en && halt_id && !redirect)
            fetch_stopped <= 1'b1;
        // si no, mantiene
    end

    assign fetch_stop = halt_id || fetch_stopped;

    // ---------------- 3. Flushes ----------------
    assign flush_if_id = redirect || (fetch_stop && !stall);
    assign flush_id_ex = redirect || stall;

endmodule