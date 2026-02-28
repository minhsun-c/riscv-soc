#include <verilated.h>
#include <iostream>
#include "Vimm_gen.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace;
vluint64_t sim_time;

enum ImmSel {
    I_TYPE = 0,
    S_TYPE = 1,
    B_TYPE = 2,
    U_TYPE = 3,
    J_TYPE = 4,
    OTHERS = 7
};

void test_imm(Vimm_gen *dut,
              uint32_t inst,
              ImmSel sel,
              uint32_t expected,
              const char *label)
{
    dut->inst_i = inst;
    dut->sel_i = sel;
    dut->eval();

    EXPECT_EQ((uint32_t) dut->imm_o, expected, label);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vimm_gen *dut = new Vimm_gen;

    init_vcd(dut, "imm_gen.vcd");

    printf("--- Starting Immediate Generator Tests ---\n");

    // TEST 1: I-Type (e.g., addi x1, x1, -1)
    // Inst: [ -1 (12b) | rs1 | f3 | rd | opcode ] -> 0xFFF00093
    test_imm(dut, 0xFFF00093, I_TYPE, 0xFFFFFFFF, "I-Type: Negative Immediate");

    // TEST 2: S-Type (e.g., sw x1, 4(x2))
    // Inst: [ imm[11:5] | rs2 | rs1 | f3 | imm[4:0] | opcode ]
    // sw x1, -4(x2) -> imm is -4 (0xFFFFFFFC)
    // Bits: [ 1111111 | 00001 | 00010 | 010 | 11100 | 0100011 ] -> 0xFE112E23
    test_imm(dut, 0xFE112E23, S_TYPE, 0xFFFFFFFC, "S-Type: Negative Offset");

    // TEST 3: B-Type (e.g., beq x1, x2, -8)
    // Target is -8. Since LSB is 0, imm is 1111_1111_1000
    // Inst: [ imm[12]|imm[10:5] | rs2 | rs1 | f3 | imm[4:1]|imm[11] | opcode ]
    test_imm(dut, 0xFE208CE3, B_TYPE, 0xFFFFFFF8, "B-Type: Branch Backward");

    // TEST 4: U-Type (e.g., lui x1, 0x12345)
    // imm = 0x12345000
    test_imm(dut, 0x123450B7, U_TYPE, 0x12345000, "U-Type: Upper Immediate");

    // TEST 5: J-Type (e.g., jal x1, -256)
    // Target -256 (0xFFFFFF00)
    test_imm(dut, 0xF01FF0EF, J_TYPE, 0xFFFFFF00, "J-Type: Jump Backward");

    // TEST 6: R-Type (e.g., add x1, x2, x3)
    // Inst: [ funct7 | rs2 | rs1 | f3 | rd | opcode ]
    // add x1, x2, x3 -> 0x003100B3
    test_imm(dut, 0x003100B3, OTHERS, 0x00000000, "R-Type: No Immediate");

    // Clean up
    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}