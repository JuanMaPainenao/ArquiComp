`timescale 1ns/1ps
// reg_file.v - Banco de 32 registros (x0 = 0) con bypass de WB a ID y puerto
// de debug. rst pone todo en 0. Ver docs/id.md.
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
    input  wire        reg_write,
    input  wire [4:0]  rd,
    input  wire [31:0] write_data,

    // Debug
    input  wire [4:0]  dbg_addr,
    output wire [31:0] dbg_data
);

    reg [31:0] regs [0:31];

    wire wr = en && reg_write && (rd != 5'd0);

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end
        else if (wr)
            regs[rd] <= write_data;
    end

    // Lectura con bypass: si se esta escribiendo el registro que se lee,
    // se devuelve el dato que entra. regs[0] queda siempre en 0.
    assign rs1_data = (wr && rd == rs1) ? write_data : regs[rs1];
    assign rs2_data = (wr && rd == rs2) ? write_data : regs[rs2];
    assign dbg_data = regs[dbg_addr];

endmodule
