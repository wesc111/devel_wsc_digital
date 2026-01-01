#
# Makefile for VERILOG simulation with iverilog
#
# Werner Schoegler
# Date: 29-Dec-2025 Release Version 1.0
#

# define variables
CUR_LIB = work
INCLUDE_DIR = ../src
SRC_DIR = ../src
TB_DIR = ../tb

SRC_FILES = $(SRC_DIR)/sat_counter.sv
TB_FILES =  $(TB_DIR)/sat_counter_tb.sv

DUMPFILE = sat_counter_tb.vcd
GTKWFILE = default.gtkw

VER_VERSION = 2012
# VER_VERSION = 2009
IVER_OPTIONS = -I $(INCLUDE_DIR) -g$(VER_VERSION)

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

.PHONY: help sim wav run clean

help:
	@echo "make [sim wav]"
	@echo "    make sim ... run icarus VERILOG simulation"
	@echo "    make wav ... run VERILOG simulation and start gtkwave waveform afterwards"

run.vvp: $(SRC_FILES) $(TB_FILES)
	$(IVERILOG) $(IVER_OPTIONS) -o run.vvp $(SRC_FILES) $(TB_FILES)

sim: run.vvp
	$(VVP) run.vvp

wav:
	$(GTKWAVE) -f $(DUMPFILE) $(GTKWFILE) &

run:
	make sim
	make run

clean:
	rm -f run.vvp $(DUMPFILE)