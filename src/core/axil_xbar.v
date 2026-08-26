`timescale 1ns / 1ps

/**
 * Module: axil_xbar (One Master, Three Slaves)
 *
 * Description:
 * Address decode on the way out, response multiplexing on the way back.
 *
 * The decode itself is trivial -- one nibble of the address picks a slave.
 * What makes this module worth writing is the part that is not: a response
 * has to come back from the same slave the request went to, and the request
 * is long gone by then. So the choice is latched when the address channel
 * completes and held until the response arrives.
 *
 * Read and write are latched separately, because AXI lets them be in flight
 * at the same time. This master never does both at once, but wiring it as if
 * it might costs one extra register and keeps the module honest about what
 * the protocol allows.
 *
 * An address matching no slave gets a response anyway -- immediately, with
 * zero data. Leaving it unanswered would hang the master forever, and a hang
 * is much harder to debug than a wrong value.
 */

/* verilator lint_off UNUSEDSIGNAL */
// memmap.vh also declares the peripheral base addresses, which only week
// 20's devices read.
/* verilator lint_off UNUSEDPARAM */

module axil_xbar #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,

    // --- Upstream (from axil_master) ---
    input             m_awvalid_i,
    output            m_awready_o,
    input  [XLEN-1:0] m_awaddr_i,
    input             m_wvalid_i,
    output            m_wready_o,
    input  [XLEN-1:0] m_wdata_i,
    input  [     3:0] m_wstrb_i,
    output            m_bvalid_o,
    input             m_bready_i,
    output [     1:0] m_bresp_o,
    input             m_arvalid_i,
    output            m_arready_o,
    input  [XLEN-1:0] m_araddr_i,
    output            m_rvalid_o,
    input             m_rready_i,
    output [XLEN-1:0] m_rdata_o,
    output [     1:0] m_rresp_o,

    // --- Downstream: 3 slaves, flattened ---
    output [      2:0] s_awvalid_o,
    input  [      2:0] s_awready_i,
    output [XLEN-1:0] s_awaddr_o,
    output [      2:0] s_wvalid_o,
    input  [      2:0] s_wready_i,
    output [XLEN-1:0] s_wdata_o,
    output [      3:0] s_wstrb_o,
    input  [      2:0] s_bvalid_i,
    output [      2:0] s_bready_o,
    output [      2:0] s_arvalid_o,
    input  [      2:0] s_arready_i,
    output [XLEN-1:0] s_araddr_o,
    input  [      2:0] s_rvalid_i,
    output [      2:0] s_rready_o,
    input  [XLEN*3-1:0] s_rdata_i
);

  `include "memmap.vh"

  // --- Decode: which slave owns this address ---
  function [1:0] decode(input [XLEN-1:0] a);
    begin
      if (a[31:28] == MMAP_RAM_SEL) decode = SLV_RAM;
      else if (a[31:28] == MMAP_PERI_SEL)
        decode = (a[19:16] == 4'h1) ? SLV_TIMER : SLV_UART;
      else decode = SLV_NONE;
    end
  endfunction

  wire [1:0] aw_sel = decode(m_awaddr_i);
  wire [1:0] ar_sel = decode(m_araddr_i);

  // --- Latch the choice so the response can find its way home ---
  reg [1:0] b_sel, r_sel;
  reg       b_busy, r_busy;

  wire [1:0] b_route = b_busy ? b_sel : aw_sel;
  wire [1:0] r_route = r_busy ? r_sel : ar_sel;

  always @(posedge clk_i) begin
    if (rst_i) begin
      b_busy <= 1'b0;
      r_busy <= 1'b0;
      b_sel  <= SLV_NONE;
      r_sel  <= SLV_NONE;
    end else begin
      if (m_awvalid_i && m_awready_o) begin
        b_sel  <= aw_sel;
        b_busy <= 1'b1;
      end else if (m_bvalid_o && m_bready_i) begin
        b_busy <= 1'b0;
      end
      if (m_arvalid_i && m_arready_o) begin
        r_sel  <= ar_sel;
        r_busy <= 1'b1;
      end else if (m_rvalid_o && m_rready_i) begin
        r_busy <= 1'b0;
      end
    end
  end

  // --- Forward: only the selected slave sees VALID ---
  assign s_awaddr_o = m_awaddr_i;
  assign s_araddr_o = m_araddr_i;
  assign s_wdata_o  = m_wdata_i;
  assign s_wstrb_o  = m_wstrb_i;

  genvar i;
  generate
    for (i = 0; i < 3; i = i + 1) begin : g_fanout
      assign s_awvalid_o[i] = m_awvalid_i && (aw_sel == i[1:0]);
      assign s_wvalid_o[i]  = m_wvalid_i && (b_route == i[1:0]);
      assign s_arvalid_o[i] = m_arvalid_i && (ar_sel == i[1:0]);
      assign s_bready_o[i]  = m_bready_i && (b_route == i[1:0]);
      assign s_rready_o[i]  = m_rready_i && (r_route == i[1:0]);
    end
  endgenerate

  // --- Return: pick the response from whichever slave was chosen ---
  // An unmapped address answers immediately with zeros. Hanging the master
  // would be worse: a wrong value shows up in a register dump, a hang does not.
  wire aw_none = (aw_sel == SLV_NONE);
  wire ar_none = (ar_sel == SLV_NONE);

  assign m_awready_o = aw_none ? 1'b1 : s_awready_i[aw_sel];
  assign m_wready_o  = (b_route == SLV_NONE) ? 1'b1 : s_wready_i[b_route];
  assign m_bvalid_o  = (b_route == SLV_NONE) ? b_busy : s_bvalid_i[b_route];
  assign m_bresp_o   = 2'b00;

  assign m_arready_o = ar_none ? 1'b1 : s_arready_i[ar_sel];
  assign m_rvalid_o  = (r_route == SLV_NONE) ? r_busy : s_rvalid_i[r_route];
  assign m_rresp_o   = 2'b00;
  assign m_rdata_o   = (r_route == SLV_NONE) ? {XLEN{1'b0}}
                                             : s_rdata_i[XLEN*r_route+:XLEN];

endmodule

/* verilator lint_on UNUSEDPARAM */
/* verilator lint_on UNUSEDSIGNAL */
