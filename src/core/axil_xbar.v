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
    input             M_AWVALID,
    output            M_AWREADY,
    input  [XLEN-1:0] M_AWADDR,
    input             M_WVALID,
    output            M_WREADY,
    input  [XLEN-1:0] M_WDATA,
    input  [     3:0] M_WSTRB,
    output            M_BVALID,
    input             M_BREADY,
    output [     1:0] M_BRESP,
    input             M_ARVALID,
    output            M_ARREADY,
    input  [XLEN-1:0] M_ARADDR,
    output            M_RVALID,
    input             M_RREADY,
    output [XLEN-1:0] M_RDATA,
    output [     1:0] M_RRESP,

    // --- Downstream: 3 slaves, flattened ---
    output [      2:0] S_AWVALID,
    input  [      2:0] S_AWREADY,
    output [XLEN-1:0] S_AWADDR,
    output [      2:0] S_WVALID,
    input  [      2:0] S_WREADY,
    output [XLEN-1:0] S_WDATA,
    output [      3:0] S_WSTRB,
    input  [      2:0] S_BVALID,
    output [      2:0] S_BREADY,
    output [      2:0] S_ARVALID,
    input  [      2:0] S_ARREADY,
    output [XLEN-1:0] S_ARADDR,
    input  [      2:0] S_RVALID,
    output [      2:0] S_RREADY,
    input  [XLEN*3-1:0] S_RDATA
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

  wire [1:0] aw_sel = decode(M_AWADDR);
  wire [1:0] ar_sel = decode(M_ARADDR);

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
      if (M_AWVALID && M_AWREADY) begin
        b_sel  <= aw_sel;
        b_busy <= 1'b1;
      end else if (M_BVALID && M_BREADY) begin
        b_busy <= 1'b0;
      end
      if (M_ARVALID && M_ARREADY) begin
        r_sel  <= ar_sel;
        r_busy <= 1'b1;
      end else if (M_RVALID && M_RREADY) begin
        r_busy <= 1'b0;
      end
    end
  end

  // --- Forward: only the selected slave sees VALID ---
  assign S_AWADDR = M_AWADDR;
  assign S_ARADDR = M_ARADDR;
  assign S_WDATA  = M_WDATA;
  assign S_WSTRB  = M_WSTRB;

  genvar i;
  generate
    for (i = 0; i < 3; i = i + 1) begin : g_fanout
      assign S_AWVALID[i] = M_AWVALID && (aw_sel == i[1:0]);
      assign S_WVALID[i]  = M_WVALID && (b_route == i[1:0]);
      assign S_ARVALID[i] = M_ARVALID && (ar_sel == i[1:0]);
      assign S_BREADY[i]  = M_BREADY && (b_route == i[1:0]);
      assign S_RREADY[i]  = M_RREADY && (r_route == i[1:0]);
    end
  endgenerate

  // --- Return: pick the response from whichever slave was chosen ---
  // An unmapped address answers immediately with zeros. Hanging the master
  // would be worse: a wrong value shows up in a register dump, a hang does not.
  wire aw_none = (aw_sel == SLV_NONE);
  wire ar_none = (ar_sel == SLV_NONE);

  assign M_AWREADY = aw_none ? 1'b1 : S_AWREADY[aw_sel];
  assign M_WREADY  = (b_route == SLV_NONE) ? 1'b1 : S_WREADY[b_route];
  assign M_BVALID  = (b_route == SLV_NONE) ? b_busy : S_BVALID[b_route];
  assign M_BRESP   = 2'b00;

  assign M_ARREADY = ar_none ? 1'b1 : S_ARREADY[ar_sel];
  assign M_RVALID  = (r_route == SLV_NONE) ? r_busy : S_RVALID[r_route];
  assign M_RRESP   = 2'b00;
  assign M_RDATA   = (r_route == SLV_NONE) ? {XLEN{1'b0}}
                                             : S_RDATA[XLEN*r_route+:XLEN];

endmodule

/* verilator lint_on UNUSEDPARAM */
/* verilator lint_on UNUSEDSIGNAL */
