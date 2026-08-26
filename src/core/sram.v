`timescale 1ns / 1ps

/**
 * Module: sram (Byte-Writable Memory with a Handshake)
 *
 * Description:
 * Storage and nothing else. Alignment, sign extension and byte selection all
 * moved to lsu.v in week 18; what is left speaks in whole words plus a
 * write-strobe mask, which is what a bus speaks.
 *
 * The handshake is the other half of the change:
 *
 *     req_i     the requester wants this access
 *     ready_o   the memory can accept it this cycle
 *     rvalid_o  read data is on rdata_o this cycle
 *
 * With LATENCY = 0 this is the old behaviour dressed in the new protocol:
 * ready and rvalid are both immediate and rdata is combinational. With
 * LATENCY = 1 the read is registered and the requester has to wait a cycle --
 * which is the point. The pipeline has to learn to tolerate memory that does
 * not answer instantly, because week 19 replaces this with a bus that
 * genuinely cannot.
 *
 * Instruction fetch uses LATENCY = 0 and the data port uses 1. That asymmetry
 * is a deliberate choice, not an oversight: making fetch multi-cycle without
 * pipelining it would roughly double CPI, and pipelining fetch is a bigger
 * change than this week should carry. See the week 18 lesson.
 *
 * @port req_i    [Input]             1 when an access is wanted this cycle.
 * @port wstrb_i  [Input]  [3:0]      Byte enables. All zero means a read.
 * @port ready_o  [Output]            1 when the access is accepted.
 * @port rvalid_o [Output]            1 when rdata_o is the answer.
 */

// 只用得到索引位元：低 2 位恆為 0，高位超出這塊記憶體的範圍
/* verilator lint_off UNUSEDSIGNAL */

module sram #(
    parameter XLEN = 32,
    parameter NUM_ENTRIES = 1024,
    parameter LATENCY = 0,
    parameter ADDR_W = $clog2(NUM_ENTRIES)
) (
    input clk_i,

    input            req_i,
    input [XLEN-1:0] addr_i,
    input [XLEN-1:0] wdata_i,
    input [     3:0] wstrb_i,

    output            ready_o,
    output            rvalid_o,
    output [XLEN-1:0] rdata_o
);

  reg [XLEN-1:0] mem[0:NUM_ENTRIES-1]  /* verilator public */;

  wire [ADDR_W-1:0] word_addr = addr_i[ADDR_W+1:2];

  // This memory never makes anyone wait to be accepted. A bus will.
  assign ready_o = 1'b1;

  // --- Write: one lane per strobe bit, and nothing else touched ---
  integer b;
  always @(posedge clk_i) begin
    if (req_i) begin
      for (b = 0; b < 4; b = b + 1) begin
        if (wstrb_i[b]) mem[word_addr][8*b+:8] <= wdata_i[8*b+:8];
      end
    end
  end

  // --- Read ---
  generate
    if (LATENCY == 0) begin : g_comb_read
      assign rvalid_o = req_i;
      assign rdata_o  = mem[word_addr];
    end else begin : g_sync_read
      reg            rv;
      reg [XLEN-1:0] rd;
      always @(posedge clk_i) begin
        rv <= req_i;
        rd <= mem[word_addr];
      end
      assign rvalid_o = rv;
      assign rdata_o  = rd;
    end
  endgenerate

endmodule

/* verilator lint_on UNUSEDSIGNAL */
