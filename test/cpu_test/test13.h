#ifndef TEST13_H
#define TEST13_H

#include <string>
#include "Vcpu_csr.h"
extern std::string uart_out;

/*
 * Test 13: the processor measures itself.
 *
 * Everything before this week was measured from outside -- the testbench
 * counted clock edges and divided. mcycle and minstret move that ability
 * inside, so a program can time a piece of itself and report the answer.
 *
 * The program times a twenty-iteration countdown loop, computes CPI to two
 * decimal places, and prints it through the UART:
 *
 *   csrrs x20, mcycle,   x0     open the window
 *   csrrs x21, minstret, x0
 *   ... the loop being measured ...
 *   csrrs x22, mcycle,   x0     close it
 *   csrrs x23, minstret, x0
 *   sub   x24, x22, x20         cycles
 *   sub   x25, x23, x21         instructions
 *
 * RV32I has neither multiply nor divide, so cycles*100 is three shifts and
 * two adds, and the division is repeated subtraction. All of it runs after
 * the window closes, which is the point: what you measure is what you put
 * between the two reads, and nothing else.
 *
 * Two things are checked. The digits the UART emitted must match the CPI
 * recomputed here from x24 and x25 -- that tests the software. And the
 * hardware mcycle must equal the number of clock edges this testbench
 * applied -- that tests the counter, against a clock the program cannot see.
 */

void load_program()
{
    printf("Loading Test 13: the CPU measures its own CPI...\n");

    imem[0 ] = 0x10000337;  // lui x6,0x10000
    imem[1 ] = 0xB0002A73;  // csrr x20,mcycle
    imem[2 ] = 0xB0202AF3;  // csrr x21,minstret
    imem[3 ] = 0x01400393;  // li x7,20
    imem[4 ] = 0xFFF38393;  // addi x7,x7,-1
    imem[5 ] = 0xFE039EE3;  // bnez x7,10 <loop>
    imem[6 ] = 0xB0002B73;  // csrr x22,mcycle
    imem[7 ] = 0xB0202BF3;  // csrr x23,minstret
    imem[8 ] = 0x414B0C33;  // sub x24,x22,x20
    imem[9 ] = 0x415B8CB3;  // sub x25,x23,x21
    imem[10] = 0x006C1D13;  // slli x26,x24,0x6
    imem[11] = 0x005C1D93;  // slli x27,x24,0x5
    imem[12] = 0x01BD0D33;  // add x26,x26,x27
    imem[13] = 0x002C1D93;  // slli x27,x24,0x2
    imem[14] = 0x01BD0D33;  // add x26,x26,x27
    imem[15] = 0x00000F93;  // li x31,0
    imem[16] = 0x019D4863;  // blt x26,x25,50 <div_done>
    imem[17] = 0x419D0D33;  // sub x26,x26,x25
    imem[18] = 0x001F8F93;  // addi x31,x31,1
    imem[19] = 0xFF5FF06F;  // j 40 <div>
    imem[20] = 0x000F8E33;  // add x28,x31,x0
    imem[21] = 0x00000E93;  // li x29,0
    imem[22] = 0x06400F13;  // li x30,100
    imem[23] = 0x01EE4863;  // blt x28,x30,6c <hund_done>
    imem[24] = 0x41EE0E33;  // sub x28,x28,x30
    imem[25] = 0x001E8E93;  // addi x29,x29,1
    imem[26] = 0xFF5FF06F;  // j 5c <hund>
    imem[27] = 0x030E8593;  // addi x11,x29,48
    imem[28] = 0x00B32023;  // sw x11,0(x6)
    imem[29] = 0x02E00593;  // li x11,46
    imem[30] = 0x00B32023;  // sw x11,0(x6)
    imem[31] = 0x00000E93;  // li x29,0
    imem[32] = 0x00A00F13;  // li x30,10
    imem[33] = 0x01EE4863;  // blt x28,x30,94 <tens_done>
    imem[34] = 0x41EE0E33;  // sub x28,x28,x30
    imem[35] = 0x001E8E93;  // addi x29,x29,1
    imem[36] = 0xFF5FF06F;  // j 84 <tens>
    imem[37] = 0x030E8593;  // addi x11,x29,48
    imem[38] = 0x00B32023;  // sw x11,0(x6)
    imem[39] = 0x030E0593;  // addi x11,x28,48
    imem[40] = 0x00B32023;  // sw x11,0(x6)
    imem[41] = 0x00A00593;  // li x11,10
    imem[42] = 0x00B32023;  // sw x11,0(x6)
    imem[43] = 0x0000006F;  // j ac <stop>
}

// Cycles the testbench clocked after reset was released. mcycle should agree.
static const uint32_t CLOCKED_CYCLES = 40000;

void verify_results(Vcpu_core *core)
{
    printf("\n--- Verifying Test 13 (self-measured CPI) ---\n");

    uint32_t cycles = core->u_regfile->x[24];
    uint32_t instrs = core->u_regfile->x[25];

    EXPECT_EQ((uint32_t) (instrs > 0), 1u, "the program retired instructions in its window");
    EXPECT_EQ((uint32_t) (cycles > instrs), 1u, "and spent more cycles than instructions");

    // The same arithmetic the program did, done independently.
    uint32_t cpi100 = instrs ? (cycles * 100) / instrs : 0;
    char want[8];
    snprintf(want, sizeof(want), "%u.%02u\n", cpi100 / 100, cpi100 % 100);

    EXPECT_EQ((uint32_t) (uart_out == want), 1u, "UART printed the CPI the numbers imply");
    printf("          cycles %u / instret %u -> CPI %s", cycles, instrs, want);
    if (uart_out != want)
        printf("          got: \"%s\"\n", uart_out.c_str());

    // The counter against an outside clock: this is the only check here that
    // the program itself could not have faked.
    uint32_t mcycle_lo = (uint32_t) core->u_csr->mcycle;
    EXPECT_EQ(mcycle_lo, CLOCKED_CYCLES, "mcycle counted every edge the testbench applied");

    // minstret is smaller by exactly the cycles that retired nothing.
    uint32_t minstret_lo = (uint32_t) core->u_csr->minstret;
    EXPECT_EQ((uint32_t) (minstret_lo > 0 && minstret_lo < mcycle_lo), 1u,
              "minstret counts retirements, not cycles");
}

#endif  // TEST13_H
