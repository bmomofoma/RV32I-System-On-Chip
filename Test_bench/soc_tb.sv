`timescale 1ns / 1ps

module soc_tb;

    // Testbench signals
    logic clk;
    logic rst;
    wire  sda;
    wire  scl;

    // Instantiate the Top-Level SoC
    soc_top dut (
        .clk(clk),
        .rst(rst),
        .sda(sda),
        .scl(scl)
    );

    // 100 MHz Clock Generation (Matches Basys 3)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // Simulation Sequence
    initial begin
        $display("Starting SoC Interconnect Test...");
        
        rst = 1;
        #20;
        rst = 0;
        
        // Let the CPU fetch and execute the program for 100 clock cycles
        #1000;
        
        $display("Simulation Complete.");
        $finish;
    end

endmodule