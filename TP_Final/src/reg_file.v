`timescale 1ns/1ps
// ============================================================================
// reg_file.v - Banco de registros x0..x31 (etapa ID, escritura desde WB)
//
//   - Dos lecturas asincronicas (rs1, rs2) para ID.
//   - Una escritura sincronica (rd) que viene de WB.
//   - Una tercera lectura asincronica (dbg) para el dump de la Debug Unit.
//
// Decisiones de diseno:
//   - x0 siempre lee 0 y nunca se escribe.
//   - La escritura solo ocurre con en = 1 (enable global de la Debug Unit):
//     si no, en paso a paso WB escribiria aunque el procesador este en pausa.
//   - Bypass interno: si WB escribe el mismo registro que ID esta leyendo en
//     el mismo ciclo, la lectura devuelve el dato nuevo. El forwarding cubre
//     dependencias a 1 y 2 instrucciones de distancia; la de 3 la cubre esto.
//     (Equivale a "escribir en la primera mitad del ciclo" del libro, pero sin
//     usar el flanco de bajada del clock.)
//   - Implementado con flip-flops (31 x 32 = 992 FF, ~2.4% de la Basys 3) para
//     poder borrarlo en 1 ciclo con rst: al reprogramar arranca con todo en 0.
//     El puerto dbg NO tiene bypass: muestra lo que esta guardado.
// ============================================================================
module reg_file (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,

    // Lectura (ID)
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,

    // Escritura (WB)
    input  wire        we,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,

    // Debug
    input  wire [4:0]  dbg_addr,
    output wire [31:0] dbg_data
);

    reg [31:0] regs [0:31];

    wire wr = en && we && (rd_addr != 5'd0);

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end
        else if (wr)
            regs[rd_addr] <= rd_data;
    end

    assign rs1_data = (rs1_addr == 5'd0)              ? 32'd0   :
                      (wr && rs1_addr == rd_addr)     ? rd_data :
                                                        regs[rs1_addr];

    assign rs2_data = (rs2_addr == 5'd0)              ? 32'd0   :
                      (wr && rs2_addr == rd_addr)     ? rd_data :
                                                        regs[rs2_addr];

    assign dbg_data = (dbg_addr == 5'd0) ? 32'd0 : regs[dbg_addr];

endmodule
