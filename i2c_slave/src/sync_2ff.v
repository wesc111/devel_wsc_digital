
// File: i2c_slave/src/sync_2ff.v
// sync_2ff.v
// 2-Flip-Flop Synchronizer Module
// This module synchronizes an asynchronous input signal to the local clock domain
// using a two-stage flip-flop approach to reduce metastability issues.
// Author: Werner Schoegler
// Date: 30-Nov-2025

`timescale 1ns / 1ps

module sync_2ff #(
    parameter RESET_VALUE = 1'b0
    ) (
    input logic clk,
    input logic rst_n,
    input logic in_ai,      // asynchronous input
    output logic out_o      // synchronized output
);
    logic ff1, ff2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ff1 <= RESET_VALUE;
            ff2 <= RESET_VALUE;
        end else begin
            ff1 <= in_ai;
            ff2 <= ff1;
        end
    end

    assign out_o = ff2;
endmodule
