#ifndef TEST11_H
#define TEST11_H

/*
 * Test 11: exceptions and mret.
 *
 * Three different traps go through one handler, which proves the mechanism is
 * generic rather than special-cased per cause:
 *
 *     ecall              mcause = 11
 *     0xFFFFFFFF         mcause = 2   (illegal instruction)
 *     lw from address 3  mcause = 4   (load address misaligned)
 *
 * The handler reads mcause, advances mepc past the faulting instruction, and
 * returns. Every trap must land back on the instruction after the one that
 * trapped, which is what the marker registers check.
 *
 *   main (0x00)
 *     0x00  addi  x5, x0, 0x40      handler address
 *     0x04  csrrw x0, mtvec, x5
 *     0x08  addi  x1, x0, 1         reached main
 *     0x0C  ecall                   -> trap 1
 *     0x10  addi  x2, x0, 99        returned from trap 1
 *     0x14  .word 0xFFFFFFFF        -> trap 2
 *     0x18  addi  x3, x0, 55        returned from trap 2
 *     0x1C  addi  x6, x0, 3         a deliberately odd address
 *     0x20  lw    x7, 0(x6)         -> trap 3
 *     0x24  addi  x8, x0, 77        returned from trap 3
 *     0x28  j .
 *
 *   handler (0x40)
 *     0x40  csrrs x10, mcause, x0   remember the cause
 *     0x44  csrrs x11, mepc, x0
 *     0x48  addi  x11, x11, 4       step over the faulting instruction
 *     0x4C  csrrw x0, mepc, x11
 *     0x50  addi  x12, x12, 1       count the traps
 *     0x54  mret
 */

void load_program()
{
    printf("Loading Test 11: ecall, illegal instruction, misaligned load...\n");

    imem[0] = 0x04000293;   // addi  x5, x0, 0x40
    imem[1] = 0x30529073;   // csrrw x0, mtvec, x5
    imem[2] = 0x00100093;   // addi  x1, x0, 1
    imem[3] = 0x00000073;   // ecall
    imem[4] = 0x06300113;   // addi  x2, x0, 99
    imem[5] = 0xFFFFFFFF;   // illegal instruction
    imem[6] = 0x03700193;   // addi  x3, x0, 55
    imem[7] = 0x00300313;   // addi  x6, x0, 3
    imem[8] = 0x00032383;   // lw    x7, 0(x6)     <- misaligned
    imem[9] = 0x04D00413;   // addi  x8, x0, 77
    imem[10] = 0x0000006F;  // j .

    // handler at 0x40
    imem[16] = 0x34202573;  // csrrs x10, mcause, x0
    imem[17] = 0x341025F3;  // csrrs x11, mepc, x0
    imem[18] = 0x00458593;  // addi  x11, x11, 4
    imem[19] = 0x34159073;  // csrrw x0, mepc, x11
    imem[20] = 0x00160613;  // addi  x12, x12, 1
    imem[21] = 0x30200073;  // mret
}

void verify_results(Vcore_core *dut)
{
    printf("\n--- Verifying Test 11 (exceptions and mret) ---\n");

    // Every marker after a trap proves mret landed on the right instruction.
    EXPECT_EQ(dut->u_regfile->x[1], 1, "main ran before the first trap");
    EXPECT_EQ(dut->u_regfile->x[2], 99, "returned past the ecall");
    EXPECT_EQ(dut->u_regfile->x[3], 55, "returned past the illegal instruction");
    EXPECT_EQ(dut->u_regfile->x[8], 77, "returned past the misaligned load");

    // The faulting load must not have written anything.
    EXPECT_EQ(dut->u_regfile->x[7], 0, "the misaligned load did not retire");

    EXPECT_EQ(dut->u_regfile->x[12], 3, "the handler ran three times");
    EXPECT_EQ(dut->u_regfile->x[10], 4, "last cause was load-address-misaligned");
}

#endif  // TEST11_H
