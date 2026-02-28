#include <verilated.h>
#include <iostream>
#include <string>
#include "Vex_mem.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

/**
 * Unified Test Function for EX/MEM Register
 * Validates every signal including PC, mem_op, and rd_src.
 */
void test_ex_mem(Vex_mem *dut,
                 uint32_t pc_plus4,  // Added PC
                 uint32_t alu_res,
                 uint32_t rs2,
                 uint8_t rd,
                 bool rd_wen,
                 uint8_t rd_src,  // Changed from bool m2r to 2-bit rd_src
                 uint8_t mem_op,  // Changed from bool mem_ren to 3-bit mem_op
                 bool mem_wen,
                 bool stall,
                 bool flush,
                 // Expected values for non-flush/non-stall cases
                 uint32_t exp_pc,
                 uint32_t exp_alu,
                 uint32_t exp_rs2,
                 uint8_t exp_rd,
                 bool exp_rd_wen,
                 uint8_t exp_rd_src,
                 uint8_t exp_mem_op,
                 bool exp_mem_wen,
                 const char *label)
{
    // --- Phase 1: Set Inputs ---
    dut->pc_plus4_i = pc_plus4;
    dut->alu_result_i = alu_res;
    dut->rs2_data_i = rs2;
    dut->rd_addr_i = rd;
    dut->rd_wen_i = rd_wen;
    dut->rd_src_i = rd_src;
    dut->mem_op_i = mem_op;
    dut->mem_wen_i = mem_wen;

    dut->stall_i = stall;
    dut->flush_i = flush;

    dut->eval();
    tick(dut);

    // --- Phase 2: Verify Outputs ---
    std::string msg = std::string(label);

    if (flush) {
        // High-Priority Safety Check: Control signals MUST be zero/safe
        EXPECT_EQ((bool) dut->rd_wen_o, false,
                  (msg + " (Flush: rd_wen)").c_str());
        EXPECT_EQ((bool) dut->mem_wen_o, false,
                  (msg + " (Flush: mem_wen)").c_str());
        // Note: mem_op_o should likely be 0 on flush, depending on logic
        EXPECT_EQ((uint32_t) dut->mem_op_o, 0,
                  (msg + " (Flush: mem_op)").c_str());
    } else {
        // Standard data path validation
        EXPECT_EQ(dut->pc_plus4_o, exp_pc, (msg + " (pc_plus4)").c_str());
        EXPECT_EQ(dut->alu_result_o, exp_alu, (msg + " (alu_result)").c_str());
        EXPECT_EQ(dut->rs2_data_o, exp_rs2, (msg + " (rs2_data)").c_str());
        EXPECT_EQ((uint32_t) dut->rd_addr_o, (uint32_t) exp_rd,
                  (msg + " (rd_addr)").c_str());

        // Standard control path validation
        EXPECT_EQ((bool) dut->rd_wen_o, exp_rd_wen,
                  (msg + " (rd_wen)").c_str());
        EXPECT_EQ((uint32_t) dut->rd_src_o, (uint32_t) exp_rd_src,
                  (msg + " (rd_src)").c_str());
        EXPECT_EQ((uint32_t) dut->mem_op_o, (uint32_t) exp_mem_op,
                  (msg + " (mem_op)").c_str());
        EXPECT_EQ((bool) dut->mem_wen_o, exp_mem_wen,
                  (msg + " (mem_wen)").c_str());
    }
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vex_mem *dut = new Vex_mem;
    init_vcd(dut, "ex_mem.vcd");

    dut->rst_i = 1;
    dut->eval();
    tick(dut);
    dut->rst_i = 0;

    printf("--- Starting Comprehensive EX/MEM Verification ---\n");

    // Definitions for clarity
    const uint8_t RD_ALU = 0;
    const uint8_t MEM_SW = 2;  // Assuming 2 is the code for SW (funct3)

    // Test 1: Normal ALU Add instruction
    // Input: PC=0x4000, ALU=0x2A, rd_src=0 (ALU)
    test_ex_mem(dut, 0x4000, 0x0000002A, 0, 10, 1, RD_ALU, 0, 0, 0,
                0,                                           // Inputs
                0x4000, 0x0000002A, 0, 10, 1, RD_ALU, 0, 0,  // Expected
                "1. ADDI Latch");

    // Test 2: Memory Store instruction
    // Input: PC=0x4004, ALU=0x100 (addr), RS2=0xDEADBEEF, mem_op=2 (SW),
    // mem_wen=1
    test_ex_mem(dut, 0x4004, 0x00000100, 0xDEADBEEF, 0, 0, RD_ALU, MEM_SW, 1, 0,
                0,  // Inputs
                0x4004, 0x00000100, 0xDEADBEEF, 0, 0, RD_ALU, MEM_SW,
                1,  // Expected
                "2. SW Latch");

    // Test 3: Stall Integrity (Hold current SW values even if new data arrives)
    // We input "Garbage" (0x5555) but set Stall=1. We Expect "Old" values
    // (0x100 from Test 2).
    test_ex_mem(dut, 0x8000, 0x5555, 0x6666, 5, 1, RD_ALU, 0, 0, 1,
                0,  // Inputs (Stall=1)
                0x4004, 0x00000100, 0xDEADBEEF, 0, 0, RD_ALU, MEM_SW,
                1,  // Expected (Old values)
                "3. Stall Hold");

    // Test 4: Stall Release (Data from Test 3 finally passes through)
    // We keep the inputs from Test 3, but set Stall=0. Now the new values
    // should latch.
    test_ex_mem(dut, 0x8000, 0x5555, 0x6666, 5, 1, RD_ALU, 0, 0, 0,
                0,  // Inputs (Stall=0)
                0x8000, 0x5555, 0x6666, 5, 1, RD_ALU, 0,
                0,  // Expected (New values)
                "4. Stall Release");

    // Test 5: Flush
    // Input valid data but set Flush=1. Expected outputs should be
    // cleared/safe.
    test_ex_mem(dut, 0x9000, 0x8888, 0x9999, 12, 1, RD_ALU, MEM_SW, 1, 0,
                1,                       // Inputs (Flush=1)
                0, 0, 0, 0, 0, 0, 0, 0,  // Expected (Zeros/Safe)
                "5. Pipeline Flush");

    // Test 6: Sequence after Flush (Resume normal operation)
    test_ex_mem(dut, 0xA000, 0x1234, 0x5678, 2, 1, RD_ALU, 0, 0, 0,
                0,                                           // Inputs
                0xA000, 0x1234, 0x5678, 2, 1, RD_ALU, 0, 0,  // Expected
                "6. Post-Flush Resume");

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}