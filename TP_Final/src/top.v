`timescale 1ns/1ps
// ============================================================================
// top.v - Top para la Basys 3
//
// Por ahora solo esta la etapa IF (pc_unit + instr_mem) conectada a la Debug
// Unit. A medida que se agreguen etapas:
//   - cpu_halted pasa a ser "HALT llego a WB" (pipeline vacio).
//   - Se agregan entradas al mux del dump (registros, latches, memoria).
// ============================================================================
module top #(
    parameter ADDR_W = 8
)(
    input  wire clk,          // 100 MHz
    input  wire i_reset,      // boton
    input  wire i_rx,
    output wire o_tx
);

    localparam N_DUMP = 2;
    localparam DUMP_W = 8;
    localparam HALT   = 32'h00000000;

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
        .i_rx      (i_rx),
        .i_reset   (i_reset),
        .o_dout    (rx_data),
        .o_rx_done (rx_done)
    );

    tx_uart u_tx (
        .clk        (clk),
        .i_br       (br_tick),
        .i_reset    (i_reset),
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
    reg  [31:0]       dump_data;

    debug_unit #(
        .ADDR_W (ADDR_W),
        .N_DUMP (N_DUMP),
        .DUMP_W (DUMP_W)
    ) u_du (
        .clk        (clk),
        .rst        (i_reset),
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

    wire cpu_rst = i_reset | du_cpu_rst;

    // ---------------- Etapa IF ----------------
    wire [31:0] pc;
    wire [31:0] pc_plus4;
    wire [31:0] instr;

    // Provisorio: sin pipeline todavia, el HALT se detecta en IF
    wire halt_if = (instr == HALT);
    assign cpu_halted = halt_if;

    pc_unit u_pc (
        .clk             (clk),
        .rst             (cpu_rst),
        .en              (cpu_en),
        .stall           (1'b0),
        .halt            (halt_if),
        .redirect        (1'b0),
        .redirect_target (32'd0),
        .pc              (pc),
        .pc_plus4        (pc_plus4)
    );

    instr_mem #(.ADDR_W(ADDR_W)) u_imem (
        .clk       (clk),
        .pc        (pc),
        .instr     (instr),
        .dbg_we    (imem_we),
        .dbg_addr  (imem_addr),
        .dbg_wdata (imem_wdata),
        .dbg_rdata ()
    );

    // ---------------- Mux del dump ----------------
    always @(*) begin
        case (dump_idx)
            8'd0:    dump_data = pc;
            8'd1:    dump_data = instr;
            default: dump_data = 32'hDEADBEEF;
        endcase
    end

endmodule
