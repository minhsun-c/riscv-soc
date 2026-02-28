#include <verilated.h>
#include <iostream>
#include <string>
#include "Vex_stage.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

void test_ex(Vex_stage *dut,
             uint8_t alu_op,
             bool src_a,
             bool src_b,
             bool alu_shift,
             bool branch_en,
             uint8_t branch_op,
             bool jump_en,
             uint32_t pc,
             uint32_t rs1,
             uint32_t rs2_proc,
             uint32_t imm,
             uint32_t exp_res,
             bool exp_jb,
             uint32_t exp_target,  // Added Target Check Parameter
             const char *label)
{
    dut->alu_op_i = alu_op;
    dut->alu_src_a_i = src_a;
    dut->alu_src_b_i = src_b;
    dut->alu_shift_i = alu_shift;
    dut->branch_i = branch_en;
    dut->branch_op_i = branch_op;
    dut->jump_i = jump_en;
    dut->pc_i = pc;
    dut->rs1_data_i = rs1;
    dut->rs2_data_i = rs2_proc;
    dut->imm_i = imm;
    dut->eval();

    std::string msg = std::string(label);

    EXPECT_EQ(dut->alu_result_o, exp_res, (msg + " (Result)").c_str());
    EXPECT_EQ((uint32_t) dut->jb_taken_o, (uint32_t) exp_jb,
              (msg + " (JB Taken)").c_str());
    EXPECT_EQ(dut->jb_target_o, exp_target,
              (msg + " (JB Target)").c_str());  // Added Assertion

    if (m_trace)
        m_trace->dump(sim_time++);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vex_stage *dut = new Vex_stage;
    init_vcd(dut, "ex_stage_full.vcd");

    const uint8_t ADD = 0, SLT = 2, SLTU = 3, XOR = 4, SRL = 5;
    const uint8_t BEQ = 0, BNE = 1, BLT = 4, BGE = 5, BLTU = 6, BGEU = 7;

    printf("--- Starting Full 20-Test EX Stage Suite ---\n");

    // Params: op, src_a, src_b, shift, br_en, br_op, jump_en | pc, rs1,
    // rs2_proc, imm | exp_res, exp_jb, exp_target | label

    // --- Basic Arithmetic (Non-branches use ALU Result as Target) ---
    test_ex(dut, ADD, 0, 0, 0, 0, 0, 0, 0x1000, 10, 20, 0, 30, 0, 30,
            "1. ADD: 10+20");
    test_ex(dut, ADD, 0, 0, 0, 0, 0, 0, 0x1000, 10, 0xFFFFFFEC, 0, 0xFFFFFFF6,
            0, 0xFFFFFFF6, "2. SUB: 10-20");
    test_ex(dut, XOR, 0, 0, 0, 0, 0, 0, 0x1000, 0xAA, 0x55, 0, 0xFF, 0, 0xFF,
            "3. XOR");
    test_ex(dut, ADD, 0, 1, 0, 0, 0, 0, 0x1000, 100, 0, 0xFFFFFFFB, 95, 0, 95,
            "4. ADDI: 100-5");

    // --- Equality Branches (Branches use PC + Imm as Target) ---
    test_ex(dut, ADD, 0, 0, 0, 1, BEQ, 0, 0x2000, 50, 0xFFFFFFCE, 4, 0, 1,
            0x2004, "5. BEQ: Taken");
    test_ex(dut, ADD, 0, 0, 0, 1, BEQ, 0, 0x2000, 50, 0xFFFFFFD8, 8, 10, 0,
            0x2008, "6. BEQ: Not Taken");
    test_ex(dut, ADD, 0, 0, 0, 1, BNE, 0, 0x2000, 50, 0xFFFFFFD8, 12, 10, 1,
            0x200C, "7. BNE: Taken");

    // --- Comparison Branches (Use SLT/SLTU) ---
    test_ex(dut, SLT, 0, 0, 0, 1, BLT, 0, 0x3000, 5, 10, 16, 1, 1, 0x3010,
            "8. BLT: Taken");
    test_ex(dut, SLT, 0, 0, 0, 1, BGE, 0, 0x3000, 5, 10, 20, 1, 0, 0x3014,
            "9. BGE: Not Taken");
    test_ex(dut, SLTU, 0, 0, 0, 1, BLTU, 0, 0x3000, 5, 10, 24, 1, 1, 0x3018,
            "10. BLTU: Taken");
    test_ex(dut, SLTU, 0, 0, 0, 1, BGEU, 0, 0x3000, 10, 5, 28, 0, 1, 0x301C,
            "11. BGEU: Taken");

    // --- Shifts & Jump Targets (Jumps use ALU Result as Target) ---
    test_ex(dut, SRL, 0, 1, 1, 0, 0, 0, 0x4000, 0xFFFFFFF0, 0, 2, 0xFFFFFFFC, 0,
            0xFFFFFFFC, "12. SRAI");
    test_ex(dut, ADD, 1, 1, 0, 0, 0, 1, 0x1000, 0, 0, 0x10, 0x1010, 1, 0x1010,
            "13. JAL: Redirect");
    test_ex(dut, ADD, 0, 1, 0, 0, 0, 1, 0x1000, 100, 0, 4, 104, 1, 104,
            "14. JALR Target");
    test_ex(dut, ADD, 0, 1, 0, 0, 0, 0, 0x1000, 200, 55, 8, 208, 0, 208,
            "15. SW Address");

    // --- Upper Immediates ---
    test_ex(dut, ADD, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0x12345000, 0x12345000, 0,
            0x12345000, "16. LUI");
    test_ex(dut, ADD, 1, 1, 0, 0, 0, 0, 0x1000, 0, 0, 0x12345000, 0x12346000, 0,
            0x12346000, "17. AUIPC");

    // --- Edge Cases ---
    test_ex(dut, ADD, 0, 0, 0, 0, 0, 0, 0, 0x7FFFFFFF, 1, 0, 0x80000000, 0,
            0x80000000, "18. Signed Overflow");
    test_ex(dut, SLTU, 0, 0, 0, 0, 0, 0, 0, 0xFFFFFFFF, 0, 0, 0, 0, 0,
            "19. SLTU MAX < 0");
    // Test 20: PC = 0x100, Imm = -10 (0xFFFFFFF6). Target = 0x100 - 10 = 0xF6
    test_ex(dut, ADD, 1, 1, 0, 1, BNE, 0, 0x100, 10, 0, 0xFFFFFFF6, 0xF6, 1,
            0x000000F6, "20. BNE with Imm Target");

    printf("--- All 20 EX Stage Tests Passed ---\n");
    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}