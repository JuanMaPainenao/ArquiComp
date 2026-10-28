`timescale 1ns/1ps
// ============================================================================
// pc_unit.v - Program Counter + seleccion del proximo PC (etapa IF)
//
// Prioridad del proximo valor:
//   1. rst            -> PC = RESET_PC
//   2. !en            -> PC se mantiene (Debug Unit: pausa / paso a paso)
//   3. redirect       -> PC = redirect_target (branch tomado, jal, jalr)
//   4. stall || halt  -> PC se mantiene (riesgo load-use / HALT en ID)
//   5. normal         -> PC = PC + 4
//
// Notas de diseno:
//   - El clock NUNCA se toca: la pausa se hace con el enable `en`, que maneja
//     la Debug Unit. Paso a paso = en en 1 durante un solo ciclo.
//   - redirect le gana a halt: si hay un salto tomado, la instruccion que esta
//     detras (aunque sea HALT) es del camino equivocado y se va a descartar.
//   - Los destinos de salto se calculan en ID/EX; este modulo solo los recibe.
// ============================================================================
module pc_unit #(
    parameter [31:0] RESET_PC = 32'h00000000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        en,               // enable global (Debug Unit)
    input  wire        stall,            // hazard detection unit
    input  wire        halt,             // HALT decodificado en ID
    input  wire        redirect,         // salto tomado
    input  wire [31:0] redirect_target,  // destino del salto

    output reg  [31:0] pc,
    output wire [31:0] pc_plus4
);

    assign pc_plus4 = pc + 32'd4;

    always @(posedge clk) begin
        if (rst)
            pc <= RESET_PC;
        else if (!en)
            pc <= pc;
        else if (redirect)
            pc <= redirect_target;
        else if (stall || halt)
            pc <= pc;
        else
            pc <= pc_plus4;
    end

endmodule
