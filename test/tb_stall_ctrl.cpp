#include <verilated.h>
#include <iostream>
#include "Vstall_ctrl.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

static void test_stall(Vstall_ctrl *dut,
                       bool load_use,
                       bool im_wait,
                       bool dm_wait,
                       bool expected,
                       const char *label)
{
    dut->load_use_i = load_use;
    dut->im_wait_i = im_wait;
    dut->dm_wait_i = dm_wait;
    dut->eval();

    EXPECT_EQ((uint32_t) dut->stall_o, (uint32_t) expected, label);
    tick(dut);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vstall_ctrl *dut = new Vstall_ctrl;

    init_vcd(dut, "stall_ctrl.vcd");

    printf("--- Starting Stall Arbitration Tests ---\n");

    // Stalling is not a choice between reasons. If any of them says wait, the
    // pipeline waits -- so this is an OR, not a priority chain. Priority is a
    // question for flushing, and that lives in core.v.
    test_stall(dut, 0, 0, 0, 0, "1. Nothing waiting");
    test_stall(dut, 1, 0, 0, 1, "2. Load-use alone");
    test_stall(dut, 0, 1, 0, 1, "3. Instruction fetch alone");
    test_stall(dut, 0, 0, 1, 1, "4. Data access alone");
    test_stall(dut, 1, 1, 0, 1, "5. Load-use and fetch");
    test_stall(dut, 0, 1, 1, 1, "6. Fetch and data");
    test_stall(dut, 1, 1, 1, 1, "7. All three");

    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}
