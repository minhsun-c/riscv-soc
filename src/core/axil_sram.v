`timescale 1ns / 1ps

/**
 * Module: axil_sram (AXI4-Lite SRAM Slave)
 *
 * Description:
 * A memory that speaks AXI4-Lite. The storage itself is unchanged from week
 * 18 -- words and a byte mask -- which is the point: because lsu.v already
 * removed everything the bus cannot express, wrapping it took no changes to
 * the memory at all.
 *
 * This slave accepts one transaction at a time and answers in the cycle after
 * the address is taken. It deliberately does NOT assert AWREADY and WREADY in
 * the same cycle every time: the write address is taken first and the data a
 * cycle later, so a master that assumes the two channels move together will
 * fail here. Real slaves vary, and assuming otherwise is a common bug.
 */

/* verilator lint_off UNUSEDSIGNAL */

module axil_sram #(
    parameter XLEN = 32,
    parameter NUM_ENTRIES = 1024,
    parameter ADDR_W = $clog2(NUM_ENTRIES)
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
    output     [     1:0] rresp_o
);

  reg [XLEN-1:0] mem[0:NUM_ENTRIES-1]  /* verilator public */;

  // OKAY on everything. A slave that can report SLVERR needs somewhere to
  // report it to, and this core has no bus-error exception yet.
  assign bresp_o = 2'b00;
  assign rresp_o = 2'b00;

  // --- Write: take the address, then the data ---
  reg            aw_taken;
  reg [ADDR_W-1:0] aw_addr;

  assign awready_o = !aw_taken && !bvalid_o;
  assign wready_o  = aw_taken;  // data only after the address, on purpose

  integer b;
  always @(posedge clk_i) begin
    if (rst_i) begin
      aw_taken <= 1'b0;
      bvalid_o <= 1'b0;
    end else begin
      if (awvalid_i && awready_o) begin
        aw_taken <= 1'b1;
        aw_addr  <= awaddr_i[ADDR_W+1:2];
      end
      if (wvalid_i && wready_o) begin
        for (b = 0; b < 4; b = b + 1) begin
          if (wstrb_i[b]) mem[aw_addr][8*b+:8] <= wdata_i[8*b+:8];
        end
        aw_taken <= 1'b0;
        bvalid_o <= 1'b1;
      end
      if (bvalid_o && bready_i) bvalid_o <= 1'b0;
    end
  end

  // --- Read: take the address, answer next cycle ---
  assign arready_o = !rvalid_o;

  always @(posedge clk_i) begin
    if (rst_i) begin
      rvalid_o <= 1'b0;
    end else begin
      if (arvalid_i && arready_o) begin
        rdata_o  <= mem[araddr_i[ADDR_W+1:2]];
        rvalid_o <= 1'b1;
      end else if (rvalid_o && rready_i) begin
        rvalid_o <= 1'b0;
      end
    end
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */
