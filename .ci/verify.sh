#!/bin/bash

TARGETS=(
  mux2 pc sram decoder ctrl regfile imm_gen 
  alu bcu hdu if_id id_ex ex_mem mem_wb
  if_stage id_stage ex_stage wb_stage
  core-1 core-2 core-3 core-4 core-5 core-6 core-7 core-8
  cpu-1 cpu-2 cpu-3 cpu-4 cpu-5 cpu-6 cpu-7 cpu-8
)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Starting Local SoC Component Verification..."

if ! command -v verilator &> /dev/null || ! command -v riscv64-unknown-elf-gcc &> /dev/null; then
    echo -e "${RED}Error: Verilator or RISC-V Toolchain not found.${NC}"
    echo "Please run: sudo apt-get install verilator gcc-riscv64-unknown-elf"
    exit 1
fi

FAILED_TESTS=()

for target in "${TARGETS[@]}"; do
    echo "----------------------------------------------------"
    echo "Testing: $target"
    
    # Logic to split target name (matches your GH Action 'Set Simulation Variables' step)
    if [[ "$target" =~ ^(core|cpu)-([0-9]+)$ ]]; then
        MODULE="${BASH_REMATCH[1]}"
        TESTNUM="${BASH_REMATCH[2]}"
    else
        MODULE="$target"
        TESTNUM="1"
    fi

    make "$MODULE" TESTNUM="$TESTNUM" > output.log 2>&1
    RESULT=$?

    if [ $RESULT -ne 0 ] || grep -q "STATUS: FAILED" output.log; then
        echo -e "${RED}[FAILED]${NC} $target"
        FAILED_TESTS+=("$target")
    elif ! grep -q "STATUS: ALL PASSED" output.log; then
        echo -e "${RED}[INCOMPLETE]${NC} $target (No 'ALL PASSED' summary found)"
        FAILED_TESTS+=("$target")
    else
        echo -e "${GREEN}[PASSED]${NC} $target"
    fi
done

echo "----------------------------------------------------"
if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: All components passed!${NC}"
    rm output.log
    exit 0
else
    echo -e "${RED}FAILURE: The following targets failed:${NC}"
    for ft in "${FAILED_TESTS[@]}"; do
        echo " - $ft"
    done
    exit 1
fi