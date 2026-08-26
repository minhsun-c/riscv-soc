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

      .awvalid_o(aw_valid), .awready_i(aw_ready), .awaddr_o(aw_addr),
      .wvalid_o (w_valid),  .wready_i (w_ready),  .wdata_o (w_data), .wstrb_o(w_strb),
      .bvalid_i (b_valid),  .bready_o (b_ready),  .bresp_i (b_resp),
      .arvalid_o(ar_valid), .arready_i(ar_ready), .araddr_o(ar_addr),
      .rvalid_i (r_valid),  .rready_o (r_ready),  .rdata_i (r_data), .rresp_i(r_resp)
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

      .m_awvalid_i(aw_valid), .m_awready_o(aw_ready), .m_awaddr_i(aw_addr),
      .m_wvalid_i (w_valid),  .m_wready_o (w_ready),  .m_wdata_i (w_data), .m_wstrb_i(w_strb),
      .m_bvalid_o (b_valid),  .m_bready_i (b_ready),  .m_bresp_o (b_resp),
      .m_arvalid_i(ar_valid), .m_arready_o(ar_ready), .m_araddr_i(ar_addr),
      .m_rvalid_o (r_valid),  .m_rready_i (r_ready),  .m_rdata_o (r_data), .m_rresp_o(r_resp),

      .s_awvalid_o(s_awvalid), .s_awready_i(s_awready), .s_awaddr_o(s_awaddr),
      .s_wvalid_o (s_wvalid),  .s_wready_i (s_wready),  .s_wdata_o (s_wdata), .s_wstrb_o(s_wstrb),
      .s_bvalid_i (s_bvalid),  .s_bready_o (s_bready),
      .s_arvalid_o(s_arvalid), .s_arready_i(s_arready), .s_araddr_o(s_araddr),
      .s_rvalid_i (s_rvalid),  .s_rready_o (s_rready),  .s_rdata_i (s_rdata)
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

      .awvalid_i(s_awvalid[0]), .awready_o(s_awready[0]), .awaddr_i(s_awaddr),
      .wvalid_i (s_wvalid[0]),  .wready_o (s_wready[0]),  .wdata_i (s_wdata), .wstrb_i(s_wstrb),
      .bvalid_o (s_bvalid[0]),  .bready_i (s_bready[0]),  .bresp_o (ram_bresp),
      .arvalid_i(s_arvalid[0]), .arready_o(s_arready[0]), .araddr_i(s_araddr),
      .rvalid_o (s_rvalid[0]),  .rready_i (s_rready[0]),  .rdata_o (s_rdata[XLEN-1:0]),
      .rresp_o  (ram_rresp)
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

      .awvalid_i(s_awvalid[1]), .awready_o(s_awready[1]), .awaddr_i(s_awaddr),
      .wvalid_i (s_wvalid[1]),  .wready_o (s_wready[1]),  .wdata_i (s_wdata), .wstrb_i(s_wstrb),
      .bvalid_o (s_bvalid[1]),  .bready_i (s_bready[1]),  .bresp_o (uart_bresp),
      .arvalid_i(s_arvalid[1]), .arready_o(s_arready[1]), .araddr_i(s_araddr),
      .rvalid_o (s_rvalid[1]),  .rready_i (s_rready[1]),  .rdata_o (s_rdata[XLEN*2-1:XLEN]),
      .rresp_o  (uart_rresp),

      // The testbench reads these directly; a real chip would drive a pin.
      .tx_valid_o(uart_tx_valid), .tx_data_o(uart_tx_data)
  );

  axil_timer #(
      .XLEN(XLEN)
  ) u_timer (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .awvalid_i(s_awvalid[2]), .awready_o(s_awready[2]), .awaddr_i(s_awaddr),
      .wvalid_i (s_wvalid[2]),  .wready_o (s_wready[2]),  .wdata_i (s_wdata), .wstrb_i(s_wstrb),
      .bvalid_o (s_bvalid[2]),  .bready_i (s_bready[2]),  .bresp_o (timer_bresp),
      .arvalid_i(s_arvalid[2]), .arready_o(s_arready[2]), .araddr_i(s_araddr),
      .rvalid_o (s_rvalid[2]),  .rready_i (s_rready[2]),  .rdata_o (s_rdata[XLEN*3-1:XLEN*2]),
      .rresp_o  (timer_rresp),

      .mtip_o(mtip)
  );

endmodule

/* verilator lint_on UNUSEDSIGNAL */
