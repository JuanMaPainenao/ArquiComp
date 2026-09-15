`timescale 1ns / 1ps


module br_generator(
    input clk,
    output reg clk_br
    );
    reg[7:0] counter = 0;
    
    always @(posedge clk) begin
        
        if (counter == 163) begin
            clk_br <= ~clk_br;
            counter <= 0;
        end
        else begin
            counter <=counter+1;
        end
    end 
endmodule
