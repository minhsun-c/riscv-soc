#include <verilated.h>
#include <iostream>
#include <string>
#include "Vhdu.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

void test_hdu(Vhdu *dut,
              uint8_t rs1_id,
              uint8_t rs2_id,
              uint8_t rd_ex,
              bool reg_write_ex,
              uint8_t rd_mem,
              bool reg_write_mem,
              bool expected_stall,
              const char *label)
{
    dut->rs1_id_i = rs1_id;
    dut->rs2_id_i = rs2_id;
    dut->rd_ex_i = rd_ex;
    dut->reg_write_ex_i = reg_write_ex;
    dut->rd_mem_i = rd_mem;
    dut->reg_write_mem_i = reg_write_mem;

    dut->eval();
    tick(dut);

    EXPECT_EQ((uint32_t) dut->stall_o, (uint32_t) expected_stall, label);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vhdu *dut = new Vhdu;

    init_vcd(dut, "hdu.vcd");

    printf("--- Starting Hazard Detection Unit Tests ---\n");

    // --- TEST 1: No Hazards ---
    // Decode needs x1, x2. EX writes to x3. MEM writes to x4.
    test_hdu(dut, 1, 2, 3, true, 4, true, false, "1. No Hazard");

    // --- TEST 2: Hazard in Execute Stage (rs1) ---
    // Decode needs x1. EX is writing to x1.
    test_hdu(dut, 1, 2, 1, true, 4, false, true, "2. EX Hazard on rs1");

    // --- TEST 3: Hazard in Execute Stage (rs2) ---
    // Decode needs x2. EX is writing to x2.
    test_hdu(dut, 1, 2, 3, false, 2, true, true,
             "3. MEM Hazard on rs2");  // Wait, fixed this below to match label

    // Let's do a proper EX Hazard on rs2
    test_hdu(dut, 1, 2, 2, true, 4, false, true, "3. EX Hazard on rs2");

    // --- TEST 4: Hazard in Memory Stage (rs1) ---
    // Decode needs x1. MEM is writing to x1.
    test_hdu(dut, 1, 2, 3, false, 1, true, true, "4. MEM Hazard on rs1");

    // --- TEST 5: Hazard in Memory Stage (rs2) ---
    // Decode needs x2. MEM is writing to x2.
    test_hdu(dut, 1, 2, 3, false, 2, true, true, "5. MEM Hazard on rs2");

    // --- TEST 6: False Hazard (Write Enable is 0) ---
    // Decode needs x1. EX has rd=x1, but is NOT writing to it (e.g., a Branch
    // instruction).
    test_hdu(dut, 1, 2, 1, false, 4, false, false,
             "6. False Hazard (EX Write Disabled)");

    // --- TEST 7: Ignore x0 (Zero Register) Hazard ---
    // Decode reads x0. EX is "writing" to x0. Since x0 is hardwired to 0, no
    // stall needed.
    test_hdu(dut, 0, 2, 0, true, 4, false, false, "7. Ignore x0 Hazard");

    // Clean up
    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}