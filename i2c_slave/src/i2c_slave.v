// i2c_slave.v
// Simple I2C Slave Module

// This module implements a basic I2C slave that can receive data from an I2C master.
// It supports start and stop condition detection, address recognition, and data reception.
// The module assumes a fixed 7-bit address and acknowledges received data.

// Note: This is a simplified example and may not cover all edge cases of the I2C protocol.
// The module is intended for educational purposes and may require further enhancements for production use.
//
// prerelease with limited features

// Features:
// - Fixed 7-bit slave address
// - Start and Stop condition detection
// - Address recognition
// - Data reception with acknowledgment
// - Synchronized inputs to local clock domain
// - all Flip-Flops are positive edge triggered with asynchronous active low reset

// Limitations:
// - No clock stretching
// - No multi-master support
// - No error handling
// - Only supports write operations from master to slave

// Planned enhancements:
// - Support for read operations (implementation in progress)

// Author: Werner Schoegler
// Date: 30-Nov-2025

`timescale 1ns / 1ps

module i2c_slave 
    #(
        parameter SLAVE_ADDRESS = 7'h21 // Fixed 7-bit slave address
    ) 
    (   
    input logic clk,
    input logic rst_n,
    input logic scl_i,
    input logic sda_i,
    output logic scl_o,
    output logic sda_o,

    // data interface
    // data_i: data input from uC interface for read operations
    input logic [7:0] data_i,
    // handshake signals: 
    // data_i_valid: indicates that data_i has valid data from the uC interface
    input logic data_i_valid,
    // data_i_ready: indicates that the slave is ready to accept next data_i
    output logic data_i_ready,
    // data_o: data output to uC interface for write operations
    output logic [7:0] data_o,
    // data_o_valid: indicates that data_o has valid data for the uC interface
    output logic       data_o_valid
);

    typedef enum logic [2:0] {
        STATE_IDLE = 3'd0,
        STATE_ADDRESS = 3'd1,
        STATE_DATA = 3'd2,
        STATE_RWN_BIT = 3'd3,
        STATE_DATA_ACK = 3'd4
    } i2c_state_t;

    // asynchronous inputs need to be synchronized to local clock domain
    logic sda_i_sync;
    logic scl_i_sync;
    sync_2ff #(.RESET_VALUE(1'b1)) sync1 (
        .clk(clk),
        .rst_n(rst_n),
        .in_ai(sda_i),
        .out_o(sda_i_sync) );
    sync_2ff #(.RESET_VALUE(1'b1)) sync2 (
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

    logic [3:0] bit_count;

    // generate pulse signals showing edges of SCL
    logic scl_posedge;
    assign scl_posedge = !scl_i_sync_d1 && scl_i_sync;
    logic scl_negedge;
    assign scl_negedge = scl_i_sync_d1 && !scl_i_sync;

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

    i2c_state_t current_state, next_state;
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end  
        else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            STATE_IDLE: begin
                if (start_condition) begin
                    next_state = STATE_ADDRESS;
                end
            end
            STATE_ADDRESS: begin
                if (start_condition) begin
                    next_state = STATE_ADDRESS;
                end
                else if (stop_condition) begin
                    next_state = STATE_IDLE;
                end
                else if (bit_count==3'd0 & scl_posedge) begin
                    next_state = STATE_RWN_BIT;
                end
            end
            STATE_RWN_BIT: begin
                if (stop_condition) begin
                    next_state = STATE_IDLE;
                end
                else if (scl_posedge) begin
                    next_state = STATE_DATA;
                end
            end
            STATE_DATA: begin
                if (stop_condition) begin
                    next_state = STATE_IDLE;
                end
                else if (ack_cycle & scl_posedge) begin
                    next_state = STATE_DATA;
                end
            end
            default: begin
                next_state = STATE_IDLE;
            end
            STATE_DATA_ACK: begin
                if (stop_condition) begin
                    next_state = STATE_IDLE;
                end
                else if (scl_posedge) begin
                    next_state = STATE_DATA;
                end
            end 
        endcase
    end

// address register
    logic [6:0] address_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            address_reg <= 7'b0;
        end  
        else if (start_condition) begin
            address_reg <= 7'b0;
        end
        // shift in address bits till bit_count reaches 0
        else if (scl_posedge && (current_state == STATE_ADDRESS) && (bit_count != 4'd0)) begin
            address_reg <= {address_reg[5:0], sda_i_sync};
        end
    end
    // address matched flag: to indicate if the received address matches the slave address
    logic address_matched;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            address_matched <= 1'b0;
        end  
        // on start or stop condition, reset address matched
        else if (start_condition | stop_condition) begin
            address_matched <= 1'b0;
        end
        // after receiving address, compare
        else if (current_state == STATE_RWN_BIT) begin
            if (address_reg == SLAVE_ADDRESS) begin
                address_matched <= 1'b1;
            end
            else begin
                address_matched <= 1'b0;
            end
        end
    end

    // data register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_o <= 8'b0;
        end  
        else if (start_condition) begin
            data_o <= 8'b0;
        end
        // shift in data bits till bit_count reaches 0
        else if (scl_posedge && (current_state == STATE_DATA) && !ack_cycle && !rwn_bit && address_matched) begin
            data_o <= {data_o[6:0], sda_i_sync};
        end
    end

    // rwn bit: read/write_not bit (1=read, 0=write)
    logic rwn_bit;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rwn_bit <= 1'b0;
        end  
        else if (start_condition) begin
            rwn_bit <= 1'b0;
        end
        else if (scl_posedge && (current_state == STATE_ADDRESS) && (bit_count == 4'd0)) begin
            rwn_bit <= sda_i_sync;
        end
    end

    // data_o_valid signal: indicates that data_o has valid data from slave
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_o_valid <= 1'b0;
        end  
        else if (start_condition | stop_condition) begin
            data_o_valid <= 1'b0;
        end
        else if ((current_state == STATE_DATA) && ack_cycle && !rwn_bit && address_matched) begin
            data_o_valid <= 1'b1;
        end
        else begin
            data_o_valid <= 1'b0;
        end
    end

   // bit counter
   localparam BIT_COUNT_MAX = 4'd7;
 
    logic ack_cycle;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= BIT_COUNT_MAX;
            ack_cycle <= 1'b0;
        end  
        else if (start_condition) begin
            bit_count <= BIT_COUNT_MAX;
            ack_cycle <= 1'b0;
        end
        else if (stop_condition) begin
            bit_count <= BIT_COUNT_MAX;
            ack_cycle <= 1'b0;
        end
        else if (scl_posedge && ack_cycle) begin
            ack_cycle <= 1'b0;
            bit_count <= BIT_COUNT_MAX;
        end
        else if (scl_posedge && !ack_cycle) begin
            // Decrement bit count or enter ack cycle
            if (bit_count == 4'd0) begin
                ack_cycle <= 1'b1;
            end
            else begin
                bit_count <= bit_count - 4'd1;
                ack_cycle <= 1'b0;
            end
        end
    end

    logic addr_ack;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_ack <= 1'b0;
        end  
        else begin
            // start ack after receiving address + R/W bit at the positive clock edge
            if (current_state == STATE_RWN_BIT && address_matched && scl_negedge) begin
                addr_ack <= 1'b1;
            end
            else if (current_state == STATE_DATA && scl_negedge) begin
                addr_ack <= 1'b0;
            end
        end 
    end

    logic data_ack;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_ack <= 1'b0;
        end  
        else begin
            // start ack after receiving address + R/W bit at the positive clock edge
            if ((current_state == STATE_DATA) && ack_cycle && address_matched && scl_negedge) begin
                data_ack <= 1'b1;
            end
            else if (scl_negedge) begin
                data_ack <= 1'b0;
            end
        end 
    end

    // implement data output logic for read operations
    logic read_data;
    logic data_send;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data <= 1'b0;
            data_send <= 1'b0;
        end  
        else begin   
            if (rwn_bit && address_matched && (current_state == STATE_DATA)) begin
                if (scl_negedge && bit_count>4'd0) begin
                        read_data <= data_i[bit_count];
                        data_send <= 1'b1;
                end
                else if (scl_negedge && bit_count==4'd0) begin
                        read_data <= data_i[0];
                        data_send <= 1'b0; // last bit sent
                end
            end
            else begin
                read_data <= 1'b0;
                data_send <= 1'b0;
            end 
        end
    end

   always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_i_ready <= 1'b0;
        end  
        else begin
            if (scl_posedge && rwn_bit && address_matched && (current_state == STATE_DATA) && bit_count==4'd0 && !data_ack) begin
                data_i_ready <= 1'b1;
            end
            else begin
                data_i_ready <= 1'b0;
            end 
        end
    end

    // Acknowledge by pulling SDA low
    assign sda_o =  (addr_ack) ? 1'b0 :                 // address acknowledge          
                    (data_ack && !rwn_bit) ? 1'b0 :     // data acknowledge only for write operations
                    (data_send) ? read_data :           // sending data for read operations
                    1'b1;                               // Release SDA for all other cases

    // scl_o always 1 -> intentional: no clock stretching (slave delivers data always immediately)
    assign scl_o = 1'b1; 

endmodule