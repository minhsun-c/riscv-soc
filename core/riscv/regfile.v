
`timescale 1ns / 1ps

/**
 * Module: regfile
 *
 * Description:
 * A dual-read, single-write Register File for a RISC-V processor. 
 * This implementation follows the RISC-V specification where register 
 * x0 is hardwired to zero.
 *
 * @param NUM_REGS     Number of registers in the file (default 32).
 * @param XLEN         Word width (default 32).
 *
 * @port clk_i         [Input]  [1:0]       System clock; updates occur on the 
 *                                          rising edge.
 * @port rst_i         [Input]  [1:0]       System reset.
 *
 * @port rs1_addr_i    [Input]  [NRLEN-1:0] Address of first source register 
 *                                          to read.
 * @port rs2_addr_i    [Input]  [NRLEN-1:0] Address of second source register 
 *                                          to read.
 *
 * @port rd_we_i       [Input]  [1:0]       Register File write enable.
 * @port rd_addr_i     [Input]  [NRLEN-1:0] Destination register address.
 * @port rd_data_i     [Input]  [XLEN-1:0]  Data to be written into rd.
 *
 * @port rs1_data_o    [Output] [XLEN-1:0]  Data output from rs1 port.
 * @port rs2_data_o    [Output] [XLEN-1:0]  Data output from rs2 port.
 */

module regfile #(
    parameter NUM_REGS = 32,
    parameter XLEN = 32,
    parameter NRLEN = $clog2(NUM_REGS)  // address width for register file
) (
    // System signals
    input clk_i,
    input rst_i,

    // from Decode
    input [NRLEN-1 : 0] rs1_addr_i,
    input [NRLEN-1 : 0] rs2_addr_i,

    // from Writeback
    input               rd_we_i,
    input [NRLEN-1 : 0] rd_addr_i,
    input [ XLEN-1 : 0] rd_data_i,

    // to Decode
    output [XLEN-1 : 0] rs1_data_o,
    output [XLEN-1 : 0] rs2_data_o
);
  reg [XLEN-1 : 0] x[0 : NUM_REGS-1]  /* verilator public */;

  // --- Asynchronous Read Logic ---
  // RISC-V x0 is hardwired to zero. If the address is 0, output 0.
  assign rs1_data_o = (rs1_addr_i == 0) ? {XLEN{1'b0}} : x[rs1_addr_i];
  assign rs2_data_o = (rs2_addr_i == 0) ? {XLEN{1'b0}} : x[rs2_addr_i];

  // --- Synchronous Write Logic ---
  always @(negedge clk_i) begin
    if (rst_i) begin
      for (integer i = 0; i < XLEN; i = i + 1) x[i] <= {XLEN{1'b0}};
    end else if (rd_we_i && rd_addr_i != 0) begin
      x[rd_addr_i] <= rd_data_i;
    end
  end

endmodule
