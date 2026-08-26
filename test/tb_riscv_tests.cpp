// Testbench for the riscv-tests rv32ui suite.
//
// Unlike tb_core.cpp, which drives hand-written instruction sequences and
// checks the register file afterwards, this testbench runs a self-checking
// program image and only reports the verdict the program itself produced.
//
// The image is built by test/riscv_tests/Makefile against the bare-metal
// environment in test/riscv_tests/env/riscv_test.h. That environment ends a
// test by storing a result word to RVTEST_TOHOST; this testbench watches the
// data write port for that address:
//
//   1                  -> pass
//   (TESTNUM << 1) | 1 -> fail, TESTNUM identifies the failing case
//
// Memory is modelled as one flat RAM serving both ports, because the test
// images place .data immediately after .text in a single address space. The
// core has no cache and never writes to its own instruction stream, so a
// single backing array is sufficient (fence_i, the one test that would need
// otherwise, is excluded -- see test/riscv_tests/tests.mk).

#include <verilated.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "Vcore.h"
#include "Vcore___024root.h"
#include "Vcore_core.h"
#include "Vcore_regfile.h"

#define MODULE_HAS_CLK 1
#include "vcd.h"

// vcd.h drives these; tracing stays off unless --trace is passed, and tick()
// skips dumping while m_trace is null.
VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

// ---------------------------------------------------------------------------
// Memory map. Must match test/riscv_tests/env/riscv_test.h and env/link.ld.
// ---------------------------------------------------------------------------

static const uint32_t RAM_SIZE = 0x00010000;  // 64 KiB unified RAM at 0
static const uint32_t RAM_WORDS = RAM_SIZE / 4;
static const uint32_t TOHOST_ADDR = 0x00020000;  // MMIO doorbell, outside RAM

static uint32_t mem[RAM_WORDS];

// funct3 encodings, matching src/include/memop.vh.
enum { OP_B = 0x0, OP_H = 0x1, OP_W = 0x2, OP_BU = 0x4, OP_HU = 0x5 };

// ---------------------------------------------------------------------------
// Image loading
// ---------------------------------------------------------------------------

static long load_image(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) {
        fprintf(stderr, "error: cannot open image '%s'\n", path);
        return -1;
    }

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (size < 0 || (uint32_t) size > RAM_SIZE) {
        fprintf(stderr, "error: image '%s' is %ld bytes, RAM is %u\n", path,
                size, RAM_SIZE);
        fclose(f);
        return -1;
    }

    memset(mem, 0, sizeof(mem));

    // Both the host and the target are little-endian, so the raw image can be
    // read straight into the word array.
    size_t got = fread(mem, 1, (size_t) size, f);
    fclose(f);

    if (got != (size_t) size) {
        fprintf(stderr, "error: short read on '%s'\n", path);
        return -1;
    }
    return size;
}

// ---------------------------------------------------------------------------
// Data port
//
// The core does no sign extension of its own -- wb_stage forwards whatever the
// memory returns -- so the load logic here mirrors src/core/sram.v, including
// its treatment of the low address bits.
// ---------------------------------------------------------------------------

static uint32_t dm_read(uint32_t addr, uint32_t op)
{
    if (addr >= RAM_SIZE)
        return 0;

    uint32_t word = mem[addr >> 2];
    uint32_t byte_off = addr & 3;
    uint32_t half_off = (addr >> 1) & 1;

    switch (op) {
    case OP_B:
        return (uint32_t) (int32_t) (int8_t) (word >> (8 * byte_off));
    case OP_H:
        return (uint32_t) (int32_t) (int16_t) (word >> (16 * half_off));
    case OP_W:
        return word;
    case OP_BU:
        return (word >> (8 * byte_off)) & 0xFF;
    case OP_HU:
        return (word >> (16 * half_off)) & 0xFFFF;
    default:
        return 0;
    }
}

static void dm_write(uint32_t addr, uint32_t data, uint32_t op)
{
    if (addr >= RAM_SIZE)
        return;

    uint32_t idx = addr >> 2;
    uint32_t shift;

    switch (op) {
    case OP_B:
        shift = 8 * (addr & 3);
        mem[idx] = (mem[idx] & ~(0xFFu << shift)) | ((data & 0xFF) << shift);
        break;
    case OP_H:
        shift = 16 * ((addr >> 1) & 1);
        mem[idx] =
            (mem[idx] & ~(0xFFFFu << shift)) | ((data & 0xFFFF) << shift);
        break;
    case OP_W:
        mem[idx] = data;
        break;
    default:
        break;
    }
}

// ---------------------------------------------------------------------------

