`timescale 1ns/1ps
// pc_unit.v - Registro del PC. Prioridad del proximo valor: rst, en = 0
// (se mantiene), salto tomado, stall o fetch_stop (se mantiene) y PC + 4.
module pc_unit #(
    parameter [31:0] RESET_PC = 32'h00000000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        en,               // enable global (Debug Unit)
    input  wire        stall,            // hazard detection unit
    input  wire        fetch_stop,             // HALT en ID o fetch frenado (hazard_unit)
    input  wire        redirect,         // salto tomado
    input  wire [31:0] redirect_target,  // destino del salto

    output reg  [31:0] pc,
    output wire [31:0] pc4
);

    assign pc4 = pc + 32'd4;

    always @(posedge clk) begin
        if (rst)
            pc <= RESET_PC;
        else if (!en)
            pc <= pc;
        else if (redirect)
            pc <= redirect_target;
        else if (stall || fetch_stop)
            pc <= pc;
        else
            pc <= pc4;
    end

endmodule
