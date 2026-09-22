`timescale 1ns / 1ps


module br_generator(
    input clk,
    output reg o_br = 0
    );
    reg[7:0] counter = 0;
    
    always @(posedge clk) begin
        
        if (counter == 163) begin
            o_br <= 1;
            counter <= 0;
        end
        else begin
            o_br <= 0;
            counter <= counter + 1;
        end
    end 
endmodule
