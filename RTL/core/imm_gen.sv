`timescale 1ns / 1ps
module imm_gen (
    input  logic [31:0] instr,   
    input  logic [2:0]  immSrc,  
    output logic [31:0] immExt   
);
  
    always @* begin
        case (immSrc)
            // I-Type Layout
            3'b000: immExt = { {20{instr[31]}}, instr[31:20] };
            
            // S-Type Store Layout
            3'b001: immExt = { {20{instr[31]}}, instr[31:25], instr[11:7] };
            
            // B-Type Conditional Jump Layouts.
            3'b010: immExt = { {19{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0 };
            
            // U-Type Large Direct Upper Layout
            3'b011: immExt = { instr[31:12], 12'b0 };
            
            // J-Type Unconditional Branch Jump Layout
            3'b100: immExt = { {11{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0 };
            
            default: immExt = 32'h0000_0000;
        endcase
    end

endmodule
