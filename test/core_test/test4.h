#ifndef TEST4_H
#define TEST4_H

void load_program()
{
    printf("Loading Test 4: Function Calls, Stack Memory, & JALR...\n");

    // --- Caller ---
    // 0: Initialize Stack Pointer (sp / x2) to 4
    imem[0] = 0x00400113;  // addi x2, x0, 4      (x2 = 4)

    // 4: Call the function at PC 16
    imem[1] = 0x00c000ef;  // jal  x1, 12         (Jump to PC 16, x1 = PC+4 = 8)

    // 8: Return point! The function should bring us back here.
    imem[2] = 0x00110193;  // addi x3, x2, 1      (x3 = 4 + 1 = 5)

    // 12: Infinite loop / trap (If JALR fails, we get stuck here)
    imem[3] = 0x0000006f;  // jal  x0, 0          (Jump to self)

    // --- Callee (The Function) ---
    // 16: Save a register to the stack (memory)
    imem[4] = 0x00212023;  // sw   x2, 0(x2)      (Mem[4] = 4)

    // 20: Load the register back from the stack
    imem[5] = 0x00012203;  // lw   x4, 0(x2)      (x4 = Mem[4] = 4)

    // 24: Return to caller
    imem[6] =
        0x00008067;  // jalr x0, 0(x1)      (Jump to address in x1, which is 8)
}

void verify_results(Vcore_core *dut)
{
    printf("\n--- Verifying Test 4 Register States ---\n");

    EXPECT_EQ(dut->u_regfile->x[2], 4,
              "Stack Pointer init check (x2 = 4)");

    EXPECT_EQ(dut->u_regfile->x[1], 8,
              "JAL Link check (x1 saved return address PC 8)");

    EXPECT_EQ(dut->u_regfile->x[4], 4,
              "Stack LW/SW check (x4 successfully loaded 4 from memory)");

    EXPECT_EQ(dut->u_regfile->x[3], 5,
              "JALR Return check (x3 = 5, meaning CPU successfully returned to "
              "caller!)");
}

#endif  // TEST4_H