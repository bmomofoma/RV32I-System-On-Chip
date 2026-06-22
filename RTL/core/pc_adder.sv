`timescale 1ns / 1ps

module pc_adder (
    input  logic [31:0] a,
    output logic [31:0] result
);

    assign result = a + 32'd4;

endmodule