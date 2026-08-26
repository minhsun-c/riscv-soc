# Build the riscv-tests rv32ui suite for this core.
#
# Each test is assembled against the bare-metal environment in env/ (see
# env/riscv_test.h for why the upstream env/p environment cannot be used) and
# emitted as a flat binary image that test/tb_riscv_tests.cpp loads at
# address 0.
#
# Usage (normally driven by `make riscv-tests` at the repo root):
#   make            build every test in tests.mk
#   make list       print the test names
#   make submodule  fetch the vendored suite if it is missing
#   make clean      remove build/

RISCV_PREFIX ?= riscv64-unknown-elf-
CC      := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump

VENDOR    := vendor/riscv-tests
ISA_DIR   := $(VENDOR)/isa
ENV_DIR   := env
BUILD_DIR := build

# Path of the submodule relative to the repo root, for `git submodule`.
SUBMODULE_PATH := test/riscv_tests/vendor/riscv-tests

include tests.mk

ARCH    := -march=rv32i -mabi=ilp32
CFLAGS  := $(ARCH) -static -nostdlib -nostartfiles -fno-builtin \
           -I$(ENV_DIR) -I$(ISA_DIR)/macros/scalar
# The image is one flat RWX blob loaded at address 0; there is no MMU to
# police section permissions, so the linker's RWX warning is just noise.
LDFLAGS := -T $(ENV_DIR)/link.ld -Wl,--no-warn-rwx-segments

ENV_DEPS := $(ENV_DIR)/riscv_test.h $(ENV_DIR)/link.ld

ELFS  := $(patsubst %,$(BUILD_DIR)/rv32ui-p-%.elf,$(RV32UI_TESTS))
BINS  := $(ELFS:.elf=.bin)
DUMPS := $(ELFS:.elf=.dump)

.PHONY: all list submodule clean
# Keep the ELFs: they feed the .dump rule and are what you disassemble when
# a test fails. Without this make deletes them as intermediates.
.SECONDARY: $(ELFS)

all: $(BINS) $(DUMPS)

# The vendored suite is a git submodule. The repo-root `riscv-tests` target
# invokes this as a separate `make` before the build proper, so that the
# pattern rules below are matched against an already-populated tree.
submodule:
	@if [ ! -f $(ISA_DIR)/rv32ui/add.S ]; then \
		echo "--- riscv-tests submodule missing, fetching ---"; \
		git -C ../.. submodule update --init $(SUBMODULE_PATH); \
	fi

$(BUILD_DIR):
	@mkdir -p $@

$(BUILD_DIR)/rv32ui-p-%.elf: $(ISA_DIR)/rv32ui/%.S $(ENV_DEPS) | $(BUILD_DIR)
	@$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@

# Flat image loaded at address 0 by the testbench.
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf
	@$(OBJCOPY) -O binary $< $@

# Kept alongside each test purely as a debugging aid.
$(BUILD_DIR)/%.dump: $(BUILD_DIR)/%.elf
	@$(OBJDUMP) -D $< > $@

list:
	@echo $(RV32UI_TESTS)

clean:
	@rm -rf $(BUILD_DIR)
