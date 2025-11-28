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
    logic finished;

    string  dump_fname;
    initial dump_fname = `DUMP_FILE;

    // Instantiate the I2C slave module
    logic scl_slave_o;
    logic sda_slave_o;
    i2c_slave i2c_slave_inst (
        .clk(clk), .rst_n(rst_n), .scl_i(scl), .sda_i(sda),
        .scl_o(scl_slave_o), .sda_o(sda_slave_o),
        .data_o(data_out), .data_ready(data_ready)
    );

    // Instantiate the I2C master model
    logic scl_master_o;
    logic sda_master_o;
    i2c_master i2c_master_inst (
        .clk(clk), .rst_n(rst_n), .sda_i(sda), .scl_i(scl),
        .sda_o(sda_master_o), .scl_o(scl_master_o), .finished(finished)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    always @(posedge finished) begin
        $display("I2C Master Finished Transactions");
        #100;
        $finish;
    end


    assign (weak1, strong0) scl = (scl_slave_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior
    assign (weak1, strong0) sda = (sda_slave_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior
    assign (weak1, strong0) scl = (scl_master_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior
    assign (weak1, strong0) sda = (sda_master_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior

    // I2C master simulation tasks can be added here to drive scl_master and sda_master
    // Test sequence
    initial begin
        // Initialize signals
        rst_n <= 0;

        // Release reset
        #(CLK_PERIOD * 2);
        rst_n = 1;

        // Simulate I2C transactions here
        // Example: Start condition, address, data, stop condition

        // Finish simulation after 1s if not finished before
        #1_000_000;
        $finish;
    end

    initial
    if (DUMP_FLAG==1) begin
        $display("... generating dump file %s",dump_fname);
        $dumpfile(dump_fname);
        $dumpvars(0,testbench);
    end

endmodule   