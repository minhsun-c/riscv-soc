#ifndef TEST12_H
#define TEST12_H

#include <string>
extern std::string uart_out;

/*
 * Test 12: the whole thing at once.
 *
 * A program that prints through a memory-mapped UART while a memory-mapped
 * timer interrupts it periodically. Every part of the second half of the
 * course is load-bearing here:
 *
 *   week 16   csrrw / csrrs to program mtvec, mie and mstatus
 *   week 17   the trap path the interrupt arrives through, and mret
 *   week 19   both devices are reached over AXI4-Lite
 *   week 20   the timer's mtip wire, and the UART
 *
 *   main (0x00)
 *     0x00  addi  x5, x0, 0x60        handler address
 *     0x04  csrrw x0, mtvec, x5
 *     0x08  lui   x6, 0x10000         UART base
 *     0x0C  lui   x7, 0x10010         timer base
 *     0x10  addi  x8, x0, 200
 *     0x14  sw    x8, 8(x7)           mtimecmp = 200
 *     0x18  addi  x9, x0, 0x80
 *     0x1C  csrrs x0, mie, x9         enable the timer interrupt
 *     0x20  addi  x10, x0, 8
 *     0x24  csrrs x0, mstatus, x10    enable interrupts at all
 *     0x28..0x3C   print 'H', 'I', '\n'
 *     0x40  addi  x12, x0, 3
 *     0x44  bne   x13, x12, 0x44      wait here for three interrupts
 *     0x48  csrrc x0, mstatus, x10    turn interrupts off before stopping
 *     0x4C  j .
 *
 *   handler (0x60)
 *     0x60  addi  x13, x13, 1         count it
 *     0x64  lw    x15, 0(x7)          read mtime
 *     0x68  addi  x15, x15, 200
 *     0x6C  sw    x15, 8(x7)          push mtimecmp forward
 *     0x70  mret
 *
 * The handler advancing mtimecmp is not bookkeeping: mtip is a level, so a
 * handler that returns without moving mtimecmp re-enters immediately and
 * forever.
 *
 * The csrrc before the final spin is the same lesson from the other side. The
 * timer does not know the program has finished; it keeps counting and keeps
 * asking. Without that line the counter climbs past three and never stops --
 * which is exactly what the first version of this test did.
 */

void load_program()
{
    printf("Loading Test 12: UART output with timer interrupts...\n");

    imem[0]  = 0x06000293;  // addi  x5, x0, 0x60
    imem[1]  = 0x30529073;  // csrrw x0, mtvec, x5
    imem[2]  = 0x10000337;  // lui   x6, 0x10000
    imem[3]  = 0x100103B7;  // lui   x7, 0x10010
    imem[4]  = 0x0C800413;  // addi  x8, x0, 200
    imem[5]  = 0x0083A423;  // sw    x8, 8(x7)
    imem[6]  = 0x08000493;  // addi  x9, x0, 0x80
    imem[7]  = 0x3044A073;  // csrrs x0, mie, x9
    imem[8]  = 0x00800513;  // addi  x10, x0, 8
    imem[9]  = 0x30052073;  // csrrs x0, mstatus, x10
    imem[10] = 0x04800593;  // addi  x11, x0, 'H'
    imem[11] = 0x00B32023;  // sw    x11, 0(x6)
    imem[12] = 0x04900593;  // addi  x11, x0, 'I'
    imem[13] = 0x00B32023;  // sw    x11, 0(x6)
    imem[14] = 0x00A00593;  // addi  x11, x0, '\n'
    imem[15] = 0x00B32023;  // sw    x11, 0(x6)
    imem[16] = 0x00300613;  // addi  x12, x0, 3
    imem[17] = 0x00C69063;  // bne   x13, x12, 0
    imem[18] = 0x30053073;  // csrrc x0, mstatus, x10   turn interrupts off
    imem[19] = 0x0000006F;  // j .

    // handler at 0x60
    imem[24] = 0x00168693;  // addi  x13, x13, 1
    imem[25] = 0x0003A783;  // lw    x15, 0(x7)
    imem[26] = 0x0C878793;  // addi  x15, x15, 200
    imem[27] = 0x00F3A423;  // sw    x15, 8(x7)
    imem[28] = 0x30200073;  // mret
}

void verify_results(Vcpu_core *dut)
{
    printf("\n--- Verifying Test 12 (UART + timer interrupt) ---\n");

    // The UART actually emitted characters, in order, exactly once each.
    EXPECT_EQ((uint32_t) (uart_out == "HI\n"), 1u,
              "UART printed HI followed by a newline");
    if (uart_out != "HI\n")
        printf("          got: \"%s\"\n", uart_out.c_str());

    // The loop only exits when the handler has run three times, so reaching
    // this state at all proves interrupt entry and mret both work.
    EXPECT_EQ(dut->u_regfile->x[13], 3, "the handler ran three times");

    // Interrupts left the program's own registers alone.
    EXPECT_EQ(dut->u_regfile->x[6], 0x10000000, "UART base survived the interrupts");
    EXPECT_EQ(dut->u_regfile->x[7], 0x10010000, "timer base survived the interrupts");
    EXPECT_EQ(dut->u_regfile->x[12], 3, "the loop bound is intact");
}

#endif  // TEST12_H
