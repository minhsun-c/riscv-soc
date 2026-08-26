#include <verilated.h>
#include <iostream>
#include <string>
#include "Vbht.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

// The table is indexed by pc[IDX_W+1:2], so entry n lives at PC n*4.
static uint32_t pc_of(int entry)
{
    return (uint32_t) entry * 4;
}

// Resolve a branch at `pc` as taken / not taken, one update per cycle.
static void update(Vbht *dut, uint32_t pc, bool taken)
{
    dut->upd_valid_i = 1;
    dut->upd_pc_i = pc;
    dut->upd_taken_i = taken;
    tick(dut);
    dut->upd_valid_i = 0;
}

static void expect_pred(Vbht *dut, uint32_t pc, bool expected, const char *label)
{
    dut->pc_i = pc;
    dut->eval();
    EXPECT_EQ((uint32_t) dut->predict_taken_o, (uint32_t) expected, label);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vbht *dut = new Vbht;

    init_vcd(dut, "bht.vcd");

    printf("--- Starting Branch History Table Tests ---\n");

    dut->rst_i = 1;
    dut->upd_valid_i = 0;
    tick(dut);
    dut->rst_i = 0;

    // --- 1. After reset every counter is weakly not taken ---
    expect_pred(dut, pc_of(0), false, "1. Reset: predict not taken");
    expect_pred(dut, pc_of(7), false, "2. Reset: another entry too");

    // --- 3. One taken outcome flips the prediction (01 -> 10) ---
    update(dut, pc_of(0), true);
    expect_pred(dut, pc_of(0), true, "3. One taken -> predict taken");

    // --- 4. Saturates at strongly taken ---
    update(dut, pc_of(0), true);  // 11
    update(dut, pc_of(0), true);  // stays 11
    update(dut, pc_of(0), true);
    expect_pred(dut, pc_of(0), true, "4. Saturates at strongly taken");

    // --- 5. Hysteresis: this is the whole reason for the second bit ---
    // From strongly taken, one not-taken outcome must NOT change the
    // prediction. A 1-bit predictor would flip here, and would then mispredict
    // the first iteration of the next loop as well.
    update(dut, pc_of(0), false);  // 11 -> 10
    expect_pred(dut, pc_of(0), true, "5. One contrary outcome does not flip");

    // --- 6. A second contrary outcome does flip it (10 -> 01) ---
    update(dut, pc_of(0), false);
    expect_pred(dut, pc_of(0), false, "6. Two in a row do flip");

    // --- 7. Saturates at strongly not taken ---
    update(dut, pc_of(0), false);  // 00
    update(dut, pc_of(0), false);  // stays 00
    update(dut, pc_of(0), false);
    expect_pred(dut, pc_of(0), false, "7. Saturates at strongly not taken");

    // --- 8. And symmetrically, one taken does not flip it back ---
    update(dut, pc_of(0), true);  // 00 -> 01
    expect_pred(dut, pc_of(0), false, "8. Hysteresis works both ways");

    // --- 9. Entries are independent ---
    update(dut, pc_of(5), true);
    update(dut, pc_of(5), true);
    expect_pred(dut, pc_of(5), true, "9. Entry 5 trained taken");
    expect_pred(dut, pc_of(0), false, "10. Entry 0 unaffected");

    // --- 11. No update when upd_valid is low ---
    dut->upd_valid_i = 0;
    dut->upd_pc_i = pc_of(5);
    dut->upd_taken_i = 0;
    tick(dut);
    tick(dut);
    expect_pred(dut, pc_of(5), true, "11. upd_valid low changes nothing");

    // --- 12. Aliasing: two PCs 64 entries apart share one counter ---
    // The table has no tags, so this is expected. It costs prediction accuracy,
    // never correctness -- EX still resolves every branch for real.
    uint32_t pc_a = pc_of(3);
    uint32_t pc_b = pc_of(3) + 64 * 4;  // same index, different upper bits
    update(dut, pc_a, true);
    update(dut, pc_a, true);
    expect_pred(dut, pc_b, true, "12. Aliased PC sees the same counter");

    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}
