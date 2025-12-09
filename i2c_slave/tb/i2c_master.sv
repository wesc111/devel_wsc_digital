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

task set_idle;
    sda_o = 1'b1;
    scl_o = 1'b1;
endtask

task gen_start;
    sda_o = 1'b1;
    scl_o = 1'b1;
    #(STASTO_DELAY);
     // transition of sda from 1 to 0 while scl is high creates start condition
    sda_o = 1'b0;
    #(STASTO_DELAY);
    scl_o = 1'b0;
    #(STASTO_DELAY);
endtask

task gen_stop;
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
    #(BIT_DELAY/4);
    sda_o = bit_value;
    #(BIT_DELAY/4);
    scl_o = 1'b1;
    #(BIT_DELAY/2);
    scl_o = 1'b0;
endtask

task gen_write(input logic [6:0] addr);
    for (int i = 6; i >= 0; i--) begin
        gen_bit(addr[i]);
    end
    gen_bit(1'b0); //R_WN bit for write operation
    // Generate ACK bit (assuming slave always ACKs)
    gen_bit(1'b1); // Master releases SDA for ACK    
endtask

task gen_data(input logic [7:0] data);
    for (int i = 7; i >= 0; i--) begin
        gen_bit(data[i]);
    end
    gen_bit(1'b1); // Master releases SDA for ACK
endtask

// Write multiple data bytes to a given address
task write_data_bytes(input int number_of_bytes=1, input logic [6:0] addr, 
                      input logic [7:0] data0 = 8'h00,
                      input logic [7:0] data1 = 8'h00,
                      input logic [7:0] data2 = 8'h00,
                      input logic [7:0] data3 = 8'h00);
    $display("I2C Master Model write_data_bytes() called with %0d bytes", number_of_bytes);
    gen_start();
    gen_write(addr);
    gen_data(data0);
    if (number_of_bytes > 1) gen_data(data1);
    if (number_of_bytes > 2) gen_data(data2);
    if (number_of_bytes > 3) gen_data(data3);
    gen_stop();
    $display("I2C Master Model write_data_bytes() completed");
endtask

endmodule
    // I2C Master signals and states
    // I2C Master implementation goes here