`timescale 1ns / 1ps

// Tick de 16x el baud rate: un pulso cada DIV ciclos de clk.
// DIV = f_clk / (16 * 38400): 100 MHz -> 163 (164 ciclos), 80 MHz -> 130.
module br_generator #(
    parameter DIV = 164
)(
    input clk,
    output reg o_br_tick = 0
    );
    reg[7:0] counter = 0;

    always @(posedge clk) begin

        if (counter == DIV - 1) begin
            o_br_tick <= 1;
            counter <= 0;
        end
        else begin
            o_br_tick <= 0;
            counter <= counter + 1;
        end
    end
endmodule
