# devel_wsc_digital readme

This is my repository for some digital design examples. It is basically just started, the first block I did is a i2c slave.
- Author: Werner Schoegler
- Published 

These examples are:
- i2c_slave:
  - RTL implementation of an I2C slave block.
  - Included is a simple functional testbench with master functionality, testing simple and randomized read/write cylce of 1 to 4 bytes.
  - Simulation setup for iverilog included
 
Planned future blocks are:
- uart
- spi
- counter (basically acting as "hello world" example)
- lfsr (linear feedback shift register)
