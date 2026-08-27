`timescale 1ns / 1ps

/**
 * Module: cpu
 *
 * Description:
 * The top-level system wrapper. This module instantiates the RISC-V core 
 * and connects it to separate Instruction and Data SRAM blocks in a 
 * Harvard architecture configuration.
 *
 * Parameters:
 * XLEN : Word width (default 32)
 *
 * @port clk_i        [Input]  [1:0]      Global clock signal.
 * @port rst_i        [Input]  [1:0]      Global reset signal (active high).
 */

// Slave slots 1 and 2 are stubs until week 20, so parts of the flattened
// slave buses are legitimately unread.
/* verilator lint_off UNUSEDSIGNAL */

module cpu #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i
);

  // Instruction memory port. LATENCY 0, so this handshake completes in the
  // cycle it is issued -- the old behaviour, wearing the new protocol.
  wire            im_req, im_ready, im_rvalid;
  wire [XLEN-1:0] im_addr, im_data;

  // Data memory port. LATENCY 1: every load and store costs a cycle now.
  wire            dm_req, dm_ready, dm_rvalid;
  wire [XLEN-1:0] dm_addr, dm_wdata, dm_rdata;
  wire [     3:0] dm_wstrb;

  // The timer's request for attention.
  wire            mtip;

  core #(
      .XLEN(XLEN)
  ) u_core (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .im_req_o   (im_req),
      .im_addr_o  (im_addr),
      .im_ready_i (im_ready),
      .im_rvalid_i(im_rvalid),
      .im_data_i  (im_data),

      .dm_req_o   (dm_req),
      .dm_addr_o  (dm_addr),
      .dm_wdata_o (dm_wdata),
      .dm_wstrb_o (dm_wstrb),
      .dm_ready_i (dm_ready),
      .dm_rvalid_i(dm_rvalid),
      .dm_rdata_i (dm_rdata),
      .mtip_i     (mtip)
  );

  // -------------------------------------------------------------------------
  // Instruction SRAM
  // -------------------------------------------------------------------------
  // Zero latency, and the core never writes it -- wstrb tied off means every
  // access is a read. Making this one cycle without pipelining fetch would
  // roughly double CPI; see the week 18 lesson.
  sram #(
      .XLEN(XLEN),
      .NUM_ENTRIES(1024),
      .LATENCY(0)
  ) u_imem (
      .clk_i   (clk_i),
      .req_i   (im_req),
      .addr_i  (im_addr),
      .wdata_i ({XLEN{1'b0}}),
      .wstrb_i (4'b0000),
      .ready_o (im_ready),
      .rvalid_o(im_rvalid),
      .rdata_o (im_data)
  );

  // -------------------------------------------------------------------------
  // Data path: AXI4-Lite
  // -------------------------------------------------------------------------
  // The core's req/ready/rvalid port goes through an adapter onto a bus, and
  // the bus decides which device answers. Nothing in the core changed to make
  // this possible -- week 18's LSU split is what made the request expressible
  // as address + word + WSTRB in the first place.
  wire            aw_valid, aw_ready, w_valid, w_ready, b_valid, b_ready;
  wire            ar_valid, ar_ready, r_valid, r_ready;
  wire [XLEN-1:0] aw_addr, w_data, ar_addr, r_data;
  wire [     3:0] w_strb;
  wire [     1:0] b_resp, r_resp;

  axil_master #(
      .XLEN(XLEN)
  ) u_axil_master (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .req_i   (dm_req),
      .addr_i  (dm_addr),
      .wdata_i (dm_wdata),
      .wstrb_i (dm_wstrb),
      .ready_o (dm_ready),
      .rvalid_o(dm_rvalid),
      .rdata_o (dm_rdata),

      .AWVALID(aw_valid), .AWREADY(aw_ready), .AWADDR(aw_addr),
      .WVALID (w_valid),  .WREADY (w_ready),  .WDATA (w_data), .WSTRB(w_strb),
      .BVALID (b_valid),  .BREADY (b_ready),  .BRESP (b_resp),
      .ARVALID(ar_valid), .ARREADY(ar_ready), .ARADDR(ar_addr),
      .RVALID (r_valid),  .RREADY (r_ready),  .RDATA (r_data), .RRESP(r_resp)
  );

  // Three slave ports. Only the RAM exists this week; UART and timer arrive in
  // week 20 and plug into the spare slots without touching anything else.
  wire [2:0] s_awvalid, s_awready, s_wvalid, s_wready, s_bvalid, s_bready;
  wire [2:0] s_arvalid, s_arready, s_rvalid, s_rready;
  wire [XLEN-1:0] s_awaddr, s_wdata, s_araddr;
  wire [3:0] s_wstrb;
  wire [XLEN*3-1:0] s_rdata;

  axil_xbar #(
      .XLEN(XLEN)
  ) u_xbar (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .M_AWVALID(aw_valid), .M_AWREADY(aw_ready), .M_AWADDR(aw_addr),
      .M_WVALID (w_valid),  .M_WREADY (w_ready),  .M_WDATA (w_data), .M_WSTRB(w_strb),
      .M_BVALID (b_valid),  .M_BREADY (b_ready),  .M_BRESP (b_resp),
      .M_ARVALID(ar_valid), .M_ARREADY(ar_ready), .M_ARADDR(ar_addr),
      .M_RVALID (r_valid),  .M_RREADY (r_ready),  .M_RDATA (r_data), .M_RRESP(r_resp),

      .S_AWVALID(s_awvalid), .S_AWREADY(s_awready), .S_AWADDR(s_awaddr),
      .S_WVALID (s_wvalid),  .S_WREADY (s_wready),  .S_WDATA (s_wdata), .S_WSTRB(s_wstrb),
      .S_BVALID (s_bvalid),  .S_BREADY (s_bready),
      .S_ARVALID(s_arvalid), .S_ARREADY(s_arready), .S_ARADDR(s_araddr),
      .S_RVALID (s_rvalid),  .S_RREADY (s_rready),  .S_RDATA (s_rdata)
  );

  // The xbar reports OKAY on the master side regardless, so these are only
  // here to avoid an unconnected-pin warning. Week 20's exercise is to route
  // a real SLVERR into the trap machinery week 17 built.
  wire [1:0] ram_bresp, ram_rresp;

  axil_sram #(
      .XLEN(XLEN),
      .NUM_ENTRIES(1024)
  ) u_dmem (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .AWVALID(s_awvalid[0]), .AWREADY(s_awready[0]), .AWADDR(s_awaddr),
      .WVALID (s_wvalid[0]),  .WREADY (s_wready[0]),  .WDATA (s_wdata), .WSTRB(s_wstrb),
      .BVALID (s_bvalid[0]),  .BREADY (s_bready[0]),  .BRESP (ram_bresp),
      .ARVALID(s_arvalid[0]), .ARREADY(s_arready[0]), .ARADDR(s_araddr),
      .RVALID (s_rvalid[0]),  .RREADY (s_rready[0]),  .RDATA (s_rdata[XLEN-1:0]),
      .RRESP  (ram_rresp)
  );

  // -------------------------------------------------------------------------
  // Peripherals
  // -------------------------------------------------------------------------
  // These plug into the slots week 19 left empty. The crossbar does not change.
  wire [1:0] uart_bresp, uart_rresp, timer_bresp, timer_rresp;
  wire       uart_tx_valid;
  wire [7:0] uart_tx_data;

  axil_uart #(
      .XLEN(XLEN)
  ) u_uart (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .AWVALID(s_awvalid[1]), .AWREADY(s_awready[1]), .AWADDR(s_awaddr),
      .WVALID (s_wvalid[1]),  .WREADY (s_wready[1]),  .WDATA (s_wdata), .WSTRB(s_wstrb),
      .BVALID (s_bvalid[1]),  .BREADY (s_bready[1]),  .BRESP (uart_bresp),
      .ARVALID(s_arvalid[1]), .ARREADY(s_arready[1]), .ARADDR(s_araddr),
      .RVALID (s_rvalid[1]),  .RREADY (s_rready[1]),  .RDATA (s_rdata[XLEN*2-1:XLEN]),
      .RRESP  (uart_rresp),

      // The testbench reads these directly; a real chip would drive a pin.
      .tx_valid_o(uart_tx_valid), .tx_data_o(uart_tx_data)
  );

  axil_timer #(
      .XLEN(XLEN)
  ) u_timer (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .AWVALID(s_awvalid[2]), .AWREADY(s_awready[2]), .AWADDR(s_awaddr),
      .WVALID (s_wvalid[2]),  .WREADY (s_wready[2]),  .WDATA (s_wdata), .WSTRB(s_wstrb),
      .BVALID (s_bvalid[2]),  .BREADY (s_bready[2]),  .BRESP (timer_bresp),
      .ARVALID(s_arvalid[2]), .ARREADY(s_arready[2]), .ARADDR(s_araddr),
      .RVALID (s_rvalid[2]),  .RREADY (s_rready[2]),  .RDATA (s_rdata[XLEN*3-1:XLEN*2]),
      .RRESP  (timer_rresp),

      .mtip_o(mtip)
  );

endmodule

/* verilator lint_on UNUSEDSIGNAL */
