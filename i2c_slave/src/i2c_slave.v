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
// Date: 26-Dec-2025

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
    // data_i_valid: from uC Interface to I2C slave
    //               indicates that valid data are put onto the data_i signal from the uC interface
    input logic data_i_valid,
    // data_i_ready: from I2C slave to uC Interface
    //               indicates that the I2C slave is ready to accept next data_i
    output logic data_i_ready,
    // data_o: data output to uC interface for write operations
    output logic [7:0] data_o,
    // data_o_valid: indicates that data_o has valid data for the uC interface
    output logic       data_o_valid
);

    typedef enum logic [3:0] {
        STATE_IDLE     = 4'd0,
        STATE_ADDRESS  = 4'd1,
        STATE_DATA     = 4'd2,
        STATE_RWN_BIT  = 4'd3,
        STATE_DATA_ACK = 4'd4,
        STATE_ADDR_ACK = 4'd5,
        STATE_START    = 4'd6
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

   // rwn bit: read/write_not bit (1=read, 0=write)
    logic rwn_bit;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rwn_bit <= 1'b0;
        end  
        else if (start_condition) begin
            rwn_bit <= 1'b0;
        end
        else if (scl_posedge && current_state==STATE_RWN_BIT) begin
            rwn_bit <= sda_i_sync;
        end
    end

    // address register
    logic [6:0] address_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            address_reg <= 7'b0;
        end  
        else if (current_state==STATE_IDLE || start_condition) begin
            address_reg <= 7'b0;
        end
        // first bit of address is received in STATE_START
        else if (current_state==STATE_START) begin
            address_reg[bit_count] <= sda_i_sync;
        end
        // shift in address bits till bit_count reaches 0
        else if (scl_posedge && current_state==STATE_ADDRESS) begin
            address_reg[bit_count] <= sda_i_sync;
        end
    end

    // data (write) register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_o <= 8'b0;
        end  
        else if (start_condition) begin
            data_o <= 8'b0;
        end
        // shift in data bits till bit_count reaches 0
        else if (scl_posedge && current_state==STATE_DATA && !rwn_bit && address_matched) begin
            data_o[bit_count] <= sda_i_sync;
        end
    end

    logic sda_o1;
    // for data read, serial output goes to sda_o1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_o1 <= 1'b1;
        end  
        else if (start_condition) begin
            sda_o1 <= 1'b1;
        end
        else if (scl_negedge && current_state==STATE_DATA && rwn_bit && address_matched) begin
            sda_o1 <= data_i[bit_count];
        end
        else if (sda_ack_master_negedge && current_state==STATE_DATA_ACK && rwn_bit && address_matched) begin
            sda_o1 <= data_i[bit_count];
        end
        else if (scl_negedge && current_state==STATE_DATA_ACK && rwn_bit && address_matched) begin
            sda_o1 <= 1'b1;
        end
    end
    
    //assign sda_o1 = (current_state==STATE_DATA && rwn_bit && address_matched) ? data_i[bit_count] : 1'b1;

    // on the falling edge of SCL in DATA_ACK state, check if master acknowledged
    logic master_acknowledged;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            master_acknowledged <= 1'b0;
        end  
        else if (scl_negedge && current_state==STATE_DATA_ACK && rwn_bit && address_matched) begin
            if (!sda_i_sync) begin
                master_acknowledged <= 1'b1;
            end
            else begin
                master_acknowledged <= 1'b0;
            end
        end
        else begin
            master_acknowledged <= 1'b0;
        end
    end

    logic data_fetched_within_ack;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_fetched_within_ack <= 1'b0;
        end
        else if (current_state==STATE_DATA_ACK && master_acknowledged) begin
            data_fetched_within_ack <= 1'b1;
        end
        else if (current_state==STATE_DATA || current_state==STATE_IDLE) begin
            data_fetched_within_ack <= 1'b0;
        end
    end

    // two signals show when a ack coms from the slave or from the master
    logic sda_ack_slave;
    logic sda_ack_master;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_ack_slave <= 1'b0;
        end  
        // all conditions to set one of the ack signals
        else if (scl_negedge && address_matched && current_state==STATE_ADDR_ACK) begin
            sda_ack_slave <= 1'b1;
        end
        else if (scl_negedge && address_matched && current_state==STATE_DATA_ACK && !rwn_bit) begin
            sda_ack_slave <= 1'b1;
        end
        // all conditions to clear the ack signals
        else if (stop_condition) begin
            sda_ack_slave <= 1'b0;
        end
        else if (scl_negedge && current_state==STATE_DATA) begin
            sda_ack_slave <= 1'b0;
        end
        else if (scl_negedge && current_state==STATE_DATA_ACK && !rwn_bit) begin
            sda_ack_slave <= 1'b0;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_ack_slave <= 1'b0;
            sda_ack_master <= 1'b0;
        end  
        else if (scl_posedge && address_matched && current_state==STATE_DATA_ACK && rwn_bit && !sda_i_sync) begin
                sda_ack_master <= 1'b1;
        end
        // all conditions to clear the ack signals
        else if (stop_condition) begin
            sda_ack_master <= 1'b0;
        end
        else if (scl_posedge && current_state==STATE_DATA && rwn_bit) begin
            sda_ack_master <= 1'b0;
        end
        else if (scl_negedge && current_state==STATE_DATA_ACK && rwn_bit) begin
            sda_ack_master <= 1'b0;
        end
        else if (current_state==STATE_DATA_ACK && rwn_bit && sda_i_sync) begin
            sda_ack_master <= 1'b0;
        end
    end

    logic sda_ack_master_d1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_ack_master_d1 <= 1'b0;
        end  
        else begin
            sda_ack_master_d1 <= sda_ack_master;
        end
    end

    assign sda_ack_master_negedge = sda_ack_master_d1 && !sda_ack_master;

    // data_i_ready: indicates that the I2C slave is ready to accept next data_i
    // We are ready to accept new data when master has acknowledged the last byte that has been sent
    assign data_i_ready = master_acknowledged && !data_fetched_within_ack;

    logic address_matched;
    assign address_matched = (address_reg == SLAVE_ADDRESS);

    // data_o_valid: indicates that data_o has valid data for the uC interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_o_valid <= 1'b0;
        end  
        else if (current_state==STATE_DATA && bit_count==4'd0 && !rwn_bit && address_matched && scl_posedge) begin
            data_o_valid <= 1'b1;
        end
        else begin
            data_o_valid <= 1'b0;
        end
    end

    logic bit_count_finished;   // currently not used : TBD WSC - check if necessary, otherwise remove
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= 'd0;
            bit_count_finished <= 1'b0;
        end  
        else if (current_state==STATE_IDLE && start_condition) begin
            bit_count <= 'd6;
            bit_count_finished <= 1'b0;
        end
        else if (stop_condition) begin
            bit_count <= 'd0;
            bit_count_finished <= 1'b0;
        end
        else if (scl_posedge && (current_state==STATE_ADDR_ACK || current_state==STATE_DATA_ACK)) begin
            bit_count <= 'd7;
            bit_count_finished <= 1'b0;
        end
        /* early return to DATA state after ACK from master -> reset bit_count */
        else if (scl_negedge && current_state==STATE_DATA_ACK) begin
            bit_count <= 'd7;
            bit_count_finished <= 1'b0;
        end
        else if (scl_negedge && current_state==STATE_ADDRESS) begin
            // Decrement bit count as long as we are in ADDRESS or DATA state
            if (bit_count>4'd0) begin
                    bit_count <= bit_count - 4'd1;
            end
            else begin
                bit_count_finished <= 1'b1;
            end
        end
        else if (scl_posedge && current_state==STATE_DATA) begin
            // Decrement bit count as long as we are in ADDRESS or DATA state
            if (bit_count>4'd0) begin
                    bit_count <= bit_count - 4'd1;
            end
            else begin
                bit_count_finished <= 1'b1;
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

    // all state transitions depend only on current_state, start_condition, stop_condition, scl_posedge, bit_count, rwn_bit
    always_comb begin
        next_state = current_state;
        case (current_state)
            STATE_IDLE: begin
                if (start_condition) begin
                    next_state = STATE_START;
                end
            end
            STATE_START: begin
                if (stop_condition) begin
                    next_state = STATE_IDLE;
                end
                else if (scl_posedge) begin
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
                else if (bit_count==4'd0 & scl_posedge) begin
                    next_state = STATE_RWN_BIT;
                end
            end
            STATE_RWN_BIT: begin
                if (stop_condition) begin
                    next_state = STATE_IDLE;
                end
                else if (scl_posedge) begin
                    next_state = STATE_ADDR_ACK;
                end
            end
            STATE_ADDR_ACK: begin
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
                // after 8 bits of data, go to DATA_ACK state
                else if (scl_posedge && current_state==STATE_DATA && bit_count==4'd0) begin
                    next_state = STATE_DATA_ACK;
                end
            end
            default: begin
                next_state = STATE_IDLE;
            end
            STATE_DATA_ACK: begin
                if (stop_condition) begin
                    next_state = STATE_IDLE;
                end
                else if (start_condition) begin
                    next_state = STATE_START;
                end
                // for write operation go back to DATA state after next falling edge of SCL
                else if (scl_posedge && !rwn_bit) begin
                    next_state = STATE_DATA;
                end
                // for read operations, after ACK from master, go back to DATA state
                else if (scl_posedge && rwn_bit && bit_count==4'd7 && sda_i_sync==1'b1) begin
                    next_state = STATE_DATA;
                end
                // for read operations, after NACK from master, go back to DATA state
                else if (sda_ack_master_negedge && rwn_bit && bit_count==4'd7 ) begin
                    next_state = STATE_DATA;
                end
            end 
        endcase
    end
   
    assign sda_o =  1'b1 & 
                    !sda_ack_slave &
                    sda_o1;       // Slave pulls SDA low to acknowledge
    // TBD WSC - remove if not needed:
    // assign sda_o = sda_ack_o;    // Acknowledge by pulling SDA low

    // scl_o always 1 -> intentional: no clock stretching (slave delivers data always immediately)
    assign scl_o = 1'b1; 

endmodule