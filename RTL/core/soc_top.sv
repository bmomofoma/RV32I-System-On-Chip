`timescale 1ns / 1ps

module soc_top (
    input  logic clk,
    input  logic rst,      // Active-high reset for RISC-V core
    inout  wire  sda,
    output logic scl,
    inout  wire  dht_pin   
);

    logic [31:0] cpu_pc;
    logic [31:0] cpu_instr;
    logic [31:0] cpu_addr;
    logic [31:0] cpu_wdata;
    logic [31:0] cpu_rdata;
    logic        cpu_mem_write;

    // I2C Peripheral wires
    logic [6:0]  i2c_device_addr_reg;
    logic [7:0]  i2c_tx_data_reg;
    logic        i2c_start_pulse;
    logic        i2c_busy;

    // DHT11 Peripheral wires
    logic        dht_start_pulse;
    logic        dht_busy;
    logic        dht_valid;
    logic [31:0] dht_sensor_data;

    // Internal SRAM wires
    logic [31:0] ram_rdata;
    logic        ram_we;

    logic [31:0] sram_array [0:4095]; 

    assign ram_word_addr = cpu_addr[13:2]; 
    assign pc_word_addr  = cpu_pc[13:2];

    // Instruction Fetch (Asynchronous)
    assign cpu_instr = sram_array[pc_word_addr];

    // Data Memory Access
    always_ff @(posedge clk) begin
        if (ram_we) begin
            sram_array[ram_word_addr] <= cpu_wdata;
        end
    end
    assign ram_rdata = sram_array[ram_word_addr];

    assign ram_we = (cpu_addr >= 32'h0000_0000 && cpu_addr <= 32'h0000_3FFF) ? cpu_mem_write : 1'b0;

    always_comb begin
        if (cpu_addr >= 32'h0000_0000 && cpu_addr <= 32'h0000_3FFF) begin
            cpu_rdata = ram_rdata;
        end else if (cpu_addr[31:16] == 16'h4000) begin
            case (cpu_addr[7:0])
                8'h00:   cpu_rdata = {30'b0, i2c_busy, 1'b0};
                8'h04:   cpu_rdata = {17'b0, i2c_device_addr_reg, i2c_tx_data_reg};
                8'h10:   cpu_rdata = {29'b0, dht_valid, dht_busy, 1'b0};
                8'h14:   cpu_rdata = dht_sensor_data;
                default: cpu_rdata = 32'h0;
            endcase
        end else begin
            cpu_rdata = 32'hDEAD_BEEF;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            i2c_device_addr_reg <= '0;
            i2c_tx_data_reg     <= '0;
            i2c_start_pulse     <= 1'b0;
            dht_start_pulse     <= 1'b0;
        end else begin
            i2c_start_pulse <= 1'b0;
            dht_start_pulse <= 1'b0;
            
            if (cpu_mem_write && (cpu_addr[31:16] == 16'h4000)) begin
                case (cpu_addr[7:0])
                    8'h00: if (cpu_wdata[0] && !i2c_busy) i2c_start_pulse <= 1'b1;
                    8'h04: begin
                        i2c_device_addr_reg <= cpu_wdata[14:8];
                        i2c_tx_data_reg     <= cpu_wdata[7:0];
                    end
                    8'h10: if (cpu_wdata[0] && !dht_busy) dht_start_pulse <= 1'b1;
                    default: ;
                endcase
            end
        end
    end

    riscv_core u_riscv_core (
        .clk            (clk),
        .rst            (rst),
        .pc             (cpu_pc),
        .instr          (cpu_instr),
        .alu_result     (cpu_addr),
        .write_data_mem (cpu_wdata),
        .mem_write      (cpu_mem_write),
        .read_data_mem  (cpu_rdata)
    );

    I2c_master u_I2c_master (
        .clk         (clk),
        .rest_n      (!rst),
        .start_en    (i2c_start_pulse),
        .device_addr (i2c_device_addr_reg),
        .tx_data     (i2c_tx_data_reg),
        .sda         (sda),
        .scl         (scl)
    );

    dht11_core u_dht11_core (
        .clk         (clk),
        .rst_n       (!rst),
        .start_en    (dht_start_pulse),
        .dht_pin     (dht_pin),
        .sensor_data (dht_sensor_data),
        .data_valid  (dht_valid),
        .busy        (dht_busy)
    );

    assign i2c_busy = (u_I2c_master.current_state != u_I2c_master.STATE_IDLE);

    initial begin
        $readmemh("program.mem", sram_array);
    end

endmodule
