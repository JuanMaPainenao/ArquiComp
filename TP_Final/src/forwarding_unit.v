module forwarding_unit(
    input wire [4:0] rs1_ex,
    input wire [4:0] rs2_ex,
    input wire [4:0] rd_mem,
    input wire reg_write_mem,
    input wire [4:0]rd_wb,
    input wire reg_write_wb,

    output reg [1:0] fwd_a,
    output reg [1:0] fwd_b
);

    always @(*) begin
        if (reg_write_mem && (rd_mem != 5'd0) && (rd_mem == rs1_ex))
            fwd_a = 2'b01;
        else if (reg_write_wb && (rd_wb != 5'd0) && (rd_wb == rs1_ex))
            fwd_a = 2'b10;
        else
            fwd_a = 2'b00;

        if (reg_write_mem && (rd_mem != 5'd0) && (rd_mem == rs2_ex))
            fwd_b = 2'b01;
        else if (reg_write_wb && (rd_wb != 5'd0) && (rd_wb == rs2_ex))
            fwd_b = 2'b10;
        else
            fwd_b = 2'b00;
    end


endmodule