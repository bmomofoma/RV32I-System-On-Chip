module I2c_master (
    input logic       clk,
    input logic       rest_n,
    input logic       start_en,
    input logic [6:0] device_addr,
    input logic [7:0] tx_data,
    inout wire        sda,
    output wire       scl
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

    localparam int clk_divide_limit = 250;
    logic [$clog2(clk_divide_limit) - 1:0] clk_cnt;
    logic i2c_tick;
    logic [1:0] scl_phase; 

    always_ff @(posedge clk, negedge rest_n) begin 
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

    always_ff @(posedge clk, negedge rest_n) begin
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

    always_ff @(posedge clk, negedge rest_n) begin 
        if (!rest_n) begin
            bit_cnt <= 3'd7;
            shift_reg <= 8'b0;
        end
        else begin
            if ( current_state == STATE_START && (i2c_tick && scl_phase == 2'b11) ) begin
                shift_reg <= { device_addr, 1'b0 };
                bit_cnt <= 3'd7;
            end
            else if ( current_state == STATE_ADDR ) begin
                if ( i2c_tick && scl_phase == 2'b11 ) begin
                    if (bit_cnt > 0) begin
                        bit_cnt <= bit_cnt - 1'b1;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end
                end
            end
            else if ( current_state == STATE_ACK && (i2c_tick && scl_phase == 2'b11 && ack_received) ) begin
                shift_reg <= tx_data;
                bit_cnt   <= 3'd7;
            end
            else if ( current_state == STATE_DATA ) begin
                if ( i2c_tick && scl_phase == 2'b11 ) begin
                    if (bit_cnt > 0) begin
                        bit_cnt <= bit_cnt - 1'b1;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end
                end
            end
        end
    end

    logic ack_received;
    always_ff @(posedge clk, negedge rest_n) begin
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

    always_ff @(posedge clk, negedge rest_n) begin
        if (!rest_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            STATE_IDLE:  if (start_en) next_state = STATE_START;
            STATE_START: if (i2c_tick && (scl_phase == 2'b11)) next_state = STATE_ADDR;
            STATE_ADDR:  if (i2c_tick && (scl_phase == 2'b11)) if (bit_cnt == 3'd0) next_state = STATE_ACK;
            STATE_ACK:   if (i2c_tick && (scl_phase == 2'b11)) next_state = (ack_received) ? STATE_DATA : STATE_STOP;
            STATE_DATA:  if (i2c_tick && (scl_phase == 2'b11)) if (bit_cnt == 3'd0) next_state = STATE_STOP;
            STATE_STOP:  if (i2c_tick && (scl_phase == 2'b11)) next_state = STATE_IDLE;
            default:     next_state = STATE_IDLE;
        endcase
    end

    assign scl = (current_state == STATE_IDLE)  ? 1'b1 :
                 (current_state == STATE_START) ? (scl_phase == 2'b00 || scl_phase == 2'b01) : 
                 (current_state == STATE_STOP)  ? (scl_phase == 2'b01 || scl_phase == 2'b10 || scl_phase == 2'b11) : 
                 (scl_phase == 2'b01 || scl_phase == 2'b10); 

    assign sda = (current_state == STATE_IDLE)   ? 1'b1 :
                 (current_state == STATE_START)  ? 1'b0 : 
                 (current_state == STATE_ADDR)   ? shift_reg[7] :
                 (current_state == STATE_DATA)   ? shift_reg[7] : 
                 (current_state == STATE_ACK)    ? 1'bZ : 
                 (current_state == STATE_STOP)   ? ((scl_phase == 2'b00 || scl_phase == 2'b01) ? 1'b0 : 1'b1) : 1'bZ;

endmodule
