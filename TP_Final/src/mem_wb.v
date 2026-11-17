`timescale 1ns/1ps

// Latch MEM/WB: rst = burbuja (todo en 0), !en = mantiene, en = avanza
module mem_wb #(
    parameter NB_DATA = 32
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               en,

    // Desde MEM
    input  wire [NB_DATA-1:0] load_data_in,

    // Desde EX/MEM
    input  wire [NB_DATA-1:0] alu_result_in,
    input  wire [NB_DATA-1:0] pc4_in,
    input  wire [4:0]         rd_in,
    input  wire               reg_write_in,
    input  wire [1:0]         wb_sel_in,
    input  wire               halt_in,

    // Hacia WB
    output reg  [NB_DATA-1:0] load_data_out,
    output reg  [NB_DATA-1:0] alu_result_out,
    output reg  [NB_DATA-1:0] pc4_out,
    output reg  [4:0]         rd_out,
    output reg                reg_write_out,
    output reg  [1:0]         wb_sel_out,
    output reg                halt_out
);

    always @(posedge clk) begin
        if (rst) begin
            load_data_out  <= {NB_DATA{1'b0}};
            alu_result_out <= {NB_DATA{1'b0}};
            pc4_out        <= {NB_DATA{1'b0}};
            rd_out         <= 5'd0;
            reg_write_out  <= 1'b0;
            wb_sel_out     <= 2'b00;
            halt_out       <= 1'b0;
        end
        else if (en) begin
            load_data_out  <= load_data_in;
            alu_result_out <= alu_result_in;
            pc4_out        <= pc4_in;
            rd_out         <= rd_in;
            reg_write_out  <= reg_write_in;
            wb_sel_out     <= wb_sel_in;
            halt_out       <= halt_in;
        end
    end

endmodule
