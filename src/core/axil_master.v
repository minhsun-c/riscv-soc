`timescale 1ns / 1ps

/**
 * Module: axil_master (AXI4-Lite Master Adapter)
 *
 * Description:
 * Turns the core's req/ready/rvalid port into AXI4-Lite's five channels.
 *
 * The core asks for one thing at a time, so this adapter never has more than
 * one transaction in flight -- which is also all AXI4-Lite allows. What it
 * does have to handle is that the five channels complete independently:
 *
 *     AW  write address     -+
 *     W   write data        -+-> both must be accepted, in either order
 *     B   write response    ---> then this arrives
 *     AR  read address      ---> accepted
 *     R   read data         ---> then this arrives
 *
 * AW and W being separate is the whole reason AXI is shaped like this. The
 * address can be accepted before the data is ready, or after -- a slave may
 * take them in either order and the master may not assume one. So this keeps
 * a flag per channel and only moves on when both have gone.
 *
 * Every channel follows the same rule: once VALID is asserted it stays
 * asserted, and the payload does not change, until READY is seen. Pulling
 * VALID back because the requester changed its mind is the classic way to
 * deadlock a real slave, and axil_checker.h watches for exactly that.
 */

// BRESP and RRESP are accepted and ignored: reporting a bus error needs an
// exception to report it to, and this core has none. Week 17 gave it the
// machinery, so wiring SLVERR to a trap is a real exercise, not a stub.
/* verilator lint_off UNUSEDSIGNAL */

module axil_master #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,

    // --- Core side ---
    input             req_i,
    input  [XLEN-1:0] addr_i,
    input  [XLEN-1:0] wdata_i,
    input  [     3:0] wstrb_i,
    output            ready_o,
    output            rvalid_o,
    output [XLEN-1:0] rdata_o,

    // --- AXI4-Lite write address channel ---
    output reg            awvalid_o,
    input                 awready_i,
    output     [XLEN-1:0] awaddr_o,

    // --- AXI4-Lite write data channel ---
    output reg            wvalid_o,
    input                 wready_i,
    output     [XLEN-1:0] wdata_o,
    output     [     3:0] wstrb_o,

    // --- AXI4-Lite write response channel ---
    input        bvalid_i,
    output       bready_o,
    input  [1:0] bresp_i,

    // --- AXI4-Lite read address channel ---
    output reg            arvalid_o,
    input                 arready_i,
    output     [XLEN-1:0] araddr_o,

    // --- AXI4-Lite read data channel ---
    input             rvalid_i,
    output            rready_o,
    input  [XLEN-1:0] rdata_i,
    input  [     1:0] rresp_i
);

  localparam [1:0] S_IDLE = 2'd0, S_WRITE = 2'd1, S_READ = 2'd2;

  reg [1:0] state;
  reg [XLEN-1:0] addr_q, wdata_q;
  reg [     3:0] wstrb_q;

  // Payload is registered so it cannot change while VALID is high.
  assign awaddr_o = addr_q;
  assign araddr_o = addr_q;
  assign wdata_o  = wdata_q;
  assign wstrb_o  = wstrb_q;

  // Always able to accept a response. A master that can back-pressure B or R
  // is legal but buys nothing here -- the pipeline is stalled waiting anyway.
  assign bready_o = 1'b1;
  assign rready_o = 1'b1;

  // The core's port only accepts a new request when nothing is in flight.
  assign ready_o  = (state == S_IDLE);
  assign rvalid_o = (state == S_READ && rvalid_i) || (state == S_WRITE && bvalid_i);
  assign rdata_o  = rdata_i;

  always @(posedge clk_i) begin
    if (rst_i) begin
      state     <= S_IDLE;
      awvalid_o <= 1'b0;
      wvalid_o  <= 1'b0;
      arvalid_o <= 1'b0;
      addr_q    <= {XLEN{1'b0}};
      wdata_q   <= {XLEN{1'b0}};
      wstrb_q   <= 4'b0;
    end else begin
      case (state)
        S_IDLE: begin
          if (req_i) begin
            addr_q  <= addr_i;
            wdata_q <= wdata_i;
            wstrb_q <= wstrb_i;
            if (|wstrb_i) begin
              // A write raises both address and data channels at once. The
              // slave may take them in either order.
              awvalid_o <= 1'b1;
              wvalid_o  <= 1'b1;
              state     <= S_WRITE;
            end else begin
              arvalid_o <= 1'b1;
              state     <= S_READ;
            end
          end
        end

        S_WRITE: begin
          // Each channel drops its own VALID as soon as that channel's READY
          // has been seen, and not before.
          if (awvalid_o && awready_i) awvalid_o <= 1'b0;
          if (wvalid_o && wready_i) wvalid_o <= 1'b0;
          if (bvalid_i) state <= S_IDLE;
        end

        S_READ: begin
          if (arvalid_o && arready_i) arvalid_o <= 1'b0;
          if (rvalid_i) state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */
