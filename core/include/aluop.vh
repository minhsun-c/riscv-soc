`ifndef __ALUOP_LOCALPARAM
`define __ALUOP_LOCALPARAM

// RISC-V ALU Opcodes
localparam [2:0] ADD_OP  = 3'b000; // ADD
localparam [2:0] SLL_OP  = 3'b001; // SLL  (Shift Left Logical)
localparam [2:0] SLT_OP  = 3'b010; // SLT  (Set Less Than - Signed)
localparam [2:0] SLTU_OP = 3'b011; // SLTU (Set Less Than - Unsigned)
localparam [2:0] XOR_OP  = 3'b100; // XOR  (Bitwise XOR)
localparam [2:0] SRL_OP  = 3'b101; // SRL  (if shift_mode_i=0) / SRA (if shift_mode_i=1)
localparam [2:0] OR_OP   = 3'b110; // OR   (Bitwise OR)
localparam [2:0] AND_OP  = 3'b111; // AND  (Bitwise AND)

`undef __ALUOP_LOCALPARAM
`endif // __ALUOP_LOCALPARAM
