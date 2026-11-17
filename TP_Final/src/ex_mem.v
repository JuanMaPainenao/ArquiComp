`timescale 1ns/1ps

module ex_mem #(
    parameter NB_DATA = 32
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               en,

    // Desde EX
    input  wire [NB_DATA-1:0] alu_result_in,
    input  wire [NB_DATA-1:0] store_data_in,

    // Desde ID/EX
    input  wire [4:0]         rd_in,
    input  wire [2:0]         funct3_in,
    input  wire [NB_DATA-1:0] pc4_in,
    input  wire               reg_write_in,
    input  wire               mem_read_in,
    input  wire               mem_write_in,
    input  wire [1:0]         wb_sel_in,
    input  wire               halt_in,

    // Hacia MEM
    output reg  [NB_DATA-1:0] alu_result_out,
    output reg  [NB_DATA-1:0] store_data_out,
    output reg  [4:0]         rd_out,
    output reg  [2:0]         funct3_out,
    output reg  [NB_DATA-1:0] pc4_out,
    output reg                reg_write_out,
    output reg                mem_read_out,
    output reg                mem_write_out,
    output reg  [1:0]         wb_sel_out,
    output reg                halt_out
);

    always @(posedge clk) begin
        if (rst) begin
            alu_result_out <= {NB_DATA{1'b0}};
            store_data_out <= {NB_DATA{1'b0}};
            rd_out         <= 5'd0;
            funct3_out     <= 3'd0;
            pc4_out        <= {NB_DATA{1'b0}};
            reg_write_out  <= 1'b0;
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            wb_sel_out     <= 2'b00;
            halt_out       <= 1'b0;
        end
        else if (en) begin
            alu_result_out <= alu_result_in;
            store_data_out <= store_data_in;
            rd_out         <= rd_in;
            funct3_out     <= funct3_in;
            pc4_out        <= pc4_in;
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            wb_sel_out     <= wb_sel_in;
            halt_out       <= halt_in;
        end
    end

endmodule
