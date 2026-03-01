# --- Project Settings ---
VERILATOR = verilator
RTL_DIR   = src/core
INC_DIR   = src/include
TEST_DIR  = test
OBJ_DIR   = obj_dir
SW_DIR    = $(TEST_DIR)/test_program

# --- Dynamic Core Test Selection ---
TESTNUM ?= 1

# Automatically map TESTNUM to the correct C source for software tests
ifeq ($(TESTNUM), 6)
    PROG_NAME = merge_sort
else ifeq ($(TESTNUM), 7)
    PROG_NAME = linked_list
else ifeq ($(TESTNUM), 8)
    PROG_NAME = josephus
else
    PROG_NAME = unknown
endif

# --- Compilation Flags ---
VFLAGS = -Wall --trace --cc --assert \
         -I$(INC_DIR) \
         -CFLAGS -DTESTNUM=$(TESTNUM) \
         --exe --build -j 0

# --- Dependencies ---
CPU_DEPS  = $(wildcard $(RTL_DIR)/*.v)
CORE_DEPS = $(wildcard $(RTL_DIR)/*.v)
IF_DEPS   = $(RTL_DIR)/if_stage.v  $(RTL_DIR)/pc.v   $(RTL_DIR)/mux2.v
ID_DEPS   = $(RTL_DIR)/id_stage.v  $(RTL_DIR)/ctrl.v $(RTL_DIR)/decoder.v $(RTL_DIR)/imm_gen.v
EX_DEPS   = $(RTL_DIR)/ex_stage.v  $(RTL_DIR)/alu.v  $(RTL_DIR)/bcu.v     $(RTL_DIR)/mux2.v
WB_DEPS   = $(RTL_DIR)/wb_stage.v  $(RTL_DIR)/mux2.v

# --- Standard Targets ---
.PHONY: all clean help style sw_build

help:
	@echo "Usage:"
	@echo "  make core TESTNUM=X  (Run full core simulation)"
	@echo "  make clean           (Clean hardware & software artifacts)"

# Integrated Core Target
cpu: $(CPU_DEPS) $(TEST_DIR)/tb_cpu.cpp
# Only trigger the software Makefile for Test 6 and above
ifeq ($(shell expr $(TESTNUM) \>= 6), 1)
	@echo "--- Building Software: $(PROG_NAME) (test$(TESTNUM).bin) ---"
	@$(MAKE) -C $(SW_DIR) PROG=$(PROG_NAME) TESTNUM=$(TESTNUM)
endif
	@$(MAKE) build_sim MODULE=cpu SRCS="$^"

# Integrated Core Target
core: $(CORE_DEPS) $(TEST_DIR)/tb_core.cpp
# Only trigger the software Makefile for Test 6 and above
ifeq ($(shell expr $(TESTNUM) \>= 6), 1)
	@echo "--- Building Software: $(PROG_NAME) (test$(TESTNUM).bin) ---"
	@$(MAKE) -C $(SW_DIR) PROG=$(PROG_NAME) TESTNUM=$(TESTNUM)
endif
	@$(MAKE) build_sim MODULE=core SRCS="$^"

# Module-specific targets
if_stage: $(IF_DEPS) $(TEST_DIR)/tb_if_stage.cpp
	@$(MAKE) build_sim MODULE=if_stage SRCS="$^"

id_stage: $(ID_DEPS) $(TEST_DIR)/tb_id_stage.cpp
	@$(MAKE) build_sim MODULE=id_stage SRCS="$^"

ex_stage: $(EX_DEPS) $(TEST_DIR)/tb_ex_stage.cpp
	@$(MAKE) build_sim MODULE=ex_stage SRCS="$^"

wb_stage: $(WB_DEPS) $(TEST_DIR)/tb_wb_stage.cpp
	@$(MAKE) build_sim MODULE=wb_stage SRCS="$^"

%: $(RTL_DIR)/%.v $(TEST_DIR)/tb_%.cpp
	@$(MAKE) build_sim MODULE=$* SRCS="$^"

# Internal helper to build and run any simulation
build_sim:
	@rm -rf $(OBJ_DIR)_$(MODULE)
	@echo "--- Building: $(MODULE) ---"
	@mkdir -p $(OBJ_DIR)_$(MODULE)
	$(VERILATOR) $(VFLAGS) \
		--top-module $(MODULE) \
		$(SRCS) \
		--Mdir $(OBJ_DIR)_$(MODULE) \
		-o V$(MODULE)
	@echo "--- Running: $(MODULE) ---"
	./$(OBJ_DIR)_$(MODULE)/V$(MODULE)

# --- Master Clean ---
clean:
	rm -rf obj_dir* *.vcd
	@$(MAKE) -C $(SW_DIR) clean
	@echo "Hardware and Software artifacts cleaned."

# Check if tools exist
CLANG_FORMAT := $(shell command -v clang-format 2> /dev/null)
VERIBLE_FORMAT := $(shell command -v verible-verilog-format 2> /dev/null)

# Styling
style:
	@echo "--- Checking and Formatting Code ---"
ifdef CLANG_FORMAT
	$(CLANG_FORMAT) -i $(TEST_DIR)/*.cpp $(TEST_DIR)/*.h $(TEST_DIR)/cpu_test/*.h $(TEST_DIR)/core_test/*.h $(SW_DIR)/*.c
	@echo "C++ formatting complete."
else
	@echo "Hint: clang-format not found. Skip C++ styling. (sudo apt install clang-format)"
endif

ifdef VERIBLE_FORMAT
	$(VERIBLE_FORMAT) --inplace $(RTL_DIR)/*.v
	@echo "Verilog formatting complete."
else
	@echo "Hint: verible-verilog-format not found. Skip Verilog styling."
	@echo "To install verible: "
	@echo "1. Go to https://github.com/chipsalliance/verible/releases"
	@echo "2. Download verible-vX.X.X-linux-static-x86_64.tar.gz"
	@echo "3. Extract and add the 'bin' folder to your PATH."
endif