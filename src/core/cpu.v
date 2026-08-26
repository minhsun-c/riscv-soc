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

  // Instruction memory port. LATENCY 0, so this handshake completes in the
  // cycle it is issued -- the old behaviour, wearing the new protocol.
  wire            im_req, im_ready, im_rvalid;
  wire [XLEN-1:0] im_addr, im_data;

  // Data memory port. LATENCY 1: every load and store costs a cycle now.
  wire            dm_req, dm_ready, dm_rvalid;
  wire [XLEN-1:0] dm_addr, dm_wdata, dm_rdata;
  wire [     3:0] dm_wstrb;

  core #(
      .XLEN(XLEN)
  ) u_core (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .im_req_o   (im_req),
      .im_addr_o  (im_addr),
      .im_ready_i (im_ready),
      .im_rvalid_i(im_rvalid),
      .im_data_i  (im_data),

      .dm_req_o   (dm_req),
      .dm_addr_o  (dm_addr),
      .dm_wdata_o (dm_wdata),
      .dm_wstrb_o (dm_wstrb),
      .dm_ready_i (dm_ready),
      .dm_rvalid_i(dm_rvalid),
      .dm_rdata_i (dm_rdata)
  );

  // -------------------------------------------------------------------------
  // Instruction SRAM
  // -------------------------------------------------------------------------
  // Zero latency, and the core never writes it -- wstrb tied off means every
  // access is a read. Making this one cycle without pipelining fetch would
  // roughly double CPI; see the week 18 lesson.
  sram #(
      .XLEN(XLEN),
      .NUM_ENTRIES(1024),
      .LATENCY(0)
  ) u_imem (
      .clk_i   (clk_i),
      .req_i   (im_req),
      .addr_i  (im_addr),
      .wdata_i ({XLEN{1'b0}}),
      .wstrb_i (4'b0000),
      .ready_o (im_ready),
      .rvalid_o(im_rvalid),
      .rdata_o (im_data)
  );

  // -------------------------------------------------------------------------
  // Data SRAM
  // -------------------------------------------------------------------------
  sram #(
      .XLEN(XLEN),
      .NUM_ENTRIES(1024),
      .LATENCY(1)
  ) u_dmem (
      .clk_i   (clk_i),
      .req_i   (dm_req),
      .addr_i  (dm_addr),
      .wdata_i (dm_wdata),
      .wstrb_i (dm_wstrb),
      .ready_o (dm_ready),
      .rvalid_o(dm_rvalid),
      .rdata_o (dm_rdata)
  );

endmodule
