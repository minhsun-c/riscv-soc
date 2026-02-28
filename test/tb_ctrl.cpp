#include <verilated.h>
#include <iostream>
#include <string>
#include "Vctrl.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

void test_ctrl(Vctrl *dut,
               uint8_t opcode,
               uint8_t funct3,
               uint8_t funct7,
               bool exp_rd_wen,
               uint8_t exp_imm_sel,
               bool exp_src_a,
               bool exp_src_b,
               uint8_t exp_alu_op,
               bool exp_shift,
               bool exp_sub,
               uint8_t exp_br_op,
               bool exp_branch,
               bool exp_jump,
               uint8_t exp_mem_op,
               bool exp_mem_wen,
               uint8_t exp_rd_src,
               const char *label)
{
    dut->opcode_i = opcode;
    dut->funct3_i = funct3;
    dut->funct7_i = funct7;
    dut->eval();

    std::string msg = std::string(label);
    EXPECT_EQ((bool) dut->rd_wen_o, exp_rd_wen, (msg + " (rd_wen)").c_str());
    EXPECT_EQ((uint32_t) dut->imm_sel_o, (uint32_t) exp_imm_sel,
              (msg + " (imm_sel)").c_str());
    EXPECT_EQ((bool) dut->alu_src_a_o, exp_src_a,
              (msg + " (alu_src_a)").c_str());
    EXPECT_EQ((bool) dut->alu_src_b_o, exp_src_b,
              (msg + " (alu_src_b)").c_str());
    EXPECT_EQ((uint32_t) dut->alu_op_o, (uint32_t) exp_alu_op,
              (msg + " (alu_op)").c_str());
    EXPECT_EQ((bool) dut->alu_shift_o, exp_shift,
              (msg + " (alu_shift)").c_str());
    EXPECT_EQ((bool) dut->alu_sub_o, exp_sub, (msg + " (alu_sub)").c_str());
    EXPECT_EQ((uint32_t) dut->branch_op_o, (uint32_t) exp_br_op,
              (msg + " (branch_op)").c_str());
    EXPECT_EQ((bool) dut->branch_o, exp_branch, (msg + " (branch)").c_str());
    EXPECT_EQ((bool) dut->jump_o, exp_jump, (msg + " (jump)").c_str());
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
    Vctrl *dut = new Vctrl;
    init_vcd(dut, "ctrl.vcd");

    // Opcodes per RISC-V Spec
    const uint8_t R_TYPE = 0x33, I_ALU = 0x13, I_LOAD = 0x03, S_TYPE = 0x23,
                  B_TYPE = 0x63, U_LUI = 0x37, U_AUIPC = 0x17, J_JAL = 0x6F,
                  I_JALR = 0x67;

    const uint8_t ADD = 0, SLT = 2, SLTU = 3, AND = 7, SRL = 5;
    const uint8_t NOBR = 2;  // Default func3 for non-branches

    // RD_SRC Mappings from your Verilog comments (0:ALU, 1:MEM, 2:PC+4, 3:ELSE)
    const uint8_t RD_ALU = 0, RD_MEM = 1, RD_PC4 = 2, RD_NONE = 3;

    printf("--- Starting Full 18-Test Control Unit Suite ---\n");

    // --- 1-3. R-TYPE (Reg-Reg) ---
    test_ctrl(dut, R_TYPE, 0x0, 0x00, 1, 7, 0, 0, ADD, 0, 0, NOBR, 0, 0, 0, 0,
              RD_ALU, "1. ADD (R)");
    test_ctrl(dut, R_TYPE, 0x0, 0x20, 1, 7, 0, 0, ADD, 0, 1, NOBR, 0, 0, 0, 0,
              RD_ALU, "2. SUB (R)");
    test_ctrl(dut, R_TYPE, 0x7, 0x00, 1, 7, 0, 0, AND, 0, 0, NOBR, 0, 0, 0, 0,
              RD_ALU, "3. AND (R)");

    // --- 4-6. I-TYPE (Reg-Imm) ---
    test_ctrl(dut, I_ALU, 0x0, 0x00, 1, 0, 0, 1, ADD, 0, 0, NOBR, 0, 0, 0, 0,
              RD_ALU, "4. ADDI");
    test_ctrl(dut, I_ALU, 0x5, 0x20, 1, 0, 0, 1, SRL, 1, 0, NOBR, 0, 0, 0, 0,
              RD_ALU, "5. SRAI");
    test_ctrl(dut, I_ALU, 0x5, 0x00, 1, 0, 0, 1, SRL, 0, 0, NOBR, 0, 0, 0, 0,
              RD_ALU, "6. SRLI");

    // --- 7-8. LOAD / STORE ---
    // Note: mem_op for LW/SW is the funct3 value (0x2 for LW/SW)
    test_ctrl(dut, I_LOAD, 0x2, 0x00, 1, 0, 0, 1, ADD, 0, 0, NOBR, 0, 0, 2, 0,
              RD_MEM, "7. LW");
    test_ctrl(dut, S_TYPE, 0x2, 0x00, 0, 1, 0, 1, ADD, 0, 0, NOBR, 0, 0, 2, 1,
              RD_NONE, "8. SW");

    // --- 9-14. BRANCHES ---
    test_ctrl(dut, B_TYPE, 0x0, 0x00, 0, 2, 0, 0, ADD, 0, 1, 0x0, 1, 0, 0, 0,
              RD_NONE, "9. BEQ");
    test_ctrl(dut, B_TYPE, 0x1, 0x00, 0, 2, 0, 0, ADD, 0, 1, 0x1, 1, 0, 0, 0,
              RD_NONE, "10. BNE");
    test_ctrl(dut, B_TYPE, 0x4, 0x00, 0, 2, 0, 0, SLT, 0, 0, 0x4, 1, 0, 0, 0,
              RD_NONE, "11. BLT");
    test_ctrl(dut, B_TYPE, 0x5, 0x00, 0, 2, 0, 0, SLT, 0, 0, 0x5, 1, 0, 0, 0,
              RD_NONE, "12. BGE");
    test_ctrl(dut, B_TYPE, 0x6, 0x00, 0, 2, 0, 0, SLTU, 0, 0, 0x6, 1, 0, 0, 0,
              RD_NONE, "13. BLTU");
    test_ctrl(dut, B_TYPE, 0x7, 0x00, 0, 2, 0, 0, SLTU, 0, 0, 0x7, 1, 0, 0, 0,
              RD_NONE, "14. BGEU");

    // --- 15-18. JUMPS / UPPER IMM ---
    // TEST 15 CHANGED: exp_src_b is now 1 (8th argument)
    test_ctrl(dut, J_JAL, 0x0, 0x00, 1, 4, 1, 1, ADD, 0, 0, NOBR, 0, 1, 0, 0,
              RD_PC4, "15. JAL");
    test_ctrl(dut, I_JALR, 0x0, 0x00, 1, 0, 0, 1, ADD, 0, 0, NOBR, 0, 1, 0, 0,
              RD_PC4, "16. JALR");
    test_ctrl(dut, U_LUI, 0x0, 0x00, 1, 3, 0, 1, ADD, 0, 0, NOBR, 0, 0, 0, 0,
              RD_ALU, "17. LUI");
    test_ctrl(dut, U_AUIPC, 0x0, 0x00, 1, 3, 1, 1, ADD, 0, 0, NOBR, 0, 0, 0, 0,
              RD_ALU, "18. AUIPC");

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}