`timescale 1ns/1ps

module mem #(
    parameter NB_DATA = 32,
    parameter ADDR_W  = 10,             // 2^10 = 1024 bytes = 1 KB
    parameter NB_MEM  = 8               // ancho de cada posicion (un byte)
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               en,

    // Desde EX/MEM
    input  wire [NB_DATA-1:0] addr,
    input  wire [NB_DATA-1:0] store_data,
    input  wire [2:0]         funct3,
    input  wire               mem_read,
    input  wire               mem_write,

    // Hacia MEM/WB
    output reg  [NB_DATA-1:0] load_data,

    // Debug Unit
    input  wire [ADDR_W-3:0]  dbg_addr,
    output wire [NB_DATA-1:0] dbg_data,
    output reg  [ADDR_W-1:0]  max_addr
);

    // 0. Constantes de funct3
    localparam F3_LB  = 3'b000;
    localparam F3_LH  = 3'b001;
    localparam F3_LW  = 3'b010;
    localparam F3_LBU = 3'b100;
    localparam F3_LHU = 3'b101;
    localparam F3_SB  = 3'b000;
    localparam F3_SH  = 3'b001;
    localparam F3_SW  = 3'b010;

    // 1. Memoria de bytes y direcciones de los 4 bytes a tocar
    localparam DEPTH = 1 << ADDR_W;

    reg [NB_MEM-1:0] mem [0:DEPTH-1];
    reg [ADDR_W-1:0] a0, a1, a2, a3;

    always @(*) begin
        a0 = addr[ADDR_W-1:0];
        a1 = a0 + 1;
        a2 = a0 + 2;
        a3 = a0 + 3;
    end

    // 2. Escritura: rst borra todo, store escribe 1, 2 o 4 bytes (little-endian)
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                mem[i] <= {NB_MEM{1'b0}};
            end
        end
        else if (en && mem_write) begin
            case (funct3)
                F3_SB: begin
                    mem[a0] <= store_data[7:0];
                end
                F3_SH: begin
                    mem[a0] <= store_data[7:0];
                    mem[a1] <= store_data[15:8];
                end
                F3_SW: begin
                    mem[a0] <= store_data[7:0];
                    mem[a1] <= store_data[15:8];
                    mem[a2] <= store_data[23:16];
                    mem[a3] <= store_data[31:24];
                end
                default: begin
                end
            endcase
        end
    end

    // 3. Lectura: arma 1, 2 o 4 bytes y extiende a 32 bits segun funct3
    always @(*) begin
        case (funct3)
            F3_LB: begin
                load_data = {{24{mem[a0][7]}}, mem[a0]};
            end
            F3_LH: begin
                load_data = {{16{mem[a1][7]}}, mem[a1], mem[a0]};
            end
            F3_LW: begin
                load_data = {mem[a3], mem[a2], mem[a1], mem[a0]};
            end
            F3_LBU: begin
                load_data = {24'd0, mem[a0]};
            end
            F3_LHU: begin
                load_data = {16'd0, mem[a1], mem[a0]};
            end
            default: begin
                load_data = {NB_DATA{1'b0}};
            end
        endcase
    end

    // 4. Memoria usada: guarda el ultimo byte escrito mas alto
    always @(posedge clk) begin
        if (rst) begin
            max_addr <= {ADDR_W{1'b0}};
        end
        else if (en && mem_write) begin
            case (funct3)
                F3_SB: begin
                    if (a0 > max_addr) begin
                        max_addr <= a0;
                    end
                end
                F3_SH: begin
                    if (a1 > max_addr) begin
                        max_addr <= a1;
                    end
                end
                F3_SW: begin
                    if (a3 > max_addr) begin
                        max_addr <= a3;
                    end
                end
                default: begin
                end
            endcase
        end
    end

    // 5. Puerto de debug: lee la palabra dbg_addr (bytes 4k a 4k+3)
    wire [ADDR_W-1:0] d0;
    wire [ADDR_W-1:0] d1;
    wire [ADDR_W-1:0] d2;
    wire [ADDR_W-1:0] d3;

    assign d0 = {dbg_addr, 2'b00};
    assign d1 = {dbg_addr, 2'b01};
    assign d2 = {dbg_addr, 2'b10};
    assign d3 = {dbg_addr, 2'b11};

    assign dbg_data = {mem[d3], mem[d2], mem[d1], mem[d0]};

endmodule
