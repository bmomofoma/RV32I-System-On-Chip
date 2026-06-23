`timescale 1ns / 1ps

module soc_tb;
    logic clk;
    logic rst;
    wire  sda;
    wire  scl;

    // the Top-Level SoC
    soc_top dut (
        .clk(clk),
        .rst(rst),
        .sda(sda),
        .scl(scl)
    );

    // 100 MHz Clock Generation 
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
        
        // the CPU fetch and execute the program for 100 clock cycles
        #1000;
        
        $display("Simulation Complete.");
        $finish;
    end

endmodule
