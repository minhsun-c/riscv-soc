#ifndef TEST1_H
#define TEST1_H

void load_program()
{
    printf("Loading Test 1: ALU Hazards...\n");
    // addi x1, x0, 10  (0x00a00093)
    imem[0] = 0x00a00093;
    // addi x2, x0, 20  (0x01400113)
    imem[1] = 0x01400113;
    // add  x3, x1, x2  (0x002081b3)
    imem[2] = 0x002081b3;
}

void verify_results(Vcore *dut)
{
    printf("\n--- Verifying Test 1 Register States ---\n");
    EXPECT_EQ(dut->core->u_regfile->x[3], 30,
              "Register x3 calculation check (10 + 20)");
}

#endif  // TEST1_H
