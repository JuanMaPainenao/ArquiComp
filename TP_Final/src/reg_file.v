`timescale 1ns/1ps
// ============================================================================
// reg_file.v - Banco de registros RV32I (32 x 32 bits, x0 = 0)
//
// Puertos:
//   - 2 lecturas asincronicas (rs1, rs2) para la etapa ID.
//   - 1 escritura sincronica (rd) desde la etapa WB.
//   - 1 lectura asincronica de debug para la Debug Unit (dump).
//
// Decisiones de diseno:
//   - Escritura en el flanco de SUBIDA + bypass interno: si WB escribe el mismo
//     registro que ID esta leyendo en ese ciclo, la lectura devuelve el dato
//     nuevo. Es equivalente a "escribir en la primera mitad del ciclo" del
//     libro, pero sin usar el flanco de bajada (que obligaria a que toda la
//     escritura entre en medio periodo y achicaria la frecuencia maxima).
//   - x0 nunca se escribe y siempre se lee 0 (tambien en el bypass).
//   - La escritura se habilita con `en` (cpu_en de la Debug Unit): con el
//     procesador pausado no cambia nada.
//   - `rst` (cpu_rst) pone todos los registros en 0: al reprogramar, el
//     programa nuevo arranca con un estado conocido. Por eso el banco se
//     implementa con flip-flops (1024 FF) y no con RAM distribuida.
// ============================================================================
module reg_file (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,

    // Lectura (ID)
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,

    // Escritura (WB)
    input  wire        we,
    input  wire [4:0]  rd,
    input  wire [31:0] rd_data,

    // Debug
    input  wire [4:0]  dbg_addr,
    output wire [31:0] dbg_data
);

    reg [31:0] regs [0:31];

    wire wr = en && we && (rd != 5'd0);

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end
        else if (wr)
            regs[rd] <= rd_data;
    end

    // Lectura con bypass: si se esta escribiendo el registro que se lee,
    // se devuelve el dato que entra. regs[0] queda siempre en 0.
    assign rs1_data = (wr && rd == rs1) ? rd_data : regs[rs1];
    assign rs2_data = (wr && rd == rs2) ? rd_data : regs[rs2];
    assign dbg_data = regs[dbg_addr];

endmodule
