#include <verilated.h>
#include <iostream>
#include <string>
#include "Vhdu.h"
#include "checker.h"

#define MODULE_HAS_CLK 0
#include "vcd.h"

VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

// rd_src encodings, mirroring src/include/rdsel.vh
static const uint8_t RD_ALU = 0, RD_MEM = 1, RD_PC4 = 2, RD_NONE = 3;

void test_hdu(Vhdu *dut,
              uint8_t rs1_id,
              uint8_t rs2_id,
              uint8_t rd_ex,
              bool reg_write_ex,
              uint8_t rd_src_ex,
              bool expected_stall,
              const char *label)
{
    dut->rs1_id_i = rs1_id;
    dut->rs2_id_i = rs2_id;
    dut->rd_ex_i = rd_ex;
    dut->reg_write_ex_i = reg_write_ex;
    dut->rd_src_ex_i = rd_src_ex;

    dut->eval();
    tick(dut);

    EXPECT_EQ((uint32_t) dut->stall_o, (uint32_t) expected_stall, label);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vhdu *dut = new Vhdu;

    init_vcd(dut, "hdu.vcd");

    printf("--- Starting Hazard Detection Unit Tests ---\n");

    // With forwarding in place, the only hazard left is load-use: a load in EX
    // whose destination the instruction in ID is about to read. Everything else
    // is resolved by routing the value back into the EX operand mux.

    // --- 1-2. The hazard that remains ---
    test_hdu(dut, 1, 2, 1, true, RD_MEM, true, "1. Load-use on rs1");
    test_hdu(dut, 1, 2, 2, true, RD_MEM, true, "2. Load-use on rs2");

    // --- 3. No dependency at all ---
    test_hdu(dut, 1, 2, 3, true, RD_MEM, false, "3. Load, unrelated rd");

    // --- 4-6. Dependencies that forwarding now covers ---
    // Same register, same distance -- but the producer is not a load, so its
    // result exists in EX and fwd can route it. Stalling here would be the old
    // behaviour and would cost a cycle for nothing.
    test_hdu(dut, 1, 2, 1, true, RD_ALU, false, "4. ALU producer, forwarded");
    test_hdu(dut, 1, 2, 2, true, RD_ALU, false, "5. ALU producer on rs2, forwarded");
    test_hdu(dut, 1, 2, 1, true, RD_PC4, false, "6. JAL producer, forwarded");

    // --- 7. Load that writes nothing ---
    // rd_src says MEM but the instruction does not write a register, so there is
    // no dependency to stall on.
    test_hdu(dut, 1, 2, 1, false, RD_MEM, false, "7. rd_wen low, no stall");

    // --- 8. x0 is never a dependency ---
    // A load into x0 discards its result, so the register file's zero is already
    // the right answer.
    test_hdu(dut, 0, 2, 0, true, RD_MEM, false, "8. Load into x0 ignored");

    // --- 9. Both operands match ---
    test_hdu(dut, 5, 5, 5, true, RD_MEM, true, "9. Load-use on both operands");

    // --- 10. Store consuming a load ---
    // `lw x1, 0(x2)` then `sw x1, 0(x3)`: the store reads x1 as rs2, so this is
    // a load-use hazard like any other.
    test_hdu(dut, 3, 1, 1, true, RD_MEM, true, "10. Load-use into a store");

    // --- 11. Non-writing instruction in EX ---
    test_hdu(dut, 1, 2, 0, true, RD_NONE, false, "11. Branch in EX, no stall");

    close_vcd();
    delete dut;

    TEST_SUMMARY();

    return 0;
}
