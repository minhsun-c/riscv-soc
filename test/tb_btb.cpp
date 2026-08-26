#include <verilated.h>
#include <iostream>
#include <string>
#include "Vbtb.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

// 64 entries -> index is pc[7:2], so entry n is at PC n*4 and two PCs that are
// 64*4 = 256 bytes apart land on the same entry with different tags.
static const uint32_t STRIDE = 64 * 4;

static uint32_t pc_of(int entry)
{
    return (uint32_t) entry * 4;
}

// Record a taken branch at `pc` going to `target`.
static void update(Vbtb *dut, uint32_t pc, uint32_t target)
{
    dut->upd_valid_i = 1;
    dut->upd_pc_i = pc;
    dut->upd_target_i = target;
    tick(dut);
    dut->upd_valid_i = 0;
}

static void expect_lookup(Vbtb *dut,
                          uint32_t pc,
                          bool exp_hit,
                          uint32_t exp_target,
                          const char *label)
{
    dut->pc_i = pc;
    dut->eval();
    std::string msg = std::string(label);
    EXPECT_EQ((uint32_t) dut->hit_o, (uint32_t) exp_hit, (msg + " (hit)").c_str());
    if (exp_hit) {
        EXPECT_EQ(dut->target_o, exp_target, (msg + " (target)").c_str());
    }
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vbtb *dut = new Vbtb;

    init_vcd(dut, "btb.vcd");

    printf("--- Starting Branch Target Buffer Tests ---\n");

    dut->rst_i = 1;
    dut->upd_valid_i = 0;
    tick(dut);
    dut->rst_i = 0;

    // --- 1-2. Nothing is recorded yet ---
    expect_lookup(dut, pc_of(0), false, 0, "1. Reset: miss");
    expect_lookup(dut, pc_of(9), false, 0, "2. Reset: miss elsewhere");

    // --- 3. Record a branch, then find it again ---
    update(dut, pc_of(4), 0x1000);
    expect_lookup(dut, pc_of(4), true, 0x1000, "3. Recorded branch hits");

    // --- 4. A different index is still empty ---
    expect_lookup(dut, pc_of(5), false, 0, "4. Neighbouring entry still empty");

    // --- 5. Same index, different tag -> MISS ---
    // This is the entire reason the BTB is tagged. Without the tag this lookup
    // would hit and send fetch to 0x1000, a target belonging to a completely
    // different branch.
    expect_lookup(dut, pc_of(4) + STRIDE, false, 0, "5. Same index, wrong tag: miss");

    // --- 6. That other PC can claim the entry ---
    update(dut, pc_of(4) + STRIDE, 0x2000);
    expect_lookup(dut, pc_of(4) + STRIDE, true, 0x2000, "6. Evicting PC now hits");

    // --- 7. And the original is gone: direct-mapped means one entry per index ---
    expect_lookup(dut, pc_of(4), false, 0, "7. Original evicted");

    // --- 8. Overwriting the same PC updates the target ---
    update(dut, pc_of(4) + STRIDE, 0x3000);
    expect_lookup(dut, pc_of(4) + STRIDE, true, 0x3000, "8. Target updated in place");

    // --- 9-10. Entries are independent ---
    update(dut, pc_of(1), 0xAAA0);
    update(dut, pc_of(2), 0xBBB0);
    expect_lookup(dut, pc_of(1), true, 0xAAA0, "9. Entry 1 intact");
    expect_lookup(dut, pc_of(2), true, 0xBBB0, "10. Entry 2 intact");

    // --- 11. No update when upd_valid is low ---
    dut->upd_valid_i = 0;
    dut->upd_pc_i = pc_of(1);
    dut->upd_target_i = 0xDEAD;
    tick(dut);
    tick(dut);
    expect_lookup(dut, pc_of(1), true, 0xAAA0, "11. upd_valid low changes nothing");

    // --- 12. The last entry works too (index wraps at NUM_ENTRIES-1) ---
    update(dut, pc_of(63), 0x7FF0);
    expect_lookup(dut, pc_of(63), true, 0x7FF0, "12. Last entry");

    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}
