`ifndef __OPCODE_LOCALPARAM
`define __OPCODE_LOCALPARAM

// RISC-V Opcodes
localparam [6:0] R_TYPE  = 7'b0110011;
localparam [6:0] I_ALU   = 7'b0010011;
localparam [6:0] I_LOAD  = 7'b0000011;
localparam [6:0] S_TYPE  = 7'b0100011;
localparam [6:0] B_TYPE  = 7'b1100011;
localparam [6:0] U_LUI   = 7'b0110111;
localparam [6:0] U_AUIPC = 7'b0010111;
localparam [6:0] J_JAL   = 7'b1101111;
localparam [6:0] I_JALR  = 7'b1100111;

`undef __OPCODE_LOCALPARAM
`endif // __OPCODE_LOCALPARAM
