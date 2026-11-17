`timescale 1ns/1ps

// Etapa WB: elige el dato a escribir en rd y avisa cuando termino el programa
module wb #(
    parameter NB_DATA = 32
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               en,

    // Desde MEM/WB
    input  wire [NB_DATA-1:0] load_data_in,
    input  wire [NB_DATA-1:0] alu_result_in,
    input  wire [NB_DATA-1:0] pc4_in,
    input  wire [4:0]         rd_in,
    input  wire               reg_write_in,
    input  wire [1:0]         wb_sel_in,
    input  wire               halt_in,

    // Hacia el reg_file
    output reg  [NB_DATA-1:0] write_data_out,
    output wire [4:0]         rd_out,
    output wire               reg_write_out,

    // Hacia la Debug Unit
    output reg                halted
);

    // 0. Valores de wb_sel
    localparam WB_ALU = 2'b00;
    localparam WB_MEM = 2'b01;
    localparam WB_PC4 = 2'b10;

    // 1. Mux del dato a escribir
    always @(*) begin
        case (wb_sel_in)
            WB_ALU: begin
                write_data_out = alu_result_in;
            end
            WB_MEM: begin
                write_data_out = load_data_in;
            end
            WB_PC4: begin
                write_data_out = pc4_in;
            end
            default: begin
                write_data_out = {NB_DATA{1'b0}};
            end
        endcase
    end

    // 2. Señales hacia el reg_file
    assign reg_write_out = reg_write_in;
    assign rd_out        = rd_in;

    // 3. Halted: se traba en 1 hasta el rst
    always @(posedge clk) begin
        if (rst) begin
            halted <= 1'b0;
        end
        else if (en && halt_in) begin
            halted <= 1'b1;
        end
    end

endmodule
