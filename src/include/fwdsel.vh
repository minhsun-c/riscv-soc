`ifndef __FWD_SEL_LOCALPARAM
`define __FWD_SEL_LOCALPARAM

// Forwarding source selection (Defined by Implementation)
localparam [1:0] FWD_NONE = 2'd0;  // use the value id_ex latched from the register file
localparam [1:0] FWD_MEM  = 2'd1;  // take it from the MEM stage (one instruction ahead)
localparam [1:0] FWD_WB   = 2'd2;  // take it from the WB stage (two instructions ahead)

`undef __FWD_SEL_LOCALPARAM
`endif  // __FWD_SEL_LOCALPARAM
