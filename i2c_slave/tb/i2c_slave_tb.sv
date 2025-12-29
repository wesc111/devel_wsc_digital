// i2c_slave_tb.sv
// Testbench for I2C slave module
//
// Author: Werner Schoegler
// Date: 26-Dec-2025

// Note: This testbench uses a simple I2C master model to drive the I2C slave DUT.
// The I2C master model is a placeholder and should be expanded according to specific test requirements
// as needed.
//
// The testbench has following features:
// - basic write operations
// - basic read operations
// - randomized write operations
// - randomized read operations
// - watchdog timeout to avoid infinite hangs
// - open-drain behavior for I2C lines
// - configurable debug levels
// - configurable number of test cases
// - configurable dump file generation
// - partially configurable I2C timing parameters
// - data verification for read and write operations with assertion mechanism, self testing
// - done code review based on AI suggestions (Claude Sonnet) on 29-Dec-2025

// Limitations:
// - I2C master model is simplistic and may not cover all edge cases
// - No support for clock stretching in I2C slave
// - No support for repeated start conditions in I2C slave
// - Test coverage may not be exhaustive, further tests may be needed for full verification
// - Timing parameters are fixed, no dynamic adjustment during simulation

`timescale 1ns / 1ps

// control dump file generation
`define DUMP_FLAG 1
`define DUMP_FILE "i2c_slave_tb.vcd"
`define DEBUG_LEVEL 1

// select which tests to run

// WRITE tests
`define RUN_WRITE_TESTS 1
`define RUN_WRITE_TESTS_RAND 1
`define WRITE_TESTS_RAND_NUM 80

// READ tests
`define RUN_READ_TESTS 1
`define RUN_READ_TESTS_RAND 1
`define READ_TESTS_RAND_NUM 80

