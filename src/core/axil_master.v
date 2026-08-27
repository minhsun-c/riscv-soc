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
    output reg            AWVALID,
    input                 AWREADY,
    output     [XLEN-1:0] AWADDR,

    // --- AXI4-Lite write data channel ---
    output reg            WVALID,
    input                 WREADY,
    output     [XLEN-1:0] WDATA,
    output     [     3:0] WSTRB,

    // --- AXI4-Lite write response channel ---
    input        BVALID,
    output       BREADY,
    input  [1:0] BRESP,

    // --- AXI4-Lite read address channel ---
    output reg            ARVALID,
    input                 ARREADY,
    output     [XLEN-1:0] ARADDR,

    // --- AXI4-Lite read data channel ---
    input             RVALID,
    output            RREADY,
    input  [XLEN-1:0] RDATA,
    input  [     1:0] RRESP
);

  localparam [1:0] S_IDLE = 2'd0, S_WRITE = 2'd1, S_READ = 2'd2;

  reg [1:0] state;
  reg [XLEN-1:0] addr_q, wdata_q;
  reg [     3:0] wstrb_q;

  // Payload is registered so it cannot change while VALID is high.
  assign AWADDR = addr_q;
  assign ARADDR = addr_q;
  assign WDATA  = wdata_q;
  assign WSTRB  = wstrb_q;

  // Always able to accept a response. A master that can back-pressure B or R
  // is legal but buys nothing here -- the pipeline is stalled waiting anyway.
  assign BREADY = 1'b1;
  assign RREADY = 1'b1;

  // The core's port only accepts a new request when nothing is in flight.
  assign ready_o  = (state == S_IDLE);
  assign rvalid_o = (state == S_READ && RVALID) || (state == S_WRITE && BVALID);
  assign rdata_o  = RDATA;

  always @(posedge clk_i) begin
    if (rst_i) begin
      state     <= S_IDLE;
      AWVALID <= 1'b0;
      WVALID  <= 1'b0;
      ARVALID <= 1'b0;
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
              AWVALID <= 1'b1;
              WVALID  <= 1'b1;
              state     <= S_WRITE;
            end else begin
              ARVALID <= 1'b1;
              state     <= S_READ;
            end
          end
        end

        S_WRITE: begin
          // Each channel drops its own VALID as soon as that channel's READY
          // has been seen, and not before.
          if (AWVALID && AWREADY) AWVALID <= 1'b0;
          if (WVALID && WREADY) WVALID <= 1'b0;
          if (BVALID) state <= S_IDLE;
        end

        S_READ: begin
          if (ARVALID && ARREADY) ARVALID <= 1'b0;
          if (RVALID) state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */
