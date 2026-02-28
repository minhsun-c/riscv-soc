#ifndef VCD_HELPER_H
#define VCD_HELPER_H

#include <string>
#include "verilated_vcd_c.h"

extern VerilatedVcdC *m_trace;
extern vluint64_t sim_time;

template <typename T>
static inline void init_vcd(T *dut, const char *vcd_filename)
{
    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open(vcd_filename);
    sim_time = 0;
}

template <typename T>
static inline void tick(T *dut)
{
#if MODULE_HAS_CLK
    dut->clk_i = 0;
    dut->eval();
    if (m_trace)
        m_trace->dump(sim_time++);
    dut->clk_i = 1;
    dut->eval();
    if (m_trace)
        m_trace->dump(sim_time++);
#else
    dut->eval();
    if (m_trace)
        m_trace->dump(sim_time++);
#endif
}

static inline void close_vcd()
{
    if (m_trace) {
        m_trace->dump(sim_time++);
        m_trace->close();
        delete m_trace;
        m_trace = nullptr;
    }
}

#endif