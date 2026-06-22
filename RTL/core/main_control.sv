`timescale 1ns / 1ps

module main_control (
    input  logic [6:0] op,         
    output logic       branch,     
    output logic       jump,       
    output logic       memRead,    
    output logic       memtoReg,   
    output logic [1:0] aluOp,      
    output logic       memWrite,   
    output logic       aluSrc,     
    output logic       regWrite,   
    output logic [2:0] immSrc      
);
    always_comb begin
        branch   = 1'b0;
        jump     = 1'b0;   // <--- ADD THIS RIGHT HERE
        memRead  = 1'b0;
        memtoReg = 1'b0;
        aluOp    = 2'b00;
        memWrite = 1'b0;
        aluSrc   = 1'b0;
        regWrite = 1'b0;
        immSrc   = 3'b000;

        case (op)
            7'b0110011: begin
                regWrite = 1'b1;  // Commit calculation to rd
                aluSrc   = 1'b0;  // Operand B sourced from rs2 port
                aluOp    = 2'b10; // Pass-through to secondary ALU decoder
            end

            7'b0010011: begin
                regWrite = 1'b1;  // Commit calculation to rd
                aluSrc   = 1'b1;  // Operand B sourced from Imm Generator
                immSrc   = 3'b000; // Force sign-extended 12-bit scalar layout
                aluOp    = 2'b10; // Pass-through to secondary ALU decoder
            end
            // Load Word (lw) - Opcode 0000011
            7'b0000011: begin
                regWrite = 1'b1;         // We are saving data back to a register
                aluSrc   = 1'b1;         // Add immediate offset to base register
                memRead  = 1'b1;         // Enable RAM read (optional flag in this architecture)
                memtoReg = 1'b1;         // Flip writeback MUX to select RAM data instead of ALU
                aluOp    = 2'b00;        // Category 00 forces ALU into ADD mode for address calculation
                memWrite = 1'b0;
                branch   = 1'b0;
                immSrc   = 3'b000;       // I-Type immediate layout
            end

            // Store Word (sw) - Opcode 0100011
            7'b0100011: begin
                regWrite = 1'b0;         // We are writing to RAM, NOT a register
                memWrite = 1'b1;         // Trigger the RAM write enable pin
                aluSrc   = 1'b1;         // Add immediate offset to base register
                aluOp    = 2'b00;        // Category 00 forces ALU into ADD mode
                branch   = 1'b0;
                memRead  = 1'b0;
                memtoReg = 1'b0;
                immSrc   = 3'b001;       // S-Type immediate layout
            end
            // Jump and Link (jal) - Opcode 1101111
            7'b1101111: begin
                jump     = 1'b1;         // Force the PC multiplexer to take the jump target
                regWrite = 1'b1;         // We are saving the return address to a register
                immSrc   = 3'b100;       // J-Type immediate layout (extracts 20-bit jump distance)
                
                // Don't cares / defaults for ALU and RAM
                branch   = 1'b0;
                memRead  = 1'b0;
                memtoReg = 1'b0;         // Ignored because our writeback mux will prioritize the jump signal
                aluSrc   = 1'b0;         
                aluOp    = 2'b00;        
                memWrite = 1'b0;
            end
            // B-Type Conditional Branches (beq, bne, blt, bge)
            7'b1100011: begin
                branch   = 1'b1;  // Enable target logic branch calculation
                regWrite = 1'b0;  // Retain architectural register states during check
                aluSrc   = 1'b0;  // Evaluate rs1 vs rs2 outputs directly
                aluOp    = 2'b01; // Force subtraction mode to drive zero flag high if identical
                immSrc   = 3'b010; // Slice branch offset layout format
            end
            // U-Type Load Upper Immediate (lui) - Opcode 0110111
            7'b0110111: begin
                regWrite = 1'b1;   // Commit data back to rd
                aluSrc   = 1'b1;   // Route immediate to ALU operand B
                aluOp    = 2'b00;  // Force ALU to ADD (x0 + Imm = Imm)
                immSrc   = 3'b011; // Assuming 011 is your U-Type layout in imm_gen
                
                memRead  = 1'b0;
                memtoReg = 1'b0;
                memWrite = 1'b0;
                branch   = 1'b0;
                jump     = 1'b0;
            end
            default: begin
                // Unimplemented Opcode handling
            end
        endcase
    end

endmodule