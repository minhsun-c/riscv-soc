`timescale 1ns / 1ps

/**
 * Module: axil_timer (Machine Timer)
 *
 * Description:
 * A counter that never stops, a comparison value software can set, and one
 * wire that goes high when the first reaches the second.
 *
 * That wire is the whole reason this week exists. It is the first thing in
 * the entire design that demands attention without any instruction asking for
 * it -- every exception so far was caused by the instruction it interrupted.
 * An interrupt is not.
 *
 * Register map, relative to MMAP_TIMER_BASE:
 *
 *     +0  MTIME     free-running, one tick per cycle
 *     +8  MTIMECMP  when MTIME reaches this, mtip_o goes high
 *
 * The spec makes both 64 bits. These are 32, which is a simplification worth
 * naming: a 32-bit counter at one tick per cycle wraps in a few seconds of
 * real time, and a wrap makes MTIME < MTIMECMP again, which silently drops an
 * interrupt. Nothing in this course runs long enough to see it. The register
 * offsets leave room for the high words, so widening it later does not move
 * anything.
 *
 * mtip_o is a level, not a pulse: it stays high until software moves
 * MTIMECMP forward. That is what makes the interrupt safe to miss for a few
 * cycles -- and it is why a handler that forgets to advance MTIMECMP
 * re-enters immediately and forever.
 */

/* verilator lint_off UNUSEDSIGNAL */

module axil_timer #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,

    input             awvalid_i,
    output            awready_o,
    input  [XLEN-1:0] awaddr_i,

    input             wvalid_i,
    output            wready_o,
    input  [XLEN-1:0] wdata_i,
    input  [     3:0] wstrb_i,

    output reg       bvalid_o,
    input            bready_i,
    output     [1:0] bresp_o,

    input             arvalid_i,
    output            arready_o,
    input  [XLEN-1:0] araddr_i,

    output reg            rvalid_o,
    input                 rready_i,
    output reg [XLEN-1:0] rdata_o,
    output     [     1:0] rresp_o,

    output mtip_o
);

  assign bresp_o = 2'b00;
  assign rresp_o = 2'b00;

  reg [XLEN-1:0] mtime  /* verilator public */;
  reg [XLEN-1:0] mtimecmp  /* verilator public */;

  // Level, not pulse. Software clears it by moving mtimecmp forward.
  assign mtip_o = (mtime >= mtimecmp) && (mtimecmp != {XLEN{1'b0}});

  reg       aw_taken;
  reg [3:0] aw_off;

  assign awready_o = !aw_taken && !bvalid_o;
  assign wready_o  = aw_taken;
  assign arready_o = !rvalid_o;

  always @(posedge clk_i) begin
    if (rst_i) begin
      mtime    <= {XLEN{1'b0}};
      mtimecmp <= {XLEN{1'b0}};
      aw_taken <= 1'b0;
      bvalid_o <= 1'b0;
      rvalid_o <= 1'b0;
      aw_off   <= 4'b0;
    end else begin
      mtime <= mtime + 32'd1;

      if (awvalid_i && awready_o) begin
        aw_taken <= 1'b1;
        aw_off   <= awaddr_i[3:0];
      end
      if (wvalid_i && wready_o) begin
        // Only mtimecmp is writable. Writing mtime is legal in the spec but
        // this core has no use for it, and a timer software can rewind is a
        // debugging hazard.
        if (aw_off[3]) mtimecmp <= wdata_i;
        aw_taken <= 1'b0;
        bvalid_o <= 1'b1;
      end
      if (bvalid_o && bready_i) bvalid_o <= 1'b0;

      if (arvalid_i && arready_o) begin
        rdata_o  <= araddr_i[3] ? mtimecmp : mtime;
        rvalid_o <= 1'b1;
      end else if (rvalid_o && rready_i) begin
        rvalid_o <= 1'b0;
      end
    end
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */
