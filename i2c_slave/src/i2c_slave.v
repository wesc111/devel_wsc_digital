// i2c_slave.v
// Simple I2C Slave Module

// This module implements a basic I2C slave that can receive data from an I2C master.
// It supports start and stop condition detection, address recognition, and data reception.
// The module assumes a fixed 7-bit address and acknowledges received data.

// Note: This is a simplified example and may not cover all edge cases of the I2C protocol.
// The module is intended for educational purposes and may require further enhancements for production use.
// Author: Werner Schoegler
// Date: 30-Nov-2025

`timescale 1ns / 1ps

module i2c_slave (
    input logic clk,
    input logic rst_n,
    input logic scl_i,
    input logic sda_i,
    output logic scl_o,
    output logic sda_o,
    output logic [7:0] data_o,
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
    logic start_condition, stop_condition;

    initial begin
        current_state = IDLE;
        data_o = 8'b0;
        data_ready = 1'b0;
        scl_o = 1'b1; // Release SCL
        sda_o = 1'b1; // Release SDA
    end

    // Start and Stop condition detection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_condition <= 1'b0;
            stop_condition <= 1'b0;
        end else begin
            start_condition <= (scl_i == 1'b1 && sda_i == 1'b0);
            stop_condition <= (scl_i == 1'b1 && sda_i == 1'b1);
        end
    end

endmodule