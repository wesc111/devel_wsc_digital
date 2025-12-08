#-------------------------------------------------------------
#
# Makefile for VERILOG simulation with iverilog
#
# WSG, V0.0 1.2020
#      V0.1 9.2021 modified to run under MAC OS X
#      V0.2 10.2025 updated for i2c_slave project
#-------------------------------------------------------------

# define variables
CUR_LIB = work
INCLUDE_DIR = ../src
SRC_DIR = ../src
TB_DIR = ../tb

SRC_FILES = $(SRC_DIR)/sync_2ff.v $(SRC_DIR)/i2c_slave.v
TB_FILES =  $(TB_DIR)/i2c_master.sv $(TB_DIR)/i2c_slave_tb.sv

DUMPFILE = i2c_slave_tb.vcd
GTKWFILE = default.gtkw

IVER_OPTIONS = -I $(INCLUDE_DIR) -g2012 

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

help:
	@echo "make [sim wav]"
	@echo "    make sim ... start icarus VERILOG simulation"
	@echo "    make wav ... start gtkwave waveform viewer"

# 
sim:
	$(IVERILOG) $(IVER_OPTIONS) -o run.vvp $(TB_FILES) $(SRC_FILES)
	$(VVP) run.vvp

wav:
	$(GTKWAVE) -f $(DUMPFILE) $(GTKWFILE) &

clean:
	rm -f run.vvp $(DUMPFILE)