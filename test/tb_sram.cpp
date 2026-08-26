#include <verilated.h>
#include <iostream>
#include <string>
#include "Vsram.h"
#include "checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

// Issue one access and settle. This memory answers immediately (LATENCY 0),
// so rvalid is just req echoed back and rdata is combinational.
static void access(Vsram *dut, uint32_t addr, uint32_t wdata, uint8_t wstrb)
{
    dut->req_i = 1;
    dut->addr_i = addr;
    dut->wdata_i = wdata;
    dut->wstrb_i = wstrb;
    dut->eval();
    tick(dut);
    dut->req_i = 0;
}

static uint32_t read_word(Vsram *dut, uint32_t addr)
{
    dut->req_i = 1;
    dut->addr_i = addr;
    dut->wstrb_i = 0;
    dut->eval();
    uint32_t v = dut->rdata_o;
    dut->req_i = 0;
    return v;
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vsram *dut = new Vsram;

    init_vcd(dut, "sram.vcd");

    printf("--- Starting SRAM Tests ---\n");

    dut->req_i = 0;
    dut->wstrb_i = 0;
    tick(dut);

    // Since week 18 this module stores and nothing else: no alignment, no sign
    // extension, no notion of LB versus LW. It takes a word and a byte mask.
    EXPECT_EQ((uint32_t) dut->ready_o, 1u, "1. Always ready to accept");

    // --- Whole-word write ---
    access(dut, 0x100, 0xDEADBEEF, 0b1111);
    EXPECT_EQ(read_word(dut, 0x100), 0xDEADBEEFu, "2. Full word written");

    // --- Byte lanes: each strobe bit touches exactly one byte ---
    access(dut, 0x100, 0x000000AA, 0b0001);
    EXPECT_EQ(read_word(dut, 0x100), 0xDEADBEAAu, "3. Lane 0 only");
    access(dut, 0x100, 0x0000BB00, 0b0010);
    EXPECT_EQ(read_word(dut, 0x100), 0xDEADBBAAu, "4. Lane 1 only");
    access(dut, 0x100, 0x00CC0000, 0b0100);
    EXPECT_EQ(read_word(dut, 0x100), 0xDECCBBAAu, "5. Lane 2 only");
    access(dut, 0x100, 0xDD000000, 0b1000);
    EXPECT_EQ(read_word(dut, 0x100), 0xDDCCBBAAu, "6. Lane 3 only");

    // --- Halfword strobes ---
    access(dut, 0x200, 0xFFFFFFFF, 0b1111);
    access(dut, 0x200, 0x00001234, 0b0011);
    EXPECT_EQ(read_word(dut, 0x200), 0xFFFF1234u, "7. Low half only");
    access(dut, 0x200, 0x56780000, 0b1100);
    EXPECT_EQ(read_word(dut, 0x200), 0x56781234u, "8. High half only");

    // --- A read is a request with no strobes set ---
    access(dut, 0x300, 0x11111111, 0b1111);
    access(dut, 0x300, 0x99999999, 0b0000);
    EXPECT_EQ(read_word(dut, 0x300), 0x11111111u, "9. wstrb = 0 does not write");

    // --- The low two address bits are not part of the index ---
    // Byte lane selection is lsu.v's job now; this module only sees words.
    EXPECT_EQ(read_word(dut, 0x302), 0x11111111u, "10. Address 0x302 is the same word");

    // --- Words are independent ---
    EXPECT_EQ(read_word(dut, 0x100), 0xDDCCBBAAu, "11. Earlier word untouched");

    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}
