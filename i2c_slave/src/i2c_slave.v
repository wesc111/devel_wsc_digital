// i2c_slave.v
// Simple I2C Slave Module

// This module implements a basic I2C slave that can receive data from an I2C master.
// It supports start and stop condition detection, address recognition, and data reception.
// The module assumes a fixed 7-bit address and acknowledges received data.

// Note: This is a simplified example and may not cover all edge cases of the I2C protocol.
// The module is intended for educational purposes and may require further enhancements for production use.
// Author: Werner Schoegler
// Date: 30-Nov-2025

module i2c_slave (
    input logic clk,
    input logic rst_n,
    inout wire scl,
    inout wire sda,
    output logic [7:0] data_out,
    output logic data_ready
);
    typedef enum logic [1:0] {
        IDLE,
        ADDRESS,
        DATA,
        ACK
    } state_t;

    state_t current_state, next_state;
    logic [7:0] shift_reg;
    logic [2:0] bit_count;
    logic sda_in, sda_out, sda_dir;
    logic start_condition, stop_condition;

    // SDA line direction control
    assign sda = sda_dir ? sda_out : 1'bz;
    assign sda_in = sda;

    // Start and Stop condition detection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_condition <= 1'b0;
            stop_condition <= 1'b0;
        end else begin
            start_condition <= (scl == 1'b1 && sda_in == 1'b0);
            stop_condition <= (scl == 1'b1 && sda_in == 1'b1);
        end
    end

    // State transition logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always_comb begin 
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start_condition) begin
                    next_state = ADDRESS;
                    bit_count = 3'd0;
                end
            end
            ADDRESS: begin
                if (bit_count == 3'd7 && scl == 1'b1) begin
                    next_state = ACK;
                end
            end
            DATA: begin
                if (bit_count == 3'd7 && scl == 1'b1) begin
                    next_state = ACK;
                end
            end
            ACK: begin
                if (stop_condition) begin
                    next_state = IDLE;
                end else begin
                    next_state = DATA;
                    bit_count = 3'd0;
                end
            end
        endcase
    end

    // Data reception logic
    always_ff @(posedge scl or negedge rst_n) begin 
        if (!rst_n) begin
            shift_reg <= 8'd0;
            data_out <= 8'd0;
            data_ready <= 1'b0;
            sda_dir <= 1'b0;
            sda_out <= 1'b1;
        end else begin
            case (current_state)
                ADDRESS, DATA: begin
                    shift_reg <= {shift_reg[6:0], sda_in};
                    bit_count <= bit_count + 1;
                end
                ACK: begin
                    data_out <= shift_reg;
                    data_ready <= 1'b1;
                    sda_dir <= 1'b1; // Drive SDA for ACK
                    sda_out <= 1'b0; // ACK bit
                end
                default: begin
                    data_ready <= 1'b0;
                    sda_dir <= 1'b0; // Release SDA
                end
            endcase
        end
    end
endmodule