`timescale 1ns/1ps
// hazard_unit.v - Load use (stall y burbuja), salto tomado (flush) y HALT
// (frena el fetch hasta el reset). Ver docs/riesgos.md.
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