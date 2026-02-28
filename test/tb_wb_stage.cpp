#include <verilated.h>
#include <iostream>
#include <string>
#include "Vwb_stage.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

void test_wb_stage(Vwb_stage *dut,
                   uint8_t rd_src,  // Changed from bool sel to 2-bit rd_src
                   uint32_t alu,
                   uint32_t mem,
                   uint32_t pc_plus4,  // Added pc_plus4 input
                   uint32_t exp,
                   const char *label)  // Added label for cleaner console output
{
    dut->rd_src_i = rd_src;
    dut->alu_result_i = alu;
    dut->mem_data_i = mem;
    dut->pc_plus4_i = pc_plus4;
    dut->eval();

    std::string msg = std::string(label) + " (WB Selection Check)";
    EXPECT_EQ(dut->wb_data_o, exp, msg.c_str());
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vwb_stage *dut = new Vwb_stage;

    // RD_SRC Mappings (0:ALU, 1:MEM, 2:PC+4, 3:NONE)
    const uint8_t RD_ALU = 0;
    const uint8_t RD_MEM = 1;
    const uint8_t RD_PC4 = 2;
    const uint8_t RD_NONE = 3;

    printf("--- Starting WB Stage Verification ---\n");

    // Params: dut, rd_src, alu_val, mem_val, pc4_val, expected_out, label

    // 1. Pick ALU
    test_wb_stage(dut, RD_ALU, 0x1111, 0x2222, 0x3333, 0x1111, "1. Pick ALU");

    // 2. Pick MEM
    test_wb_stage(dut, RD_MEM, 0x1111, 0x2222, 0x3333, 0x2222, "2. Pick MEM");

    // 3. Pick PC+4
    test_wb_stage(dut, RD_PC4, 0x1111, 0x2222, 0x3333, 0x3333, "3. Pick PC+4");

    // 4. Pick NONE (Expected output is 0)
    test_wb_stage(dut, RD_NONE, 0x1111, 0x2222, 0x3333, 0x0000, "4. Pick NONE");

    delete dut;
    TEST_SUMMARY();
    return 0;
}