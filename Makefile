# --- Project Settings ---
VERILATOR = verilator
SRC_DIR   = src
INC_DIR   = src/include
# RTL 分四區：管線、互連、記憶體階層、週邊。頂層 cpu.sv 直接放在 src/ 下。
CORE_DIR  = src/core
BUS_DIR   = src/bus
MEM_DIR   = src/mem
PERI_DIR  = src/peri
RTL_DIRS  = $(SRC_DIR) $(CORE_DIR) $(BUS_DIR) $(MEM_DIR) $(PERI_DIR)
TEST_DIR  = test
OBJ_DIR   = obj_dir
SW_DIR    = $(TEST_DIR)/test_program
RVT_DIR   = $(TEST_DIR)/riscv_tests

# --- Dynamic Core Test Selection ---
TESTNUM ?= 1

# Which tests are C programs that have to be compiled first. The rest are
# hand-written machine code inside the test header, and must not trigger a
# software build -- there is no .c file for them.
SW_TESTS = 6 7 8
IS_SW    = $(filter $(TESTNUM),$(SW_TESTS))

ifeq ($(TESTNUM), 6)
    PROG_NAME = merge_sort
else ifeq ($(TESTNUM), 7)
    PROG_NAME = linked_list
else ifeq ($(TESTNUM), 8)
    PROG_NAME = josephus
else
    PROG_NAME = unknown
endif

# --- 波形格式 ---
# 預設 VCD：文字格式，什麼檢視器都讀得動，也可以直接打開來看內容。
# 整機波形（core / cpu）動輒數 MB，這時改用 make core TRACE=fst ——
# 訊號內容與 VCD 完全一樣，檔案小一個數量級，代價是只有 GTKWave 與
# Surfer 讀得動。詳見 test/vcd.h。
TRACE ?= vcd
ifeq ($(TRACE),fst)
    TRACE_FLAGS = --trace-fst -CFLAGS -DTRACE_FST
else ifeq ($(TRACE),vcd)
    TRACE_FLAGS = --trace
else
    $(error TRACE 只能是 vcd 或 fst，收到 "$(TRACE)")
endif

# --- Compilation Flags ---
VFLAGS = -Wall $(TRACE_FLAGS) --cc --assert \
         -I$(INC_DIR) \
         -CFLAGS -DTESTNUM=$(TESTNUM) \
         --exe --build -j 0

