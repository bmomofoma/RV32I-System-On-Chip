module  I2c_master (
    input logic       clk,
    input logic       rest_n,           // asynchronous reset
    input logic       start_en,         // trigger pulse to start transmission
    input logic [6:0] device_addr,      // 7 bit addr of I2C device
    input logic [7:0] tx_data,          // data byte to send
    inout wire        sda,              // Bidirectional data line
    output reg        scl               // serial clock line
);
    typedef enum logic[5:0] { 
        STATE_IDLE  = 6'b000001,
        STATE_START = 6'b000010,
        STATE_ADDR  = 6'b000100,
        STATE_ACK   = 6'b001000,
        STATE_DATA  = 6'b010000,
        STATE_STOP  = 6'b100000
    } state_e;

    state_e current_state, next_state;

    // Basys 3 runs on 100MHz source clock, SCL standard mode is 100kHz 
    // 100MHz / 400khz = 250
    localparam int clk_divide_limit = 250;
    logic [$clog2(clk_divide_limit) - 1:0] clk_cnt;
    logic i2c_tick;
    logic [1:0] scl_phase; 

    // Generates a single-cycle 400kHz enable pulse (i2c_tick) from the 100MHz master clock.
    always_ff @( posedge clk or negedge rest_n ) begin 
        if (!rest_n) begin
            clk_cnt <= '0;
            i2c_tick <= 1'b0;
        end 
        else begin
            if( current_state == STATE_IDLE ) begin
                clk_cnt <= '0;
                i2c_tick <= 1'b0;
            end
            else if ( clk_cnt == clk_divide_limit - 1 ) begin
                clk_cnt <= '0;
                i2c_tick <= 1'b1;
            end
            else begin
                clk_cnt <= clk_cnt + 1'b1;
                i2c_tick <= 1'b0;
            end
        end
    end

    // Increments the 4-quadrant clock timing phase tracker on every clock tick event.
    always_ff @( posedge clk or negedge rest_n ) begin
        if (!rest_n) begin
            scl_phase <= '0;
        end 
        else if (current_state == STATE_IDLE) begin
            scl_phase <= '0;
        end
        else if (i2c_tick) begin
            scl_phase <= scl_phase + 1'b1;
        end
    end

    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;

    // Loads the device address or data byte and shifts it out bit-by-bit when SCL is low.
    always_ff @( posedge clk or negedge rest_n ) begin 
        if ( !rest_n ) begin
            bit_cnt <= 3'd7;
            shift_reg <= 8'b0;
        end
        else begin
            // 1. Address Load
            if ( current_state == STATE_START && (i2c_tick && scl_phase == 2'b11) ) begin
                shift_reg <= { device_addr, 1'b0 };
                bit_cnt <= 3'd7;
            end
            // 2. Address Shift
            else if ( current_state == STATE_ADDR ) begin
                if ( i2c_tick && scl_phase == 2'b00 ) begin
                    if (bit_cnt > 0) begin
                        bit_cnt <= bit_cnt - 1'b1;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end
                end
            end
            // 3. Data Load (Triggers right at the end of a successful ACK state)
            else if ( current_state == STATE_ACK && (i2c_tick && scl_phase == 2'b11 && ack_received) ) begin
                shift_reg <= tx_data;
                bit_cnt   <= 3'd7;
            end
            // 4. Data Shift 
            else if ( current_state == STATE_DATA ) begin
                if ( i2c_tick && scl_phase == 2'b00 ) begin
                    if (bit_cnt > 0) begin
                        bit_cnt <= bit_cnt - 1'b1;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end
                end
            end
        end
    end

    // Acknowledges whether the external slave device successfully claimed the data bus.
    logic ack_received;
    always_ff @( posedge clk or negedge rest_n ) begin
        if (!rest_n) begin
            ack_received <= 1'b0;
        end
        else begin
            if ( current_state != STATE_ACK ) begin
                ack_received <= 1'b0;
            end
            else if ( current_state == STATE_ACK && (i2c_tick && scl_phase == 2'b10)) begin
                ack_received <= (!sda);
            end
        end
    end

    // Updates the primary state machine register structure on every master system clock tick.
    always_ff @( posedge clk or negedge rest_n ) begin
        if (!rest_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Evaluates combinational logic conditions to govern FSM transitions between operational states.
    always_comb begin
        next_state = current_state;

        case (current_state)
            STATE_IDLE: begin
                if (start_en) 
                    next_state = STATE_START;
            end

            STATE_START: begin
                if (i2c_tick && (scl_phase == 2'b11)) 
                    next_state = STATE_ADDR;
            end

            STATE_ADDR: begin
                if (i2c_tick && (scl_phase == 2'b11)) begin
                    if (bit_cnt == 3'd0) 
                        next_state = STATE_ACK;
                end
            end

            STATE_ACK: begin
                if (i2c_tick && (scl_phase == 2'b11)) begin
                    if (ack_received)
                        next_state = STATE_DATA;
                    else
                        next_state = STATE_STOP;
                end
            end

            STATE_DATA: begin
                if (i2c_tick && (scl_phase == 2'b11)) begin
                    if (bit_cnt == 3'd0) 
                        next_state = STATE_STOP;
                end
            end

            STATE_STOP: begin
                if (i2c_tick && (scl_phase == 2'b11)) 
                    next_state = STATE_IDLE;
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    // Drives the physical SCL clock line based on the active FSM phases.
    assign scl = (current_state == STATE_IDLE) ? 1'b1 : (scl_phase == 2'b01 || scl_phase == 2'b10);

    // Manages the physical SDA bidirectional line, executing tri-state release during ACK cycles.
    assign sda = (current_state == STATE_IDLE)     ? 1'b1 :
                    (current_state == STATE_START)    ? 1'b0 :
                    (current_state == STATE_ADDR)     ? shift_reg[7] :
                    (current_state == STATE_DATA)     ? shift_reg[7] : 
                    (current_state == STATE_ACK)      ? 1'bZ : 
                    (current_state == STATE_STOP)     ? ((scl_phase == 2'b00 || scl_phase == 2'b01) ? 1'b0 : 1'b1) : 1'bZ;

endmodule