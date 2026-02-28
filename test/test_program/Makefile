# --- Target Program ---
PROG    ?= merge_sort
TESTNUM ?= 6

# --- Toolchain Definitions ---
PREFIX  = riscv64-unknown-elf-
CC      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump

# --- Compiler & Linker Flags ---
ARCH    = -march=rv32i -mabi=ilp32
CFLAGS  = $(ARCH) -ffreestanding -nostdlib -O2
LDFLAGS = -T link.ld

# --- Files ---
SRCS    = start.S $(PROG).c

# Normalized naming convention: test6.elf, test6.bin, etc.
ELF     = test$(TESTNUM).elf
BIN     = test$(TESTNUM).bin
DUMP    = test$(TESTNUM).dump

# --- Default Target ---
all: $(BIN) $(DUMP)

# 1. Compile C and Assembly into the ELF
$(ELF): $(SRCS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRCS) -o $(ELF)

# 2. Extract the raw binary for the Verilator testbench
$(BIN): $(ELF)
	$(OBJCOPY) -O binary $(ELF) $(BIN)

# 3. Generate a human-readable assembly dump
$(DUMP): $(ELF)
	$(OBJDUMP) -D $(ELF) > $(DUMP)

# --- Cleanup ---
clean:
	rm -f test*.elf test*.bin test*.dump

.PHONY: all clean