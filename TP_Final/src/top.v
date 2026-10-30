`timescale 1ns/1ps
// ============================================================================
// top.v - Top para la Basys 3
//
//   UART (br_generator, rx_uart, tx_uart) + Debug Unit + cpu
//
// El procesador vive en cpu.v (IF + ID por ahora) junto con el mux del dump,
// asi el top no cambia cuando se agregan etapas: solo hay que actualizar
// N_DUMP si cpu.v agrega palabras al dump.
//
// Cambios respecto de la version anterior:
//   - La etapa IF y el mux del dump se mudaron a cpu.v.
//   - i_rx e i_reset pasan por un sincronizador de 2 flip-flops: son senales
//     asincronicas al clock y, sin sincronizar, cada flip-flop de la FSM puede
//     ver un valor distinto si cambian justo en el flanco.
// ============================================================================
module top #(
    parameter ADDR_W = 8
)(
    input  wire clk,          // 100 MHz
    input  wire i_reset,      // boton (btnC)
    input  wire i_rx,
    output wire o_tx
);

    localparam N_DUMP = 43;   // ver tabla del dump en cpu.v
    localparam DUMP_W = 8;

    // ---------------- Sincronizadores ----------------
    reg rx_s1  = 1'b1, rx_s2  = 1'b1;     // la linea UART en reposo esta en 1
    reg rst_s1 = 1'b0, rst_s2 = 1'b0;

    always @(posedge clk) begin
        rx_s1  <= i_rx;
        rx_s2  <= rx_s1;
        rst_s1 <= i_reset;
        rst_s2 <= rst_s1;
    end

    wire rx    = rx_s2;
    wire reset = rst_s2;

    // ---------------- UART ----------------
    wire       br_tick;
    wire [7:0] rx_data;
    wire       rx_done;
    wire       tx_start;
    wire [7:0] tx_data;
    wire       tx_done;

    br_generator u_br (
        .clk  (clk),
        .o_br (br_tick)
    );

    rx_uart u_rx (
        .clk       (clk),
        .i_br      (br_tick),
        .i_rx      (rx),
        .i_reset   (reset),
        .o_dout    (rx_data),
        .o_rx_done (rx_done)
    );

    tx_uart u_tx (
        .clk        (clk),
        .i_br       (br_tick),
        .i_reset    (reset),
        .i_tx_start (tx_start),
        .i_data     (tx_data),
        .o_tx       (o_tx),
        .o_tx_done  (tx_done)
    );

    // ---------------- Debug Unit ----------------
    wire              cpu_en;
    wire              du_cpu_rst;
    wire              cpu_halted;
    wire              imem_we;
    wire [ADDR_W-1:0] imem_addr;
    wire [31:0]       imem_wdata;
    wire [DUMP_W-1:0] dump_idx;
    wire [31:0]       dump_data;

    debug_unit #(
        .ADDR_W (ADDR_W),
        .N_DUMP (N_DUMP),
        .DUMP_W (DUMP_W)
    ) u_du (
        .clk        (clk),
        .rst        (reset),
        .rx_data    (rx_data),
        .rx_done    (rx_done),
        .br_tick    (br_tick),
        .tx_done    (tx_done),
        .tx_start   (tx_start),
        .tx_data    (tx_data),
        .cpu_en     (cpu_en),
        .cpu_rst    (du_cpu_rst),
        .cpu_halted (cpu_halted),
        .imem_we    (imem_we),
        .imem_addr  (imem_addr),
        .imem_wdata (imem_wdata),
        .dump_idx   (dump_idx),
        .dump_data  (dump_data)
    );

    // ---------------- Procesador ----------------
    cpu #(.ADDR_W(ADDR_W)) u_cpu (
        .clk        (clk),
        .rst        (reset | du_cpu_rst),
        .en         (cpu_en),
        .imem_we    (imem_we),
        .imem_addr  (imem_addr),
        .imem_wdata (imem_wdata),
        .halted     (cpu_halted),
        .dump_idx   (dump_idx),
        .dump_data  (dump_data)
    );

endmodule
