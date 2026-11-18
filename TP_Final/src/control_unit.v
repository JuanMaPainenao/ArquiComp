module control_unit(
    input wire [6:0] opcode,

    output reg reg_write,
    output reg alu_src,
    output reg [1:0] alu_op,
    output reg mem_read,
    output reg mem_write,
    output reg [1:0] wb_sel,
    output reg branch,
    output reg jump,
    output reg jalr,
    output reg halt,
    output reg uses_rs1,
    output reg uses_rs2


);

always @(*) begin

    reg_write = 1'b0;
    alu_src = 1'b0;
    alu_op = 2'b0;
    mem_read = 1'b0;
    mem_write = 1'b0;
    wb_sel = 2'b0;
    branch = 1'b0;
    jump = 1'b0;
    jalr = 1'b0;
    halt = 1'b0;
    uses_rs1 = 1'b0;
    uses_rs2 = 1'b0;

    case(opcode)
        7'b0110011: begin //R
            reg_write = 1'b1;
            alu_op = 2'b01;
            uses_rs1 = 1'b1;
            uses_rs2 = 1'b1;
        end
        
        7'b0010011: begin //I
            reg_write = 1'b1;
            alu_src = 1'b1;
            alu_op = 2'b10;
            uses_rs1 = 1'b1;
        end

        7'b0000011: begin //load
            reg_write = 1'b1;
            alu_src = 1'b1;
            mem_read = 1'b1;
            wb_sel = 2'b01;
            uses_rs1 = 1'b1;
        end

        7'b0100011: begin //store
            alu_src = 1'b1;
            mem_write = 1'b1;
            uses_rs1 = 1'b1;
            uses_rs2 = 1'b1;
        end

        7'b1100011: begin //branch
            branch = 1'b1;
            uses_rs1 = 1'b1;
            uses_rs2 = 1'b1;
        end
        
        7'b1101111: begin //jal
            reg_write = 1'b1;
            wb_sel = 2'b10;
            jump = 1'b1;
        end

        7'b1100111: begin //jalr
            reg_write = 1'b1;
            alu_src = 1'b1;
            wb_sel = 2'b10;
            jalr = 1'b1;
            uses_rs1 = 1'b1;
        end

        7'b0110111: begin //lui
            reg_write = 1'b1;
            alu_src = 1'b1;
            alu_op = 2'b11;
        end

        7'b1111111,
        7'b0000000: begin
            halt = 1'b1;
        end
         

    endcase



end

endmodule