#include <verilated.h>
#include <iostream>
#include <string>
#include "Vlsu.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

// funct3 encodings, mirroring src/include/memop.vh
static const uint8_t LB = 0, LH = 1, LW = 2, LBU = 4, LHU = 5;
static const uint8_t SB = 0, SH = 1, SW = 2;

static void test_store(Vlsu *dut,
                       uint8_t op,
                       uint32_t addr,
                       uint32_t wdata,
                       uint8_t exp_strb,
                       uint32_t exp_lane,
                       const char *label)
{
    dut->mem_op_i = op;
    dut->addr_i = addr;
    dut->wdata_i = wdata;
    dut->eval();

    std::string msg = std::string(label);
    EXPECT_EQ((uint32_t) dut->wstrb_o, (uint32_t) exp_strb, (msg + " (wstrb)").c_str());
    EXPECT_EQ(dut->wdata_lane_o, exp_lane, (msg + " (lane)").c_str());
    tick(dut);
}

static void test_load(Vlsu *dut,
                      uint8_t op,
                      uint32_t addr,
                      uint32_t word,
                      uint32_t exp,
                      const char *label)
{
    dut->mem_op_i = op;
    dut->addr_i = addr;
    dut->rdata_raw_i = word;
    dut->eval();

    EXPECT_EQ(dut->rdata_o, exp, label);
    tick(dut);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vlsu *dut = new Vlsu;

    init_vcd(dut, "lsu.vcd");

    printf("--- Starting Load/Store Unit Tests ---\n");

    // --- Stores: which bytes, and the data shifted into them ---
    // A bus carries a whole word. WSTRB says which of it to believe, and the
    // data has to already be sitting in the right lane.
    test_store(dut, SB, 0x100, 0xAB, 0b0001, 0x000000AB, "1. SB to lane 0");
    test_store(dut, SB, 0x101, 0xAB, 0b0010, 0x0000AB00, "2. SB to lane 1");
    test_store(dut, SB, 0x102, 0xAB, 0b0100, 0x00AB0000, "3. SB to lane 2");
    test_store(dut, SB, 0x103, 0xAB, 0b1000, 0xAB000000, "4. SB to lane 3");

    test_store(dut, SH, 0x100, 0xBEEF, 0b0011, 0x0000BEEF, "5. SH to the low half");
    test_store(dut, SH, 0x102, 0xBEEF, 0b1100, 0xBEEF0000, "6. SH to the high half");

    test_store(dut, SW, 0x100, 0xDEADBEEF, 0b1111, 0xDEADBEEF, "7. SW writes all four");

    // --- Loads: pull the bytes out, then extend ---
    const uint32_t W = 0x8817F5A3;  // lanes: A3 F5 17 88

    test_load(dut, LBU, 0x100, W, 0x000000A3, "8. LBU lane 0");
    test_load(dut, LBU, 0x101, W, 0x000000F5, "9. LBU lane 1");
    test_load(dut, LBU, 0x102, W, 0x00000017, "10. LBU lane 2");
    test_load(dut, LBU, 0x103, W, 0x00000088, "11. LBU lane 3");

    // Sign extension is what makes LB and LBU different instructions.
    test_load(dut, LB, 0x100, W, 0xFFFFFFA3, "12. LB lane 0 (negative)");
    test_load(dut, LB, 0x102, W, 0x00000017, "13. LB lane 2 (positive)");
    test_load(dut, LB, 0x103, W, 0xFFFFFF88, "14. LB lane 3 (negative)");

    test_load(dut, LHU, 0x100, W, 0x0000F5A3, "15. LHU low half");
    test_load(dut, LHU, 0x102, W, 0x00008817, "16. LHU high half");
    test_load(dut, LH, 0x100, W, 0xFFFFF5A3, "17. LH low half (negative)");
    test_load(dut, LH, 0x102, W, 0xFFFF8817, "18. LH high half (negative)");

    test_load(dut, LW, 0x100, W, W, "19. LW takes the word untouched");

    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}
