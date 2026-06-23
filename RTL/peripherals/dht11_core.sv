`timescale 1ns / 1ps

module dht11_core (
    input  logic        clk,          // 100MHz system clock
    input  logic        rst_n,      
    input  logic        start_en,  
    
    inout  wire         dht_pin,     
    
    output logic [31:0] sensor_data,  // {Humidity[15:0], Temperature[15:0]}
    output logic        data_valid,  
    output logic        busy         
);

    logic [6:0] tick_cnt;
    logic       us_tick;
    logic       timer_rst;
    logic [15:0] us_counter; 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= '0;
            us_tick  <= 1'b0;
        end else if (timer_rst) begin
            tick_cnt <= '0;
            us_tick  <= 1'b0;
        end else begin
            if (tick_cnt == 7'd99) begin
                tick_cnt <= '0;
                us_tick  <= 1'b1;
            end else begin
                tick_cnt <= tick_cnt + 1'b1;
                us_tick  <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            us_counter <= '0;
        end else if (timer_rst) begin
            us_counter <= '0;
        end else if (us_tick) begin
            us_counter <= us_counter + 1'b1;
        end
    end

    typedef enum logic [2:0] {
        IDLE,
        MCU_START,        // Drive low for 18ms
        DHT_WAIT_ACK,     // Wait for DHT to pull low
        DHT_ACK_LOW,      // DHT holds low for ~80us
        DHT_ACK_HIGH,     // DHT holds high for ~80us
        READ_BIT_LOW,     // DHT holds low for ~50us before data
        READ_BIT_HIGH     // Measure high time to determine 0 or 1
    } state_t;

    state_t current_state, next_state;
    
    logic [39:0] shift_reg;
    logic [5:0]  bit_count;
    logic        drive_low; 
    logic        save_bit;
    logic        bit_val;

    // Edge detection 
    logic dht_sync_1, dht_sync_2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) {dht_sync_2, dht_sync_1} <= 2'b11;
        else        {dht_sync_2, dht_sync_1} <= {dht_sync_1, dht_pin};
    end
    logic dht_falling_edge = (dht_sync_1 == 1'b0 && dht_sync_2 == 1'b1);
    logic dht_rising_edge  = (dht_sync_1 == 1'b1 && dht_sync_2 == 1'b0);

    // State Update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else        current_state <= next_state;
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        timer_rst  = 1'b0;
        drive_low  = 1'b0;
        save_bit   = 1'b0;
        bit_val    = 1'b0;
        
        case (current_state)
            IDLE: begin
                if (start_en) begin
                    next_state = MCU_START;
                    timer_rst  = 1'b1;
                end
            end
            
            MCU_START: begin
                drive_low = 1'b1; 
                if (us_counter >= 16'd18000) begin
                    next_state = DHT_WAIT_ACK;
                    timer_rst  = 1'b1;
                end
            end
            
            DHT_WAIT_ACK: begin
                if (dht_falling_edge) begin
                    next_state = DHT_ACK_LOW;
                    timer_rst  = 1'b1;
                end else if (us_counter > 16'd100) begin
                    next_state = IDLE; // Timeout error
                end
            end
            
            DHT_ACK_LOW: begin
                if (dht_rising_edge) begin
                    next_state = DHT_ACK_HIGH;
                    timer_rst  = 1'b1;
                end else if (us_counter > 16'd100) next_state = IDLE;
            end
            
            DHT_ACK_HIGH: begin
                if (dht_falling_edge) begin
                    next_state = READ_BIT_LOW;
                    timer_rst  = 1'b1;
                end else if (us_counter > 16'd100) next_state = IDLE;
            end
            
            READ_BIT_LOW: begin
                if (dht_rising_edge) begin
                    next_state = READ_BIT_HIGH;
                    timer_rst  = 1'b1;
                end else if (us_counter > 16'd100) next_state = IDLE;
            end
            
            READ_BIT_HIGH: begin
                if (dht_falling_edge) begin
                    save_bit = 1'b1;
                    bit_val  = (us_counter > 16'd40) ? 1'b1 : 1'b0;
                    
                    if (bit_count == 6'd39) begin
                        next_state = IDLE; 
                    end else begin
                        next_state = READ_BIT_LOW;
                        timer_rst  = 1'b1;
                    end
                end else if (us_counter > 16'd100) next_state = IDLE; 
            end
            
            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= '0;
            bit_count  <= '0;
            data_valid <= 1'b0;
        end else if (current_state == MCU_START && us_counter == 0) begin
            bit_count  <= '0;
            data_valid <= 1'b0;
        end else if (save_bit) begin
            shift_reg <= {shift_reg[38:0], bit_val};
            bit_count <= bit_count + 1'b1;
            
            if (bit_count == 6'd39) begin
                if ( (shift_reg[38:31] + shift_reg[30:23] + shift_reg[22:15] + {shift_reg[14:8], bit_val}) == shift_reg[38:31] ) begin
                end
            end
        end
    end

    // checksum validation
    logic [7:0] sum;
    assign sum = shift_reg[39:32] + shift_reg[31:24] + shift_reg[23:16] + shift_reg[15:8];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sensor_data <= '0;
        end else if (current_state == IDLE && bit_count == 6'd40) begin
            if (sum == shift_reg[7:0]) begin
                sensor_data <= shift_reg[39:8]; // Store {Hum_Int, Hum_Dec, Temp_Int, Temp_Dec}
                data_valid  <= 1'b1;
            end
            bit_count <= '0; 
        end else if (start_en) begin
            data_valid <= 1'b0; 
        end
    end
    assign dht_pin = drive_low ? 1'b0 : 1'bz;
    assign busy    = (current_state != IDLE);

endmodule
