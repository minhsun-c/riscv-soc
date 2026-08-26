`ifndef __IMM_MODE_LOCALPARAM
`define __IMM_MODE_LOCALPARAM

// Immediate Generator Modes (Defined by Implementation)
localparam [2:0] I_IMM_MODE  = 3'd0;
localparam [2:0] S_IMM_MODE  = 3'd1;
localparam [2:0] B_IMM_MODE  = 3'd2;
localparam [2:0] U_IMM_MODE  = 3'd3;
localparam [2:0] J_IMM_MODE  = 3'd4;
// CSRRWI / CSRRSI / CSRRCI put a 5-bit unsigned operand where rs1 normally
// sits. Zero extended, never sign extended -- it is a bit pattern, not a number.
localparam [2:0] Z_IMM_MODE  = 3'd5;
localparam [2:0] NO_IMM_MODE = 3'd7;

`undef __IMM_MODE_LOCALPARAM
`endif // __IMM_MODE_LOCALPARAM
