`timescale 1ns / 1ps

module tx_uart #(
    parameter NB_DATA = 8,
    parameter SB_TICK = 16
)(
    input i_clk_br,
    input i_reset,
    input i_tx_start,
    input [NB_DATA-1:0] i_data,
    output reg o_tx,
    output reg o_tx_done
);

    localparam idle  = 2'b00;
    localparam start = 2'b01;
    localparam data  = 2'b10;
    localparam stop  = 2'b11;

    reg [1:0] state_tx, next_state_tx;
    reg [3:0] cont, next_cont;
    reg [2:0] cont_bits, next_cont_bits;
    reg [NB_DATA-1:0] data_reg, next_data_reg;
    reg tx_reg, next_tx_reg; 

    always @(posedge i_clk_br) begin
        if (i_reset) begin
            state_tx  <= idle;
            cont      <= 0;
            cont_bits <= 0;
            data_reg  <= 0;
            tx_reg    <= 1'b1;
            o_tx      <= 1'b1;
        end else begin
            state_tx  <= next_state_tx;
            cont      <= next_cont;
            cont_bits <= next_cont_bits;
            data_reg  <= next_data_reg;
            tx_reg    <= next_tx_reg;
            o_tx      <= next_tx_reg;
        end
    end

    always @(*) begin
        next_state_tx  = state_tx;
        next_cont      = cont;
        next_cont_bits = cont_bits;
        next_data_reg  = data_reg;
        next_tx_reg    = tx_reg;
        o_tx_done      = 1'b0;

        case (state_tx)
            idle: begin
                next_tx_reg = 1'b1;
                if (i_tx_start) begin
                    next_cont     = 0;
                    next_data_reg = i_data;
                    next_state_tx = start;
                end
            end

            start: begin
                next_tx_reg = 1'b0;
                if (cont == 4'd15) begin
                    next_cont      = 0;
                    next_cont_bits = 0;
                    next_state_tx  = data;
                end else
                    next_cont = cont + 1'b1;
            end

            data: begin
                next_tx_reg = data_reg[0];
                if (cont == 4'd15) begin
                    next_cont     = 0;
                    next_data_reg = data_reg >> 1;
                    if (cont_bits == NB_DATA-1)
                        next_state_tx = stop;
                    else
                        next_cont_bits = cont_bits + 1'b1;
                end else
                    next_cont = cont + 1'b1;
            end

            stop: begin
                next_tx_reg = 1'b1;
                if (cont == SB_TICK-1) begin
                    next_cont     = 0;
                    o_tx_done     = 1'b1;
                    next_state_tx = idle;
                end else
                    next_cont = cont + 1'b1;
            end
        endcase
    end
endmodule