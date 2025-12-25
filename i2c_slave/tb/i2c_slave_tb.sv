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

`define RUN_WRITE_TESTS
//`define RUN_READ_TESTS 

module testbench ();

    // Parameters
    parameter CLK_PERIOD = 10; // Clock period in ns
    logic DUMP_FLAG = `DUMP_FLAG;

    // I2C parameters
    parameter I2C_CLOCK_PERIOD = 100; // I2C clock period in ns
    parameter SLAVE_ADDRESS = 7'h21;  // Example slave address

    parameter STASTO_DELAY = 500;   // Delay for start/stop conditions
    parameter BIT_DELAY = 1000;     // Delay for each bit

    parameter int debugging_level = `DEBUG_LEVEL;

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
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
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
                if (debugging_level >= 1) $display("Assertion pass, data match %2d: 0x%0h", data_write_index, data_o);
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
`ifdef RUN_WRITE_TESTS
        $display("I2C Master Testbench write tests");
        i2c_master.write_data_bytes(1, SLAVE_ADDRESS, data_write_array[0]);
        test_case_count++;
        i2c_idle_cycles(10);
        i2c_master.write_data_bytes(2, SLAVE_ADDRESS, data_write_array[1], data_write_array[2]);
        test_case_count++;
        i2c_idle_cycles(10);
        i2c_master.write_data_bytes(3, SLAVE_ADDRESS, data_write_array[3], data_write_array[4], data_write_array[5]);
        test_case_count++;
        i2c_idle_cycles(10);
        i2c_master.write_data_bytes(4, SLAVE_ADDRESS, data_write_array[6], data_write_array[7], data_write_array[8], data_write_array[9]);
        test_case_count++;
        i2c_idle_cycles(10);
        i2c_master.write_data_bytes(4, SLAVE_ADDRESS, data_write_array[10], data_write_array[11], data_write_array[12], data_write_array[13]);
        test_case_count++;
        i2c_idle_cycles(10);
        i2c_master.write_data_bytes(2, SLAVE_ADDRESS, data_write_array[14], data_write_array[15]);
        test_case_count++;
        i2c_idle_cycles(40);
`endif

`ifdef RUN_READ_TESTS
        $display("I2C Master Testbench read tests");
        i2c_master.read_data_bytes(1, SLAVE_ADDRESS);
        assert (i2c_master.read_byte_array[0] == data_i_array[0]) begin
            assert_pass_count++;
            if (debugging_level >= 1) $display("Read data match: 0x%0h", i2c_master.read_byte_array[0]);
        end
        else begin
            assert_fail_count++;
            $error("Read data mismatch: expected 0x%0h, got 0x%0h", data_i_array[0], i2c_master.read_byte_array[0]);
        end
        test_case_count++;
        i2c_idle_cycles(10);
        i2c_master.read_data_bytes(2, SLAVE_ADDRESS);
        assert (i2c_master.read_byte_array[0] == data_i_array[0]) begin
            assert_pass_count++;
            if (debugging_level >= 1) $display("Read data match: 0x%0h", i2c_master.read_byte_array[0]);
        end
        else begin
            assert_fail_count++;
            $error("Read data mismatch: expected 0x%0h, got 0x%0h", data_i_array[0], i2c_master.read_byte_array[0]);
        end
        assert (i2c_master.read_byte_array[1] == data_i_array[1]) begin
            assert_pass_count++;
            if (debugging_level >= 1) $display("Read data match: 0x%0h", i2c_master.read_byte_array[1]);
        end
        else begin
            assert_fail_count++;
            $error("Read data mismatch: expected 0x%0h, got 0x%0h", data_i_array[1], i2c_master.read_byte_array[1]);
        end
        test_case_count++;
        i2c_idle_cycles(10);
        test_case_count++;
        i2c_idle_cycles(10);
`endif

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