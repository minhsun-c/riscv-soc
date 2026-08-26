#ifndef TEST10_H
#define TEST10_H

/*
 * Test 10: a loop-dense program, for measuring branch prediction.
 *
 * A nested loop whose inner branch runs 500 times from one address. That is
 * exactly the shape a 2-bit predictor is built for: the counter saturates at
 * strongly-taken within a few iterations and stays there, and the only
 * mispredictions left are the ten loop exits -- one per outer iteration, and
 * each one costing a single misprediction rather than two, because hysteresis
 * keeps the counter predicting taken for the next entry.
 *
 *     x1 = 0                  outer counter
 *     x2 = 10                 outer limit
 *     x5 = 0                  accumulator
 *   outer:
 *     x3 = 0                  inner counter
 *     x4 = 50                 inner limit
 *   inner:
 *     x5 += x1
 *     x3 += 1
 *     bne x3, x4, inner       500 executions, 490 taken
 *     x1 += 1
 *     bne x1, x2, outer       10 executions, 9 taken
 *   done:
 *     j done
 *
 * x5 ends at 50 * (0+1+...+9) = 50 * 45 = 2250.
 */

void load_program()
{
    printf("Loading Test 10: nested loop, 510 branches...\n");

    imem[0] = 0x00000093;  // addi x1, x0, 0     i = 0
    imem[1] = 0x00A00113;  // addi x2, x0, 10    outer limit
    imem[2] = 0x00000293;  // addi x5, x0, 0     acc = 0

    // outer:  (PC 0x0C)
    imem[3] = 0x00000193;  // addi x3, x0, 0     j = 0
    imem[4] = 0x03200213;  // addi x4, x0, 50    inner limit

    // inner:  (PC 0x14)
    imem[5] = 0x001282B3;  // add  x5, x5, x1    acc += i
    imem[6] = 0x00118193;  // addi x3, x3, 1     j++
    imem[7] = 0xFE419CE3;  // bne  x3, x4, -8    -> inner

    imem[8] = 0x00108093;  // addi x1, x1, 1     i++
    imem[9] = 0xFE2094E3;  // bne  x1, x2, -24   -> outer

    // done:  (PC 0x28)
    imem[10] = 0x0000006F;  // jal x0, 0         spin
}

void verify_results(Vcore_core *dut)
{
    printf("\n--- Verifying Test 10 (loop-dense) ---\n");

    EXPECT_EQ(dut->u_regfile->x[1], 10, "outer counter reached its limit");
    EXPECT_EQ(dut->u_regfile->x[2], 10, "outer limit untouched");
    EXPECT_EQ(dut->u_regfile->x[3], 50, "inner counter reached its limit");
    EXPECT_EQ(dut->u_regfile->x[4], 50, "inner limit untouched");
    EXPECT_EQ(dut->u_regfile->x[5], 2250, "accumulator = 50 * (0+..+9)");
}

#endif  // TEST10_H
