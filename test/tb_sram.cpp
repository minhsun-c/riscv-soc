#include <verilated.h>
#include <iostream>
#include <vector>
#include "Vsram.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace;
vluint64_t sim_time;

// Match the RISC-V func3 specification
enum LoadOp { LB = 0b000, LH = 0b001, LW = 0b010, LBU = 0b100, LHU = 0b101 };

enum StoreOp { SB = 0b000, SH = 0b001, SW = 0b010 };

void test_mem(Vsram *dut,
              uint32_t addr,
              uint32_t data,
              bool we,
              uint8_t f3,
              uint32_t expected,
              const char *label)
{
    dut->addr_i = addr;
    dut->func3_i = f3;

    if (we) {
        // --- PURE STORE ---
        dut->wdata_i = data;
        dut->we_i = 1;
        dut->eval();
        tick(dut);      // Synchronous write occurs here
        dut->we_i = 0;  // Disable write immediately after
        dut->eval();
    } else {
        // --- PURE LOAD ---
        dut->we_i = 0;
        dut->eval();
        EXPECT_EQ((uint32_t) dut->rdata_o, expected, label);
    }
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vsram *dut = new Vsram;

    init_vcd(dut, "sram.vcd");

    printf("--- Starting SRAM Subsystem Tests ---\n");

    // --- TEST 1: Full Word ---
    test_mem(dut, 0x04, 0xDEADBEEF, true, StoreOp::SW, 0, "SW at 0x04");
    test_mem(dut, 0x04, 0, false, LoadOp::LW, 0xDEADBEEF, "LW from 0x04");

    // --- TEST 2: Byte Writing (The -86 Error Fix) ---
    // Pure Store to Offset 1
    test_mem(dut, 0x09, 0xAA, true, StoreOp::SB, 0, "SB at 0x09");
    // Pure Load to verify bits [15:8]
    test_mem(dut, 0x09, 0, false, LoadOp::LB, 0xFFFFFFAA,
             "LB from 0x09 (Offset 1 Check)");
    // Pure Load of the whole word to see if other bytes are preserved
    test_mem(dut, 0x08, 0, false, LoadOp::LW, 0x0000AA00,
             "LW check of preserved bits at 0x08");

    // --- TEST 3: Sign Extension ---
    test_mem(dut, 0x0C, 0xFF, true, StoreOp::SB, 0, "SB 0xFF at 0x0C");
    test_mem(dut, 0x0C, 0, false, LoadOp::LB, 0xFFFFFFFF,
             "LB (Signed) check at 0x0C");
    test_mem(dut, 0x0C, 0, false, LoadOp::LBU, 0x000000FF,
             "LBU (Unsigned) check at 0x0C");

    // --- TEST 4: Half Word ---
    test_mem(dut, 0x12, 0x1234, true, StoreOp::SH, 0, "SH at 0x12");
    test_mem(dut, 0x12, 0, false, LoadOp::LH, 0x00001234, "LH from 0x12");

    // Clean up
    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}