#include <verilated.h>
#include <iostream>
#include <string>
#include "Vif_stage.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

/**
 * Unified Test Function for IF Stage
 */
void test_if(Vif_stage *dut,
             bool stall,
             bool jb_taken,
             uint32_t jb_target,
             uint32_t exp_pc,
             uint32_t exp_pc_plus4,
             const char *label)
{
    dut->stall_i = stall;
    dut->jb_taken_i = jb_taken;
    dut->jb_target_i = jb_target;

    // We do NOT tick here yet because we want to check the state
    // resulting from the PREVIOUS cycle's clock edge.
    dut->eval();

    EXPECT_EQ(dut->pc_o, exp_pc,
              (std::string(label) + " (Current PC)").c_str());
    EXPECT_EQ(dut->pc_plus4_o, exp_pc_plus4,
              (std::string(label) + " (PC+4 Path)").c_str());

    // Tick to move to the next state defined by the inputs above
    tick(dut);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vif_stage *dut = new Vif_stage;
    init_vcd(dut, "if_stage.vcd");

    // Reset Sequence
    dut->rst_i = 1;
    dut->eval();
    tick(dut);
    dut->rst_i = 0;

    printf("--- Starting Mixed Sequential/Branch IF Tests ---\n");

    // 1. Start from 0
    test_if(dut, 0, 0, 0, 0x0, 0x4, "1. Initial");

    // 2. Step to 4
    test_if(dut, 0, 0, 0, 0x4, 0x8, "2. Seq Step");

    // 3. Jump to a far address (0x1000)
    test_if(dut, 0, 1, 0x1000, 0x8, 0xC, "3. Jump Trigger");

    // 4. Land at 0x1000 and check Seq Adder
    test_if(dut, 0, 0, 0, 0x1000, 0x1004, "4. Land & Seq Check");

    // 5. One more sequential step
    test_if(dut, 0, 0, 0, 0x1004, 0x1008, "5. Seq Step");

    // 6. Branch back to a previous address (0x4)
    test_if(dut, 0, 1, 0x4, 0x1008, 0x100C, "6. Loop Back Trigger");

    // 7. Verify we are back at 0x4
    test_if(dut, 0, 0, 0, 0x4, 0x8, "7. Landed at Loop Start");

    // 8. Stall immediately after a jump lands
    test_if(dut, 1, 0, 0, 0x8, 0xC, "8. Stall at 0x8");

    // 9. Verify stall held
    test_if(dut, 0, 0, 0, 0x8, 0xC, "9. Verify Stall Held");

    printf("--- Mixed IF Stage Verification Complete ---\n");

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}