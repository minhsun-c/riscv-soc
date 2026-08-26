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
    output     [XLEN-1:0] rdata_o,
    output     [     1:0] rresp_o,

    // Watched by the testbench. A real design would drive a pin.
    output reg           tx_valid_o  /* verilator public */,
    output reg [    7:0] tx_data_o  /* verilator public */
);

  assign bresp_o = 2'b00;
  assign rresp_o = 2'b00;
  assign rdata_o = {XLEN{1'b0}};

  reg aw_taken;

  assign awready_o = !aw_taken && !bvalid_o;
  assign wready_o  = aw_taken;
  assign arready_o = !rvalid_o;

  always @(posedge clk_i) begin
    if (rst_i) begin
      aw_taken   <= 1'b0;
      bvalid_o   <= 1'b0;
      rvalid_o   <= 1'b0;
      tx_valid_o <= 1'b0;
      tx_data_o  <= 8'b0;
    end else begin
      // A character is announced for exactly one cycle.
      tx_valid_o <= 1'b0;

      if (awvalid_i && awready_o) aw_taken <= 1'b1;
      if (wvalid_i && wready_o) begin
        if (wstrb_i[0]) begin
          tx_data_o  <= wdata_i[7:0];
          tx_valid_o <= 1'b1;
        end
        aw_taken <= 1'b0;
        bvalid_o <= 1'b1;
      end
      if (bvalid_o && bready_i) bvalid_o <= 1'b0;

      if (arvalid_i && arready_o) rvalid_o <= 1'b1;
      else if (rvalid_o && rready_i) rvalid_o <= 1'b0;
    end
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */
