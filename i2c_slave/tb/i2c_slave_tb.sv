// i2c_slave_tb.sv
// Testbench for I2C slave module
//
// Author: Werner Schoegler
// Date: 30-Nov-2025

`timescale 1ns / 1ps

// control dump file generation
`define DUMP_FLAG 1
`define DUMP_FILE "i2c_slave_tb.vcd"

module testbench ();

    // Parameters
    parameter CLK_PERIOD = 10; // Clock period in ns
    logic DUMP_FLAG = `DUMP_FLAG;

    // I2C parameters
    parameter I2C_CLOCK_PERIOD = 100; // I2C clock period in ns
    parameter SLAVE_ADDRESS = 7'h42;  // Example slave address

    // Signals
    logic clk;
    logic rst_n;
    wire scl;
    wire sda;
    logic [7:0] data_out;
    logic data_ready;

    string  dump_fname;
    initial dump_fname = `DUMP_FILE;

    // Instantiate the I2C slave module
    logic scl_slave_o;
    logic sda_slave_o;
    i2c_slave #(.SLAVE_ADDRESS(7'h21)) 
        i2c_slave_inst (
        .clk(clk), .rst_n(rst_n), .scl_i(scl), .sda_i(sda),
        .scl_o(scl_slave_o), .sda_o(sda_slave_o),
        .data_o(data_out), .data_ready(data_ready)
    );

    // Instantiate the I2C master model
    logic scl_master_o;
    logic sda_master_o;
    i2c_master 
        #(  .STASTO_DELAY(50),   // Delay for start/stop conditions
            .BIT_DELAY(1000)     // Delay for each bi
    )  i2c_master (
        .clk(clk), .rst_n(rst_n), .sda_i(sda), .scl_i(scl),
        .sda_o(sda_master_o), .scl_o(scl_master_o) 
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end


    assign (weak1, strong0) scl = (scl_slave_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior
    assign (weak1, strong0) sda = (sda_slave_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior
    assign (weak1, strong0) scl = (scl_master_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior
    assign (weak1, strong0) sda = (sda_master_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior

    // I2C master simulation tasks can be added here to drive scl_master and sda_master
    // Test sequence
    initial begin
        $display("I2C Master Testbench started ...");
        // Initialize signals
        rst_n <= 0;

        // Release reset
        #(CLK_PERIOD * 2);
        rst_n = 1;

        // Simulate I2C transactions here
        // Example: Start condition, address, data, stop condition
        i2c_master.set_idle();
        #(1000);
        // Additional I2C transactions can be added here
        i2c_master.write_data_bytes(1, 7'h21, 8'h5A);
        #(1000);
        i2c_master.write_data_bytes(2, 7'h21, 8'h33, 8'h7E);
        #(1000);
        i2c_master.write_data_bytes(3, 7'h21, 8'h1A, 8'hCD, 8'hC4);
        #(1000);
        i2c_master.write_data_bytes(4, 7'h21, 8'h83, 8'h72, 8'hA5, 8'h23);
        #(1000);
        $display("I2C Master Testbench finished ...");
        $finish;
    end

    // Dump file generation
    initial
    if (DUMP_FLAG==1) begin
        $display("... generating dump file %s",dump_fname);
        $dumpfile(dump_fname);
        $dumpvars(0,testbench);
    end

endmodule   