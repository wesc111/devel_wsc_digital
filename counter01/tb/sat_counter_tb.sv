

/* verilator lint_off WIDTHEXPAND */

`define DUMP_ENABLE 1
`define DUMP_FNAME  "Vsat_counter_tb.vcd"

`timescale 1ns/1ps

module sat_counter_tb;

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------
    localparam int WIDTH = 8;

    // ------------------------------------------------------------
    // DUT Signals
    // ------------------------------------------------------------
    logic                   clk;
    logic                   rst_n;
    logic                   clear;
    logic                   enable;
    logic                   up_down_n;
    logic [2:0]             step_size;
    logic [WIDTH-1:0]       count_max;
    logic [WIDTH-1:0]       count;
    logic                   count_max_reached;
    logic                   count_zero_reached;

    // ------------------------------------------------------------
    // Reference model
    // ------------------------------------------------------------
    logic [WIDTH-1:0] ref_count;
    logic [WIDTH-1:0] step;

    assign step = step_size + 1'b1;

    // ------------------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------------------
    sat_counter #(
        .WIDTH(WIDTH)
    ) dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .clear             (clear),
        .enable            (enable),
        .up_down_n         (up_down_n),
        .step_size         (step_size),
        .count_max         (count_max),
        .count             (count),
        .count_max_reached (count_max_reached),
        .count_zero_reached(count_zero_reached)
    );

    // ------------------------------------------------------------
    // Clock generation: 100 MHz
    // ------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // Reference model update
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ref_count <= '0;
        end
        else if (clear) begin
            ref_count <= '0;
        end
        else if (enable) begin
            if (up_down_n) begin
                // Count UP (saturating)
                if (ref_count >= count_max)
                    ref_count <= count_max;
                else if (ref_count + step >= count_max)
                    ref_count <= count_max;
                else
                    ref_count <= ref_count + step;
            end
            else begin
                // Count DOWN (saturating)
                if (ref_count <= step)
                    ref_count <= '0;
                else
                    ref_count <= ref_count - step;
            end
        end
    end

    // ------------------------------------------------------------
    // Checker
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst_n) begin
            // Counter value check
            assert (count === ref_count)
                else begin
                    $error("COUNT MISMATCH @ %0t | DUT=%0d REF=%0d",
                            $time, count, ref_count);
                    $stop;
                end

            // Max flag check
            assert (count_max_reached == (count == count_max))
                else begin
                    $error("count_max_reached ERROR @ %0t", $time);
                    $stop;
                end

            // Zero flag check
            assert (count_zero_reached == (count == '0))
                else begin
                    $error("count_zero_reached ERROR @ %0t", $time);
                    $stop;
                end
        end
    end

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------
    initial begin
        $display("=== Saturating Counter Testbench Start ===");

        // Defaults
        enable     = 0;
        clear      = 0;
        up_down_n  = 1;
        step_size  = 3'd0;   // step = 1
        count_max  = 8'd20;
        rst_n      = 1;

        // -------------------------------
        // Async reset
        // -------------------------------
        #2  rst_n = 0;
        #15 rst_n = 1;

        // -------------------------------
        // Test 1: Count UP, step = 1
        // -------------------------------
        $display("Test 1: Count UP, step=1");
        enable    = 1;
        up_down_n = 1;
        repeat (25) @(posedge clk);

        // -------------------------------
        // Test 2: Clear priority
        // -------------------------------
        $display("Test 2: Clear priority");
        clear = 1;
        @(posedge clk);
        clear = 0;
        repeat (2) @(posedge clk);

        // -------------------------------
        // Test 3: Count UP, step = 4
        // -------------------------------
        $display("Test 3: Count UP, step=4");
        step_size = 3'd3; // step = 4
        repeat (10) @(posedge clk);

        // -------------------------------
        // Test 4: Count DOWN, step = 2
        // -------------------------------
        $display("Test 4: Count DOWN, step=2");
        up_down_n = 0;
        step_size = 3'd1; // step = 2
        repeat (15) @(posedge clk);

        // -------------------------------
        // Test 5: Enable gating
        // -------------------------------
        $display("Test 5: Enable gating");
        enable = 0;
        repeat (5) @(posedge clk);
        enable = 1;
        repeat (5) @(posedge clk);

        // -------------------------------
        // Test 6: Max step size (8)
        // -------------------------------
        $display("Test 6: Step size = 8");
        clear     = 1;
        @(posedge clk);
        clear     = 0;
        up_down_n = 1;
        step_size = 3'd7; // step = 8
        repeat (10) @(posedge clk);

        // -------------------------------
        // Done
        // -------------------------------
        $display("=== ALL TESTS PASSED (%t) ===", $time);
        $finish;
    end

    // Dump file generation
    initial
    if (`DUMP_ENABLE==1) begin
        $display("... generating dump file %s",`DUMP_FNAME);
        $dumpfile(`DUMP_FNAME);
        $dumpvars(0,sat_counter_tb);
    end

endmodule
