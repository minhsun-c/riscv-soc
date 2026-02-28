#ifndef TEST5_H
#define TEST5_H

void load_program()
{
    printf("Loading Test 5: AUIPC, LUI, Dynamic JALR, and Advanced ALU...\n");

    // --- 1. Upper Immediates & PC-Relative Math ---
    // PC 0: auipc x1, 2. (Upper 20 bits = 2). Target: PC(0) + (2 << 12)
    imem[0] = 0x00002097;  // auipc x1, 2      (x1 = 0 + 0x2000 = 0x00002000)

    // PC 4: auipc x2, 0. Target: PC(4) + 0
    imem[1] = 0x00000117;  // auipc x2, 0      (x2 = 4 + 0 = 4)

    // PC 8: lui x3, 5. (Upper 20 bits = 5). Target: (5 << 12)
    imem[2] = 0x000051b7;  // lui   x3, 5      (x3 = 0x00005000)

    // --- 2. Dynamic JALR ---
    // PC 12: jalr x4, 16(x2). Target = x2(which is 4) + 16 = PC 20.
    imem[3] = 0x01010267;  // jalr  x4, 16(x2) (x4 = PC+4 = 16, Jumps to 20!)

    // PC 16: SKIPPED
    imem[4] = 0x06300293;  // addi  x5, x0, 99 (SKIPPED by JALR)

    // PC 20: Landing Pad
    imem[5] = 0x06400293;  // addi  x5, x0, 100(x5 = 100)

    // --- 3. Advanced ALU Operations ---
    // PC 24: Load a negative number
    imem[6] = 0xff600313;  // addi  x6, x0, -10(x6 = -10 or 0xFFFFFFF6)

    // PC 28: Arithmetic Shift Right (Maintains sign bit!)
    imem[7] =
        0x40135393;  // srai  x7, x6, 1  (x7 = -10 >> 1 = -5 or 0xFFFFFFFB)

    // PC 32: Set Less Than (Signed comparison)
    imem[8] = 0x00732433;  // slt   x8, x6, x7 (Is -10 < -5? Yes, so x8 = 1)

    // PC 36: Logical XOR
    imem[9] = 0x005444b3;  // xor   x9, x8, x5 (x9 = 1 ^ 100 = 101)
}

void verify_results(Vcpu_core *dut)
{
    uint32_t pc_base =
        0x00009000;  // Adjust this to match your hardware start address
    printf("\n--- Verifying Test 5 Register States ---\n");

    EXPECT_EQ(dut->u_regfile->x[1], pc_base + 0x2000, "AUIPC check 1");
    EXPECT_EQ(dut->u_regfile->x[2], pc_base + 4, "AUIPC check 2");
    EXPECT_EQ(dut->u_regfile->x[3], 0x00005000,
              "LUI check");  // Absolute, stays same
    EXPECT_EQ(dut->u_regfile->x[4], pc_base + 16, "JALR Link check");
    EXPECT_EQ(dut->u_regfile->x[5], 100,
              "JALR Target check (x5 is 100, PC 16 was skipped)");

    // Advanced ALU
    EXPECT_EQ(dut->u_regfile->x[6], 0xFFFFFFF6,
              "Negative ADDI check (x6 = -10)");
    EXPECT_EQ(dut->u_regfile->x[7], 0xFFFFFFFB,
              "SRAI Arithmetic Shift check (x7 = -5)");
    EXPECT_EQ(dut->u_regfile->x[8], 1, "SLT check (x8 = 1, since -10 < -5)");
    EXPECT_EQ(dut->u_regfile->x[9], 101, "XOR check (x9 = 1 ^ 100 = 101)");
}

#endif  // TEST5_H