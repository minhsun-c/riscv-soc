#include <verilated.h>
#include <iostream>
#include <string>
#include "Vid_ex.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

void test_full_validation(Vid_ex *dut, bool rst, bool flush, const char *phase)
{
    // Set unique patterns for every input
    dut->rst_i = rst;
    dut->flush_i = flush;

    // Data Inputs
    dut->pc_i = 0x12345678;
    dut->pc_plus4_i = 0x1234567C;
    dut->rs1_data_i = 0xAAAA5555;
    dut->rs2_data_i = 0x5555AAAA;
    dut->imm_i = 0xFF00FF00;
    dut->rd_addr_i = 0x0F;

    // Control Inputs (Updated to match Verilog)
    dut->rd_wen_i = 1;
    dut->rd_src_i = 2;
    dut->alu_src_a_i = 1;
    dut->alu_src_b_i = 1;
    dut->alu_op_i = 7;
    dut->alu_shift_i = 1;
    dut->branch_i = 1;
    dut->branch_op_i = 4;
    dut->jump_i = 1;
    dut->mem_wen_i = 1;
    dut->mem_op_i = 3;
    tick(dut);

    std::string p = std::string(phase);
    bool active = (!rst && !flush);

    // Dynamic checks based on phase for ALL outputs
    EXPECT_EQ(dut->pc_ex_o, active ? 0x12345678 : 0, (p + ": pc").c_str());
    EXPECT_EQ(dut->pc_plus4_ex_o, active ? 0x1234567C : 0,
              (p + ": pc_plus4").c_str());
    EXPECT_EQ(dut->rs1_data_ex_o, active ? 0xAAAA5555 : 0,
              (p + ": rs1_data").c_str());
    EXPECT_EQ(dut->rs2_data_ex_o, active ? 0x5555AAAA : 0,
              (p + ": rs2_data").c_str());
    EXPECT_EQ(dut->imm_ex_o, active ? 0xFF00FF00 : 0, (p + ": imm").c_str());
    EXPECT_EQ((uint32_t) dut->rd_addr_ex_o, active ? 0x0F : 0,
              (p + ": rd_addr").c_str());

    EXPECT_EQ((bool) dut->rd_wen_ex_o, active ? 1 : 0,
              (p + ": rd_wen").c_str());
    EXPECT_EQ((uint32_t) dut->rd_src_ex_o, active ? 2 : 0,
              (p + ": rd_src").c_str());
    EXPECT_EQ((bool) dut->alu_src_a_ex_o, active ? 1 : 0,
              (p + ": alu_src_a").c_str());
    EXPECT_EQ((bool) dut->alu_src_b_ex_o, active ? 1 : 0,
              (p + ": alu_src_b").c_str());
    EXPECT_EQ((uint32_t) dut->alu_op_ex_o, active ? 7 : 0,
              (p + ": alu_op").c_str());
    EXPECT_EQ((bool) dut->alu_shift_ex_o, active ? 1 : 0,
              (p + ": alu_shift").c_str());
    EXPECT_EQ((bool) dut->branch_ex_o, active ? 1 : 0,
              (p + ": branch").c_str());
    EXPECT_EQ((uint32_t) dut->branch_op_ex_o, active ? 4 : 2,
              (p + ": branch_op").c_str());  // 2 is NOBR_OP
    EXPECT_EQ((bool) dut->jump_ex_o, active ? 1 : 0, (p + ": jump").c_str());
    EXPECT_EQ((bool) dut->mem_wen_ex_o, active ? 1 : 0,
              (p + ": mem_wen").c_str());
    EXPECT_EQ((uint32_t) dut->mem_op_ex_o, active ? 3 : 0,
              (p + ": mem_op").c_str());
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vid_ex *dut = new Vid_ex;
    init_vcd(dut, "id_ex.vcd");

    printf("--- Starting ID/EX Normalization Tests ---\n");

    test_full_validation(dut, 1, 0, "Hard Reset");
    test_full_validation(dut, 0, 0, "Normal Pass");
    test_full_validation(dut, 0, 1, "Pipeline Flush");
    test_full_validation(dut, 0, 0, "Normal Resume");

    printf("--- All Normalized Tests Complete ---\n");

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}