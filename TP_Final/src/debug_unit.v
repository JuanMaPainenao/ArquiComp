`timescale 1ns/1ps
// debug_unit.v - Recibe comandos por UART, carga la memoria de programa,
// maneja cpu_en (paso a paso o continuo) y manda el dump. Ver docs/debug_unit.md.
module debug_unit #(
    parameter ADDR_W = 8,                  // bits de direccion de instr_mem
    parameter DUMP_W = 8                   // ancho de dump_idx
)(
    input  wire              clk,
    input  wire              rst,

    // UART
    input  wire [7:0]        rx_data,
    input  wire              rx_done,
    input  wire              br_tick,
    input  wire              tx_done,
    output wire              tx_start,
    output reg  [7:0]        tx_data,

    // Control del procesador
    output wire              cpu_en,
    output reg               cpu_rst,
    input  wire              cpu_halted,

    // Puerto de escritura de la memoria de programa
    output wire              imem_we,
    output reg  [ADDR_W-1:0] imem_addr,
    output reg  [31:0]       imem_wdata,
    input  wire [31:0]       imem_rdata,   // lectura (asincronica) en imem_addr

    // Bus de dump
    output wire [DUMP_W-1:0] dump_idx,
    input  wire [31:0]       dump_data,
    input  wire [13:0]       dump_words    // palabras de 32 bits por dump
);

    localparam CMD_LOAD  = 8'h4C;  // 'L'
    localparam CMD_STEP  = 8'h53;  // 'S'
    localparam CMD_RUN   = 8'h52;  // 'R'
    localparam CMD_DUMP  = 8'h44;  // 'D'
    localparam CMD_RESET = 8'h58;  // 'X'
    localparam CMD_PREAD = 8'h50;  // 'P'
    localparam RSP_ACK   = 8'h4B;  // 'K'
    localparam RSP_NAK   = 8'h3F;  // '?'

    localparam ST_IDLE    = 4'd0;
    localparam ST_LOAD_N0 = 4'd1;
    localparam ST_LOAD_N1 = 4'd2;
    localparam ST_LOAD_W  = 4'd3;
    localparam ST_LOAD_WR = 4'd4;
    localparam ST_STEP    = 4'd5;
    localparam ST_RUN     = 4'd6;
    localparam ST_DUMP    = 4'd7;
    localparam ST_TX_BR   = 4'd8;
    localparam ST_TX_DONE = 4'd9;
    localparam ST_PRD_N0  = 4'd10;
    localparam ST_PRD_N1  = 4'd11;
    localparam ST_PRD     = 4'd12;

    // Que hacer cuando termina de salir un byte por la UART
    localparam AFT_IDLE = 2'd0;            // volver a IDLE
    localparam AFT_DUMP = 2'd1;            // siguiente byte del dump
    localparam AFT_PRD  = 2'd2;            // siguiente byte de la lectura de imem


    reg [3:0]  state;
    reg [15:0] n_words;                    // palabras que faltan cargar
    reg [1:0]  byte_i;                     // byte dentro de la palabra
    reg [15:0] byte_cnt;                   // byte del dump que se esta mandando
    reg [1:0]  after;                      // ver AFT_*

    wire [15:0] dump_byte = byte_cnt - 16'd1;   // byte 0 es el estado

    assign dump_idx = dump_byte[DUMP_W+1:2];
    assign tx_start = (state == ST_TX_BR) && br_tick;
    assign imem_we  = (state == ST_LOAD_WR);
    assign cpu_en   = ((state == ST_STEP) || (state == ST_RUN)) && !cpu_halted;

    always @(posedge clk) begin
        if (rst) begin
            state      <= ST_IDLE;
            cpu_rst    <= 1'b0;
            n_words    <= 16'd0;
            byte_i     <= 2'd0;
            byte_cnt   <= 16'd0;
            after      <= AFT_IDLE;
            tx_data    <= 8'd0;
            imem_addr  <= {ADDR_W{1'b0}};
            imem_wdata <= 32'd0;
        end
        else begin
            cpu_rst <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (rx_done) begin
                        case (rx_data)
                            CMD_LOAD: state <= ST_LOAD_N0;
                            CMD_STEP: state <= ST_STEP;
                            CMD_RUN:  state <= ST_RUN;
                            CMD_DUMP: begin
                                byte_cnt <= 16'd0;
                                state    <= ST_DUMP;
                            end
                            CMD_PREAD: state <= ST_PRD_N0;
                            CMD_RESET: begin
                                cpu_rst <= 1'b1;
                                tx_data <= RSP_ACK;
                                after   <= AFT_IDLE;
                                state   <= ST_TX_BR;
                            end
                            default: begin
                                tx_data <= RSP_NAK;
                                after   <= AFT_IDLE;
                                state   <= ST_TX_BR;
                            end
                        endcase
                    end
                end

                ST_LOAD_N0: begin
                    if (rx_done) begin
                        n_words[7:0] <= rx_data;
                        state        <= ST_LOAD_N1;
                    end
                end

                ST_LOAD_N1: begin
                    if (rx_done) begin
                        n_words[15:8] <= rx_data;
                        imem_addr     <= {ADDR_W{1'b0}};
                        byte_i        <= 2'd0;
                        if ({rx_data, n_words[7:0]} == 16'd0) begin
                            cpu_rst <= 1'b1;
                            tx_data <= RSP_ACK;
                            after   <= AFT_IDLE;
                            state   <= ST_TX_BR;
                        end
                        else
                            state <= ST_LOAD_W;
                    end
                end

                // Arma la palabra byte a byte (little-endian)
                ST_LOAD_W: begin
                    if (rx_done) begin
                        imem_wdata <= {rx_data, imem_wdata[31:8]};
                        byte_i     <= byte_i + 2'd1;
                        if (byte_i == 2'd3)
                            state <= ST_LOAD_WR;
                    end
                end

                // imem_we = 1 en este ciclo
                ST_LOAD_WR: begin
                    imem_addr <= imem_addr + 1'b1;
                    n_words   <= n_words - 16'd1;
                    if (n_words == 16'd1) begin
                        cpu_rst <= 1'b1;
                        tx_data <= RSP_ACK;
                        after   <= AFT_IDLE;
                        state   <= ST_TX_BR;
                    end
                    else
                        state <= ST_LOAD_W;
                end

                // Lectura de la memoria de programa: 'P' N_lo N_hi
                ST_PRD_N0: begin
                    if (rx_done) begin
                        n_words[7:0] <= rx_data;
                        state        <= ST_PRD_N1;
                    end
                end

                ST_PRD_N1: begin
                    if (rx_done) begin
                        n_words[15:8] <= rx_data;
                        imem_addr     <= {ADDR_W{1'b0}};
                        byte_i        <= 2'd0;
                        if ({rx_data, n_words[7:0]} == 16'd0) begin
                            tx_data <= RSP_ACK;
                            after   <= AFT_IDLE;
                            state   <= ST_TX_BR;
                        end
                        else
                            state <= ST_PRD;
                    end
                end

                ST_PRD: begin
                    tx_data <= imem_rdata >> (8 * byte_i);
                    after   <= AFT_PRD;
                    state   <= ST_TX_BR;
                end

                // cpu_en = 1 durante exactamente este ciclo
                ST_STEP: begin
                    byte_cnt <= 16'd0;
                    state    <= ST_DUMP;
                end

                ST_RUN: begin
                    if (cpu_halted) begin
                        byte_cnt <= 16'd0;
                        state    <= ST_DUMP;
                    end
                end

                ST_DUMP: begin
                    if (byte_cnt == 16'd0)
                        tx_data <= {7'd0, cpu_halted};
                    else
                        tx_data <= dump_data >> (8 * dump_byte[1:0]);
                    after   <= AFT_DUMP;
                    state   <= ST_TX_BR;
                end

                ST_TX_BR: begin
                    if (br_tick)
                        state <= ST_TX_DONE;
                end

                ST_TX_DONE: begin
                    if (tx_done) begin
                        state <= ST_IDLE;
                        if (after == AFT_DUMP && byte_cnt != {dump_words, 2'b00}) begin
                            byte_cnt <= byte_cnt + 16'd1;
                            state    <= ST_DUMP;
                        end
                        if (after == AFT_PRD) begin
                            byte_i <= byte_i + 2'd1;
                            if (byte_i == 2'd3) begin
                                imem_addr <= imem_addr + 1'b1;
                                n_words   <= n_words - 16'd1;
                                if (n_words != 16'd1)
                                    state <= ST_PRD;
                            end
                            else
                                state <= ST_PRD;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
