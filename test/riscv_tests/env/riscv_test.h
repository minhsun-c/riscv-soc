// See LICENSE for license details.
//
// Bare-metal riscv-tests environment for this RV32I core.
//
// The upstream riscv-tests environments (env/p, env/v) assume a machine with
// CSRs, a trap vector and an `ecall`-based host interface. This core is a
// plain RV32I pipeline: it has no CSRs, no traps, and decodes SYSTEM opcodes
// as NOPs. This header therefore replaces the upstream environment with one
// that is expressible in pure RV32I.
//
// Completion is signalled by storing a result word to a magic MMIO address
// (RVTEST_TOHOST) instead of by `ecall`. test/tb_riscv_tests.cpp watches the
// data-memory write port for that address and ends the simulation.
//
// Result word encoding (the usual riscv-tests convention):
//   1                  -> pass
//   (TESTNUM << 1) | 1 -> fail in test case TESTNUM
//
// Because bit 0 is always set, a value of 1 unambiguously means "pass" and
// any other odd value carries the failing case number in its upper bits.

#ifndef RISCV_TEST_H
#define RISCV_TEST_H

//-----------------------------------------------------------------------
// Memory map
//
// Keep in sync with env/link.ld and test/tb_riscv_tests.cpp.
//-----------------------------------------------------------------------

#define RVTEST_RAM_BASE  0x00000000  // .text starts here; PC resets to 0
#define RVTEST_RAM_SIZE  0x00010000  // 64 KiB of unified instruction+data RAM
#define RVTEST_STACK_TOP 0x00010000  // top of RAM; the stack grows downward
#define RVTEST_TOHOST    0x00020000  // MMIO doorbell, deliberately outside RAM

//-----------------------------------------------------------------------
// TESTNUM
//
// test_macros.h stores the number of the running test case here so that a
// failure can report which case broke. x3/gp is the upstream choice; nothing
// in this environment uses gp for anything else.
//-----------------------------------------------------------------------

#define TESTNUM gp

//-----------------------------------------------------------------------
// ISA selectors
//
// Upstream these expand to CSR writes that enable the relevant extension.
// This core implements exactly RV32I and has no misa/mstatus to program, so
// they expand to nothing.
//-----------------------------------------------------------------------

#define RVTEST_RV32U
#define RVTEST_RV64U

//-----------------------------------------------------------------------
// Code section
//
// _start must be the very first thing in the image: the PC resets to 0 and
// the linker script places .text.init at address 0.
//
// Note the deliberate absence of a trap handler. Any instruction that would
// trap on a real machine (misaligned access, illegal instruction) instead
// executes as a NOP here, so tests that depend on trapping are excluded in
// tests.mk rather than handled at run time.
//-----------------------------------------------------------------------

#define RVTEST_CODE_BEGIN                                               \
        .section .text.init;                                            \
        .align 6;                                                       \
        .globl _start;                                                  \
_start:                                                                 \
        li sp, RVTEST_STACK_TOP;                                        \
        li TESTNUM, 0;

// Reached only if a test falls out of its body without hitting
// TEST_PASSFAIL. Spin so the testbench reports a timeout rather than
// running off into whatever follows in memory.
#define RVTEST_CODE_END                                                 \
90:     j 90b;

//-----------------------------------------------------------------------
// Pass / fail
//
// t0 and t1 are dead by the time either of these runs, so clobbering them
// is safe. TESTNUM must survive into RVTEST_FAIL, which is why the failing
// case number is shifted into t1 rather than computed in place.
//
// The local label numbers are chosen above those used by test_macros.h
// (1, 2, 3, 7, 8) so that the backward references cannot bind to a label
// emitted by the test body.
//-----------------------------------------------------------------------

#define RVTEST_PASS                                                     \
        li t0, RVTEST_TOHOST;                                           \
        li t1, 1;                                                       \
        sw t1, 0(t0);                                                   \
91:     j 91b;

#define RVTEST_FAIL                                                     \
        li t0, RVTEST_TOHOST;                                           \
        slli t1, TESTNUM, 1;                                            \
        ori t1, t1, 1;                                                  \
        sw t1, 0(t0);                                                   \
92:     j 92b;

//-----------------------------------------------------------------------
// Data section
//
// The signature symbols are not consumed by this harness (there is no
// reference model to diff against) but the test sources emit the markers,
// so they must exist.
//-----------------------------------------------------------------------

#define RVTEST_DATA_BEGIN                                               \
        .align 4;                                                       \
        .global begin_signature;                                        \
begin_signature:

#define RVTEST_DATA_END                                                 \
        .align 4;                                                       \
        .global end_signature;                                          \
end_signature:

#endif // RISCV_TEST_H
