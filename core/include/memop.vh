`ifndef __MEMOP_LOCALPARAM
`define __MEMOP_LOCALPARAM

// RISC-V Load & Store Opcodes
localparam [2:0] LB_OP  = 3'b000;
localparam [2:0] LH_OP  = 3'b001;
localparam [2:0] LW_OP  = 3'b010;
localparam [2:0] LBU_OP = 3'b100;
localparam [2:0] LHU_OP = 3'b101;
localparam [2:0] SB_OP  = 3'b000;
localparam [2:0] SH_OP  = 3'b001;
localparam [2:0] SW_OP  = 3'b010;

`undef __MEMOP_LOCALPARAM
`endif  // __MEMOP_LOCALPARAM
