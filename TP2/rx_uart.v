`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/09/2026 10:11:25 PM
// Design Name: 
// Module Name: rx_uart
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rx_uart#(
        parameter NB_DATA=8,
        parameter SB_TICK=16
)
(
        input i_clk_br,
        input i_rx,
        output reg [NB_DATA-1:0] o_dout,
        output reg o_rx_done

    );
    reg [1:0] state_rx, next_state_rx;
    reg [3:0] cont_ticks, next_cont_ticks;
    reg [2:0] cont_bits, next_cont_bits;
    
    localparam idle = 2'b00;
    localparam start = 2'b01;
    localparam data = 2'b10;
    localparam stop = 2'b11;
    
    
    reg [NB_DATA-1 : 0] shift_reg, next_shift_reg;
    reg rx_done_tick;
    
    always @(posedge i_clk_br) begin
        state_rx <= next_state_rx;
        cont_ticks <= next_cont_ticks;
        cont_bits <= next_cont_bits;
        shift_reg <= next_shift_reg;
        o_rx_done <= rx_done_tick;
    end

    always @(posedge i_clk_br) begin
        if (rx_done_tick)
            o_dout <= shift_reg;
    end

    
    always @(*) begin
        next_state_rx   = state_rx;      
        next_cont_ticks = cont_ticks;
        next_cont_bits  = cont_bits;
        next_shift_reg   = shift_reg;
        rx_done_tick    = 1'b0;
        case(state_rx)
            idle:begin
                if (i_rx == 0)begin
                    next_state_rx = start;
                end
                else begin
                    next_state_rx = idle;
                end
            end
            start:begin
                if(cont_ticks == 4'b0111) begin
                    next_cont_ticks = 4'b0;
                    next_state_rx = data;
                    next_cont_bits = 3'b0;
                end
                else begin
                    next_cont_ticks = cont_ticks + 1;
                end
            end
            data:begin
                if(cont_ticks == 4'b1111) begin
                    next_cont_ticks = 4'b0;
                    next_shift_reg = {i_rx, shift_reg[NB_DATA-1:1]};
                    next_cont_bits = cont_bits + 1;
                    if (cont_bits == NB_DATA - 1) begin
                        next_state_rx = stop;
                    end
                end
                else begin
                    next_cont_ticks = cont_ticks + 1;
                end

            end
            stop:begin
                if(cont_ticks == (SB_TICK - 1)) begin
                    rx_done_tick = 1;
                    next_state_rx = idle;
                end
                else begin
                    next_cont_ticks = cont_ticks + 1;
                end
            
            end
        endcase
    
    end
endmodule
