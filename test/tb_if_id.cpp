#include <verilated.h>
#include <iostream>
#include <string>
#include "Vif_id.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

void test_ifid(Vif_id *dut,
               uint32_t pc_in,
               uint32_t inst_in,
               bool stall,
               bool flush,
               bool rst,
               uint32_t expected_pc,
               uint32_t expected_inst,
               const char *label)
{
    dut->pc_i = pc_in;
    dut->inst_i = inst_in;
    dut->stall_i = stall;
    dut->flush_i = flush;
    dut->rst_i = rst;

    // Tick the clock to capture inputs into the IF/ID register
    tick(dut);

    // Verify both the PC and the Instruction
    EXPECT_EQ((uint32_t) dut->pc_o, expected_pc,
              (std::string(label) + " (PC)").c_str());
    EXPECT_EQ((uint32_t) dut->inst_o, expected_inst,
              (std::string(label) + " (Inst)").c_str());
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vif_id *dut = new Vif_id;

    init_vcd(dut, "fetch.vcd");

    printf("--- Starting IF Stage Tests ---\n");

    uint32_t NOP = 0x00000013;  // addi x0, x0, 0

    // --- TEST 1: Reset Behavior ---
    // Should output PC=0 and Inst=NOP regardless of inputs
    test_ifid(dut, 0x1234, 0xDEADBEEF, false, false, true, 0x00000000, NOP,
              "1. Reset");

    // --- TEST 2: Normal Execution (Fetch Instruction 1) ---
    test_ifid(dut, 0x0004, 0x00A00093, false, false, false, 0x00000004,
              0x00A00093, "2. Normal Fetch 1");

    // --- TEST 3: Normal Execution (Fetch Instruction 2) ---
    test_ifid(dut, 0x0008, 0x00B00093, false, false, false, 0x00000008,
              0x00B00093, "3. Normal Fetch 2");

    // --- TEST 4: Stall Pipeline ---
    // Change inputs, but enable stall. Outputs should remain at 0x0008 and
    // 0x00B00093.
    test_ifid(dut, 0x000C, 0x00C00093, true, false, false, 0x00000008,
              0x00B00093, "4. Stall");

    // --- TEST 5: Resume from Stall ---
    // Disable stall. Should now latch the waiting inputs (0x000C, 0x00C00093).
    test_ifid(dut, 0x000C, 0x00C00093, false, false, false, 0x0000000C,
              0x00C00093, "5. Resume");

    // --- TEST 6: Flush Pipeline (Branch Mispredict) ---
    // Set flush_i to 1. Should ignore inputs and force PC=0, Inst=NOP.
    test_ifid(dut, 0x0010, 0x00D00093, false, true, false, 0x00000000, NOP,
              "6. Flush");

    // Clean up
    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}