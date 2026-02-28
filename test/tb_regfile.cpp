#include <verilated.h>
#include <iostream>
#include "Vregfile.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace;
vluint64_t sim_time;

/**
 * Functional test wrapper for the Register File
 * Handles the Write -> Clock Tick -> Read sequence
 */
void test_regfile(Vregfile *dut,
                  uint8_t write_addr,
                  uint32_t write_data,
                  bool we,
                  uint8_t read_addr1,
                  uint8_t read_addr2,
                  uint32_t expected1,
                  uint32_t expected2,
                  const char *label)
{
    // Set Write Port signals
    dut->rd_we_i = we;
    dut->rd_addr_i = write_addr;
    dut->rd_data_i = write_data;

    // Trigger the synchronous write
    tick(dut);

    // Set Read Port addresses
    dut->rs1_addr_i = read_addr1;
    dut->rs2_addr_i = read_addr2;

    // Asynchronous read: propagation happens during eval
    dut->eval();

    // Verify results for both ports
    EXPECT_EQ(dut->rs1_data_o, expected1,
              (std::string(label) + " (Port 1)").c_str());
    EXPECT_EQ(dut->rs2_data_o, expected2,
              (std::string(label) + " (Port 2)").c_str());
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vregfile *dut = new Vregfile;

    init_vcd(dut, "regfile.vcd");

    printf("--- Starting Functional Register File Tests ---\n");

    // 1. Initialize System with Reset
    dut->rst_i = 1;
    tick(dut);
    dut->rst_i = 0;
    dut->eval();

    // 2. Test Case: Write to x1, Read back from x1 and x2
    test_regfile(dut, 1, 0x12345678, true, 1, 2, 0x12345678, 0,
                 "Write x1, Read x1/x2");

    // 3. Test Case: Write to x2, Read back from x1 and x2
    test_regfile(dut, 2, 0xABCDE001, true, 1, 2, 0x12345678, 0xABCDE001,
                 "Write x2, Read x1/x2");

    // 4. Test Case: x0 Protection (Attempt to write 0x55)
    // Even after writing, rs1_addr_i = 0 must return 0.
    test_regfile(dut, 0, 0x55555555, true, 0, 1, 0, 0x12345678,
                 "x0 Hardwired Zero Test");

    // 5. Test Case: Write Enable False (Attempt to write to x3)
    test_regfile(dut, 3, 0xFFFFFFFF, false, 3, 0, 0, 0,
                 "Write Enable False Test");

    // Clean up
    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}