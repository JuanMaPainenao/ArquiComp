`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: top_uart_alu
// Integra la UART (rx/tx + interface_rx_uart) con la Alu de TP1.
//
// Protocolo: por cada operacion se reciben 3 bytes por i_rx, en este orden:
//   1) A
//   2) B
//   3) OP  (se usan los NB_OP_CODE bits bajos del byte)
// Al recibir el tercer byte se calcula RES y se transmite automaticamente
// como un unico byte por o_tx.
//////////////////////////////////////////////////////////////////////////////////

module top_uart_alu #(
    parameter NB_DATA    = 8,
    parameter NB_OP_CODE = 6,
    parameter SB_TICK    = 16
)(
    input  clk,
    input  i_reset,
    input  i_rx,
    output o_tx
);

    localparam ST_WAIT_A      = 3'd0;
    localparam ST_WAIT_B      = 3'd1;
    localparam ST_WAIT_OP     = 3'd2;
    localparam ST_SEND_RES    = 3'd3;
    localparam ST_WAIT_TXDONE = 3'd4;

    wire i_br;
    wire [NB_DATA-1:0] rx_dout;
    wire rx_done;
    wire [NB_DATA-1:0] uart_data;
    wire uart_flag;
    wire tx_done;
    wire [NB_DATA-1:0] alu_res;

    reg [2:0] state, next_state;
    reg [NB_DATA-1:0]    reg_a,  next_reg_a;
    reg [NB_DATA-1:0]    reg_b,  next_reg_b;
    reg [NB_OP_CODE-1:0] reg_op, next_reg_op;
    reg clr_flag, tx_start;

    br_generator u_br (
        .clk  (clk),
        .o_br (i_br)
    );

    rx_uart #(.NB_DATA(NB_DATA), .SB_TICK(SB_TICK)) u_rx (
        .clk       (clk),
        .i_br      (i_br),
        .i_rx      (i_rx),
        .i_reset   (i_reset),
        .o_dout    (rx_dout),
        .o_rx_done (rx_done)
    );

    interface_rx_uart #(.NB_DATA(NB_DATA)) u_if (
        .clk      (clk),
        .i_data   (rx_dout),
        .set_flag (rx_done),
        .clr_flag (clr_flag),
        .o_data   (uart_data),
        .o_flag   (uart_flag)
    );

    tx_uart #(.NB_DATA(NB_DATA), .SB_TICK(SB_TICK)) u_tx (
        .clk        (clk),
        .i_br       (i_br),
        .i_reset    (i_reset),
        .i_tx_start (tx_start),
        .i_data     (alu_res),
        .o_tx       (o_tx),
        .o_tx_done  (tx_done)
    );

    Alu #(.NB_DATA(NB_DATA), .NB_OP_CODE(NB_OP_CODE)) u_alu (
        .A   (reg_a),
        .B   (reg_b),
        .OP  (reg_op),
        .RES (alu_res)
    );

    always @(posedge clk) begin
        if (i_reset) begin
            state  <= ST_WAIT_A;
            reg_a  <= {NB_DATA{1'b0}};
            reg_b  <= {NB_DATA{1'b0}};
            reg_op <= {NB_OP_CODE{1'b0}};
        end
        else begin
            state  <= next_state;
            reg_a  <= next_reg_a;
            reg_b  <= next_reg_b;
            reg_op <= next_reg_op;
        end
    end

    always @(*) begin
        next_state  = state;
        next_reg_a  = reg_a;
        next_reg_b  = reg_b;
        next_reg_op = reg_op;
        clr_flag = 1'b0;
        tx_start = 1'b0;

        case (state)
            ST_WAIT_A: begin
                if (uart_flag) begin
                    next_reg_a = uart_data;
                    clr_flag   = 1'b1;
                    next_state = ST_WAIT_B;
                end
            end

            ST_WAIT_B: begin
                if (uart_flag) begin
                    next_reg_b = uart_data;
                    clr_flag   = 1'b1;
                    next_state = ST_WAIT_OP;
                end
            end

            ST_WAIT_OP: begin
                if (uart_flag) begin
                    next_reg_op = uart_data[NB_OP_CODE-1:0];
                    clr_flag    = 1'b1;
                    next_state  = ST_SEND_RES;
                end
            end

            // Espera un tick de baudrate para asegurar que tx_uart
            // vea i_tx_start e i_br=1 en el mismo ciclo (esta en idle).
            ST_SEND_RES: begin
                if (i_br) begin
                    tx_start   = 1'b1;
                    next_state = ST_WAIT_TXDONE;
                end
            end

            ST_WAIT_TXDONE: begin
                if (tx_done)
                    next_state = ST_WAIT_A;
            end
        endcase
    end

endmodule
