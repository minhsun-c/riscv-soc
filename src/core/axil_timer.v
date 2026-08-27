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

    input             AWVALID,
    output            AWREADY,
    input  [XLEN-1:0] AWADDR,

    input             WVALID,
    output            WREADY,
    input  [XLEN-1:0] WDATA,
    input  [     3:0] WSTRB,

    output reg       BVALID,
    input            BREADY,
    output     [1:0] BRESP,

    input             ARVALID,
    output            ARREADY,
    input  [XLEN-1:0] ARADDR,

    output reg            RVALID,
    input                 RREADY,
    output reg [XLEN-1:0] RDATA,
    output     [     1:0] RRESP,

    output mtip_o
);

  assign BRESP = 2'b00;
  assign RRESP = 2'b00;

  reg [XLEN-1:0] mtime  /* verilator public */;
  reg [XLEN-1:0] mtimecmp  /* verilator public */;

  // Level, not pulse. Software clears it by moving mtimecmp forward.
  assign mtip_o = (mtime >= mtimecmp) && (mtimecmp != {XLEN{1'b0}});

  reg       aw_taken;
  reg [3:0] aw_off;

  assign AWREADY = !aw_taken && !BVALID;
  assign WREADY  = aw_taken;
  assign ARREADY = !RVALID;

  always @(posedge clk_i) begin
    if (rst_i) begin
      mtime    <= {XLEN{1'b0}};
      mtimecmp <= {XLEN{1'b0}};
      aw_taken <= 1'b0;
      BVALID <= 1'b0;
      RVALID <= 1'b0;
      aw_off   <= 4'b0;
    end else begin
      mtime <= mtime + 32'd1;

      if (AWVALID && AWREADY) begin
        aw_taken <= 1'b1;
        aw_off   <= AWADDR[3:0];
      end
      if (WVALID && WREADY) begin
        // Only mtimecmp is writable. Writing mtime is legal in the spec but
        // this core has no use for it, and a timer software can rewind is a
        // debugging hazard.
        if (aw_off[3]) mtimecmp <= WDATA;
        aw_taken <= 1'b0;
        BVALID <= 1'b1;
      end
      if (BVALID && BREADY) BVALID <= 1'b0;

      if (ARVALID && ARREADY) begin
        RDATA  <= ARADDR[3] ? mtimecmp : mtime;
        RVALID <= 1'b1;
      end else if (RVALID && RREADY) begin
        RVALID <= 1'b0;
      end
    end
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */
