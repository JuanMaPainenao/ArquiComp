`timescale 1ns/1ps
// tb_wb.v - Prueba el mux de WB, que rd y reg_write pasen directo y que
// halted se trabe en 1 hasta el rst.
module tb_wb;

    reg         clk;
    reg         rst;
    reg         en;
    reg  [31:0] load_data;
    reg  [31:0] alu_result;
    reg  [31:0] pc4;
    reg  [4:0]  rd;
    reg         reg_write;
    reg  [1:0]  wb_sel;
    reg         halt;
    wire [31:0] write_data;
    wire [4:0]  rd_out;
    wire        reg_write_out;
    wire        halted;

    integer errores = 0;

    wb dut (
        .clk            (clk),
        .rst            (rst),
        .en             (en),
        .load_data_in   (load_data),
        .alu_result_in  (alu_result),
        .pc4_in         (pc4),
        .rd_in          (rd),
        .reg_write_in   (reg_write),
        .wb_sel_in      (wb_sel),
        .halt_in        (halt),
        .write_data_out (write_data),
        .rd_out         (rd_out),
        .reg_write_out  (reg_write_out),
        .halted         (halted)
    );

    always #5 clk = ~clk;

    task check(input [255:0] nombre, input [31:0] got, input [31:0] exp);
        begin
            if (got !== exp) begin
                $display("ERROR %0s: got=%h esperado=%h", nombre, got, exp);
                errores = errores + 1;
            end
        end
    endtask

    // Los valores iniciales se ponen aca y no en la declaracion, para que
    // generen un cambio en t = 0 y el always @(*) de wb.v se evalue.
    initial begin
        clk        = 0;
        rst        = 1;
        en         = 1;
        load_data  = 32'hAAAA0001;
        alu_result = 32'hBBBB0002;
        pc4        = 32'h00000044;
        rd         = 0;
        reg_write  = 0;
        wb_sel     = 0;
        halt       = 0;
        @(negedge clk);
        rst = 0;

        $display("--- 1. Mux del dato");
        wb_sel = 2'b00;
        #1;
        check("wb_sel 00 (ALU)", write_data, 32'hBBBB0002);
        wb_sel = 2'b01;
        #1;
        check("wb_sel 01 (MEM)", write_data, 32'hAAAA0001);
        wb_sel = 2'b10;
        #1;
        check("wb_sel 10 (PC+4)", write_data, 32'h00000044);
        wb_sel = 2'b11;
        #1;
        check("wb_sel 11 (invalido)", write_data, 32'h00000000);

        $display("--- 2. rd y reg_write");
        rd        = 17;
        reg_write = 1;
        #1;
        check("rd", rd_out, 17);
        check("reg_write", reg_write_out, 1);

        $display("--- 3. halted");
        check("halted al empezar", halted, 0);
        en   = 0;
        halt = 1;
        @(negedge clk);
        check("con en = 0 no sube", halted, 0);
        en = 1;
        @(negedge clk);
        check("sube", halted, 1);
        halt = 0;
        @(negedge clk);
        check("queda en 1", halted, 1);
        rst = 1;
        @(negedge clk);
        check("baja con rst", halted, 0);

        if (errores == 0) begin
            $display("TEST OK");
        end
        else begin
            $display("TEST FALLIDO: %0d errores", errores);
        end
        $finish;
    end

endmodule
