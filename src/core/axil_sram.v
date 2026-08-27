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
    output     [     1:0] RRESP
);

  reg [XLEN-1:0] mem[0:NUM_ENTRIES-1]  /* verilator public */;

  // OKAY on everything. A slave that can report SLVERR needs somewhere to
  // report it to, and this core has no bus-error exception yet.
  assign BRESP = 2'b00;
  assign RRESP = 2'b00;

  // --- Write: take the address, then the data ---
  reg            aw_taken;
  reg [ADDR_W-1:0] aw_addr;

  assign AWREADY = !aw_taken && !BVALID;
  assign WREADY  = aw_taken;  // data only after the address, on purpose

  integer b;
  always @(posedge clk_i) begin
    if (rst_i) begin
      aw_taken <= 1'b0;
      BVALID <= 1'b0;
    end else begin
      if (AWVALID && AWREADY) begin
        aw_taken <= 1'b1;
        aw_addr  <= AWADDR[ADDR_W+1:2];
      end
      if (WVALID && WREADY) begin
        for (b = 0; b < 4; b = b + 1) begin
          if (WSTRB[b]) mem[aw_addr][8*b+:8] <= WDATA[8*b+:8];
        end
        aw_taken <= 1'b0;
        BVALID <= 1'b1;
      end
      if (BVALID && BREADY) BVALID <= 1'b0;
    end
  end

  // --- Read: take the address, answer next cycle ---
  assign ARREADY = !RVALID;

  always @(posedge clk_i) begin
    if (rst_i) begin
      RVALID <= 1'b0;
    end else begin
      if (ARVALID && ARREADY) begin
        RDATA  <= mem[ARADDR[ADDR_W+1:2]];
        RVALID <= 1'b1;
      end else if (RVALID && RREADY) begin
        RVALID <= 1'b0;
      end
    end
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */
