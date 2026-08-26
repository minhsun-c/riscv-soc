`timescale 1ns / 1ps

/**
 * Module: btb (Branch Target Buffer)
 *
 * Description:
 * A direct-mapped cache of branch targets, so that IF can redirect the PC in
 * the same cycle it fetches, before the instruction has even been decoded.
 *
 * The bht says *whether* to jump; this table says *where*. Both are needed:
 * knowing a branch is taken is useless in IF if the target is still locked
 * inside an instruction nobody has decoded yet.
 *
 * Unlike the bht, this table is tagged. A wrong prediction of "taken" costs
 * two flushed cycles, which is survivable, but sending the PC to a target
 * belonging to a different branch would send fetch somewhere arbitrary for no
 * reason at all. The tag makes a hit mean "this entry really is about this
 * PC", so a miss falls back to pc+4 rather than to garbage.
 *
 *     index  pc[IDX_W+1:2]     which entry
 *     tag    pc[XLEN-1:IDX_W+2] which PC that entry is about
 *
 * Only taken branches are recorded. A not-taken branch has no target worth
 * remembering -- its "target" is pc+4, which IF computes anyway.
 *
 * @port pc_i         [Input]  [XLEN-1:0] PC being fetched, for lookup.
 * @port hit_o        [Output]            1 if this PC has a recorded target.
 * @port target_o     [Output] [XLEN-1:0] The recorded target (valid on hit).
 * @port upd_valid_i  [Input]             1 when EX resolves a taken branch.
 * @port upd_pc_i     [Input]  [XLEN-1:0] PC of that branch.
 * @port upd_target_i [Input]  [XLEN-1:0] Where it actually went.
 */

// Only pc[1:0] goes unused: instructions are word aligned, so those two bits
// are always zero. Everything above them is either index or tag -- which is
// the difference from the bht, where all the upper bits are discarded.
/* verilator lint_off UNUSEDSIGNAL */

module btb #(
    parameter XLEN        = 32,
    parameter NUM_ENTRIES = 64
) (
    input clk_i,
    input rst_i,

    // Lookup (combinational, in IF)
    input  [XLEN-1:0] pc_i,
    output            hit_o,
    output [XLEN-1:0] target_o,

    // Update (from EX, only for branches that were actually taken)
    input            upd_valid_i,
    input [XLEN-1:0] upd_pc_i,
    input [XLEN-1:0] upd_target_i
);

  localparam IDX_W = $clog2(NUM_ENTRIES);
  localparam TAG_W = XLEN - IDX_W - 2;

  wire [IDX_W-1:0] rd_idx = pc_i[IDX_W+1:2];
  wire [TAG_W-1:0] rd_tag = pc_i[XLEN-1:IDX_W+2];
  wire [IDX_W-1:0] wr_idx = upd_pc_i[IDX_W+1:2];
  wire [TAG_W-1:0] wr_tag = upd_pc_i[XLEN-1:IDX_W+2];

  reg                  valid [0:NUM_ENTRIES-1]  /* verilator public */;
  reg [   TAG_W-1:0]   tag   [0:NUM_ENTRIES-1]  /* verilator public */;
  reg [    XLEN-1:0]   target[0:NUM_ENTRIES-1]  /* verilator public */;

  assign hit_o    = valid[rd_idx] && (tag[rd_idx] == rd_tag);
  assign target_o = target[rd_idx];

  integer i;
  always @(posedge clk_i) begin
    if (rst_i) begin
      // Only valid needs clearing. tag and target are don't-care while
      // valid is 0, and clearing them would cost flops for nothing.
      for (i = 0; i < NUM_ENTRIES; i = i + 1) valid[i] <= 1'b0;
    end else if (upd_valid_i) begin
      valid[wr_idx]  <= 1'b1;
      tag[wr_idx]    <= wr_tag;
      target[wr_idx] <= upd_target_i;
    end
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */
