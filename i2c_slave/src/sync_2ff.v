
// File: i2c_slave/src/sync_2ff.v
// sync_2ff.v
// 2-Flip-Flop Synchronizer Module
// This module synchronizes an asynchronous input signal to the local clock domain
// using a two-stage flip-flop approach to reduce metastability issues.

module sync_2ff (
    input logic clk,
    input logic rst_n,
    input logic in_ai,
    output logic out_o
);
    logic ff1, ff2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin
            ff1 <= in_ai;
            ff2 <= ff1;
        end
    end

    assign out_o = ff2;
endmodule
