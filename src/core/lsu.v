`timescale 1ns / 1ps

/**
 * Module: lsu (Load/Store Unit)
 *
 * Description:
 * Everything sram.v used to do apart from actually storing anything: turning a
 * byte address and an access width into byte lanes, and turning a word read
 * back out of memory into the value the instruction asked for.
 *
 * Splitting this out is not tidying. The memory below is about to become a bus
 * -- week 19 -- and a bus speaks in whole words plus a byte-enable mask. There
 * is nowhere on an AXI channel to say "this is an LH from an odd halfword";
 * that has to be resolved before the request leaves.
 *
 * Writes go out as a word plus WSTRB, with the data replicated into the lane
 * it belongs in. Reads come back as a whole word and the wanted bytes are
 * extracted and extended here.
 *
 * @port mem_op_i     [Input]  [2:0]      funct3 of the load or store.
 * @port addr_i       [Input]  [XLEN-1:0] Byte address.
 * @port wdata_i      [Input]  [XLEN-1:0] Value to store (rs2).
 * @port wstrb_o      [Output] [3:0]      Which bytes of the word to write.
 * @port wdata_lane_o [Output] [XLEN-1:0] wdata shifted into its lane.
 * @port rdata_raw_i  [Input]  [XLEN-1:0] The word the memory returned.
 * @port rdata_o      [Output] [XLEN-1:0] Extracted and extended for rd.
 */

/* verilator lint_off UNUSEDPARAM */

// 只看低 2 位：位元組通道由 addr[1:0] 決定，其餘與對齊無關
/* verilator lint_off UNUSEDSIGNAL */

module lsu #(
    parameter XLEN = 32
) (
    input [      2:0] mem_op_i,
    input [XLEN-1:0] addr_i,

    // Store path
    input  [XLEN-1:0] wdata_i,
    output [     3:0] wstrb_o,
    output [XLEN-1:0] wdata_lane_o,

    // Load path
    input  [XLEN-1:0] rdata_raw_i,
    output reg [XLEN-1:0] rdata_o
);

  `include "memop.vh"

  wire [1:0] off = addr_i[1:0];

  // --- Store: which bytes, and where the data sits inside the word ---
  // A byte store to address 3 writes lane 3, so the byte has to be shifted up
  // by 24 bits. The bus carries a word; WSTRB says which of it to believe.
  reg [3:0] wstrb;
  assign wstrb_o = wstrb;

  always @(*) begin
    case (mem_op_i[1:0])
      2'b00:   wstrb = 4'b0001 << off;        // SB
      2'b01:   wstrb = 4'b0011 << off;        // SH (off[0] is 0 for aligned)
      default: wstrb = 4'b1111;               // SW
    endcase
  end

  assign wdata_lane_o = wdata_i << (8 * off);

  // --- Load: pull the wanted bytes out of the returned word and extend ---
  wire [ 7:0] byte_sel = rdata_raw_i[8*off+:8];
  wire [15:0] half_sel = off[1] ? rdata_raw_i[31:16] : rdata_raw_i[15:0];

  always @(*) begin
    case (mem_op_i)
      LB_OP:   rdata_o = {{24{byte_sel[7]}}, byte_sel};
      LH_OP:   rdata_o = {{16{half_sel[15]}}, half_sel};
      LBU_OP:  rdata_o = {24'b0, byte_sel};
      LHU_OP:  rdata_o = {16'b0, half_sel};
      LW_OP:   rdata_o = rdata_raw_i;
      default: rdata_o = {XLEN{1'b0}};
    endcase
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */

/* verilator lint_on UNUSEDPARAM */
