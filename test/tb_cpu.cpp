#include <verilated.h>
#include <verilated_vcd_c.h>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

// Verilator Generated Headers
#include "Vcpu.h"
#include "Vcpu___024root.h"
#include "Vcpu_core.h"
#include "Vcpu_cpu.h"
#include "Vcpu_regfile.h"
#include "Vcpu_sram.h"

// Testbench Utilities
#include "checker.h"
#define MODULE_HAS_CLK 1
#include "vcd.h"

// Global Simulation State
VerilatedVcdC *m_trace = nullptr;
vluint64_t sim_time = 0;

// Memory Pointers: These will be "hotwired" to the Verilog SRAM arrays
uint32_t *imem = nullptr;
uint32_t *dmem = nullptr;

// --- Macro Magic for Dynamic Includes ---
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

/* clang-format off */
#ifdef TESTNUM
    #define _HEADER_PATH(n) cpu_test/test##n.h
    #define _BIN_PATH(n)    test/test_program/test##n.bin

    #define HEADER_FILE(n) _HEADER_PATH(n)
    #define BIN_FILE(n)    _BIN_PATH(n)

    #include TOSTRING(HEADER_FILE(TESTNUM))
    #define BIN_PATH TOSTRING(BIN_FILE(TESTNUM))
#else
    #error "TESTNUM not defined!"
#endif
/* clang-format on */

/**
 * Loads a compiled RISC-V binary file into the hardware SRAMs
 */
void load_binary_to_hardware(const char *filename)
{
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        std::cerr << "ERROR: Binary file not found: " << filename << std::endl;
        exit(1);
    }

    std::vector<char> buffer((std::istreambuf_iterator<char>(file)),
                             std::istreambuf_iterator<char>());

    for (size_t i = 0; i < buffer.size(); i += 4) {
        uint32_t word = 0;
        for (int b = 0; b < 4 && (i + b) < buffer.size(); ++b) {
            word |= (uint8_t) buffer[i + b] << (8 * b);
        }
        if (i / 4 < 1024) {
            imem[i / 4] = word;
            dmem[i / 4] = word;
        }
    }
    printf("Successfully loaded %lu bytes from %s into Hardware SRAMs.\n",
           buffer.size(), filename);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vcpu *dut = new Vcpu;

    imem = &(dut->rootp->cpu->u_imem->mem[0]);
    dmem = &(dut->rootp->cpu->u_dmem->mem[0]);

    char vcd_name[64];
    snprintf(vcd_name, 64, "cpu.vcd");
    init_vcd(dut, vcd_name);


#if TESTNUM >= 6
    load_binary_to_hardware(BIN_PATH);
#else
    // Calls the hardcoded loader inside test1.h - test5.h
    load_program();
#endif

    dut->rst_i = 1;
    for (int i = 0; i < 10; i++) {
        dut->clk_i = 0;
        dut->eval();
        dut->clk_i = 1;
        dut->eval();
    }
    dut->rst_i = 0;

    printf("--- Starting Simulation: Test %d ---\n", TESTNUM);

    for (int i = 0; i < 10000; i++) {
        // Falling Edge
        dut->clk_i = 0;
        dut->eval();
        if (m_trace)
            m_trace->dump(sim_time * 10);
        Verilated::timeInc(5);  // Advance time

        // Rising Edge
        dut->clk_i = 1;
        dut->eval();
        if (m_trace)
            m_trace->dump(sim_time * 10 + 5);
        Verilated::timeInc(5);  // Advance time

        sim_time++;
    }

#if TESTNUM >= 6
    verify_results(dut);
#else
    verify_results(dut->rootp->cpu->u_core);
#endif

    printf("--- Simulation Finished ---\n");
    close_vcd();
    delete dut;
    TEST_SUMMARY();
    return 0;
}