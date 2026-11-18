`timescale 1ns/1ps
// ============================================================================
// top.v - Top para la Basys 3: UART + Debug Unit + cpu (pipeline de 5 etapas)
//
// Layout del dump (palabras de 32 bits, indice = dump_idx), despues del byte
// de estado (bit0 = halted):
//   0              PC (etapa IF)
//   1              M = palabras de memoria de datos que vienen al final
//   2  .. 21       latches / riesgos (dbg_latch_sel 0..19, ver cpu.v)
//   22 .. 53       x0 .. x31
//   54 .. 54+M-1   memoria de datos usada: palabras 0 .. M-1
//
// "Memoria usada" = desde la direccion 0 hasta la palabra que contiene el
// byte escrito mas alto (dmem_max_addr). Como minimo se manda la palabra 0.
//
// Memoria de datos: DMEM_ADDR_W = 8 (256 bytes). mem.v esta hecha con
// flip-flops (rst la borra entera y la lectura es asincronica), asi que con
// 1 KB no entra en la xc7a35t; con 256 bytes si.
//
// Clock: el pipeline no cierra timing a 100 MHz, asi que todo el sistema
// corre con clk_sys = 80 MHz generado por el MMCM (clk_gen.v). El clock de la
// placa solo entra al MMCM. Mientras el MMCM no engancha (locked = 0) todo
// queda en reset.
// ============================================================================
module top #(
    parameter IMEM_ADDR_W = 8,          // 256 instrucciones
    parameter DMEM_ADDR_W = 8,          // 256 bytes de datos
    parameter BR_DIV      = 130         // 80 MHz / (16 * 38400) = 130.2
)(
    input  wire clk_100,      // 100 MHz de la placa
    input  wire i_reset,      // boton
    input  wire i_rx,
    output wire o_tx
);

    localparam DUMP_W   = 8;
    localparam N_LAT    = 20;
    localparam LAT_BASE = 2;
    localparam REG_BASE = LAT_BASE + N_LAT;      // 22
    localparam MEM_BASE = REG_BASE + 32;         // 54

    // ---------------- Clock y reset ----------------
    wire clk;                 // clk_sys: 80 MHz, lo usa todo el diseno
    wire locked;

    clk_gen u_clk (
        .clk_in  (clk_100),
        .clk_out (clk),
        .locked  (locked)
    );

    wire rst = i_reset | ~locked;

    // ---------------- UART ----------------
    wire       br_tick;
    wire [7:0] rx_data;
    wire       rx_done;
    wire       tx_start;
    wire [7:0] tx_data;
    wire       tx_done;

    br_generator #(.DIV(BR_DIV)) u_br (
        .clk  (clk),
        .o_br (br_tick)
    );

    rx_uart u_rx (
        .clk       (clk),
        .i_br      (br_tick),
        .i_rx      (i_rx),
        .i_reset   (rst),
        .o_dout    (rx_data),
        .o_rx_done (rx_done)
    );

    tx_uart u_tx (
        .clk        (clk),
        .i_br       (br_tick),
        .i_reset    (rst),
        .i_tx_start (tx_start),
        .i_data     (tx_data),
        .o_tx       (o_tx),
        .o_tx_done  (tx_done)
    );

    // ---------------- Debug Unit ----------------
    wire                   cpu_en;
    wire                   du_cpu_rst;
    wire                   cpu_halted;
    wire                   imem_we;
    wire [IMEM_ADDR_W-1:0] imem_addr;
    wire [31:0]            imem_wdata;
    wire [31:0]            imem_rdata;
    wire [DUMP_W-1:0]      dump_idx;
    reg  [31:0]            dump_data;

    wire [DMEM_ADDR_W-1:0] dmem_max_addr;
    wire [13:0]            mem_words  = dmem_max_addr[DMEM_ADDR_W-1:2] + 14'd1;
    wire [13:0]            dump_words = MEM_BASE + mem_words;

    debug_unit #(
        .ADDR_W (IMEM_ADDR_W),
        .DUMP_W (DUMP_W)
    ) u_du (
        .clk        (clk),
        .rst        (rst),
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
        .imem_rdata (imem_rdata),
        .dump_idx   (dump_idx),
        .dump_data  (dump_data),
        .dump_words (dump_words)
    );

    wire cpu_rst = rst | du_cpu_rst;

    // ---------------- Procesador ----------------
    wire [DUMP_W-1:0] lat_idx = dump_idx - LAT_BASE;
    wire [DUMP_W-1:0] reg_idx = dump_idx - REG_BASE;
    wire [DUMP_W-1:0] mem_idx = dump_idx - MEM_BASE;

    wire [31:0] pc;
    wire [31:0] reg_dbg_data;
    wire [31:0] mem_dbg_data;
    wire [31:0] lat_dbg_data;

    cpu #(
        .IMEM_ADDR_W (IMEM_ADDR_W),
        .DMEM_ADDR_W (DMEM_ADDR_W)
    ) u_cpu (
        .clk            (clk),
        .rst            (cpu_rst),
        .en             (cpu_en),
        .halted         (cpu_halted),
        .dbg_imem_we    (imem_we),
        .dbg_imem_addr  (imem_addr),
        .dbg_imem_wdata (imem_wdata),
        .dbg_imem_rdata (imem_rdata),
        .dbg_reg_addr   (reg_idx[4:0]),
        .dbg_reg_data   (reg_dbg_data),
        .dbg_dmem_addr  (mem_idx[DMEM_ADDR_W-3:0]),
        .dbg_dmem_data  (mem_dbg_data),
        .dmem_max_addr  (dmem_max_addr),
        .pc             (pc),
        .dbg_latch_sel  (lat_idx[4:0]),
        .dbg_latch_data (lat_dbg_data)
    );

    // ---------------- Mux del dump ----------------
    always @(*) begin
        if (dump_idx == 0)
            dump_data = pc;
        else if (dump_idx == 1)
            dump_data = {18'd0, mem_words};
        else if (dump_idx < REG_BASE)
            dump_data = lat_dbg_data;
        else if (dump_idx < MEM_BASE)
            dump_data = reg_dbg_data;
        else
            dump_data = mem_dbg_data;
    end

endmodule
