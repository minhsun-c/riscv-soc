#include <verilated.h>
#include <iostream>
#include <string>
#include "Vbcu.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

/**
 * Test function for the BCU
 */
void test_bcu(Vbcu *dut,
              uint32_t alu_result,
              uint8_t branch_op,
              bool branch_en,
              bool jump_en,
              bool exp_jb_taken,
              const char *label)
{
    dut->alu_result_i = alu_result;
    dut->branch_op_i = branch_op;
    dut->branch_i = branch_en;
    dut->jump_i = jump_en;
    dut->eval();

    EXPECT_EQ((uint32_t) dut->jb_taken_o, (uint32_t) exp_jb_taken, label);

    tick(dut);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vbcu *dut = new Vbcu;
    init_vcd(dut, "bcu.vcd");

    // Branch Op Constants from branchop.vh
    const uint8_t BEQ = 0, BNE = 1, BLT = 4, BGE = 5, BLTU = 6, BGEU = 7;

    printf("--- Starting BCU Logic Tests ---\n");

    // 1. Unconditional Jump
    // Jump should always result in taken, regardless of ALU or Branch signals
    test_bcu(dut, 0x1234, 0, false, true, true, "1. Unconditional Jump");

    // 2. BEQ (ALU result is 0 -> Taken)
    test_bcu(dut, 0x00000000, BEQ, true, false, true, "2. BEQ Taken (Zero)");
    // 3. BEQ (ALU result is non-zero -> Not Taken)
    test_bcu(dut, 0x00000001, BEQ, true, false, false, "3. BEQ Not Taken");

    // 4. BNE (ALU result is non-zero -> Taken)
    test_bcu(dut, 0xFFFFFFF6, BNE, true, false, true,
             "4. BNE Taken (Non-Zero)");
    // 5. BNE (ALU result is zero -> Not Taken)
    test_bcu(dut, 0x00000000, BNE, true, false, false, "5. BNE Not Taken");

    // 6. BLT (ALU result is 1 -> Taken)
    // In this mode, ALU has already performed SLT and returned 1.
    test_bcu(dut, 0x00000001, BLT, true, false, true,
             "6. BLT Taken (ALU Result 1)");
    // 7. BLT (ALU result is 0 -> Not Taken)
    test_bcu(dut, 0x00000000, BLT, true, false, false, "7. BLT Not Taken");

    // 8. BGE (ALU result is 0 -> Taken)
    // BGE is taken if (rs1 < rs2) is FALSE. ALU SLT returns 0 if rs1 >= rs2.
    test_bcu(dut, 0x00000000, BGE, true, false, true,
             "8. BGE Taken (ALU Result 0)");
    // 9. BGE (ALU result is 1 -> Not Taken)
    test_bcu(dut, 0x00000001, BGE, true, false, false, "9. BGE Not Taken");

    // 10. BLTU (Unsigned comparison, ALU result 1 -> Taken)
    test_bcu(dut, 0x00000001, BLTU, true, false, true, "10. BLTU Taken");

    // 11. BGEU (Unsigned comparison, ALU result 0 -> Taken)
    test_bcu(dut, 0x00000000, BGEU, true, false, true, "11. BGEU Taken");

    // 12. No Branch/No Jump (Should be 0)
    test_bcu(dut, 0x00000000, BEQ, false, false, false, "12. Idle State");

    printf("--- BCU Tests Completed ---\n");

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}