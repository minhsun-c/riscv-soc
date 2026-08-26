`ifndef __EXC_CAUSE_LOCALPARAM
`define __EXC_CAUSE_LOCALPARAM

// mcause values for the exceptions this core can raise. The numbers come from
// the privileged spec, so nothing here is a free choice. The interrupt bit
// (mcause[31]) stays clear for all of these -- week 20 sets it for the timer.
localparam [3:0] EXC_INST_MISALIGNED  = 4'd0;
localparam [3:0] EXC_ILLEGAL_INST     = 4'd2;
localparam [3:0] EXC_BREAKPOINT       = 4'd3;
localparam [3:0] EXC_LOAD_MISALIGNED  = 4'd4;
localparam [3:0] EXC_STORE_MISALIGNED = 4'd6;
localparam [3:0] EXC_ECALL_M          = 4'd11;

// The immediate field of a SYSTEM instruction with funct3 = 000 says which
// privileged instruction it is.
localparam [11:0] PRIV_ECALL  = 12'h000;
localparam [11:0] PRIV_EBREAK = 12'h001;
localparam [11:0] PRIV_MRET   = 12'h302;

`undef __EXC_CAUSE_LOCALPARAM
`endif  // __EXC_CAUSE_LOCALPARAM
