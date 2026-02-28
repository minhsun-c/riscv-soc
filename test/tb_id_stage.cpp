#include <verilated.h>
#include <iostream>
#include <string>
#include "Vid_stage.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

void test_id(Vid_stage *dut,
             uint32_t inst,
             uint32_t rs1_val,
             uint32_t rs2_val,
             uint32_t exp_imm,
             uint32_t exp_rs2_out,
             bool exp_rd_wen,
             bool exp_src_a,
             bool exp_src_b,
             uint8_t exp_alu_op,
             bool exp_shift,
             uint8_t exp_br_op,
             bool exp_branch,
             bool exp_jump,
             uint8_t exp_mem_op,
             bool exp_mem_wen,
             uint8_t exp_rd_src,
             const char *label)
{
    dut->inst_i = inst;
    dut->rs1_data_i = rs1_val;
    dut->rs2_data_i = rs2_val;
    dut->eval();

    std::string msg = std::string(label);

    // --- Data Path Checks ---
    EXPECT_EQ(dut->imm_o, exp_imm, (msg + " (imm)").c_str());
    EXPECT_EQ(dut->rs2_data_o, exp_rs2_out, (msg + " (rs2 processed)").c_str());

    // --- Control Signal Checks ---
    EXPECT_EQ((bool) dut->rd_wen_o, exp_rd_wen, (msg + " (rd_wen)").c_str());
    EXPECT_EQ((bool) dut->alu_src_a_o, exp_src_a,
              (msg + " (alu_src_a)").c_str());
    EXPECT_EQ((bool) dut->alu_src_b_o, exp_src_b,
              (msg + " (alu_src_b)").c_str());
    EXPECT_EQ((uint32_t) dut->alu_op_o, (uint32_t) exp_alu_op,
              (msg + " (alu_op)").c_str());
    EXPECT_EQ((bool) dut->alu_shift_o, exp_shift,
              (msg + " (alu_shift)").c_str());

    // Branch/Jump Logic
    EXPECT_EQ((bool) dut->branch_o, exp_branch, (msg + " (branch)").c_str());
    EXPECT_EQ((uint32_t) dut->branch_op_o, (uint32_t) exp_br_op,
              (msg + " (branch_op)").c_str());
    EXPECT_EQ((bool) dut->jump_o, exp_jump, (msg + " (jump)").c_str());

    // Memory Interface (Updated)
    EXPECT_EQ((uint32_t) dut->mem_op_o, (uint32_t) exp_mem_op,
              (msg + " (mem_op)").c_str());
    EXPECT_EQ((bool) dut->mem_wen_o, exp_mem_wen, (msg + " (mem_wen)").c_str());
    EXPECT_EQ((uint32_t) dut->rd_src_o, (uint32_t) exp_rd_src,
              (msg + " (rd_src)").c_str());

    tick(dut);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vid_stage *dut = new Vid_stage;
    init_vcd(dut, "id_stage.vcd");

    const uint8_t ADD = 0, SLT = 2, SLTU = 3, AND = 7, SRL = 5;
    const uint8_t NOBR = 2;

    // RD_SRC Mappings (0:ALU, 1:MEM, 2:PC+4, 3:ELSE)
    const uint8_t RD_ALU = 0, RD_MEM = 1, RD_PC4 = 2, RD_NONE = 3;

    printf("--- Starting Comprehensive 18-Test ID Stage Suite ---\n");

    // --- 1-3. R-TYPE ---
    test_id(dut, 0x002081B3, 10, 20, 0, 20, 1, 0, 0, ADD, 0, NOBR, 0, 0, 0, 0,
            RD_ALU, "1. ADD (R)");
    test_id(dut, 0x402081B3, 10, 20, 0, 0xFFFFFFEC, 1, 0, 0, ADD, 0, NOBR, 0, 0,
            0, 0, RD_ALU, "2. SUB (R)");
    test_id(dut, 0x0020F1B3, 10, 20, 0, 20, 1, 0, 0, AND, 0, NOBR, 0, 0, 0, 0,
            RD_ALU, "3. AND (R)");

    // --- 4-6. I-TYPE (ALU) ---
    test_id(dut, 0xFF608093, 10, 20, 0xFFFFFFF6, 20, 1, 0, 1, ADD, 0, NOBR, 0,
            0, 0, 0, RD_ALU, "4. ADDI");
    test_id(dut, 0x4050D093, 10, 5, 0x405, 5, 1, 0, 1, SRL, 1, NOBR, 0, 0, 0, 0,
            RD_ALU, "5. SRAI");
    test_id(dut, 0x0050D093, 10, 5, 0x005, 5, 1, 0, 1, SRL, 0, NOBR, 0, 0, 0, 0,
            RD_ALU, "6. SRLI");

    // --- 7-8. LOAD / STORE ---
    // Note: mem_op for LW/SW is their funct3 (010 = 2)
    test_id(dut, 0x00452283, 100, 20, 4, 20, 1, 0, 1, ADD, 0, NOBR, 0, 0, 2, 0,
            RD_MEM, "7. LW");
    test_id(dut, 0x00552423, 100, 55, 8, 55, 0, 0, 1, ADD, 0, NOBR, 0, 0, 2, 1,
            RD_NONE, "8. SW");

    // --- 9-14. BRANCHES (With SUB inversion) ---
    test_id(dut, 0x00208863, 10, 10, 16, 0xFFFFFFF6, 0, 0, 0, ADD, 0, 0, 1, 0,
            0, 0, RD_NONE, "9. BEQ");
    test_id(dut, 0x00A09463, 10, 20, 8, 0xFFFFFFEC, 0, 0, 0, ADD, 0, 1, 1, 0, 0,
            0, RD_NONE, "10. BNE");
    test_id(dut, 0x00A0C063, 10, 20, 0, 20, 0, 0, 0, SLT, 0, 4, 1, 0, 0, 0,
            RD_NONE, "11. BLT");
    test_id(dut, 0x00A0D063, 10, 20, 0, 20, 0, 0, 0, SLT, 0, 5, 1, 0, 0, 0,
            RD_NONE, "12. BGE");
    test_id(dut, 0x00A0E063, 10, 20, 0, 20, 0, 0, 0, SLTU, 0, 6, 1, 0, 0, 0,
            RD_NONE, "13. BLTU");
    test_id(dut, 0x00A0F063, 10, 20, 0, 20, 0, 0, 0, SLTU, 0, 7, 1, 0, 0, 0,
            RD_NONE, "14. BGEU");

    // --- 15-18. JUMPS & UPPER IMM ---
    test_id(dut, 0x7D0000EF, 0, 0, 2000, 0, 1, 1, 0, ADD, 0, NOBR, 0, 1, 0, 0,
            RD_PC4, "15. JAL");
    test_id(dut, 0x00008067, 10, 0, 0, 0, 1, 0, 1, ADD, 0, NOBR, 0, 1, 0, 0,
            RD_PC4, "16. JALR");
    test_id(dut, 0x123450B7, 0, 0, 0x12345000, 0, 1, 0, 1, ADD, 0, NOBR, 0, 0,
            0, 0, RD_ALU, "17. LUI");
    test_id(dut, 0x12345017, 0, 0, 0x12345000, 0, 1, 1, 1, ADD, 0, NOBR, 0, 0,
            0, 0, RD_ALU, "18. AUIPC");

    printf("--- ID Stage Verification Complete ---\n");
    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}