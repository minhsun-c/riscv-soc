#include <verilated.h>
#include <iostream>
#include "Vpc.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace;
vluint64_t sim_time;

// Updated function signature to include jb_taken
void test_pc(Vpc *dut,
             uint32_t pc_next,
             bool jb_taken,
             bool stall,
             bool rst,
             uint32_t expected,
             const char *label)
{
    dut->pc_next_i = pc_next;
    dut->jb_taken_i = jb_taken;  // <-- Drive the new port
    dut->stall_i = stall;
    dut->rst_i = rst;

    tick(dut);

    EXPECT_EQ((uint32_t) dut->pc_o, expected, label);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vpc *dut = new Vpc;

    init_vcd(dut, "pc.vcd");

    printf("--- Starting Program Counter Unit Tests ---\n");

    // Params: pc_next, jb_taken, stall, rst | expected | label

    // --- TEST 1: Reset Vector ---
    // Even if pc_next is 0x1234, rst_i should force it to 0
    test_pc(dut, 0x00001234, false, false, true, 0x00000000,
            "1. Reset Priority Test");

    // --- TEST 2: Sequential Increment ---
    test_pc(dut, 0x00000004, false, false, false, 0x00000004,
            "2. Increment to 0x4");
    test_pc(dut, 0x00000008, false, false, false, 0x00000008,
            "3. Increment to 0x8");

    // --- TEST 3: Stall Behavior ---
    // Set next to 0xC but enable stall; PC should remain at 0x8
    test_pc(dut, 0x0000000C, false, true, false, 0x00000008,
            "4. Stall Hold Test");

    // --- TEST 4: Resume from Stall ---
    // Disable stall; PC should now take the 0xC
    test_pc(dut, 0x0000000C, false, false, false, 0x0000000C,
            "5. Stall Release Test");

    // --- TEST 5: Normal Jump (Branch/JAL) ---
    // jb_taken is true, normal jump
    test_pc(dut, 0x0000DEAD, true, false, false, 0x0000DEAD,
            "6. Jump to 0xDEAD");

    // --- TEST 6: Priority Override (The Bug Fix!) ---
    // Both jb_taken AND stall are high. The Jump MUST win.
    test_pc(dut, 0x0000BEEF, true, true, false, 0x0000BEEF,
            "7. Priority: Jump Overrides Stall");

    // Clean up
    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}