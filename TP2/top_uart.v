module top_uart
#(
    parameter NB_DATA = 8
)(
    input clk,
    input i_rx,
    input i_reset,
    output [NB_DATA-1:0] o_dout,
    output o_rx_done,

    input i_tx_start,
    input [NB_DATA-1:0] i_data,
    output o_tx,
    output o_tx_done
);

wire i_br;

rx_uart #(.NB_DATA(NB_DATA)) u_rx_uart(
    .clk (clk),
    .i_br (i_br),
    .i_rx (i_rx),
    .i_reset (i_reset),
    .o_dout (o_dout),
    .o_rx_done (o_rx_done)
);

tx_uart #(.NB_DATA(NB_DATA)) u_tx_uart(
    .clk (clk),
    .i_br (i_br),
    .i_reset (i_reset),
    .i_tx_start (i_tx_start),
    .i_data (i_data),
    .o_tx (o_tx),
    .o_tx_done (o_tx_done)
);

br_generator u_br_generator(
    .clk (clk),
    .o_br (i_br)
);




endmodule