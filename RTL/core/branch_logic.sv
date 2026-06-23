`timescale 1ns / 1ps

module branch_logic (
    input  logic        branch,
    input  logic        zero,
    input  logic [31:0] src_a,      // Pass raw Operand A from the register file read port
    input  logic [31:0] src_b,      // Pass raw Operand B from the register file read port
    input  logic [31:0] alu_result, // Pass the active ALU calculation bus
    input  logic [2:0]  funct3,
    output logic        pc_src
);

    logic cond_met;
    logic alu_sign;
    logic overflow;
    logic signed_lt;

    assign alu_sign = alu_result[31];
    assign overflow = (src_a[31] ^ src_b[31]) & (alu_sign ^ src_a[31]);
    
    assign signed_lt = alu_sign ^ overflow;

    always_comb begin
        case (funct3)
            3'b000:  cond_met = zero;       // BEQ  
            3'b001:  cond_met = ~zero;      // BNE 
            3'b100:  cond_met = signed_lt;  // BLT  
            3'b101:  cond_met = ~signed_lt; // BGE  
            3'b110:  cond_met = (src_a < src_b); // BLTU 
            3'b111:  cond_met = (src_a >= src_b);// BGEU 
            default: cond_met = 1'b0;
        endcase
    end

    assign pc_src = branch & cond_met;

endmodule
