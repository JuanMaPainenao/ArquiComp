`timescale 1ns / 1ps
// ============================================================================
// tb_cpu.v - Testbench autoverificante del pipeline (cpu.v) con
// programs/pipeline.hex. Carga el programa por el puerto de debug de imem,
// corre hasta halted y chequea registros y memoria de datos. Imprime en cada
// ciclo que direccion hay en cada etapa (-- = burbuja).
// ============================================================================
module tb_cpu;

    localparam N = 29;

    reg         clk = 0, rst = 1, en = 0;
    reg         imem_we = 0;
    reg  [7:0]  imem_addr = 0;
    reg  [31:0] imem_wdata = 0;
    reg  [4:0]  reg_addr = 0;
    reg  [5:0]  dmem_addr = 0;
    reg  [4:0]  lat_sel = 0;
    wire [31:0] reg_data, dmem_data, lat_data, pc;
    wire [7:0]  dmem_max;
    wire        halted;

    reg [31:0] prog [0:N];
    integer i, ciclos = 0, errores = 0;

    cpu #(.IMEM_ADDR_W(8), .DMEM_ADDR_W(8)) dut (
        .clk(clk), .rst(rst), .en(en), .halted(halted),
        .dbg_imem_we(imem_we), .dbg_imem_addr(imem_addr),
        .dbg_imem_wdata(imem_wdata), .dbg_imem_rdata(),
        .dbg_reg_addr(reg_addr), .dbg_reg_data(reg_data),
        .dbg_dmem_addr(dmem_addr), .dbg_dmem_data(dmem_data),
        .dmem_max_addr(dmem_max), .pc(pc),
        .dbg_latch_sel(lat_sel), .dbg_latch_data(lat_data)
    );

    always #5 clk = ~clk;

    task check_reg(input integer r, input [31:0] exp);
        begin
            reg_addr = r; #1;
            if (reg_data !== exp) begin
                $display("ERROR x%0d = %h (esperado %h)", r, reg_data, exp);
                errores = errores + 1;
            end
        end
    endtask

    task check_mem(input integer w, input [31:0] exp);
        begin
            dmem_addr = w; #1;
            if (dmem_data !== exp) begin
                $display("ERROR mem[%0d] = %h (esperado %h)", 4*w, dmem_data, exp);
                errores = errores + 1;
            end
        end
    endtask

    function [39:0] st(input [31:0] pc4);
        st = (pc4 == 0) ? "  -- " : {"0x", hex3(pc4 - 4)};
    endfunction
    function [23:0] hex3(input [31:0] v);
        hex3 = {hx(v[11:8]), hx(v[7:4]), hx(v[3:0])};
    endfunction
    function [7:0] hx(input [3:0] n);
        hx = (n < 10) ? ("0" + n) : ("A" + n - 10);
    endfunction

    reg [31:0] p_id, p_ex, p_mem, p_wb, hz;

    initial begin
        prog[0] = 32'h00500093;
        prog[1] = 32'h00700113;
        prog[2] = 32'h002081b3;
        prog[3] = 32'h40118233;
        prog[4] = 32'h123452b7;
        prog[5] = 32'h67828293;
        prog[6] = 32'h00502023;
        prog[7] = 32'h00300223;
        prog[8] = 32'h00401323;
        prog[9] = 32'h00002303;
        prog[10] = 32'h00130393;
        prog[11] = 32'h00300403;
        prog[12] = 32'h00004483;
        prog[13] = 32'h00201503;
        prog[14] = 32'h00220663;
        prog[15] = 32'hfff00593;
        prog[16] = 32'hfff00593;
        prog[17] = 32'h00109063;
        prog[18] = 32'h00300613;
        prog[19] = 32'h00c686b3;
        prog[20] = 32'hfff60613;
        prog[21] = 32'hfe061ce3;
        prog[22] = 32'h00c000ef;
        prog[23] = 32'h00d02423;
        prog[24] = 32'h00000000;
        prog[25] = 32'h06468713;
        prog[26] = 32'h00e02623;
        prog[27] = 32'h003227b3;
        prog[28] = 32'h00008067;
        prog[N] = 32'h00000000;   // HALT de seguridad (como agrega du.ps1)

        // Carga por el puerto de debug
        for (i = 0; i <= N; i = i + 1) begin
            imem_addr = i; imem_wdata = prog[i]; imem_we = 1;
            @(posedge clk); #1;
        end
        imem_we = 0;
        @(posedge clk); #1 rst = 0;

        $display(" ciclo   IF     ID     EX     MEM    WB    riesgos");
        en = 1;
        while (!halted && ciclos < 500) begin
            lat_sel = 2;  #0.1 p_id  = lat_data;
            lat_sel = 3;  #0.1 p_ex  = lat_data;
            lat_sel = 8;  #0.1 p_mem = lat_data;
            lat_sel = 11; #0.1 p_wb  = lat_data;
            lat_sel = 15; #0.1 hz    = lat_data;
            $display("%5d   0x%h  %s  %s  %s  %s %s%s%s%s",
                     ciclos, pc[11:0], st(p_id), st(p_ex), st(p_mem), st(p_wb),
                     hz[0] ? " STALL" : "", hz[3] ? " SALTO" : "",
                     hz[4] ? " HALT-fetch" : "",
                     (hz[6:5] | hz[8:7]) ? " fwd" : "");
            @(posedge clk); #1;
            ciclos = ciclos + 1;
        end
        en = 0;
        $display("halted en %0d ciclos", ciclos);

        check_reg(0,  32'd0);
        check_reg(1,  32'h5C);
        check_reg(2,  32'd7);
        check_reg(3,  32'd12);
        check_reg(4,  32'd7);
        check_reg(5,  32'h12345678);
        check_reg(6,  32'h12345678);
        check_reg(7,  32'h12345679);
        check_reg(8,  32'h12);
        check_reg(9,  32'h78);
        check_reg(10, 32'h1234);
        check_reg(11, 32'd0);
        check_reg(12, 32'd0);
        check_reg(13, 32'd6);
        check_reg(14, 32'd106);
        check_reg(15, 32'd1);
        check_mem(0, 32'h12345678);
        check_mem(1, 32'h0007000C);
        check_mem(2, 32'd6);
        check_mem(3, 32'd106);
        if (dmem_max !== 8'd15) begin
            $display("ERROR dmem_max_addr = %0d (esperado 15)", dmem_max);
            errores = errores + 1;
        end

        if (!halted) $display("ERROR: no llego a HALT");
        if (errores == 0 && halted) $display("TEST OK");
        else                        $display("TEST FALLIDO: %0d errores", errores);
        $finish;
    end

endmodule
