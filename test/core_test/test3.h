#ifndef TEST3_H
#define TEST3_H

void load_program()
{
    printf("Loading Test 3: Iterative Loop (Backwards Jumps & Hazards)...\n");

    // --- Iterative Loop: sum = 0; for(i=5; i>0; i--) sum += i; ---
    // Expected Result: sum (x2) = 15

    // --- Initialization ---
    imem[0] = 0x00500093;  //  0: addi x1, x0, 5      (x1 = 5, loop counter 'i')
    imem[1] =
        0x00000113;  //  4: addi x2, x0, 0      (x2 = 0, accumulator 'sum')

    // --- Loop Start ---
    imem[2] =
        0x00008863;  //  8: beq  x1, x0, 16     (If i == 0, break loop to PC 24)
    imem[3] = 0x00110133;  // 12: add  x2, x2, x1     (sum += i)
    imem[4] = 0xfff08093;  // 16: addi x1, x1, -1     (i--)
    imem[5] = 0xff5ff06f;  // 20: jal  x0, -12        (Unconditional jump back
                           // to PC 8)

    // --- Loop End ---
    imem[6] =
        0x00010193;  // 24: addi x3, x2, 0      (x3 = final sum, expected 15)
}

void verify_results(Vcore *dut)
{
    printf("\n--- Verifying Test 3 Register States ---\n");
    // The loop calculates 5 + 4 + 3 + 2 + 1 = 15
    EXPECT_EQ(dut->core->u_regfile->x[1], 0,
              "Loop Counter check (x1 reached 0)");
    EXPECT_EQ(dut->core->u_regfile->x[2], 15, "Accumulator check (x2 = 15)");
    EXPECT_EQ(dut->core->u_regfile->x[3], 15,
              "Final Assignment check (x3 = 15)");
}

#endif  // TEST3_H