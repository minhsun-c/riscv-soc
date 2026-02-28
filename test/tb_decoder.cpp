#include <verilated.h>
#include <iostream>
#include <string>
#include "Vdecoder.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

void test_decode(Vdecoder *dut,
                 uint32_t inst,
                 uint8_t exp_opcode,
                 uint8_t exp_rd,
                 uint8_t exp_funct3,
                 uint8_t exp_rs1,
                 uint8_t exp_rs2,
                 uint8_t exp_funct7,
                 const char *label)
{
    dut->inst_i = inst;
    dut->eval();

    EXPECT_EQ((uint32_t) dut->opcode_o, (uint32_t) exp_opcode,
              (std::string(label) + " (Opcode)").c_str());
    EXPECT_EQ((uint32_t) dut->rd_o, (uint32_t) exp_rd,
              (std::string(label) + " (rd)").c_str());
    EXPECT_EQ((uint32_t) dut->funct3_o, (uint32_t) exp_funct3,
              (std::string(label) + " (funct3)").c_str());
    EXPECT_EQ((uint32_t) dut->rs1_o, (uint32_t) exp_rs1,
              (std::string(label) + " (rs1)").c_str());
    EXPECT_EQ((uint32_t) dut->rs2_o, (uint32_t) exp_rs2,
              (std::string(label) + " (rs2)").c_str());
    EXPECT_EQ((uint32_t) dut->funct7_o, (uint32_t) exp_funct7,
              (std::string(label) + " (funct7)").c_str());

    tick(dut);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vdecoder *dut = new Vdecoder;

    init_vcd(dut, "decoder.vcd");

    printf("--- Starting Decoder Tests ---\n");

    // TEST 1: R-Type (add x1, x2, x3)
    // Inst: [ 0000000 | 00011 | 00010 | 000 | 00001 | 0110011 ] -> 0x003100B3
    test_decode(dut, 0x003100B3, 0x33, 1, 0, 2, 3, 0x00, "1. R-Type (ADD)");

    // TEST 2: I-Type (addi x5, x6, -1)
    // Inst: [ 111111111111 | 00110 | 000 | 00101 | 0010011 ] -> 0xFFF30293
    // Note: rs2 overlaps with the lower part of the immediate (0x1F)
    test_decode(dut, 0xFFF30293, 0x13, 5, 0, 6, 0x1F, 0x7F, "2. I-Type (ADDI)");

    // TEST 3: S-Type (sw x4, 8(x8))
    // Inst: [ 0000000 | 00100 | 01000 | 010 | 01000 | 0100011 ] -> 0x00442423
    test_decode(dut, 0x00442423, 0x23, 8, 2, 8, 4, 0x00, "3. S-Type (SW)");

    // TEST 4: B-Type (beq x1, x2, -8)
    // Inst: [ 1111111 | 00010 | 00001 | 000 | 11001 | 1100011 ] -> 0xFE208CE3
    // Note: B-types don't have 'rd', so the bits [11:7] act as garbage output
    // for rd (0x19)
    test_decode(dut, 0xFE208CE3, 0x63, 0x19, 0, 1, 2, 0x7F, "4. B-Type (BEQ)");

    // TEST 5: U-Type (lui x1, 0x12345)
    // Inst: [ 0001001 | 00011 | 01000 | 101 | 00001 | 0110111 ] -> 0x123450B7
    test_decode(dut, 0x123450B7, 0x37, 1, 5, 8, 3, 0x09, "5. U-Type (LUI)");

    // TEST 6: J-Type (jal x1, -4096)
    // Inst: [ 1111000 | 00001 | 11111 | 111 | 00001 | 1101111 ] -> 0xF01FF0EF
    test_decode(dut, 0xF01FF0EF, 0x6F, 1, 7, 0x1F, 1, 0x78, "6. J-Type (JAL)");

    // Clean up
    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}