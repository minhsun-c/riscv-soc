`timescale 1ns / 1ps

/**
 * Module: bht (Branch History Table)
 *
 * Description:
 * A direct-mapped table of 2-bit saturating counters, one per index, each
 * predicting whether the branch at that index will be taken.
 *
 * A single bit would remember only the last outcome, which mispredicts twice
 * per loop: once on the final iteration when the loop exits, and again on the
 * first iteration of the next execution, because the exit overwrote the
 * history. Two bits add hysteresis -- one contrary outcome moves the counter
 * but does not flip the prediction -- so a loop taken n times mispredicts once
 * instead of twice.
 *
 *     00 strongly not taken  <->  01 weakly not taken
 *     10 weakly taken        <->  11 strongly taken
 *
 * The prediction is the top bit: counter >= 2 means predict taken.
 *
 * This table is not tagged. Two branches whose indices collide share a counter
 * and interfere with each other; the cost is a worse prediction, never a wrong
 * execution, because EX always resolves the branch for real. That is why a
 * predictor can be approximate in a way a cache cannot.
 *
 * @port pc_i             [Input]  [XLEN-1:0] PC being fetched, for lookup.
 * @port predict_taken_o  [Output]            1 if the counter predicts taken.
 * @port upd_valid_i      [Input]             1 when EX resolves a branch.
 * @port upd_pc_i         [Input]  [XLEN-1:0] PC of the resolved branch.
 * @port upd_taken_i      [Input]             How that branch actually went.
 */

// The table is untagged on purpose: only the index bits of the PC are read,
// so the rest are genuinely unused. Verilator is right to point that out --
// those discarded bits are exactly why two branches can alias onto one entry.
/* verilator lint_off UNUSEDSIGNAL */

module bht #(
    parameter XLEN        = 32,
    parameter NUM_ENTRIES = 64
) (
    input clk_i,
    input rst_i,

    // Lookup (combinational, in IF)
    input  [XLEN-1:0] pc_i,
    output            predict_taken_o,

    // Update (from EX, when a branch resolves)
    input            upd_valid_i,
    input [XLEN-1:0] upd_pc_i,
    input            upd_taken_i
);

  localparam IDX_W = $clog2(NUM_ENTRIES);

  // Instructions are word aligned, so pc[1:0] is always zero and carries no
  // information. Indexing from bit 2 up keeps consecutive instructions in
  // consecutive entries instead of piling them into one in four.
  wire [IDX_W-1:0] rd_idx = pc_i[IDX_W+1:2];
  wire [IDX_W-1:0] wr_idx = upd_pc_i[IDX_W+1:2];

  reg [1:0] counter[0:NUM_ENTRIES-1]  /* verilator public */;

  // The top bit is the prediction: 10 and 11 predict taken.
  assign predict_taken_o = counter[rd_idx][1];

  integer i;
  always @(posedge clk_i) begin
    if (rst_i) begin
      // Weakly not taken: one taken outcome is enough to start predicting
      // taken, so a loop warms up quickly, but a stray branch does not.
      for (i = 0; i < NUM_ENTRIES; i = i + 1) counter[i] <= 2'b01;
    end else if (upd_valid_i) begin
      if (upd_taken_i) begin
        if (counter[wr_idx] != 2'b11) counter[wr_idx] <= counter[wr_idx] + 2'b01;
      end else begin
        if (counter[wr_idx] != 2'b00) counter[wr_idx] <= counter[wr_idx] - 2'b01;
      end
    end
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */
