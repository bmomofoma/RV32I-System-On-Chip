`timescale 1ns / 1ps

module i2c_master_tb;
    logic       tb_clk;
    logic       tb_rest_n;
    logic       tb_start_en;
    logic [6:0] tb_device_addr;
    logic [7:0] tb_tx_data;
    wire        tb_sda;
    wire        tb_scl;

    // the custom I2C Master design block
    I2c_master uut (
        .clk(tb_clk),
        .rest_n(tb_rest_n),
        .start_en(tb_start_en),
        .device_addr(tb_device_addr),
        .tx_data(tb_tx_data),
        .sda(tb_sda),
        .scl(tb_scl)
    );

    initial tb_clk = 1'b0;
    always #5 tb_clk = ~tb_clk; 
    assign tb_sda = (uut.current_state == uut.STATE_ACK && uut.scl_phase == 2'b10) ? 1'b0 : 1'bZ;

    initial begin
        // Time 0: System Reset & Initialization
        tb_rest_n      = 1'b0;  
        tb_start_en    = 1'b0;   // Clear start strobe
        tb_device_addr = 7'h3C; // Set target sensor peripheral address to 0x3C
        tb_tx_data     = 8'hA5; // Prepare test data payload byte (0xA5)
        
        #50;                     
        tb_rest_n      = 1'b1;   
        
        #20;                     
        @(posedge tb_clk);       // Synchronize to the next rising clock edge
        tb_start_en = 1'b1;      
        
        @(posedge tb_clk);       // high for exactly one clock period
        tb_start_en = 1'b0;     
        
        #300000; 
        
        $display("Simulation complete. Verify state transitions and waveforms in Vivado.");
        $finish;
    end

endmodule
