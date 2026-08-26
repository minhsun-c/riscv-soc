#include <verilated.h>
#include <iostream>
#include <vector>
#include "Vcore.h"
#include "Vcore_core.h"
#include "Vcore_regfile.h"
#include "Vcore___024root.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

// Simple Memory Emulation (4KB each)
uint32_t imem[1024];
uint32_t dmem[1024];

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

#ifdef TESTNUM
/* clang-format off */
#define HEADER_NAME(x) core_test/test##x.h
#define TO_HEADER(x) TOSTRING(HEADER_NAME(x))
#include TO_HEADER(TESTNUM)
/* clang-format on */
#else
#error "TESTNUM not defined!"
#endif

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vcore *dut = new Vcore;

    // Dynamically name the waveform file based on the test
    char vcd_name[32];
    snprintf(vcd_name, 32, "core.vcd");
    init_vcd(dut, vcd_name);

// Only the C-program tests load an external binary; the rest build their
// instruction memory inside the test header.
#if TESTNUM >= 6 && TESTNUM <= 8
    /* clang-format off */
#define BIN_NAME(x) test/test_program/test##x.bin
#define TO_BIN(x) TOSTRING(BIN_NAME(x))
    load_program(TO_BIN(TESTNUM));
/* clang-format on */
#else
    load_program();
#endif

    dut->rst_i = 1;
    tick(dut);
    dut->rst_i = 0;

    printf("--- Starting Core Pipeline Simulation (TESTNUM=%d) ---\n", TESTNUM);

    // Performance counters. Everything here is derived from signals the core
    // already has -- no counters were added to the hardware.
    uint64_t stall_cycles = 0;   // load-use stalls
    uint64_t instret = 0;        // an instruction enters EX whenever flush_id_ex is low
    uint64_t branches = 0;       // control-flow instructions resolved in EX
    uint64_t mispredicts = 0;    // ... of which the guess was wrong
    uint64_t run_cycles = 0;     // cycles until the program stops advancing

    // These programs finish by spinning on `j .`. Watching for the PC to stop
    // moving does not work: without prediction the spin still fetches pc+4 and
    // gets redirected back every cycle, so the PC oscillates forever. What is
    // unambiguous either way is a jump whose target is itself.
    bool done = false;

    // The spin loop is itself a jump that always predicts correctly, so letting
    // it run would quietly inflate the hit rate. Snapshot the counters on every
    // cycle where the PC is still moving, and report the snapshot.
    uint64_t f_cycles = 0, f_instret = 0, f_stalls = 0, f_branches = 0, f_mis = 0;

    for (int i = 0; i < 8000; i++) {
        uint32_t pc_idx = (dut->im_addr_o & 0xFFF) >> 2;
        dut->im_data_i = imem[pc_idx];

        uint32_t data_idx = (dut->dm_addr_o & 0xFFF) >> 2;
        if (dut->dm_we_o) {
            dmem[data_idx] = dut->dm_wdata_o;
        }
        dut->data_rdata_i = dmem[data_idx];

        if (!done) {
            if (dut->rootp->core->cf_resolved && dut->rootp->core->ex_jb_taken
                && dut->rootp->core->ex_jb_target == dut->rootp->core->ex_pc) {
                done = true;  // the spin loop committed: everything after is idling
            }
        }

        if (!done) {
            run_cycles++;
            if (dut->rootp->core->stall_all) stall_cycles++;
            if (!dut->rootp->core->flush_id_ex) instret++;
            if (dut->rootp->core->cf_resolved) {
                branches++;
                if (dut->rootp->core->ex_redirect) mispredicts++;
            }

            f_cycles = run_cycles;
            f_instret = instret;
            f_stalls = stall_cycles;
            f_branches = branches;
            f_mis = mispredicts;
        }

        tick(dut);
    }

    run_cycles = f_cycles;
    instret = f_instret;
    stall_cycles = f_stalls;
    branches = f_branches;
    mispredicts = f_mis;

    double cpi = instret ? (double) run_cycles / (double) instret : 0.0;
    double hit = branches
                     ? 100.0 * (double) (branches - mispredicts) / (double) branches
                     : 0.0;

    printf("\n--- Performance ---\n");
    printf("  cycles       %llu\n", (unsigned long long) run_cycles);
    printf("  instret      %llu\n", (unsigned long long) instret);
    printf("  CPI          %.3f\n", cpi);
    printf("  stalls       %llu  (load-use)\n", (unsigned long long) stall_cycles);
    printf("  branches     %llu\n", (unsigned long long) branches);
    printf("  mispredicts  %llu  (%llu cycles flushed)\n",
           (unsigned long long) mispredicts, (unsigned long long) mispredicts * 2);
    printf("  prediction   %.1f%% correct\n", hit);
    printf("-------------------\n\n");

    verify_results(dut->rootp->core);

    printf("--- Core Simulation Complete ---\n");

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}