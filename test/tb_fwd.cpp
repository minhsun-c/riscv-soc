#include <verilated.h>
#include <iostream>
#include <string>
#include "Vfwd.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

// Forwarding selectors, mirroring src/include/fwdsel.vh
static const uint8_t FWD_NONE = 0, FWD_MEM = 1, FWD_WB = 2;

static const char *sel_name(uint8_t s)
{
    switch (s) {
        case FWD_NONE: return "NONE";
        case FWD_MEM:  return "MEM";
        case FWD_WB:   return "WB";
        default:       return "??";
    }
}

void test_fwd(Vfwd *dut,
              uint8_t rs1_ex,
              uint8_t rs2_ex,
              uint8_t rd_mem,
              bool rd_wen_mem,
              uint8_t rd_wb,
              bool rd_wen_wb,
              uint8_t exp_a,
              uint8_t exp_b,
              const char *label)
{
    dut->rs1_addr_ex_i = rs1_ex;
    dut->rs2_addr_ex_i = rs2_ex;
    dut->rd_addr_mem_i = rd_mem;
    dut->rd_wen_mem_i = rd_wen_mem;
    dut->rd_addr_wb_i = rd_wb;
    dut->rd_wen_wb_i = rd_wen_wb;

    dut->eval();
    tick(dut);

    std::string msg = std::string(label);
    EXPECT_EQ((uint32_t) dut->fwd_a_o, (uint32_t) exp_a,
              (msg + " (fwd_a should be " + sel_name(exp_a) + ")").c_str());
    EXPECT_EQ((uint32_t) dut->fwd_b_o, (uint32_t) exp_b,
              (msg + " (fwd_b should be " + sel_name(exp_b) + ")").c_str());
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vfwd *dut = new Vfwd;

    init_vcd(dut, "fwd.vcd");

    printf("--- Starting Forwarding Unit Tests ---\n");

    // --- 1. Nothing in flight touches our sources ---
    test_fwd(dut, 1, 2, 3, true, 4, true, FWD_NONE, FWD_NONE, "1. No dependency");

    // --- 2-3. Distance one: the value is in MEM ---
    //   add x1, ...      <- in MEM
    //   add x5, x1, x2   <- in EX, needs x1
    test_fwd(dut, 1, 2, 1, true, 9, true, FWD_MEM, FWD_NONE, "2. MEM -> rs1");
    test_fwd(dut, 1, 2, 2, true, 9, true, FWD_NONE, FWD_MEM, "3. MEM -> rs2");

    // --- 4-5. Distance two: the value is in WB ---
    test_fwd(dut, 1, 2, 9, true, 1, true, FWD_WB, FWD_NONE, "4. WB -> rs1");
    test_fwd(dut, 1, 2, 9, true, 2, true, FWD_NONE, FWD_WB, "5. WB -> rs2");

    // --- 6. Both match: MEM is the newer write and must win ---
    //   add x1, ...   <- in WB   (older)
    //   add x1, ...   <- in MEM  (newer)
    //   add x5, x1,.. <- in EX
    // Taking WB here would resurrect a value that has already been overwritten.
    test_fwd(dut, 1, 1, 1, true, 1, true, FWD_MEM, FWD_MEM, "6. MEM wins over WB");

    // --- 7. Each operand picks its own source ---
    test_fwd(dut, 1, 2, 1, true, 2, true, FWD_MEM, FWD_WB, "7. rs1 from MEM, rs2 from WB");

    // --- 8-9. A producer that does not write is not a producer ---
    // rd still holds a stale value on the bus; rd_wen is what makes it real.
    test_fwd(dut, 1, 2, 1, false, 9, true, FWD_NONE, FWD_NONE, "8. MEM rd_wen low");
    test_fwd(dut, 1, 2, 9, true, 1, false, FWD_NONE, FWD_NONE, "9. WB rd_wen low");

    // --- 10. MEM does not write, so WB still applies ---
    test_fwd(dut, 1, 1, 1, false, 1, true, FWD_WB, FWD_WB, "10. MEM silent, WB forwards");

    // --- 11-12. x0 is never forwarded ---
    // Writes to x0 are discarded, so the register file's zero is already correct.
    // Forwarding here would hand the EX stage whatever the producer computed.
    test_fwd(dut, 0, 0, 0, true, 9, true, FWD_NONE, FWD_NONE, "11. x0 from MEM ignored");
    test_fwd(dut, 0, 0, 9, true, 0, true, FWD_NONE, FWD_NONE, "12. x0 from WB ignored");

    // --- 13. Same register into both operands ---
    //   add x3, ...      <- in MEM
    //   sub x5, x3, x3   <- in EX
    test_fwd(dut, 3, 3, 3, true, 9, true, FWD_MEM, FWD_MEM, "13. Both operands from MEM");

    // --- 14. Back-to-back chain: MEM feeds rs1, WB feeds nothing ---
    test_fwd(dut, 7, 8, 7, true, 8, false, FWD_MEM, FWD_NONE, "14. Chain, WB disabled");

    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}
