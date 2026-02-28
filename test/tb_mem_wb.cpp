#include <verilated.h>
#include <iostream>
#include <string>
#include "Vmem_wb.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

/**
 * Unified Test Function for MEM/WB Register
 * Validates the latching of data, PC, and control signals.
 */
void test_mem_wb(Vmem_wb *dut,
                 uint32_t pc_plus4,  // Added PC
                 uint32_t alu_res,
                 uint32_t mem_data,
                 uint8_t rd,
                 bool rd_wen,
                 uint8_t rd_src,  // Changed from bool m2r to 2-bit rd_src
                 bool stall,
                 // Expected values (outputs from previous cycle)
                 uint32_t exp_pc,
                 uint32_t exp_alu,
                 uint32_t exp_mem,
                 uint8_t exp_rd,
                 bool exp_rd_wen,
                 uint8_t exp_rd_src,
                 const char *label)
{
    // --- Phase 1: Drive Inputs (Current Cycle) ---
    dut->pc_plus4_i = pc_plus4;
    dut->alu_result_i = alu_res;
    dut->mem_data_i = mem_data;
    dut->rd_addr_i = rd;
    dut->rd_wen_i = rd_wen;
    dut->rd_src_i = rd_src;
    dut->stall_i = stall;

    dut->eval();
    tick(dut);  // The Edge: Capture Phase 1 -> Phase 2

    // --- Phase 2: Verify Outputs (Landed State) ---
    std::string msg = std::string(label);

    EXPECT_EQ(dut->pc_plus4_o, exp_pc, (msg + " (pc_plus4)").c_str());
    EXPECT_EQ(dut->alu_result_o, exp_alu, (msg + " (alu_result)").c_str());
    EXPECT_EQ(dut->mem_data_o, exp_mem, (msg + " (mem_data)").c_str());
    EXPECT_EQ((uint32_t) dut->rd_addr_o, (uint32_t) exp_rd,
              (msg + " (rd_addr)").c_str());
    EXPECT_EQ((bool) dut->rd_wen_o, exp_rd_wen, (msg + " (rd_wen)").c_str());
    EXPECT_EQ((uint32_t) dut->rd_src_o, (uint32_t) exp_rd_src,
              (msg + " (rd_src)").c_str());
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vmem_wb *dut = new Vmem_wb;
    init_vcd(dut, "mem_wb.vcd");

    // 1. Initial Reset
    dut->rst_i = 1;
    dut->eval();
    tick(dut);
    dut->rst_i = 0;

    printf("--- Starting MEM/WB Register Verification ---\n");

    // Constants for RD_SRC (0:ALU, 1:MEM, 2:PC+4)
    const uint8_t RD_ALU = 0;
    const uint8_t RD_MEM = 1;

    // Test 1: Latch an Arithmetic Result (ADD)
    // Input: PC=0x4000, ALU=0x1234, rd_src=0 (ALU)
    test_mem_wb(dut, 0x4000, 0x1234, 0, 10, 1, RD_ALU, 0,  // Inputs
                0x4000, 0x1234, 0, 10, 1, RD_ALU,          // Expected
                "1. ALU Latch");

    // Test 2: Latch a Memory Load (LW)
    // Input: PC=0x4004, ALU=0x5555, MEM=0xABCD, rd_src=1 (MEM)
    test_mem_wb(dut, 0x4004, 0x5555, 0xABCD, 5, 1, RD_MEM, 0,  // Inputs
                0x4004, 0x5555, 0xABCD, 5, 1, RD_MEM,          // Expected
                "2. Load Latch");

    // Test 3: Stall Integrity
    // Input is "Garbage" (0xDEAD/0xFFFF), but stall is 1.
    // Output should stay at Test 2 values (0x4004, 0x5555, 0xABCD).
    test_mem_wb(dut, 0x8000, 0xDEAD, 0xFFFF, 31, 1, RD_ALU,
                1,                                     // Inputs (Stall=1)
                0x4004, 0x5555, 0xABCD, 5, 1, RD_MEM,  // Expected (Old values)
                "3. Stall Hold");

    // Test 4: Stall Release
    // Data from Test 3 inputs (0x8000, 0xDEAD...) should now land because stall
    // is 0.
    test_mem_wb(dut, 0x8000, 0xDEAD, 0xFFFF, 31, 1, RD_ALU,
                0,                                      // Inputs (Stall=0)
                0x8000, 0xDEAD, 0xFFFF, 31, 1, RD_ALU,  // Expected (New values)
                "4. Stall Release");

    // Test 5: Reset Check
    dut->rst_i = 1;
    tick(dut);
    EXPECT_EQ(dut->rd_wen_o, 0, "5. Reset RD_WEn");
    EXPECT_EQ(dut->alu_result_o, 0, "5. Reset ALU Result");
    EXPECT_EQ(dut->pc_plus4_o, 0, "5. Reset PC+4");

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}