static void dump_regs(Vcore *dut)
{
    static const char *abi[32] = {
        "zero", "ra", "sp", "gp", "tp",  "t0",  "t1", "t2", "s0", "s1", "a0",
        "a1",   "a2", "a3", "a4", "a5",  "a6",  "a7", "s2", "s3", "s4", "s5",
        "s6",   "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"};

    fprintf(stderr, "  register file:\n");
    for (int i = 0; i < 32; i += 4) {
        fprintf(stderr, "   ");
        for (int j = i; j < i + 4; j++)
            fprintf(stderr, "  %-4s=%08x", abi[j],
                    dut->rootp->core->u_regfile->x[j]);
        fprintf(stderr, "\n");
    }
}

static void usage(const char *argv0)
{
    fprintf(stderr,
            "usage: %s <image.bin> [--trace <file.vcd>] [--max-cycles N]\n",
            argv0);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);

    const char *image = nullptr;
    const char *trace_file = nullptr;
    uint64_t max_cycles = 100000;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--trace") && i + 1 < argc) {
            trace_file = argv[++i];
        } else if (!strcmp(argv[i], "--max-cycles") && i + 1 < argc) {
            max_cycles = strtoull(argv[++i], nullptr, 0);
        } else if (argv[i][0] != '-' && !image) {
            image = argv[i];
        }
    }

    if (!image) {
        usage(argv[0]);
        return 2;
    }

    const char *name = strrchr(image, '/');
    name = name ? name + 1 : image;

    if (load_image(image) < 0)
        return 2;

    Vcore *dut = new Vcore;

    if (trace_file)
        init_vcd(dut, trace_file);

    dut->im_data_i = 0;
    dut->dm_rdata_i = 0;
    // One-cycle delay line for the data port's LATENCY 1 behaviour.
    uint32_t dm_req_prev = 0, dm_rdata_prev = 0;

    dut->rst_i = 1;
    tick(dut);
    dut->rst_i = 0;

    bool finished = false;
    bool runaway = false;
    uint32_t tohost = 0;
    uint32_t bad_pc = 0;
    uint64_t cycle = 0;

    for (; cycle < max_cycles; cycle++) {
        // --- instruction port ---
        uint32_t pc = dut->im_addr_o;
        if (pc >= RAM_SIZE || (pc & 3)) {
            runaway = true;
            bad_pc = pc;
            break;
        }
        dut->im_ready_i = 1;
        dut->im_rvalid_i = dut->im_req_o;
        dut->im_data_i = mem[pc >> 2];

        // --- data port ---
        // Since week 18 the core speaks words plus WSTRB, and lsu.v does the
        // alignment and sign extension that this model used to do. So the
        // memory here is now genuinely dumb, which is the point.
        dut->dm_ready_i = 1;
        dut->dm_rvalid_i = dm_req_prev;
        dut->dm_rdata_i = dm_rdata_prev;

        uint32_t addr = dut->dm_addr_o;
        if (dut->dm_req_o && dut->dm_wstrb_o != 0) {
            if ((addr & ~3u) == TOHOST_ADDR) {
                tohost = dut->dm_wdata_o;
                finished = true;
            } else if (addr < RAM_SIZE) {
                uint32_t w = mem[addr >> 2];
                for (int b = 0; b < 4; b++) {
                    if (dut->dm_wstrb_o & (1 << b)) {
                        w = (w & ~(0xFFu << (8 * b)))
                            | (dut->dm_wdata_o & (0xFFu << (8 * b)));
                    }
                }
                mem[addr >> 2] = w;
            }
        }
        dm_req_prev = dut->dm_req_o;
        dm_rdata_prev = (addr < RAM_SIZE) ? mem[addr >> 2] : 0;

        tick(dut);

        if (finished) {
            cycle++;
            break;
        }
    }

    close_vcd();

    int rc;
    if (runaway) {
        fprintf(stderr, "FAIL %-10s fetch left RAM at pc=0x%08x (cycle %llu)\n",
                name, bad_pc, (unsigned long long) cycle);
        dump_regs(dut);
        rc = 1;
    } else if (!finished) {
        fprintf(stderr,
                "FAIL %-10s timeout after %llu cycles, pc=0x%08x "
                "(no write to tohost)\n",
                name, (unsigned long long) max_cycles, dut->im_addr_o);
        dump_regs(dut);
        rc = 1;
    } else if (tohost == 1) {
        printf("PASS %-10s %llu cycles\n", name, (unsigned long long) cycle);
        rc = 0;
    } else {
        // Encoded by RVTEST_FAIL; bit 0 is the "done" flag.
        fprintf(stderr,
                "FAIL %-10s test case %u failed (tohost=0x%08x, %llu cycles)\n",
                name, tohost >> 1, tohost, (unsigned long long) cycle);
        dump_regs(dut);
        rc = 1;
    }

    delete dut;
    return rc;
}
