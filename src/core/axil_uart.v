`timescale 1ns / 1ps

/**
 * Module: axil_uart (Memory-Mapped Character Output)
 *
 * Description:
 * Write a byte to the data register and it comes out. That is the whole
 * device.
 *
 * There is no baud rate divider and no shift register, so this is not a real
 * UART -- it is the memory-mapped interface of one. That distinction is the
 * point: the serialisation is a self-contained problem with a known answer,
 * while "how does software get a byte to a device" is the thing this course
 * has been building toward. A real TX path would be a week on its own and
 * would teach nothing new about the SoC.
 *
 * Register map, relative to MMAP_UART_BASE:
 *
 *     +0  TXDATA   write: send the low byte.  read: 0
 *     +4  STATUS   read: 0, meaning always ready to accept
 *
 * Reading TXDATA as zero rather than as the last byte written is deliberate:
 * a write-only register that reads back what you wrote invites software to
 * treat it as storage.
 */

/* verilator lint_off UNUSEDSIGNAL */

module axil_uart #(
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
    output     [XLEN-1:0] RDATA,
    output     [     1:0] RRESP,

    // Watched by the testbench. A real design would drive a pin.
    output reg           tx_valid_o  /* verilator public */,
    output reg [    7:0] tx_data_o  /* verilator public */
);

  assign BRESP = 2'b00;
  assign RRESP = 2'b00;
  assign RDATA = {XLEN{1'b0}};

  reg aw_taken;

  assign AWREADY = !aw_taken && !BVALID;
  assign WREADY  = aw_taken;
  assign ARREADY = !RVALID;

  always @(posedge clk_i) begin
    if (rst_i) begin
      aw_taken   <= 1'b0;
      BVALID   <= 1'b0;
      RVALID   <= 1'b0;
      tx_valid_o <= 1'b0;
      tx_data_o  <= 8'b0;
    end else begin
      // A character is announced for exactly one cycle.
      tx_valid_o <= 1'b0;

      if (AWVALID && AWREADY) aw_taken <= 1'b1;
      if (WVALID && WREADY) begin
        if (WSTRB[0]) begin
          tx_data_o  <= WDATA[7:0];
          tx_valid_o <= 1'b1;
        end
        aw_taken <= 1'b0;
        BVALID <= 1'b1;
      end
      if (BVALID && BREADY) BVALID <= 1'b0;

      if (ARVALID && ARREADY) RVALID <= 1'b1;
      else if (RVALID && RREADY) RVALID <= 1'b0;
    end
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */
