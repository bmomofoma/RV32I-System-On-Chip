`timescale 1ns / 1ps

module reg_file (
    input  logic        clk,        
    input  logic        rst,        
    input  logic        reg_write,  
    input  logic [4:0]  rs1,        
    input  logic [4:0]  rs2,        
    input  logic [4:0]  rd,         
    input  logic [31:0] write_data, 
    output logic [31:0] read_data1, 
    output logic [31:0] read_data2  
);

    logic [31:0] register [31:0]; 

    assign read_data1 = (rs1 == 5'b0) ? 32'b0 : register[rs1];
    assign read_data2 = (rs2 == 5'b0) ? 32'b0 : register[rs2];

    // Synchronous Write Sequential State Control
    always_ff @(posedge clk or posedge rst) begin : register_write_port
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                register[i] <= 32'b0;
            end
        end else if (reg_write && (rd != 5'b0)) begin
            register[rd] <= write_data;
        end
    end

endmodule