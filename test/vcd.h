#ifndef VCD_HELPER_H
#define VCD_HELPER_H

#include <string>

// 波形格式在編譯期決定，由 Makefile 的 TRACE 變數控制：
//
//   make alu            預設 VCD。文字格式，什麼檢視器都讀得動，檔案本身
//                       也可以直接打開來看裡面長什麼樣。
//   make core TRACE=fst 換成 FST。訊號內容與 VCD 完全相同 -- Verilator 對
//                       兩種格式產生的是同一份追蹤宣告程式碼 -- 但檔案小
//                       一個數量級（core 的波形實測 4.8 MB → 249 KB）。
//                       整機波形建議用這個，代價是只有 GTKWave 與 Surfer
//                       讀得動，而且不能直接用文字編輯器打開。
#ifdef TRACE_FST
#include "verilated_fst_c.h"
typedef VerilatedFstC TraceFile;
#define TRACE_EXT "fst"
#else
#include "verilated_vcd_c.h"
typedef VerilatedVcdC TraceFile;
#define TRACE_EXT "vcd"
#endif

extern TraceFile *m_trace;
extern vluint64_t sim_time;

// 呼叫端一律傳 "alu.vcd" 這種名字，真正的副檔名由上面選到的格式決定 --
// 所以 TRACE=fst 時會自動寫成 alu.fst，28 支 testbench 一行都不用改。
template <typename T>
static inline void init_vcd(T *dut, const char *vcd_filename)
{
    std::string name(vcd_filename);
    // 只切掉檔名本身的副檔名。--trace build/foo.vcd 這種帶路徑的參數，
    // 目錄裡若剛好有點號不能誤傷。
    const size_t slash = name.find_last_of('/');
    const size_t dot = name.find_last_of('.');
    if (dot != std::string::npos && (slash == std::string::npos || dot > slash))
        name.resize(dot);
    name += "." TRACE_EXT;

    Verilated::traceEverOn(true);
    m_trace = new TraceFile;
    dut->trace(m_trace, 5);
    m_trace->open(name.c_str());
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
