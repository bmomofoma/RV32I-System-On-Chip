`timescale 1ns / 1ps
module alu_decoder (
    input  logic [1:0] aluOp,      
    input  logic [2:0] funct3,     
    input  logic       funct7_bit, // Maps to instruction bit [30]
    output logic [3:0] aluControl  
);

    always_comb begin
        // Safe default: Fall back to non-destructive addition logic
        aluControl = 4'b0100; 

        case (aluOp)
            // Memory Offset Calculation
            2'b00: begin
                aluControl = 4'b0100; // Force ADD address arithmetic
            end

            // Branch Comparison Jump Evaluation
            2'b01: begin
                aluControl = 4'b0101; // Force SUBTRACT subtraction logic
            end
            2'b10: begin
                case (funct3)
                    3'b000: begin
                        if (funct7_bit) 
                            aluControl = 4'b0101; // SUB
                        else            
                            aluControl = 4'b0100; // ADD
                    end
                    
                    3'b111: aluControl = 4'b0000; // AND bit-mask
                    3'b110: aluControl = 4'b0001; // OR bit-mask
                    3'b100: aluControl = 4'b0010; // XOR bit-mask
                    3'b010: aluControl = 4'b1001; // Set Less Than (SLT) Signed
                    3'b001: aluControl = 4'b0110; // Shift Left Logical (SLL)
                    
                    3'b101: begin
                        if (funct7_bit)
                            aluControl = 4'b1000; // Shift Right Arithmetic (SRA)
                        else
                            aluControl = 4'b0111; // Shift Right Logical (SRL)
                    end

                    default: aluControl = 4'b0100; // Fallback trap
                endcase
            end

            default: begin
                aluControl = 4'b0100; // Boundary catch-all
            end
        endcase
    end

endmodule