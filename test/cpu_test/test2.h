#ifndef TEST2_H
#define TEST2_H

void load_program()
{
    printf("Loading Test 2: ALU Hazards & Branching...\n");
    // --- 1. ALU & Data Hazards ---
    imem[0] = 0x00a00093;  // 0:  addi x1, x0, 10
    imem[1] = 0x01400113;  // 4:  addi x2, x0, 20
    imem[2] = 0x002081b3;  // 8:  add  x3, x1, x2   (x3 = 30)
    imem[3] = 0x40118233;  // 12: sub  x4, x3, x1   (x4 = 20)

    // --- 2. Memory Access ---
    imem[4] = 0x00302223;  // 16: sw   x3, 4(x0)    (Mem[4] = 30)
    imem[5] = 0x00402283;  // 20: lw   x5, 4(x0)    (x5 = 30)

    // --- 3. Branching (BEQ) ---
    imem[6] = 0x00518463;  // 24: beq  x3, x5, 8    (Jump to PC 32)
    imem[7] = 0x06300313;  // 28: addi x6, x0, 99   (SKIPPED)
    imem[8] = 0x06400313;  // 32: addi x6, x0, 100  (x6 = 100)
}

void verify_results(Vcpu_core *dut)
{
    printf("\n--- Verifying Test 2 Register States ---\n");
    EXPECT_EQ(dut->u_regfile->x[3], 30, "ADD check (x3 = 10 + 20)");
    EXPECT_EQ(dut->u_regfile->x[4], 20, "SUB check (x4 = 30 - 10)");
    EXPECT_EQ(dut->u_regfile->x[5], 30, "LW check (x5 loaded 30)");
    EXPECT_EQ(dut->u_regfile->x[6], 100, "BEQ check (x6 is 100)");
}

#endif  // TEST2_H