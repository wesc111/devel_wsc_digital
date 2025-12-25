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

VER_VERSION = 2012
# VER_VERSION = 2009
IVER_OPTIONS = -I $(INCLUDE_DIR) -g$(VER_VERSION)

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

help:
	@echo "make [sim wav]"
	@echo "    make sim ... run icarus VERILOG simulation"
	@echo "    make wav ... run VERILOG simulation and start gtkwave waveform afterwards"

# 

run.vvp: $(SRC_FILES) $(TB_FILES)
	$(IVERILOG) $(IVER_OPTIONS) -o run.vvp $(SRC_FILES) $(TB_FILES)

sim: run.vvp
	$(VVP) run.vvp

wav: run.vvp
	$(VVP) run.vvp
	$(GTKWAVE) -f $(DUMPFILE) $(GTKWFILE) &

run:
	make sim
	make run

clean:
	rm -f run.vvp $(DUMPFILE)