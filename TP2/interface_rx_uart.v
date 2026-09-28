module interface_rx_uart #(
    parameter NB_DATA=8
)
(
    input clk,
    input [NB_DATA-1:0] i_data,
    input set_flag, clr_flag,
    output [NB_DATA-1:0] o_data,
    output o_flag
);

    reg [NB_DATA-1:0] buffer_reg, next_buffer_reg;
    reg flag_reg, next_flag_reg;

    always @(posedge clk) begin
        buffer_reg <= next_buffer_reg;
        flag_reg <= next_flag_reg;
    end

    always @(*) begin
        next_buffer_reg = buffer_reg;
        next_flag_reg = flag_reg;

        if (set_flag) begin
            next_buffer_reg = i_data;
            next_flag_reg = 1'b1;
        end
        else if (clr_flag) begin
            next_flag_reg = 1'b0;
        end
    end

    assign o_flag = flag_reg;
    assign o_data = buffer_reg;

endmodule