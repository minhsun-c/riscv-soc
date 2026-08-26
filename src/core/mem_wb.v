`timescale 1ns / 1ps

/**
 * Module: mem_wb
 *
 * Description:
 * The final pipeline register. It catches the results from the Memory 
 * stage and holds them for the Write-Back phase.
 *
 * @port clk_i          [Input]  [1:0]      System clock.
 * @port rst_i          [Input]  [1:0]      System reset.
 * @port stall_i        [Input]  [1:0]      Freezes the register if the WB 
 *                                          stage is stalled.
 *
 * @port pc_plus4_i     [Input]  [XLEN-1:0] PC + 4 from Memory stage.
 * @port alu_result_i   [Input]  [XLEN-1:0] ALU result from Memory stage.
 * @port mem_data_i     [Input]  [XLEN-1:0] Data loaded from Data Memory.
 * @port rd_addr_i      [Input]  [4:0]      Destination register address.
 *
 * @port rd_wen_i       [Input]  [1:0]      Register file write enable.
 * @port rd_src_i       [Input]  [2:0]      Selects the data source for rd.
 *
 * @port ..._o          [Output] [Various]  Registered versions of the 
 *                                          above inputs.
 */

module mem_wb #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,
    input stall_i,
    // A trap committing in WB squashes everything behind it, this included.
    input flush_i,

    // Data Inputs (Current Cycle)
    input [XLEN-1:0] pc_plus4_i,
    input [XLEN-1:0] alu_result_i,
    input [XLEN-1:0] mem_data_i,
    input [     4:0] rd_addr_i,

    // Control Inputs
    input       rd_wen_i,
    input [2:0] rd_src_i,
    input  exc_valid_i,
    input [3:0] exc_cause_i,
    input  is_mret_i,
    input [11:0] csr_addr_i,
    input  csr_wen_i,
    input [ 2:0] csr_op_i,
    input [XLEN-1:0] csr_operand_i,

    // Latch Outputs (Next Cycle)
    output reg [XLEN-1:0] pc_plus4_o,
    output reg [XLEN-1:0] alu_result_o,
    output reg [XLEN-1:0] mem_data_o,
    output reg [     4:0] rd_addr_o,
    output reg            rd_wen_o,
    output reg [     2:0] rd_src_o,
    output reg  exc_valid_o,
    output reg [3:0] exc_cause_o,
    output reg  is_mret_o,
    output reg [    11:0] csr_addr_o,
    output reg            csr_wen_o,
    output reg [     2:0] csr_op_o,
    output reg [XLEN-1:0] csr_operand_o
);

  always @(posedge clk_i) begin
    if (rst_i || flush_i) begin
      pc_plus4_o   <= {XLEN{1'b0}};
      alu_result_o <= {XLEN{1'b0}};
      mem_data_o   <= {XLEN{1'b0}};
      rd_src_o     <= 3'b0;
      exc_valid_o <= 1'b0;
      exc_cause_o <= 4'b0;
      is_mret_o <= 1'b0;
      csr_addr_o <= 12'b0;
      csr_wen_o <= 1'b0;
      csr_op_o <= 3'b0;
      csr_operand_o <= {XLEN{1'b0}};
      rd_addr_o    <= 5'd0;
      rd_wen_o     <= 1'b0;
    end else if (stall_i) begin
      pc_plus4_o   <= pc_plus4_o;
      alu_result_o <= alu_result_o;
      mem_data_o   <= mem_data_o;
      rd_src_o     <= rd_src_o;
      exc_valid_o <= exc_valid_o;
      exc_cause_o <= exc_cause_o;
      is_mret_o <= is_mret_o;
      csr_addr_o    <= csr_addr_o;
      csr_wen_o     <= csr_wen_o;
      csr_op_o      <= csr_op_o;
      csr_operand_o <= csr_operand_o;
      rd_addr_o    <= rd_addr_o;
      rd_wen_o     <= rd_wen_o;
    end else begin
      pc_plus4_o   <= pc_plus4_i;
      alu_result_o <= alu_result_i;
      mem_data_o   <= mem_data_i;
      rd_src_o     <= rd_src_i;
      exc_valid_o <= exc_valid_i;
      exc_cause_o <= exc_cause_i;
      is_mret_o <= is_mret_i;
      csr_addr_o <= csr_addr_i;
      csr_wen_o <= csr_wen_i;
      csr_op_o <= csr_op_i;
      csr_operand_o <= csr_operand_i;
      rd_addr_o    <= rd_addr_i;
      rd_wen_o     <= rd_wen_i;
    end
  end

endmodule