module testbench ();

    // Parameters
    parameter CLK_PERIOD = 10; // Clock period in ns
    logic DUMP_ENABLE = `DUMP_FLAG;

    // I2C parameters
    parameter I2C_CLOCK_PERIOD = 100; // I2C clock period in ns
    parameter SLAVE_ADDRESS = 7'h21;  // Example slave address

    parameter STASTO_DELAY = 500;   // Delay for start/stop conditions
    parameter BIT_DELAY = 1000;     // Delay for each bit

    parameter int debugging_level_p = `DEBUG_LEVEL;
    parameter int run_write_tests_p = `RUN_WRITE_TESTS;
    parameter int run_write_tests_rand_p = `RUN_WRITE_TESTS_RAND; // enable random data for write tests
    parameter int run_read_tests_p = `RUN_READ_TESTS;
    parameter int run_read_tests_rand_p = `RUN_READ_TESTS_RAND; // enable random data for read tests

    parameter WATCHDOG_TIMEOUT = 50000; // in ns

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
        data_i_array[0]  = 8'h81;
        data_i_array[1]  = 8'h5A;
        data_i_array[2]  = 8'h00;
        data_i_array[3]  = 8'hFF;
        data_i_array[4]  = 8'hED;
        data_i_array[5]  = 8'h12;
        data_i_array[6]  = 8'h7E;
        data_i_array[7]  = 8'hE5;
        data_i_array[8]  = 8'hAA;
        data_i_array[9]  = 8'h12;
        data_i_array[10] = 8'h5F;
        data_i_array[11] = 8'hFE;
        data_i_array[12] = 8'h76;
        data_i_array[13] = 8'h56;
        data_i_array[14] = 8'h65;
        data_i_array[15] = 8'h1A;
        // ... initialize more as needed
    end
    task randomize_data_i_array();
        for (int i = 0; i < 16; i++) begin
            data_i_array[i] = $urandom_range(0, 255);
        end
    endtask 

    // Provide data_i to the slave when data_i_ready is asserted
    logic data_i_array_reset = 1'b0;
    logic data_i_valid_next;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_i_index <= 0;
            data_i <= data_i_array[0];
            data_i_valid <= 1'b0;
            data_i_valid_next <= 1'b0;
        end
        else if (data_i_array_reset) begin
            data_i_index <= 0;
            data_i <= data_i_array[0];
            data_i_valid <= 1'b1;
            data_i_valid_next <= 1'b1;
        end
        else begin
            // Handle the ready signal
            if (data_i_ready && data_i_valid) begin
                if (data_i_index < 15) begin  // Change <= to <
                    data_i_index <= data_i_index + 1;
                    data_i <= data_i_array[data_i_index + 1];
                    data_i_valid <= 1'b0;  // Deassert for one cycle
                    data_i_valid_next <= 1'b1;
                end
                else begin
                    data_i_valid <= 1'b0;  // No more data
                    data_i_valid_next <= 1'b0;
                end
            end
            else if (!data_i_valid && data_i_valid_next) begin
                // Re-assert valid after one-cycle gap
                data_i_valid <= 1'b1;
                data_i_valid_next <= 1'b0;
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
        data_write_array[8] = 8'hA5;
        data_write_array[9] = 8'h23;
        data_write_array[10] = 8'h57;
        data_write_array[11] = 8'h00;
        data_write_array[12] = 8'h1E;
        data_write_array[13] = 8'hA4;
        data_write_array[14] = 8'h24;
        data_write_array[15] = 8'h34;
    end
    task randomize_data_write_array();
        for (int i = 0; i < 16; i++) begin
            data_write_array[i] = $urandom_range(0, 255);
        end
    endtask

    // Monitor and check data_o from the slave
    always @(posedge clk) begin
        if (data_o_valid) begin
            assert (data_o == data_write_array[data_write_index]) begin
                assert_pass_count++;
                if (debugging_level_p >= 1) $display("  --> Write data match: 0x%0h", data_o);
            end
            else begin
                assert_fail_count++;
                $error("  --> Error: Write data mismatch: %t expected 0x%0h, got 0x%0h", $time, data_write_array[data_write_index], data_o);
            end
            if (data_write_index < 15)
                data_write_index++;
        end
    end

    // Open-drain behavior
    assign (weak1, strong0) scl = (scl_slave_o==1'b0 || scl_master_o==1'b0) ? 1'b0 : 1'b1;
    assign (weak1, strong0) sda = (sda_slave_o==1'b0 || sda_master_o==1'b0) ? 1'b0 : 1'b1;

    // Write multiple data bytes to a given address
    // Example usage: run_write_tests(3) to write 3 bytes
    // Watchdog simpler timeout approach - added to avoid infinite hangs
    task run_write_tests(int number_of_bytes=1);
        if (number_of_bytes < 1) number_of_bytes = 1;
        if (number_of_bytes > 4) number_of_bytes = 4;
        data_write_index = 0;
        $display("I2C Master Testbench running write test with %0d bytes", number_of_bytes);
        
        fork
            begin
                // Normal operation
                i2c_master.write_data_bytes(number_of_bytes, SLAVE_ADDRESS, 
                    data_write_array[0], data_write_array[1], data_write_array[2], data_write_array[3]);
            end
            begin
                // Timeout watchdog
                #(WATCHDOG_TIMEOUT);
                $error("WATCHDOG: Write transaction timeout at %t", $time);
                assert_fail_count++;
                $finish;
            end
        join_any
        disable fork; // Kill the timeout if transaction completed
        
        test_case_count++;
        i2c_idle_cycles(10);
    endtask

    // Read multiple data bytes from a given address (with verification)   
    // Note: data_i_array is pre-initialized with expected data
    // The read bytes from the slave are stored in i2c_master.read_byte_array
    // and verified against data_i_array
    // Example usage: run_read_test(2) to read 2 bytes and verify
    // Modified run_read_test with watchdog timeout
    task run_read_test(int number_of_bytes=1);
        if (number_of_bytes < 1) number_of_bytes = 1;
        if (number_of_bytes > 4) number_of_bytes = 4;
        $display("I2C Master Testbench running read test with %0d bytes", number_of_bytes);
        
        data_i_array_reset = 1'b1;
        #(CLK_PERIOD*2);
        data_i_array_reset = 1'b0;
        #(CLK_PERIOD*2);
        
        // Run read transaction with watchdog
        fork
            begin
                // Normal operation
                i2c_master.read_data_bytes(number_of_bytes, SLAVE_ADDRESS);
            end
            begin
                // Timeout watchdog
                #(WATCHDOG_TIMEOUT);
                $error("WATCHDOG TIMEOUT: Read transaction timed out at %t", $time);
                assert_fail_count++;
                $finish;
            end
        join_any
        disable fork; // Kill the timeout thread if transaction completed
        
        test_case_count++;
        i2c_idle_cycles(10);
        
        // Verify read data
        for (int i=0; i<number_of_bytes; i++) begin
            assert (i2c_master.read_byte_array[i] == data_i_array[i]) begin
                assert_pass_count++;
                if (debugging_level_p >= 1) $display("  --> Read data match: 0x%0h", i2c_master.read_byte_array[i]);
            end
            else begin
                assert_fail_count++;
                $error("  --> Error: Read data mismatch: %t expected 0x%0h, got 0x%0h", 
                    $time, data_i_array[i], i2c_master.read_byte_array[i]);
            end
        end
    endtask

    // I2C master simulation tasks can be added here to drive scl_master and sda_master
    // Test sequence
    int num_bytes;
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
            for (int i=1; i<=4; i++) begin
                run_write_tests(i);
                i2c_idle_cycles(10);
            end   
        end

        if (run_write_tests_rand_p) begin
            $display("\n===== I2C Master Testbench randomized write tests");      
            for (int i=1; i<=`WRITE_TESTS_RAND_NUM; i++) begin
                randomize_data_write_array();
                num_bytes = $urandom_range(1,4);               
                run_write_tests(num_bytes);
                i2c_idle_cycles(10);
            end            
        end
        
        if (run_read_tests_p) begin           
            $display("\n===== I2C Master Testbench basic read tests");
            for (int i=1; i<=4; i++) begin
                run_read_test(i);
                i2c_idle_cycles(10);
            end   
        end  
        if (run_read_tests_rand_p) begin   
            $display("\n===== I2C Master Testbench randomized read tests");      
            for (int i=1; i<=`READ_TESTS_RAND_NUM; i++) begin
                randomize_data_i_array();
                num_bytes = $urandom_range(1,4);               
                run_read_test(num_bytes);
                i2c_idle_cycles(10);
            end            
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
    if (DUMP_ENABLE==1) begin
        $display("... generating dump file %s",dump_fname);
        $dumpfile(dump_fname);
        $dumpvars(0,testbench);
    end

endmodule   