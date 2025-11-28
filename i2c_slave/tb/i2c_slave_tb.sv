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
    i2c_slave uut (
        .clk, .rst_n, .scl, .sda,
        .data_out, .data_ready
    );

    task gen_start_condition();
        begin
            // Implement start condition generation
        end
    endtask

    task gen_stop_condition();
        begin
            // Implement stop condition generation
        end
    endtask

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    logic scl_master;
    logic sda_master;
    assign scl = scl_master ? 1'bz : 1'b0; // Open-drain behavior
    assign sda = sda_master ? 1'bz : 1'b0; // Open-drain behavior
    // I2C master simulation tasks can be added here to drive scl_master and sda_master
    // Test sequence
    initial begin
        // Initialize signals
        rst_n <= 0;
        scl_master <= 1;
        sda_master <= 1;

        // Release reset
        #(CLK_PERIOD * 2);
        rst_n = 1;

        // Simulate I2C transactions here
        // Example: Start condition, address, data, stop condition

        // Finish simulation
        #(CLK_PERIOD * 100);
        $finish;
    end

    initial
    if (DUMP_FLAG==1) begin
        $display("... generating dump file %s",dump_fname);
        $dumpfile(dump_fname);
        $dumpvars(0,testbench);
    end

endmodule   