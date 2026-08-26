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
    // Old vectors pre-negate rs2 themselves and exercise no forwarding.
    dut->alu_sub_i = 0;
    dut->fwd_a_i = 0;
    dut->fwd_b_i = 0;
    dut->fwd_mem_data_i = 0xDEADBEEF;
    dut->fwd_wb_data_i = 0xDEADBEEF;
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

// Forwarding selectors, mirroring src/include/fwdsel.vh
static const uint8_t FWD_NONE = 0, FWD_MEM = 1, FWD_WB = 2;

// Drives the operand path directly: raw rs1/rs2 as id_ex would latch them, the
// two forwarding selectors, and the values MEM and WB are carrying this cycle.
void test_ex_fwd(Vex_stage *dut,
                 uint8_t alu_op,
                 bool src_a,
                 bool src_b,
                 bool alu_sub,
                 uint8_t fwd_a,
                 uint8_t fwd_b,
                 uint32_t rs1,
                 uint32_t rs2,
                 uint32_t mem_data,
                 uint32_t wb_data,
                 uint32_t imm,
                 uint32_t exp_res,
                 uint32_t exp_rs2_fwd,
                 const char *label)
{
    dut->alu_op_i = alu_op;
    dut->alu_src_a_i = src_a;
    dut->alu_src_b_i = src_b;
    dut->alu_shift_i = 0;
    dut->alu_sub_i = alu_sub;
    dut->branch_i = 0;
    dut->branch_op_i = 2;  // NOBR_OP
    dut->jump_i = 0;
    dut->pc_i = 0x1000;
    dut->rs1_data_i = rs1;
    dut->rs2_data_i = rs2;
    dut->imm_i = imm;
    dut->fwd_a_i = fwd_a;
    dut->fwd_b_i = fwd_b;
    dut->fwd_mem_data_i = mem_data;
    dut->fwd_wb_data_i = wb_data;
    dut->eval();

    std::string msg = std::string(label);
    EXPECT_EQ(dut->alu_result_o, exp_res, (msg + " (Result)").c_str());
    EXPECT_EQ(dut->rs2_fwd_o, exp_rs2_fwd, (msg + " (rs2_fwd_o)").c_str());

    tick(dut);
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

    printf("--- Forwarding and Subtraction ---\n");

    // Baseline: no forwarding, so id_ex's values are used as-is.
    test_ex_fwd(dut, 0, 0, 0, false, FWD_NONE, FWD_NONE, 100, 7, 0xAAAA, 0xBBBB,
                0, 107, 7, "F1. No forwarding");

    // Subtraction now happens here, not in id_stage: 100 - 7.
    test_ex_fwd(dut, 0, 0, 0, true, FWD_NONE, FWD_NONE, 100, 7, 0xAAAA, 0xBBBB,
                0, 93, 7, "F2. alu_sub negates rs2");

    // The store path leaves before the negation, so rs2_fwd_o is still 7 above.

    // Operand A taken from MEM / WB instead of the register file value.
    test_ex_fwd(dut, 0, 0, 0, false, FWD_MEM, FWD_NONE, 100, 7, 500, 900, 0,
                507, 7, "F3. rs1 from MEM");
    test_ex_fwd(dut, 0, 0, 0, false, FWD_WB, FWD_NONE, 100, 7, 500, 900, 0, 907,
                7, "F4. rs1 from WB");

    // Operand B taken from MEM / WB. rs2_fwd_o must follow, because that is
    // what a store in the same cycle would write to memory.
    test_ex_fwd(dut, 0, 0, 0, false, FWD_NONE, FWD_MEM, 100, 7, 500, 900, 0,
                600, 500, "F5. rs2 from MEM");
    test_ex_fwd(dut, 0, 0, 0, false, FWD_NONE, FWD_WB, 100, 7, 500, 900, 0,
                1000, 900, "F6. rs2 from WB");

    // A forwarded rs2 must still get negated when the instruction subtracts --
    // this is the case that breaks if the two's complement is left in id_stage.
    test_ex_fwd(dut, 0, 0, 0, true, FWD_NONE, FWD_MEM, 100, 7, 40, 900, 0, 60,
                40, "F7. Forwarded rs2, then negated");

    // Both operands forwarded, from different stages.
    test_ex_fwd(dut, 0, 0, 0, false, FWD_MEM, FWD_WB, 100, 7, 500, 900, 0, 1400,
                900, "F8. rs1 from MEM, rs2 from WB");

    // Forwarding is decided before the operand mux, so selecting pc or imm
    // wins: AUIPC-style (pc + imm) must ignore both forwarded values.
    test_ex_fwd(dut, 0, 1, 1, false, FWD_MEM, FWD_MEM, 100, 7, 500, 900, 0x20,
                0x1020, 500, "F9. pc+imm ignores forwarding");

    // But rs2_fwd_o still reports the forwarded value: the store data path does
    // not care which operand the ALU ended up using.

    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}