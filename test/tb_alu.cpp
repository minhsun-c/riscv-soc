#include <verilated.h>
#include <iostream>
#include "Valu.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace;
vluint64_t sim_time;

typedef enum {
    ALU_ADD = 0,   // 3'b000
    ALU_SLL = 1,   // 3'b001
    ALU_SLT = 2,   // 3'b010
    ALU_SLTU = 3,  // 3'b011
    ALU_XOR = 4,   // 3'b100
    ALU_SRL = 5,   // 3'b101
    ALU_OR = 6,    // 3'b110
    ALU_AND = 7    // 3'b111
} AluOp;

void test_alu_op(Valu *dut,
                 uint32_t a,
                 uint32_t b,
                 uint8_t op,
                 uint8_t shift_mode,
                 uint32_t expected,
                 const char *label)
{
    dut->a_i = a;
    dut->b_i = b;
    dut->op_i = op;
    dut->shift_mode_i = shift_mode;
    dut->eval();  // Compute the combinational logic

    EXPECT_EQ(dut->result_o, expected, label);
    tick(dut);
}

int main(int argc, char **argv)
{
    // 1. Initialize Verilator
    Verilated::commandArgs(argc, argv);
    Valu *dut = new Valu;

    init_vcd(dut, "alu.vcd");

    printf("--- Starting RISC-V ALU Unit Tests ---\n");

    // ============================================================
    // ARITHMETIC OPERATIONS
    // ============================================================

    // ADD: 15 + 10 = 25
    test_alu_op(dut, 15, 10, ALU_ADD, 0, 25, "ADD: 15 + 10");

    // SUB: 50 - 20 (Simulated as 50 + (~20 + 1))
    // In hex: 50 + 0xFFFFFFEC = 30
    uint32_t b_val = 20;
    test_alu_op(dut, 50, (~b_val + 1), ALU_ADD, 0, 30, "SUB: 50 - 20");

    // ============================================================
    // LOGICAL OPERATIONS
    // ============================================================

    // AND: 0x0F0F & 0xFFFF = 0x0F0F
    test_alu_op(dut, 0x0F0F, 0xFFFF, ALU_AND, 0, 0x0F0F, "AND: Masking");

    // OR: 0xF000 | 0x000F = 0xF00F
    test_alu_op(dut, 0xF000, 0x000F, ALU_OR, 0, 0xF00F, "OR: Combining");

    // XOR: 0xAAAA ^ 0x5555 = 0xFFFF
    test_alu_op(dut, 0xAAAA, 0x5555, ALU_XOR, 0, 0xFFFF, "XOR: Toggle");

    // ============================================================
    // SHIFT OPERATIONS
    // ============================================================

    // SLL: 1 << 4 = 16
    test_alu_op(dut, 1, 4, ALU_SLL, 0, 16, "SLL: Left shift by 4");

    // SRL: 0x80000000 >> 1 = 0x40000000 (Logical: shifts in a 0)
    test_alu_op(dut, 0x80000000, 1, ALU_SRL, 0, 0x40000000,
                "SRL: Logical right shift");

    // SRA: 0x80000000 >>> 1 = 0xC0000000 (Arithmetic: preserves sign bit)
    test_alu_op(dut, 0x80000000, 1, ALU_SRL, 1, 0xC0000000,
                "SRA: Arithmetic right shift");

    // --- Oversized Shift Amounts (Only lower 5 bits matter in RV32) ---

    // SLL: 1 << 32 -> 32 is 0x20. Lower 5 bits are 0. So 1 << 0 = 1.
    test_alu_op(dut, 1, 32, ALU_SLL, 0, 1, "SLL: Oversized shift (32)");

    // SRL: 0x80000000 >> 33 -> 33 is 0x21. Lower 5 bits are 1. So >> 1.
    test_alu_op(dut, 0x80000000, 33, ALU_SRL, 0, 0x40000000,
                "SRL: Oversized shift (33)");

    // SRA: 0x80000000 >>> 35 -> 35 is 0x23. Lower 5 bits are 3. So >>> 3.
    test_alu_op(dut, 0x80000000, 35, ALU_SRL, 1, 0xF0000000,
                "SRA: Oversized shift (35)");

    // ============================================================
    // COMPARISON OPERATIONS
    // ============================================================

    // SLT (Signed): -5 < 10 (True = 1)
    test_alu_op(dut, 0xFFFFFFFB, 10, ALU_SLT, 0, 1, "SLT: -5 < 10 (Signed)");

    // SLTU (Unsigned): 0xFFFFFFFB < 10 (False = 0)
    // Unsigned, 0xFFFFFFFB is 4.2 billion, which is NOT < 10
    test_alu_op(dut, 0xFFFFFFFB, 10, ALU_SLTU, 0, 0,
                "SLTU: Big < Small (Unsigned)");

    // Clean up
    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}