`ifndef __CSR_OP_LOCALPARAM
`define __CSR_OP_LOCALPARAM

// Zicsr operations. These are the funct3 encodings straight out of the spec,
// so ctrl can pass funct3 through without translating it -- the same trick
// that lets alu_op_o be funct3 for R-type instructions.
//
//   the low two bits pick the operation,  bit 2 picks the operand source
//     x01 write   x10 set   x11 clear
//     0xx operand is rs1    1xx operand is the 5-bit zero-extended uimm
localparam [2:0] CSR_NONE  = 3'b000;
localparam [2:0] CSR_RW    = 3'b001;
localparam [2:0] CSR_RS    = 3'b010;
localparam [2:0] CSR_RC    = 3'b011;
localparam [2:0] CSR_RWI   = 3'b101;
localparam [2:0] CSR_RSI   = 3'b110;
localparam [2:0] CSR_RCI   = 3'b111;

// funct3 = 000 with the SYSTEM opcode is not a CSR access at all: it is
// ecall / ebreak / mret, decoded by the immediate field instead. Week 17.
localparam [2:0] CSR_PRIV  = 3'b000;

`undef __CSR_OP_LOCALPARAM
`endif  // __CSR_OP_LOCALPARAM
