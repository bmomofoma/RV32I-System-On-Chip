`timescale 1ns / 1ps

module pc_target_adder (
    input  logic [31:0] pc,
    input  logic [31:0] imm_ext,
    output logic [31:0] result
);
    assign result = pc + imm_ext;

endmodule