`timescale 1ns / 1ps

/**
 * Module: cpu
 *
 * Description:
 * The top-level system wrapper. This module instantiates the RISC-V core 
 * and connects it to separate Instruction and Data SRAM blocks in a 
 * Harvard architecture configuration.
 *
 * Parameters:
 * XLEN : Word width (default 32)
 *
 * @port clk_i        [Input]  [1:0]      Global clock signal.
 * @port rst_i        [Input]  [1:0]      Global reset signal (active high).
 */

module cpu #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i
);

  // Instruction Memory Interface
  wire [XLEN-1:0] im_addr;
  wire [XLEN-1:0] im_data;

  // Data Memory Interface
  wire [XLEN-1:0] dm_addr;
  wire [XLEN-1:0] dm_wdata;
  wire            dm_we;
  wire [     2:0] dm_op;
  wire [XLEN-1:0] dm_rdata;

  core #(
      .XLEN(XLEN)
  ) u_core (
      .clk_i(clk_i),
      .rst_i(rst_i),

      // IMEM Ports
      .im_addr_o(im_addr),
      .im_data_i(im_data),

      // DMEM Ports
      .dm_addr_o   (dm_addr),
      .dm_wdata_o  (dm_wdata),
      .dm_we_o     (dm_we),
      .dm_op_o     (dm_op),
      .data_rdata_i(dm_rdata)
  );

  // -------------------------------------------------------------------------
  // Instruction SRAM (IMEM)
  // -------------------------------------------------------------------------
  // Note: Instructions are always word-aligned (LW_OP) and we never write 
  // to IMEM from the core side in a basic Harvard setup.
  sram #(
      .XLEN(XLEN),
      .NUM_ENTRIES(1024)
  ) u_imem (
      .clk_i  (clk_i),
      .addr_i (im_addr),
      .wdata_i({XLEN{1'b0}}),  // No writes from core
      .we_i   (1'b0),          // Read-only for core
      .func3_i(3'b010),        // Always LW_OP (32-bit instructions)
      .rdata_o(im_data)
  );

  // -------------------------------------------------------------------------
  // Data SRAM (DMEM)
  // -------------------------------------------------------------------------
  sram #(
      .XLEN(XLEN),
      .NUM_ENTRIES(1024)
  ) u_dmem (
      .clk_i  (clk_i),
      .addr_i (dm_addr),
      .wdata_i(dm_wdata),
      .we_i   (dm_we),
      .func3_i(dm_op),     // Connects to dm_op_o for SB, LH, LW, etc.
      .rdata_o(dm_rdata)
  );

endmodule
