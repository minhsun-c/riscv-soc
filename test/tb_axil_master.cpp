#include <verilated.h>
#include <iostream>
#include <string>
#include "Vaxil_master.h"
#include "checker.h"
#include "axil_checker.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

static AxiLiteChecker axi;

// A minimal but deliberately awkward slave: it takes the write address first
// and the write data only on a later cycle. A master that assumes AW and W
// move together will hang here, which is the whole point of the exercise.
struct FakeSlave {
    uint32_t mem[64] = {0};
    bool aw_taken = false;
    uint32_t aw_addr = 0;
    int b_wait = -1;   // >= 0 means a write response is on its way
    int r_wait = -1;
    uint32_t r_data = 0;

    // Drive the slave-side inputs for this cycle, from state only.
    void drive(Vaxil_master *dut)
    {
        dut->awready_i = !aw_taken && (b_wait < 0);
        dut->wready_i = aw_taken;            // data only after the address
        dut->arready_i = (r_wait < 0);
        dut->bvalid_i = (b_wait == 0);
        dut->rvalid_i = (r_wait == 0);
        dut->rdata_i = r_data;
        dut->bresp_i = 0;
        dut->rresp_i = 0;
    }

    // Apply this cycle's handshakes, after eval.
    void settle(Vaxil_master *dut)
    {
        if (dut->awvalid_o && dut->awready_i) {
            aw_taken = true;
            aw_addr = dut->awaddr_o;
        }
        if (dut->wvalid_o && dut->wready_i) {
            uint32_t idx = (aw_addr >> 2) & 63;
            for (int i = 0; i < 4; i++)
                if (dut->wstrb_o & (1 << i))
                    mem[idx] = (mem[idx] & ~(0xFFu << (8 * i)))
                               | (dut->wdata_o & (0xFFu << (8 * i)));
            aw_taken = false;
            b_wait = 1;
        } else if (b_wait > 0) {
            b_wait--;
        } else if (b_wait == 0 && dut->bready_o) {
            b_wait = -1;
        }

        if (dut->arvalid_o && dut->arready_i) {
            r_data = mem[(dut->araddr_o >> 2) & 63];
            r_wait = 1;
        } else if (r_wait > 0) {
            r_wait--;
        } else if (r_wait == 0 && dut->rready_o) {
            r_wait = -1;
        }
    }
};

static FakeSlave slave;

static void cycle(Vaxil_master *dut)
{
    slave.drive(dut);
    dut->eval();
    axi.cycle(dut->awvalid_o, dut->awready_i, dut->awaddr_o,
              dut->wvalid_o, dut->wready_i, dut->wdata_o, dut->wstrb_o,
              dut->bvalid_i, dut->bready_o,
              dut->arvalid_o, dut->arready_i, dut->araddr_o,
              dut->rvalid_i, dut->rready_o, dut->rdata_i);
    slave.settle(dut);
    tick(dut);
}

// Drive one core-side request through to completion.
static uint32_t transact(Vaxil_master *dut, uint32_t addr, uint32_t data,
                         uint8_t strb)
{
    for (int i = 0; i < 100 && !dut->ready_o; i++) cycle(dut);

    dut->req_i = 1;
    dut->addr_i = addr;
    dut->wdata_i = data;
    dut->wstrb_i = strb;
    cycle(dut);
    dut->req_i = 0;

    uint32_t got = 0;
    for (int i = 0; i < 200; i++) {
        slave.drive(dut);
        dut->eval();
        bool done = dut->rvalid_o;
        if (done) got = dut->rdata_o;
        axi.cycle(dut->awvalid_o, dut->awready_i, dut->awaddr_o,
                  dut->wvalid_o, dut->wready_i, dut->wdata_o, dut->wstrb_o,
                  dut->bvalid_i, dut->bready_o,
                  dut->arvalid_o, dut->arready_i, dut->araddr_o,
                  dut->rvalid_i, dut->rready_o, dut->rdata_i);
        slave.settle(dut);
        tick(dut);
        if (done) break;
    }
    return got;
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vaxil_master *dut = new Vaxil_master;

    init_vcd(dut, "axil_master.vcd");

    printf("--- Starting AXI4-Lite Master Tests ---\n");

    dut->rst_i = 1;
    dut->req_i = 0;
    cycle(dut);
    dut->rst_i = 0;

    // --- Writes, then read them back through the same adapter ---
    transact(dut, 0x00, 0xDEADBEEF, 0b1111);
    EXPECT_EQ(transact(dut, 0x00, 0, 0), 0xDEADBEEFu, "1. Word written and read back");

    transact(dut, 0x04, 0x11223344, 0b1111);
    EXPECT_EQ(transact(dut, 0x04, 0, 0), 0x11223344u, "2. A second address");
    EXPECT_EQ(transact(dut, 0x00, 0, 0), 0xDEADBEEFu, "3. The first one is untouched");

    // --- Byte strobes survive the trip ---
    transact(dut, 0x08, 0xFFFFFFFF, 0b1111);
    transact(dut, 0x08, 0x0000AA00, 0b0010);
    EXPECT_EQ(transact(dut, 0x08, 0, 0), 0xFFFFAAFFu, "4. Only the strobed lane changed");

    // --- Back to back, no idle cycles in between ---
    transact(dut, 0x10, 0xA0A0A0A0, 0b1111);
    transact(dut, 0x14, 0xB0B0B0B0, 0b1111);
    EXPECT_EQ(transact(dut, 0x10, 0, 0), 0xA0A0A0A0u, "5. Back-to-back writes, first");
    EXPECT_EQ(transact(dut, 0x14, 0, 0), 0xB0B0B0B0u, "6. Back-to-back writes, second");

    // The slave above hands out AWREADY and WREADY on different cycles and in
    // varying order. Everything above passing means the adapter never assumed
    // they move together.
    axi.report("7. Protocol");

    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}
