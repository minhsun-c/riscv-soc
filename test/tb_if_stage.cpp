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
    dut->redirect_i = jb_taken;
    dut->redirect_pc_i = jb_target;
    // These vectors predate the predictor; no prediction means pc+4.
    dut->pred_taken_i = 0;
    dut->pred_target_i = 0;

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

// Same as test_if but drives the prediction inputs too, for the vectors that
// exercise the priority between redirect, prediction and pc+4.
void test_if_pred(Vif_stage *dut,
                  bool stall,
                  bool redirect,
                  uint32_t redirect_pc,
                  bool pred_taken,
                  uint32_t pred_target,
                  uint32_t exp_pc,
                  const char *label)
{
    dut->stall_i = stall;
    dut->redirect_i = redirect;
    dut->redirect_pc_i = redirect_pc;
    dut->pred_taken_i = pred_taken;
    dut->pred_target_i = pred_target;
    dut->eval();

    EXPECT_EQ(dut->pc_o, exp_pc, (std::string(label) + " (Current PC)").c_str());

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

    printf("--- Prediction and its priority ---\n");

    // Land somewhere known first.
    test_if_pred(dut, 0, 1, 0x2000, 0, 0, 0xC, "P1. Redirect to 0x2000");

    // A prediction with nothing competing: the PC follows it.
    test_if_pred(dut, 0, 0, 0, 1, 0x3000, 0x2000, "P2. At 0x2000, predict 0x3000");
    test_if_pred(dut, 0, 0, 0, 0, 0, 0x3000, "P3. Prediction was taken");

    // No prediction: plain pc+4.
    test_if_pred(dut, 0, 0, 0, 0, 0, 0x3004, "P4. pc+4 when not predicted");

    // Both at once. Redirect is fact and prediction is a guess, so redirect
    // wins -- this is the ordering the whole week turns on.
    test_if_pred(dut, 0, 1, 0x5000, 1, 0x9000, 0x3008, "P5. Both asserted");
    test_if_pred(dut, 0, 0, 0, 0, 0, 0x5000, "P6. Redirect beat the prediction");

    // A stall must not be overridden by a prediction: IF is frozen, and the
    // instruction it already fetched has not moved on yet.
    test_if_pred(dut, 1, 0, 0, 1, 0x7000, 0x5004, "P7. Stalled, prediction ignored");
    test_if_pred(dut, 0, 0, 0, 0, 0, 0x5004, "P8. PC held through the stall");

    // But a redirect does override a stall: continuing to fetch down a path
    // already known to be wrong helps nobody.
    test_if_pred(dut, 1, 1, 0x8000, 0, 0, 0x5008, "P9. Stalled but redirected");
    test_if_pred(dut, 0, 0, 0, 0, 0, 0x8000, "P10. Redirect beat the stall");

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}