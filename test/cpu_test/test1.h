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


void verify_results(Vcpu_core *dut)
{
    printf("\n--- Verifying Test Register States ---\n");
    EXPECT_EQ(dut->u_regfile->x[3], 30, "Check x3 value");
}
#endif  // TEST1_H
