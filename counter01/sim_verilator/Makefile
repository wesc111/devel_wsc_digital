
TOP_NAME := sat_counter_tb
SRC_DIR  := ../src/
TB_DIR   := ../tb/
DUMP_FILE := Vsat_counter_tb.vcd
GTKWFILE := default.gtkw

TB_FILES := $(shell find $(TB_DIR) -name '*.sv') $(shell find $(TB_DIR) -name '*.svh') $(shell find $(TB_DIR) -name '*.v')
SRC_FILES := $(shell find $(SRC_DIR) -name '*.sv') $(shell find $(SRC_DIR) -name '*.svh') $(shell find $(SRC_DIR) -name '*.v')

.PHONY: sim run clean debug wav

obj_dir/V$(TOP_NAME):
	verilator -cc -Wno-NULLPORT -Wno-COMBDLY -Wno-PINMISSING -Wno-MODDUP -exe --trace --trace-structs --build \
	--timing ../src/sim_main.cpp $(TB_FILES) $(SRC_FILES) -I$(SRC_DIR) -j `nproc`

sim: run
run: obj_dir/V$(TOP_NAME)
	./obj_dir/V$(TOP_NAME)

wav:
	gtkwave -f $(DUMP_FILE) $(GTKWFILE) &

clean:
	rm -rf obj_dir *.vcd

debug:
	@echo "SRC_FILE = $(SRC_FILE)"