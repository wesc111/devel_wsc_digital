// i2c_slave_tb.sv
// Testbench for I2C slave module
//
// Author: Werner Schoegler
// Date: 26-Dec-2025

// Note: This testbench uses a simple I2C master model to drive the I2C slave DUT.
// The I2C master model is a placeholder and should be expanded according to specific test requirements
// as needed.
// The testbench performs basic write and read operations to verify the functionality of the I2C slave.
// The testbench also includes assertion checks to validate the data integrity during I2C transactions.

`timescale 1ns / 1ps

// control dump file generation
`define DUMP_FLAG 1
`define DUMP_FILE "i2c_slave_tb.vcd"
`define DEBUG_LEVEL 1

// select which tests to run
`define RUN_WRITE_TESTS 1
`define RUN_READ_TESTS 1

module testbench ();

    // Parameters
    parameter CLK_PERIOD = 10; // Clock period in ns
    logic DUMP_FLAG = `DUMP_FLAG;

    // I2C parameters
    parameter I2C_CLOCK_PERIOD = 100; // I2C clock period in ns
    parameter SLAVE_ADDRESS = 7'h21;  // Example slave address

    parameter STASTO_DELAY = 500;   // Delay for start/stop conditions
    parameter BIT_DELAY = 1000;     // Delay for each bit

    parameter int debugging_level_p = `DEBUG_LEVEL;
    parameter int run_write_tests_p = `RUN_WRITE_TESTS;
    parameter int run_read_tests_p = `RUN_READ_TESTS;

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

    // count assertions that are passing, reported at end of simulation
    int assert_pass_count = 0;
    int assert_fail_count = 0;
    int test_case_count = 0;


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
        data_i_array[7] = 8'hE5;
        // ... initialize more as needed
    end

    // Provide data_i to the slave when data_i_ready is asserted
    logic data_i_array_reset = 1'b0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || data_i_array_reset) begin
            data_i_valid = 1'b0;
            data_i_index = 0;
            data_i = data_i_array[data_i_index];           
            data_i_valid = 1'b1;
                  
        end
        else begin
            if (data_i_ready) begin
                // Load next data byte
                data_i <= data_i_array[++data_i_index];
                data_i_valid <= 1'b0;
                #(CLK_PERIOD+1); // small delay to ensure data_i is stable
                data_i_valid <= 1'b1;               
            end
        end
    end

    int data_write_index = 0;
    logic [7:0] data_write_array [0:15];
    initial begin
        // Initialize expected data_write_array with expected test data
        data_write_array[0] = 8'h5A;
        data_write_array[1] = 8'h33;
        data_write_array[2] = 8'h7E;
        data_write_array[3] = 8'h1A;
        data_write_array[4] = 8'hCD;
        data_write_array[5] = 8'hC4;
        data_write_array[6] = 8'hFF;
        data_write_array[7] = 8'h72;
        data_write_array[8] = 8'ha5;
        data_write_array[9] = 8'h23;
        data_write_array[10] = 8'h57;
        data_write_array[11] = 8'h00;
        data_write_array[12] = 8'h1E;
        data_write_array[13] = 8'hA4;
        data_write_array[14] = 8'h24;
        data_write_array[15] = 8'h34;
    end

    // Monitor and check data_o from the slave
    always @(posedge clk) begin
        if (data_o_valid) begin
            assert (data_o == data_write_array[data_write_index]) begin
                assert_pass_count++;
                if (debugging_level_p >= 1) $display("Assertion pass, data match %2d: 0x%0h", data_write_index, data_o);
            end
            else begin
                assert_fail_count++;
                $error("Data mismatch: expected 0x%0h, got 0x%0h", data_write_array[data_write_index], data_o);
            end
            data_write_index++;
        end
    end

    assign (weak1, strong0) scl = (scl_slave_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior
    assign (weak1, strong0) sda = (sda_slave_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior
    assign (weak1, strong0) scl = (scl_master_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior
    assign (weak1, strong0) sda = (sda_master_o==1'b0) ? 1'b0 : 1'b1; // Open-drain behavior

    // Write multiple data bytes to a given address
    // Example usage: run_write_tests(3) to write 3 bytes
    task run_write_tests(int number_of_bytes=1);
        if (number_of_bytes < 1) number_of_bytes = 1;
        if (number_of_bytes > 4) number_of_bytes = 4;
        data_write_index = 0;
        $display("I2C Master Testbench running write test with %0d bytes", number_of_bytes);
        i2c_master.write_data_bytes(number_of_bytes, SLAVE_ADDRESS, 
            data_write_array[0], data_write_array[1], data_write_array[2], data_write_array[3]);
        test_case_count++;
        i2c_idle_cycles(10);
    endtask 

    // Read multiple data bytes from a given address (with verification)   
    // Note: data_i_array is pre-initialized with expected data
    // The read bytes from the slave are stored in i2c_master.read_byte_array
    // and verified against data_i_array
    // Example usage: run_read_test(2) to read 2 bytes and verify
    task run_read_test(int number_of_bytes=1);
        if (number_of_bytes < 1) number_of_bytes = 1;
        if (number_of_bytes > 4) number_of_bytes = 4;
        $display("I2C Master Testbench running read test with %0d bytes", number_of_bytes);
        data_i_array_reset = 1'b1;
        #(CLK_PERIOD*2);
        data_i_array_reset = 1'b0;
        #(CLK_PERIOD*2);
        i2c_master.read_data_bytes(number_of_bytes, SLAVE_ADDRESS);
        test_case_count++;
        i2c_idle_cycles(10);
        for (int i=0; i<number_of_bytes; i++) begin
            assert (i2c_master.read_byte_array[i] == data_i_array[i]) begin
                assert_pass_count++;
                if (debugging_level_p >= 1) $display("Read data match: 0x%0h", i2c_master.read_byte_array[i]);
            end
            else begin
                assert_fail_count++;
                $error("Read data mismatch: expected 0x%0h, got 0x%0h", data_i_array[i], i2c_master.read_byte_array[i]);
            end
        end
    endtask

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
        if (run_write_tests_p) begin
            $display("I2C Master Testbench write tests");
            run_write_tests(1);
            i2c_idle_cycles(40);
            /*
            run_write_tests(2);
            i2c_idle_cycles(40);
            run_write_tests(3);
            i2c_idle_cycles(40);
            run_write_tests(4);
            i2c_idle_cycles(40);
            */
        end
        if (run_read_tests_p) begin           
            $display("I2C Master Testbench read tests");
            run_read_test(1);
            i2c_idle_cycles(40);
            run_read_test(2);
            i2c_idle_cycles(40);
        end


        // Finish simulation
        $display("I2C Master Testbench finished ...");
        $display("Total assertions passed: %0d", assert_pass_count);
        if (assert_fail_count == 0)
            $display("Success! All assertions passed.");
        else
            $display("FAIL/ERROR, total of %0d assertions failed!", assert_fail_count);
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