# --- Dependencies ---
# 常數放在 src/include/*_pkg.sv 的 package 裡，模組用 import 取用。
# package 必須排在使用它的模組前面編譯，所以每一組來源都以 PKG_SRCS 開頭。
PKG_SRCS  = $(wildcard $(INC_DIR)/*_pkg.sv)
RTL_SRCS  = $(PKG_SRCS) $(foreach d,$(RTL_DIRS),$(wildcard $(d)/*.sv))
CPU_DEPS  = $(RTL_SRCS)
CORE_DEPS = $(RTL_SRCS)
IF_DEPS   = $(PKG_SRCS) $(CORE_DIR)/if_stage.sv $(CORE_DIR)/pc.sv   $(CORE_DIR)/mux2.sv
ID_DEPS   = $(PKG_SRCS) $(CORE_DIR)/id_stage.sv $(CORE_DIR)/ctrl.sv $(CORE_DIR)/decoder.sv $(CORE_DIR)/imm_gen.sv
EX_DEPS   = $(PKG_SRCS) $(CORE_DIR)/ex_stage.sv $(CORE_DIR)/alu.sv  $(CORE_DIR)/bcu.sv     $(CORE_DIR)/mux2.sv
WB_DEPS   = $(PKG_SRCS) $(CORE_DIR)/wb_stage.sv $(CORE_DIR)/mux2.sv

# --- Standard Targets ---
.PHONY: all clean help style sw_build riscv-tests

help:
	@echo "Usage:"
	@echo "  make core TESTNUM=X  (Run full core simulation)"
	@echo "  make <target> TRACE=fst  (Write FST instead of VCD -- much smaller)"
	@echo "  make riscv-tests     (Run the riscv-tests rv32ui suite)"
	@echo "  make clean           (Clean hardware & software artifacts)"

# Integrated Core Target
cpu: $(CPU_DEPS) $(TEST_DIR)/tb_cpu.cpp
# Only trigger the software Makefile for Test 6 and above
ifneq ($(IS_SW),)
	@echo "--- Building Software: $(PROG_NAME) (test$(TESTNUM).bin) ---"
	@$(MAKE) -C $(SW_DIR) PROG=$(PROG_NAME) TESTNUM=$(TESTNUM)
endif
	@$(MAKE) build_sim MODULE=cpu SRCS="$^"

# Integrated Core Target
core: $(CORE_DEPS) $(TEST_DIR)/tb_core.cpp
# Only trigger the software Makefile for Test 6 and above
ifneq ($(IS_SW),)
	@echo "--- Building Software: $(PROG_NAME) (test$(TESTNUM).bin) ---"
	@$(MAKE) -C $(SW_DIR) PROG=$(PROG_NAME) TESTNUM=$(TESTNUM)
endif
	@$(MAKE) build_sim MODULE=core SRCS="$^"

# --- riscv-tests (rv32ui) ---
# Builds the vendored test images and a dedicated simulator, then runs every
# image. See $(RVT_DIR)/README.md for how the bare-metal environment works.
RVT_SIM = $(OBJ_DIR)_riscv_tests/Vriscv_tests

riscv-tests: $(CORE_DEPS) $(TEST_DIR)/tb_riscv_tests.cpp
	@$(MAKE) -C $(RVT_DIR) submodule
	@echo "--- Building riscv-tests images ---"
	@$(MAKE) -C $(RVT_DIR)
	@$(MAKE) build_sim_only MODULE=riscv_tests TOP=core SRCS="$^"
	@$(RVT_DIR)/run_tests.sh $(RVT_SIM) $(RVT_DIR)/build

# Module-specific targets
if_stage: $(IF_DEPS) $(TEST_DIR)/tb_if_stage.cpp
	@$(MAKE) build_sim MODULE=if_stage SRCS="$^"

id_stage: $(ID_DEPS) $(TEST_DIR)/tb_id_stage.cpp
	@$(MAKE) build_sim MODULE=id_stage SRCS="$^"

ex_stage: $(EX_DEPS) $(TEST_DIR)/tb_ex_stage.cpp
	@$(MAKE) build_sim MODULE=ex_stage SRCS="$^"

wb_stage: $(WB_DEPS) $(TEST_DIR)/tb_wb_stage.cpp
	@$(MAKE) build_sim MODULE=wb_stage SRCS="$^"

# 一區一條規則。Make 會挑前提條件實際存在的那一條，所以 make alu 找到
# src/core/alu.sv、make axil_uart 找到 src/peri/axil_uart.sv，呼叫端不必知道
# 模組住在哪一區。用 vpath 一條解決也可以，但 match-anything 規則在 make 裡
# 的行為比較難預測，四條明寫的划算。
%: $(PKG_SRCS) $(CORE_DIR)/%.sv $(TEST_DIR)/tb_%.cpp
	@$(MAKE) build_sim MODULE=$* SRCS="$^"

%: $(PKG_SRCS) $(BUS_DIR)/%.sv $(TEST_DIR)/tb_%.cpp
	@$(MAKE) build_sim MODULE=$* SRCS="$^"

%: $(PKG_SRCS) $(MEM_DIR)/%.sv $(TEST_DIR)/tb_%.cpp
	@$(MAKE) build_sim MODULE=$* SRCS="$^"

%: $(PKG_SRCS) $(PERI_DIR)/%.sv $(TEST_DIR)/tb_%.cpp
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

# Internal helper to build a simulation without running it. Used by targets
# whose binary takes arguments and therefore cannot be launched bare.
build_sim_only:
	@rm -rf $(OBJ_DIR)_$(MODULE)
	@echo "--- Building: $(MODULE) ---"
	@mkdir -p $(OBJ_DIR)_$(MODULE)
	@$(VERILATOR) $(VFLAGS) \
		--top-module $(TOP) \
		$(SRCS) \
		--Mdir $(OBJ_DIR)_$(MODULE) \
		-o V$(MODULE)

# --- Master Clean ---
clean:
	rm -rf obj_dir* *.vcd *.fst
	@$(MAKE) -C $(SW_DIR) clean
	@$(MAKE) -C $(RVT_DIR) clean
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
	$(VERIBLE_FORMAT) --inplace $(RTL_SRCS)
	@echo "Verilog formatting complete."
else
	@echo "Hint: verible-verilog-format not found. Skip Verilog styling."
	@echo "To install verible: "
	@echo "1. Go to https://github.com/chipsalliance/verible/releases"
	@echo "2. Download verible-vX.X.X-linux-static-x86_64.tar.gz"
	@echo "3. Extract and add the 'bin' folder to your PATH."
endif