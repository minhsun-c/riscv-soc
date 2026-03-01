`ifndef __BRANCHOP_LOCALPARAM
`define __BRANCHOP_LOCALPARAM

// RISC-V BRANCH Opcodes
localparam [2:0] BEQ_OP  = 3'b000; 
localparam [2:0] BNE_OP  = 3'b001; 
localparam [2:0] BLT_OP  = 3'b100; 
localparam [2:0] BGE_OP  = 3'b101; 
localparam [2:0] BLTU_OP = 3'b110; 
localparam [2:0] BGEU_OP = 3'b111; 
localparam [2:0] NOBR_OP = 3'b010; // Not a Branch

`undef __BRANCHOP_LOCALPARAM
`endif // __BRANCHOP_LOCALPARAM
