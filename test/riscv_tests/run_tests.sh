#!/usr/bin/env bash
#
# Run every built rv32ui image against the core and print a summary.
#
# Normally invoked by `make riscv-tests` from the repo root, which builds both
# the simulator and the test images first.
#
# Usage: run_tests.sh [simulator] [image-dir]

set -u

SIM=${1:-obj_dir_riscv_tests/Vriscv_tests}
IMG_DIR=${2:-test/riscv_tests/build}

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -x "$SIM" ]; then
    echo -e "${RED}Error: simulator '$SIM' not found.${NC}" >&2
    echo "Run 'make riscv-tests' from the repository root." >&2
    exit 2
fi

shopt -s nullglob
IMAGES=("$IMG_DIR"/rv32ui-p-*.bin)
if [ ${#IMAGES[@]} -eq 0 ]; then
    echo -e "${RED}Error: no test images in '$IMG_DIR'.${NC}" >&2
    echo "Run 'make -C test/riscv_tests' to build them." >&2
    exit 2
fi

echo "--- Running riscv-tests rv32ui suite (${#IMAGES[@]} tests) ---"

PASSED=0
FAILED_TESTS=()

for img in "${IMAGES[@]}"; do
    name=$(basename "$img" .bin)
    # The testbench prints its own PASS/FAIL line and exits non-zero on
    # failure; capture the diagnostics so a failure shows its register dump.
    if out=$("$SIM" "$img" 2>&1); then
        printf "${GREEN}[PASSED]${NC} %s\n" "$name"
        PASSED=$((PASSED + 1))
    else
        printf "${RED}[FAILED]${NC} %s\n" "$name"
        echo "$out" | sed 's/^/          /'
        FAILED_TESTS+=("$name")
    fi
done

TOTAL=${#IMAGES[@]}

echo
echo -e "${BLUE}--- Test Report Summary ---${NC}"
echo -e "Passed: ${GREEN}${PASSED}${NC} / ${TOTAL}"

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo -e "${GREEN}STATUS: ALL PASSED${NC}"
    echo
    exit 0
fi

echo -e "${RED}STATUS: FAILED (${#FAILED_TESTS[@]} errors)${NC}"
for t in "${FAILED_TESTS[@]}"; do
    echo " - $t"
done
echo
exit 1
