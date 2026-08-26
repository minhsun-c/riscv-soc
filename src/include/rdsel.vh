`ifndef __RD_SEL_LOCALPARAM
`define __RD_SEL_LOCALPARAM

// Register File Selection (Defined by Implementation)
// Widened from 2 bits to 3 in week 16. Four sources used all four encodings,
// and Zicsr needs a fifth: the old value of the CSR being accessed.
localparam [2:0] ALU_RDSEL  = 3'd0;
localparam [2:0] MEM_RDSEL  = 3'd1;
localparam [2:0] PC4_RDSEL  = 3'd2;
localparam [2:0] NO_RDSEL   = 3'd3;
localparam [2:0] CSR_RDSEL  = 3'd4;

`undef __RD_SEL_LOCALPARAM
`endif // __RD_SEL_LOCALPARAM
