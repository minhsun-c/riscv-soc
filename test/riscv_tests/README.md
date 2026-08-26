# riscv-tests (rv32ui) for this core

Runs the official [riscv-tests](https://github.com/riscv-software-src/riscv-tests)
`rv32ui` suite against `src/core/core.v`.

```sh
make riscv-tests        # from the repository root
```

The submodule is fetched automatically on first run, so a fresh clone does
not need `git clone --recursive`.

## Why not the upstream environment

Upstream ships two environments, `env/p` (physical) and `env/v` (virtual).
Both assume a machine with CSRs, a trap vector and an `ecall`-based host
interface:

```asm
RVTEST_PASS:  li a0, 1; ecall          # needs a trap handler
RVTEST_CODE_BEGIN: csrw mtvec, t0      # needs CSRs
```

This core is a plain RV32I pipeline. It has no CSRs, no traps, and decodes
SYSTEM opcodes as NOPs via the `default` case in `src/core/ctrl.v` — so an
`ecall` would silently do nothing and the test would hang.

`env/riscv_test.h` therefore replaces the upstream environment with one
expressible in pure RV32I. A test signals completion by **storing a word to a
magic MMIO address** instead of trapping:

| Value written to `0x00020000` | Meaning |
| --- | --- |
| `1` | pass |
| `(TESTNUM << 1) \| 1` | failed in case `TESTNUM` |

`test/tb_riscv_tests.cpp` watches the data write port for that address and
ends the simulation. Bit 0 is always set, so `1` unambiguously means pass and
any other odd value carries the failing case number in its upper bits.

## Memory map

One flat RAM serves both ports, because the images place `.data` immediately
after `.text` in a single address space. The core has no cache and never
writes to its own instruction stream, so a single backing array is enough.

| Range | Use |
| --- | --- |
| `0x00000000`–`0x0000FFFF` | 64 KiB unified RAM; `.text` at 0, `.data` after |
| `0x00010000` | initial `sp`, stack grows down into RAM |
| `0x00020000` | `tohost` MMIO doorbell, deliberately outside RAM |

`env/link.ld` places `.text.init` at address 0 because the PC resets to 0.
These three files must be kept in sync: `env/riscv_test.h`, `env/link.ld`,
and `test/tb_riscv_tests.cpp`.

Loads are sign/zero-extended by the **memory**, not the core — `wb_stage`
forwards whatever the data port returns — so `dm_read()` in the testbench
mirrors `src/core/sram.v` exactly, including its handling of the low address
bits.

## Excluded tests

40 of the 42 upstream `rv32ui` tests run. Two are excluded in `tests.mk`:

| Test | Reason |
| --- | --- |
| `fence_i` | Needs Zifencei. The test rewrites its own instruction stream and executes `FENCE.I` to make the change visible. This core has no `FENCE.I`, and the test does not even assemble for plain `rv32i`. |
| `ma_data` | Needs misaligned load/store support. `src/core/sram.v` ignores the low address bits for word accesses, and there is no trap mechanism to emulate the access in software — so neither behaviour the spec permits (handle it, or trap) is available. |

Both are genuine hardware gaps, not harness limitations. Implementing
Zifencei or a misalignment trap would let them move into the active list.

## Layout

```
test/riscv_tests/
├── env/riscv_test.h    bare-metal environment (replaces upstream env/p)
├── env/link.ld         .text at 0x0
├── tests.mk            test list + exclusion rationale
├── Makefile            builds build/rv32ui-p-*.{elf,bin,dump}
├── run_tests.sh        runs every image, prints the summary
└── vendor/riscv-tests  upstream suite (git submodule, pinned)
test/tb_riscv_tests.cpp Verilator testbench
```

## Debugging a failure

Each test also builds a `.dump` disassembly next to its image. The testbench
reports the failing case number and dumps the register file; cross-reference
the case number against the `TEST_*` macro invocations in the upstream source
(`vendor/riscv-tests/isa/rv64ui/<name>.S` — the `rv32ui` files are thin
wrappers around them).

To capture a waveform for one test:

```sh
./obj_dir_riscv_tests/Vriscv_tests \
    test/riscv_tests/build/rv32ui-p-add.bin --trace add.vcd
```
