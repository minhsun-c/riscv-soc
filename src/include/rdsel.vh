`ifndef __RD_SEL_LOCALPARAM
`define __RD_SEL_LOCALPARAM

// Register File Selection (Defined by Implementation)
localparam [1:0] ALU_RDSEL  = 2'd0;
localparam [1:0] MEM_RDSEL  = 2'd1;
localparam [1:0] PC4_RDSEL  = 2'd2;
localparam [1:0] NO_RDSEL   = 2'd3;

`undef __RD_SEL_LOCALPARAM
`endif // __RD_SEL_LOCALPARAM
