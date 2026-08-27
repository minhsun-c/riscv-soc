#include <verilated.h>
#include <iostream>
#include <string>
#include "Vcsr.h"
#include "Vcsr_csr.h"
#include "Vcsr___024root.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

// Zicsr funct3 encodings, mirroring src/include/csrop.vh
static const uint8_t OP_RW = 0b001, OP_RS = 0b010, OP_RC = 0b011;
static const uint8_t OP_RWI = 0b101, OP_RSI = 0b110, OP_RCI = 0b111;

// CSR numbers, mirroring src/include/csraddr.vh
static const uint16_t MSTATUS = 0x300, MTVEC = 0x305, MSCRATCH = 0x340;
static const uint16_t MEPC = 0x341, MCAUSE = 0x342;
static const uint16_t UNIMPL = 0xF14;  // mhartid: not implemented here
static const uint16_t MCYCLE = 0xB00, MINSTRET = 0xB02;
static const uint16_t MCYCLEH = 0xB80, MINSTRETH = 0xB82;

static uint32_t read_csr(Vcsr *dut, uint16_t addr)
{
    dut->raddr_i = addr;
    dut->wen_i = 0;
    dut->eval();
    return dut->rdata_o;
}

// One Zicsr instruction: returns what rd would get (the value before the write).
static uint32_t csr_access(Vcsr *dut, uint16_t addr, uint8_t op, uint32_t operand)
{
    dut->raddr_i = addr;
    dut->op_i = op;
    dut->operand_i = operand;
    dut->wen_i = 1;
    dut->eval();
    uint32_t old = dut->rdata_o;
    tick(dut);
    dut->wen_i = 0;
    return old;
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vcsr *dut = new Vcsr;

    init_vcd(dut, "csr.vcd");

    printf("--- Starting CSR File Tests ---\n");

    dut->rst_i = 1;
    dut->wen_i = 0;
    tick(dut);
    dut->rst_i = 0;

    // --- 1-2. Everything starts at zero ---
    EXPECT_EQ(read_csr(dut, MSTATUS), 0u, "1. mstatus resets to 0");
    EXPECT_EQ(read_csr(dut, MTVEC), 0u, "2. mtvec resets to 0");

    // --- 3-4. CSRRW: rd gets the OLD value, the CSR gets the new one ---
    // This is what makes "swap a CSR" one instruction.
    EXPECT_EQ(csr_access(dut, MSCRATCH, OP_RW, 0xAAAA0000), 0u,
              "3. CSRRW returns the value from before the write");
    EXPECT_EQ(read_csr(dut, MSCRATCH), 0xAAAA0000u, "4. ... and the write landed");

    // --- 5-6. CSRRS sets bits without touching the others ---
    EXPECT_EQ(csr_access(dut, MSCRATCH, OP_RS, 0x0000FFFF), 0xAAAA0000u,
              "5. CSRRS also returns the old value");
    EXPECT_EQ(read_csr(dut, MSCRATCH), 0xAAAAFFFFu, "6. CSRRS OR-ed the operand in");

    // --- 7-8. CSRRC clears the bits the operand names ---
    EXPECT_EQ(csr_access(dut, MSCRATCH, OP_RC, 0x0000FF00), 0xAAAAFFFFu,
              "7. CSRRC returns the old value");
    EXPECT_EQ(read_csr(dut, MSCRATCH), 0xAAAA00FFu, "8. CSRRC cleared only those bits");

    // --- 9-11. The immediate forms do the same three things ---
    csr_access(dut, MTVEC, OP_RWI, 0x1F);
    EXPECT_EQ(read_csr(dut, MTVEC), 0x1Fu, "9. CSRRWI writes");
    csr_access(dut, MTVEC, OP_RSI, 0x20);
    EXPECT_EQ(read_csr(dut, MTVEC), 0x3Fu, "10. CSRRSI sets");
    csr_access(dut, MTVEC, OP_RCI, 0x0F);
    EXPECT_EQ(read_csr(dut, MTVEC), 0x30u, "11. CSRRCI clears");

    // --- 12. Registers are independent ---
    EXPECT_EQ(read_csr(dut, MSCRATCH), 0xAAAA00FFu, "12. mscratch untouched by mtvec");

    // --- 13-14. Back-to-back on the same CSR ---
    // The whole reason csr reads and writes in one stage: instruction N+1 is
    // one cycle behind N, so it sees what N wrote. No forwarding needed.
    csr_access(dut, MEPC, OP_RW, 0x1000);
    EXPECT_EQ(csr_access(dut, MEPC, OP_RS, 0x0004), 0x1000u,
              "13. Next instruction sees the previous write");
    EXPECT_EQ(read_csr(dut, MEPC), 0x1004u, "14. ... and builds on it");

    // --- 15-16. wen low means nothing happens ---
    dut->raddr_i = MCAUSE;
    dut->op_i = OP_RW;
    dut->operand_i = 0xDEADBEEF;
    dut->wen_i = 0;
    tick(dut);
    EXPECT_EQ(read_csr(dut, MCAUSE), 0u, "15. No write without wen");
    EXPECT_EQ(read_csr(dut, MSCRATCH), 0xAAAA00FFu, "16. ... and nothing else moved");

    // --- 17-18. An unimplemented CSR reads zero and swallows writes ---
    // The spec allows this for machine CSRs the implementation does not have,
    // and it saves the decoder from carrying a list of legal addresses.
    csr_access(dut, UNIMPL, OP_RW, 0x12345678);
    EXPECT_EQ(read_csr(dut, UNIMPL), 0u, "17. Unimplemented CSR still reads 0");
    EXPECT_EQ(read_csr(dut, MSCRATCH), 0xAAAA00FFu, "18. ... and did not alias onto a real one");

    // --- 19-21. mcycle counts cycles, minstret counts only retirements ---
    // A counter that stopped while something interesting was happening could
    // not measure the interesting thing, so mcycle has no enable at all.
    dut->instret_i = 0;
    uint32_t c0 = read_csr(dut, MCYCLE);
    uint32_t i0 = read_csr(dut, MINSTRET);
    for (int k = 0; k < 5; k++)
        tick(dut);
    EXPECT_EQ(read_csr(dut, MCYCLE) - c0, 5u, "19. mcycle advanced one per cycle");
    EXPECT_EQ(read_csr(dut, MINSTRET) - i0, 0u, "20. minstret stayed put with nothing retiring");

    dut->instret_i = 1;
    for (int k = 0; k < 4; k++)
        tick(dut);
    dut->instret_i = 0;
    EXPECT_EQ(read_csr(dut, MINSTRET) - i0, 4u, "21. minstret counted the four retirements");

    // --- 22-24. The counters are 64 bits, reached through two CSRs ---
    // Ticking to 2^32 is not an option, so the low half is planted just short
    // of the wrap and the carry is watched cross into mcycleh.
    EXPECT_EQ(read_csr(dut, MCYCLEH), 0u, "22. mcycleh is still zero this early");

    dut->rootp->csr->mcycle = 0xFFFFFFFFull;
    tick(dut);
    EXPECT_EQ(read_csr(dut, MCYCLE), 0u, "23. the low half wrapped to zero");
    EXPECT_EQ(read_csr(dut, MCYCLEH), 1u, "24. ... and carried into mcycleh");

    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}
