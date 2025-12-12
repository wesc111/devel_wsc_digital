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
    parameter SLAVE_ADDRESS = 7'h21;  // Example slave address

    parameter STASTO_DELAY = 200;   // Delay for start/stop conditions
    parameter BIT_DELAY = 2500;     // Delay for each bit

    // Signals
    logic clk;
    logic rst_n;
    wire scl;
    wire sda;
    logic [7:0] data_o;
    logic data_o_valid;    // indicates that data_o has valid data from slave

   
    logic [7:0] data_i;
    logic data_i_valid;    // indicates that data_i has valid data to be read by slave
    logic data_i_ready;    // indicates that slave has read the data_i and is ready for next data


    string  dump_fname;
    initial dump_fname = `DUMP_FILE;

    task i2c_idle_cycles(input int num_bit_delays);
        #(num_bit_delays * BIT_DELAY);
    endtask

    // Instantiate the I2C slave module
    logic scl_slave_o;
    logic sda_slave_o;
    i2c_slave #(.SLAVE_ADDRESS(SLAVE_ADDRESS)) 
        i2c_slave_inst (
        .clk(clk), .rst_n(rst_n), .scl_i(scl), .sda_i(sda),
        .scl_o(scl_slave_o), .sda_o(sda_slave_o),
        .data_i(data_i), .data_i_valid(data_i_valid), .data_i_ready(data_i_ready),
        .data_o(data_o), .data_o_valid(data_o_valid)
    );

    // Instantiate the I2C master model
    logic scl_master_o;
    logic sda_master_o;
    i2c_master 
        #(  .STASTO_DELAY(STASTO_DELAY),   // Delay for start/stop conditions
            .BIT_DELAY(BIT_DELAY)          // Delay for each bit
    )  i2c_master (
        .clk(clk), .rst_n(rst_n), .sda_i(sda), .scl_i(scl),
        .sda_o(sda_master_o), .scl_o(scl_master_o) 
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    logic [7:0] data_i_array [0:15];
    integer data_i_index = 0;
    initial begin
        // Initialize data_i_array with some test data
        data_i_array[0] = 8'h81;
        data_i_array[1] = 8'h5A;
        data_i_array[2] = 8'h3C;
        data_i_array[3] = 8'hC3;
        data_i_array[4] = 8'hFF;
        data_i_array[5] = 8'h00;
        data_i_array[6] = 8'h7E;
        data_i_array[7] = 8'h81;
        // ... initialize more as needed
    end

    // Provide data_i to the slave when data_i_ready is asserted
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_i_valid = 1'b0;
            data_i = data_i_array[0];
            data_i_index++;
            data_i_valid = 1'b1;
                  
        end
        else begin
            if (data_i_ready) begin
                // Load next data byte
                data_i <= data_i_array[data_i_index];
                data_i_index++;
                data_i_valid <= 1'b0;
                #(CLK_PERIOD+1); // small delay to ensure data_i is stable
                data_i_valid <= 1'b1;               
            end
        end
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
        i2c_idle_cycles(10);
        // Additional I2C transactions can be added here
        $display("I2C Master Testbench write tests");
        i2c_master.write_data_bytes(1, SLAVE_ADDRESS, 8'h5A);
        i2c_idle_cycles(10);
        i2c_master.write_data_bytes(2, SLAVE_ADDRESS, 8'h33, 8'h7E);
        i2c_idle_cycles(10);
        i2c_master.write_data_bytes(3, SLAVE_ADDRESS, 8'h1A, 8'hCD, 8'hC4);
        i2c_idle_cycles(10);
        i2c_master.write_data_bytes(4, SLAVE_ADDRESS, 8'h83, 8'h72, 8'hA5, 8'h23);
        i2c_idle_cycles(40);
        $display("I2C Master Testbench read tests");
        i2c_master.read_data_bytes(1, SLAVE_ADDRESS);
        i2c_idle_cycles(10);
        i2c_master.read_data_bytes(2, SLAVE_ADDRESS);
        i2c_idle_cycles(10);
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