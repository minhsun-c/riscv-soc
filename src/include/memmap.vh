`ifndef __MEMMAP_LOCALPARAM
`define __MEMMAP_LOCALPARAM

// Address decode for the data bus. One nibble is enough: this SoC has a RAM
// and two peripherals, and spending more bits on decode than the design needs
// only makes the comparator wider.
//
//   0x0000_0000 .. 0x0FFF_FFFF   RAM
//   0x1000_0000 .. 0x1000_FFFF   UART   (week 20)
//   0x1001_0000 .. 0x1001_FFFF   Timer  (week 20)
//
// The RAM keeps address 0 because riscv-tests links .text there and places
// .data straight after it in one flat space. Moving RAM would mean changing
// env/link.ld, env/riscv_test.h and tb_riscv_tests.cpp together -- the three
// files week 12 warned have to stay in sync -- for no benefit.
localparam [3:0] MMAP_RAM_SEL  = 4'h0;
localparam [3:0] MMAP_PERI_SEL = 4'h1;

localparam [31:0] MMAP_UART_BASE  = 32'h1000_0000;
localparam [31:0] MMAP_TIMER_BASE = 32'h1001_0000;

// Which slave a data address belongs to.
localparam [1:0] SLV_RAM   = 2'd0;
localparam [1:0] SLV_UART  = 2'd1;
localparam [1:0] SLV_TIMER = 2'd2;
localparam [1:0] SLV_NONE  = 2'd3;

`undef __MEMMAP_LOCALPARAM
`endif  // __MEMMAP_LOCALPARAM
