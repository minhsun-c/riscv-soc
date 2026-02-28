#include <verilated.h>
#include <iostream>
#include <string>
#include "Vmux2.h"  // Verilated header for mux2.v
#include "checker.h"

#define MODULE_HAS_CLK 0  // No clock needed for combinational mux
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

/**
 * Test function for the 2-to-1 Multiplexer
 */
void test_mux(Vmux2 *dut,
              uint32_t a,
              uint32_t b,
              bool sel,
              uint32_t expected,
              const char *label)
{
    dut->a_i = a;
    dut->b_i = b;
    dut->sel_i = sel;
    dut->eval();

    EXPECT_EQ(dut->out_o, expected, label);

    // Log state for VCD
    tick(dut);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vmux2 *dut = new Vmux2;

    init_vcd(dut, "mux2.vcd");

    printf("--- Starting Mux2 Logic Tests ---\n");

    // Case 1: Select Input A (sel = 0)
    test_mux(dut, 0xAAAA5555, 0x12345678, 0, 0xAAAA5555,
             "1. Select A (0xAAAA5555)");

    // Case 2: Select Input B (sel = 1)
    test_mux(dut, 0xAAAA5555, 0x12345678, 1, 0x12345678,
             "2. Select B (0x12345678)");

    // Case 3: Zero values
    test_mux(dut, 0, 0xFFFFFFFF, 0, 0, "3. Select A (Zero)");

    // Case 4: All ones
    test_mux(dut, 0, 0xFFFFFFFF, 1, 0xFFFFFFFF, "4. Select B (All Ones)");

    printf("--- Mux2 Tests Completed ---\n");

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}