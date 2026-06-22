`timescale 1ns / 1ps

module pc_reg (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] pc_next,
    output logic [31:0] pc
);

    // Updates the pointer on every clock cycle.
    // On rst, we force it back to 0 to restart the program execution.
    always_ff @(posedge clk) begin
        if (rst)
            pc <= 32'h0000_0000;
        else
            pc <= pc_next;
    end

endmodule