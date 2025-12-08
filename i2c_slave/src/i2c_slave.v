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

    // asynchronous inputs need to be synchronized to local clock domain
    logic sda_i_sync;
    logic scl_i_sync;
    sync_2ff sync1 (
        .clk(clk),
        .rst_n(rst_n),
        .in_ai(sda_i),
        .out_o(sda_i_sync) );
    sync_2ff sync2 (
        .clk(clk),
        .rst_n(rst_n),
        .in_ai(scl_i),
        .out_o(scl_i_sync) );

    // Detect start and stop conditions
    logic sda_i_sync_d1;
    logic scl_i_sync_d1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_i_sync_d1 <= 1'b1;
            scl_i_sync_d1 <= 1'b1;
        end  
        else begin
            sda_i_sync_d1 <= sda_i_sync;
            scl_i_sync_d1 <= scl_i_sync;
        end   
    end

    // Generate strobe on SCL rising edge
    logic sdi_strobe;
    assign sdi_strobe = !scl_i_sync_d1 && scl_i_sync;

    logic start_condition;
    logic stop_condition;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_condition <= 1'b0;
            stop_condition <= 1'b0;
        end  
        else begin
            if (scl_i_sync_d1 && sda_i_sync_d1 && !sda_i_sync) begin
                // Falling edge of SDA during SCL high detected -> Start condition
                start_condition <= 1'b1;
            end
            else if (scl_i_sync_d1 && !sda_i_sync_d1 && sda_i_sync) begin
                // Rising edge of SDA during SCL high detected -> Stop condition
                stop_condition <= 1'b1;
            end
            else begin
                start_condition <= 1'b0;
                stop_condition <= 1'b0;
            end
        end
    end

   // bit counter
    logic [3:0] bit_count;
    logic ack_cycle;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= 4'd8;
            ack_cycle <= 1'b0;
        end  
        else if (start_condition) begin
            bit_count <= 4'd8;
            ack_cycle <= 1'b0;
        end
        else if (sdi_strobe) begin
            if (bit_count == 4'd0) begin      
                bit_count <= 4'd8;
                ack_cycle <= 1'b1;
            end
            else begin
                bit_count <= bit_count - 4'd1;
                ack_cycle <= 1'b0;
            end
        end
    end


   initial begin
        scl_o = 1'b1; // Open-drain idle state
        sda_o = 1'b1; // Open-drain idle state
        data_o = 8'b0;
        data_ready = 1'b0;
    end
endmodule