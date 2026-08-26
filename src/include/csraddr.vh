`ifndef __CSR_ADDR_LOCALPARAM
`define __CSR_ADDR_LOCALPARAM

// Machine-mode CSRs implemented by this core. The numbers are fixed by the
// privileged spec, not by this implementation -- unlike aluop.vh or rdsel.vh,
// nothing here is a free choice.
localparam [11:0] CSR_MSTATUS  = 12'h300;  // global interrupt enable and its saved copy
localparam [11:0] CSR_MIE      = 12'h304;  // which interrupts are enabled
localparam [11:0] CSR_MTVEC    = 12'h305;  // where a trap jumps to
localparam [11:0] CSR_MSCRATCH = 12'h340;  // scratch word for the trap handler
localparam [11:0] CSR_MEPC     = 12'h341;  // the PC the trap interrupted
localparam [11:0] CSR_MCAUSE   = 12'h342;  // why the trap happened
localparam [11:0] CSR_MTVAL    = 12'h343;  // extra detail about the cause
localparam [11:0] CSR_MIP      = 12'h344;  // which interrupts are pending

// Hardware performance counters. Read-only here: they count, software reads.
localparam [11:0] CSR_MCYCLE   = 12'hB00;  // cycles since reset
localparam [11:0] CSR_MINSTRET = 12'hB02;  // instructions retired

// mstatus bit positions actually used here. The rest of the register reads 0.
localparam integer MSTATUS_MIE  = 3;   // interrupts enabled now
localparam integer MSTATUS_MPIE = 7;   // interrupts were enabled before the trap

// mie / mip share a bit layout. Only the machine timer bit is implemented.
localparam integer MTIP_BIT = 7;

`undef __CSR_ADDR_LOCALPARAM
`endif  // __CSR_ADDR_LOCALPARAM
