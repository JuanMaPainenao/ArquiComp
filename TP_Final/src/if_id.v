module if_id(
    input wire clk,
    input wire rst,
    input wire en,
    input wire stall,
    input wire flush,

    input wire [31:0] instr_in,
    input wire [31:0] pc_in,
    input wire [31:0] pc4_in,

    output reg [31:0] instr_out,
    output reg [31:0] pc_out,
    output reg [31:0] pc4_out    
);
    localparam [31:0] NOP = 32'h00000013;

    always @(posedge clk) begin
        if(rst || (en && !stall && flush)) begin
            instr_out <= NOP;
            pc_out <= 32'b0;
            pc4_out <= 32'b0;
        end
        else if (en && !stall) begin
            instr_out <= instr_in;
            pc_out <= pc_in;
            pc4_out <= pc4_in;
        end
    
    end

endmodule