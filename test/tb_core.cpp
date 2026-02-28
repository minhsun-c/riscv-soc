#include <verilated.h>
#include <iostream>
#include <vector>
#include "Vcore.h"
#include "Vcore_core.h"
#include "Vcore_regfile.h"
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

#if TESTNUM >= 6
    /* clang-format off */
#define BIN_NAME(x) test/test_program/test##x.bin
#define TO_BIN(x) TOSTRING(BIN_NAME(x))
    load_program(TO_BIN(TESTNUM));
/* clang-format on */
#else
    load_program();
#endif

    // 1. Reset Phase
    dut->rst_i = 1;
    tick(dut);
    dut->rst_i = 0;

    printf("--- Starting Core Pipeline Simulation (TESTNUM=%d) ---\n", TESTNUM);

    for (int i = 0; i < 8000; i++) {
        uint32_t pc_idx = dut->im_addr_o >> 2;
        dut->im_data_i = imem[pc_idx];

        uint32_t data_idx = dut->dm_addr_o >> 2;
        if (dut->dm_we_o) {
            dmem[data_idx] = dut->dm_wdata_o;
        }
        dut->data_rdata_i = dmem[data_idx];

        tick(dut);
    }

    // 2. Final Verification
    // Call the verify_results() from the included header
    verify_results(dut);

    printf("--- Core Simulation Complete ---\n");

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}