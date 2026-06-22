`timescale 1ns / 1ps

module alu_logic (
    input  logic [31:0] a,       
    input  logic [31:0] b,       
    input  logic [3:0]  op,      
    output logic [31:0] result,  
    output logic        zero     
);
  
    assign zero = (result == 32'b0);
  
    always @* begin
        case (op)
            // Bitwise Hardware Paths
            4'b0000: result = a & b;                  
            4'b0001: result = a | b;                  
            4'b0010: result = a ^ b;                  
            4'b0011: result = ~a;                     
            
            // Arithmetic Combinational Logic Blocks
            4'b0100: result = a + b;                  
            4'b0101: result = a - b;                  
            
            // Barrel Shifter Sub-Circuits (RISC-V restricts shift depth to lower 5 bits)
            4'b0110: result = a << b[4:0];            
            4'b0111: result = a >> b[4:0];            
            4'b1000: result = $signed(a) >>> b[4:0]; 
            
            // Relational Comparators
            4'b1001: result = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0; 
            4'b1010: result = (a < b) ? 32'b1 : 32'b0;                   
            
            default: result = 32'h0000_0000;          
        endcase
    end

endmodule