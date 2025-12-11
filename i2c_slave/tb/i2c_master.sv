// i2c_slave/tb/i2c_master.sv
// Simple I2C Master model for testbench purposes
// Note: This is a placeholder implementation and should be expanded
// according to the specific test requirements.

// Author: Werner Schoegler
// Date: 30-Nov-2025


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

   typedef enum logic [2:0] {
        IDLE = 3'd0,
        START = 3'd1,
        STOP = 3'd2,
        BIT = 3'd3,
        ACK = 3'd4,
        DATA = 3'd5 
   } i2c_master_state_t;

   i2c_master_state_t master_state;

task set_idle;
    master_state = IDLE;
    sda_o = 1'b1;
    scl_o = 1'b1;
endtask

task gen_start;
    master_state = START;
    sda_o = 1'b1;
    scl_o = 1'b1;
    #(STASTO_DELAY);
     // transition of sda from 1 to 0 while scl is high creates start condition
    sda_o = 1'b0;
    #(STASTO_DELAY);
    scl_o = 1'b0;
    #(STASTO_DELAY);
endtask

// TBD: dead code, remove
task gen_stop;
    master_state = STOP;
    sda_o = 1'b0;
    scl_o = 1'b0;
    #(STASTO_DELAY);
    scl_o = 1'b1;
    #(STASTO_DELAY);
    // transition of sda from 0 to 1 while scl is high creates stop condition
    sda_o = 1'b1;
    #(STASTO_DELAY);
    sda_o = 1'b1;
endtask

task gen_bit(input logic bit_value);
    master_state = BIT;
    #(BIT_DELAY/4);
    sda_o = bit_value;
    #(BIT_DELAY/4);
    scl_o = 1'b1;
    #(BIT_DELAY/2);
    scl_o = 1'b0;
endtask

// generate a read or write operation to the given address
task gen_read_write(input logic rwn, input logic [6:0] addr);
    for (int i = 6; i >= 0; i--) begin
        gen_bit(addr[i]);
    end
    gen_bit(rwn); //R_WN bit for write operation
    // Generate ACK bit (assuming slave always ACKs)
    gen_bit(1'b1); // Master releases SDA for ACK    
endtask

task gen_data(input logic rwn, input logic [7:0] data);
    for (int i = 7; i >= 0; i--) begin
        gen_bit(data[i]);
    end
    if (!rwn)
        gen_bit(1'b1); // for write operation, master releases SDA for ACK from slave
    else
        gen_bit(1'b0); // for read operation, master sends ACK after data
endtask

// Write multiple data bytes to a given address
task write_data_bytes(input int number_of_bytes=1, input logic [6:0] addr, 
                      input logic [7:0] data0 = 8'h00,
                      input logic [7:0] data1 = 8'h00,
                      input logic [7:0] data2 = 8'h00,
                      input logic [7:0] data3 = 8'h00);
    $display("I2C Master Model write_data_bytes() to address 0x%0h with %0d bytes", addr, number_of_bytes);
    gen_start();
    gen_read_write(1'b0, addr);
    gen_data(1'b0, data0);
    if (number_of_bytes > 1) gen_data(1'b0, data1);
    if (number_of_bytes > 2) gen_data(1'b0, data2);
    if (number_of_bytes > 3) gen_data(1'b0, data3);
    gen_stop();
    set_idle();
    $display("I2C Master Model write_data_bytes() completed");
endtask

task read_data_bytes(input int number_of_bytes=1, input logic [6:0] addr);
    logic [7:0] dummy_data = 8'hFF; // Dummy data for clocking out reads
    $display("I2C Master Model read_data_bytes() from address 0x%0h with %0d bytes", addr, number_of_bytes);
    gen_start();
    gen_read_write(1'b1, addr);
    for (int i = 0; i < number_of_bytes; i++) begin
        gen_data(1'b1, dummy_data); // Send dummy data to clock out reads
    end
    gen_stop();
    set_idle();
    $display("I2C Master Model read_data_bytes() completed");
endtask

endmodule
    // I2C Master signals and states
    // I2C Master implementation goes here