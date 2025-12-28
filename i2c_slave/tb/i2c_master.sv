// i2c_slave/tb/i2c_master.sv
// Simple I2C Master model for testbench purposes
// Note: This is a placeholder implementation and should be expanded
// according to the specific test requirements.

// Author: Werner Schoegler
// Date: 26-Dec-2025

// TBD: stop condition is not always working correctly, needs more debugging and testing

// added i2c_master_state_t for better state tracking and debugging
// added inputs to gen_bit task for better state tracking and debugging

`timescale 1ns / 1ps

module i2c_master 
#(  parameter STASTO_DELAY = 100,       // Delay for start/stop conditions
    parameter BIT_DELAY = 1000          // Delay for each bit
)
(
    input logic clk,
    input logic rst_n,
    input logic sda_i,
    input logic scl_i,
    output logic sda_o,
    output logic scl_o
);

   typedef enum logic [7:0] {
        IDLE  = 8'h0,
        START = 8'h1,
        STOP  = 8'h2,
        BIT   = 8'h3,
        B_END = 8'h4,
        ACK   = 8'h5,
        ADDR  = 8'h6,
        DATA  = 8'h7,
        RWN   = 8'h8,
        A0    = 8'h10,
        A1    = 8'h11,
        A2    = 8'h12,
        A3    = 8'h13,
        A4    = 8'h14,
        A5    = 8'h15,
        A6    = 8'h16,
        A7    = 8'h17,
        D0    = 8'h20,
        D1    = 8'h21,
        D2    = 8'h22,
        D3    = 8'h23,
        D4    = 8'h24,
        D5    = 8'h25,
        D6    = 8'h26,
        D7    = 8'h27
   } i2c_master_state_t;

   i2c_master_state_t master_state;

   int read_byte_array_index = 0;

// SDA output is either driven low because of ACK cycle or driven by sda_o1
logic sda_o1;
logic rwn;
// TBD WSC - currently only sda_o1 is used, need to implement ACK driving logic
assign sda_o = sda_o1;
//assign sda_o = (master_state == ACK) ? 1'b0 : sda_o1;

task set_idle;
    master_state = IDLE;
    sda_o1 = 1'b1;
    scl_o = 1'b1;
endtask

task gen_start;
    read_byte_array_index = 0;   // reset read byte array index at start condition
    master_state = START;
    sda_o1 = 1'b1;
    scl_o = 1'b1;
    #(STASTO_DELAY);
     // transition of sda from 1 to 0 while scl is high creates start condition
    sda_o1 = 1'b0;
    #(STASTO_DELAY);
    scl_o = 1'b0;
    #(STASTO_DELAY);
endtask

// TBD: dead code, remove
task gen_stop;
    master_state = STOP;
    sda_o1 = 1'b0;
    #(BIT_DELAY/4);  
    scl_o = 1'b1;
    #(STASTO_DELAY);
    sda_o1 = 1'b1;
    #(BIT_DELAY);
endtask

// generate a single bit on the bus
// inputs bit_d_an, bit_num, and is_ack are just used for state tracking and debugging
logic read_bit_value;
task gen_bit(input logic bit_value, input logic bit_d_an, input logic [7:0] bit_num, input logic rwn_bit);
    if (rwn_bit) begin
        master_state = RWN;
    end
    else begin
        if (!bit_d_an) begin
            case (bit_num)
                7: master_state = A7;
                6: master_state = A6;
                5: master_state = A5;
                4: master_state = A4;
                3: master_state = A3;
                2: master_state = A2;
                1: master_state = A1;
                0: master_state = A0;
                default: master_state = ADDR;   
            endcase
        end
        else begin
            case (bit_num)
                7: master_state = D7;
                6: master_state = D6;
                5: master_state = D5;
                4: master_state = D4;
                3: master_state = D3;
                2: master_state = D2;
                1: master_state = D1;
                0: master_state = D0;
                default: master_state = DATA;   
            endcase
        end
    end
    scl_o = 1'b0;
    sda_o1 = bit_value;
    #(BIT_DELAY/4);
    scl_o = 1'b1;
    read_bit_value = sda_i; // Capture read bit value at rising edge of clock
    #(BIT_DELAY/2);
    scl_o = 1'b0;
    #(BIT_DELAY/4);
endtask

localparam ACK_TO_SCL_RISE_DELAY = 10;
// generate ACK/NACK bit on the bus, timing is similar to gen_bit, but master releases SDA faster (after neg edge of SCL)
task gen_ack(logic bit_value, input logic stop_condition=1'b0);
    master_state = ACK;
    scl_o = 1'b0;
    sda_o1 = bit_value; // Master drives ACK/NACK bit
    #(BIT_DELAY/4);
    scl_o = 1'b1;
    #(BIT_DELAY/2);
    scl_o = 1'b0;
    if (!stop_condition) begin
        #(ACK_TO_SCL_RISE_DELAY);
        sda_o1 = 1'b1; // Release SDA after ACK
        #(BIT_DELAY/4-ACK_TO_SCL_RISE_DELAY);      
    end
    else begin
        sda_o1 = 1'b0; // Keep SDA driven for stop condition
        master_state = STOP;
        #(BIT_DELAY/4);  
        scl_o = 1'b1;
        #(STASTO_DELAY);
        sda_o1 = 1'b1;
        #(BIT_DELAY);
    end
endtask

// generate the address part of the I2C protocol
task gen_addr_part(input logic rwn, input logic [6:0] addr);
    for (int i = 6; i >= 0; i--) begin
        //      bit_value, bit_d_an, bit_num, rwn_bit
        gen_bit(addr[i],   1'b0,     i,       1'b0);
    end
    //      bit_value, bit_d_an, bit_num, rwn_bit
    gen_bit(rwn,       1'b0,     7,       1'b1); //R_WN bit for write operation
    // Generate ACK bit (assuming slave always ACKs)
    //      bit_value, bit_d_an, bit_num, rwn_bit
    gen_ack(1'b1, 1'b0); // Master releases SDA for ACK    
endtask

// generate a data byte on the bus
task gen_data(input logic rwn, input logic [7:0] data, input logic stop_condition);
    for (int i = 7; i >= 0; i--) begin
        //      bit_value, bit_d_an, bit_num,  rwn_bit
        gen_bit(data[i],   1'b1,     i,     1'b0);
        read_byte[i] = read_bit_value; // Capture read data bits
    end
    read_byte_array[read_byte_array_index] = read_byte; // Store read byte in array
    read_byte_array_index++;
    // Generate ACK bit
    if (!rwn)
    // for write operation, master releases SDA for ACK from slave
        gen_ack(1'b1, stop_condition);
    else
        // for read operation, master sends ACK after data
        //      bit_value, bit_d_an, bit_num, is_ack, rwn_bit
        gen_ack(1'b0, stop_condition); 
endtask

// Write multiple data bytes to a given address
task write_data_bytes(input int number_of_bytes=1, input logic [6:0] addr, 
                      input logic [7:0] data0 = 8'h00,
                      input logic [7:0] data1 = 8'h00,
                      input logic [7:0] data2 = 8'h00,
                      input logic [7:0] data3 = 8'h00);
    $display("I2C Master Model write_data_bytes() to address 0x%0h with %0d bytes", addr, number_of_bytes);
    gen_start();
    gen_addr_part(1'b0, addr);
    gen_data(1'b0, data0, (number_of_bytes == 1) ? 1'b1 : 1'b0);
    if (number_of_bytes >= 2) begin
        gen_data(1'b0, data1, (number_of_bytes == 2) ? 1'b1 : 1'b0);
    end
    if (number_of_bytes >= 3) begin
        gen_data(1'b0, data2, (number_of_bytes == 3) ? 1'b1 : 1'b0);
    end
    if (number_of_bytes >= 4) begin
        gen_data(1'b0, data3, (number_of_bytes == 4) ? 1'b1 : 1'b0);
    end
    set_idle();
    $display("I2C Master Model write_data_bytes() completed");
endtask

logic [7:0] read_byte; // Store up to 16 read bytes
byte read_byte_array [15:0]; // alternative storage for read bytes
task read_data_bytes(input int number_of_bytes=1, input logic [6:0] addr);
    logic [7:0] dummy_data = 8'hFF; // Dummy data for clocking out reads
    $display("I2C Master Model read_data_bytes() from address 0x%0h with %0d bytes", addr, number_of_bytes);
    gen_start();
    gen_addr_part(1'b1, addr);
    for (int i = 0; i < number_of_bytes; i++) begin
        gen_data(1'b1, dummy_data, (i == number_of_bytes - 1) ? 1'b1 : 1'b0); // Send dummy data to clock out reads
    end
    set_idle();
    $display("I2C Master Model read_data_bytes() completed");
endtask

function logic [7:0] get_data_byte(int byte_index=0);
    // TBD: implement reading data byte from slave
    $display("I2C Master Model get_data_byte() called, returning 0x%0h", read_byte_array[byte_index]);
    if (byte_index < 0 || byte_index > 15) begin
        $error("get_data_byte() index out of range: %0d", byte_index);
        return 8'h00;
    end 
    get_data_byte = read_byte_array[byte_index];
endfunction

endmodule
    // I2C Master signals and states
    // I2C Master implementation goes here