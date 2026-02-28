`timescale 1ns / 1ps

/**
 * Module: ex_mem
 *
 * Description:
 * Pipeline register between the Execute (EX) and Memory (MEM) stages. 
 * This module captures the combinational results from the EX stage on 
 * the clock edge, ensuring stable data and control signals.
 *
 * @port clk_i        [Input]  [1:0]      System clock.
 * @port rst_i        [Input]  [1:0]      Active-high synchronous reset.
 * @port stall_i      [Input]  [1:0]      Freezes the register if the MEM stage 
 *                                        is busy.
 * @port flush_i      [Input]  [1:0]      Clears control signals (NOP) on branch 
 *                                        mispredicts.
 *
 * @port pc_plus4_i   [Input]  [XLEN-1:0] PC + 4.
 * @port alu_result_i [Input]  [XLEN-1:0] The ALU output (either a result or a 
 *                                        MEM address).
 * @port rs2_data_i   [Input]  [XLEN-1:0] The raw data for Store instructions.
 * @port rd_addr_i    [Input]  [4:0]      The destination register address.
 *
 * @port rd_wen_i     [Input]  [1:0]      Control: Write to Register File?
 * @port rd_src_i     [Input]  [1:0]      Control: Selects the data source for rd.
 * @port mem_op_i     [Input]  [2:0]      Control: 3-bit Memory operation selector.
 * @port mem_wen_i    [Input]  [1:0]      Control: Write to Data SRAM?
 *
 * @port ..._o        [Output] [Various]  Registered versions of the above inputs 
 *                                        passed to the MEM stage.
 */

module ex_mem #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,
    input stall_i,
    input flush_i,

    // Data from EX Stage
    input [XLEN-1:0] pc_plus4_i,
    input [XLEN-1:0] alu_result_i,
    input [XLEN-1:0] rs2_data_i,
    input [     4:0] rd_addr_i,

    // Control Signals (from EX Stage, originally from ID)
    input       rd_wen_i,
    input [1:0] rd_src_i,
    input [2:0] mem_op_i,
    input       mem_wen_i,

    // Outputs to MEM Stage
    output reg [XLEN-1:0] pc_plus4_o,
    output reg [XLEN-1:0] alu_result_o,
    output reg [XLEN-1:0] rs2_data_o,
    output reg [     4:0] rd_addr_o,

    // Control Signals to MEM/WB Stages
    output reg       rd_wen_o,
    output reg [1:0] rd_src_o,
    output reg [2:0] mem_op_o,
    output reg       mem_wen_o
);

  always @(posedge clk_i) begin
    if (rst_i || flush_i) begin
      pc_plus4_o   <= {XLEN{1'b0}};
      alu_result_o <= {XLEN{1'b0}};
      rs2_data_o   <= {XLEN{1'b0}};
      rd_addr_o    <= 5'b0;
      rd_wen_o     <= 1'b0;
      rd_src_o     <= 2'b0;
      mem_wen_o    <= 1'b0;
      mem_op_o     <= 3'b0;
    end else if (stall_i) begin
      pc_plus4_o   <= pc_plus4_o;
      alu_result_o <= alu_result_o;
      rs2_data_o   <= rs2_data_o;
      rd_addr_o    <= rd_addr_o;
      rd_wen_o     <= rd_wen_o;
      rd_src_o     <= rd_src_o;
      mem_wen_o    <= mem_wen_o;
      mem_op_o     <= mem_op_o;
    end else begin
      pc_plus4_o   <= pc_plus4_i;
      alu_result_o <= alu_result_i;
      rs2_data_o   <= rs2_data_i;
      rd_addr_o    <= rd_addr_i;
      rd_wen_o     <= rd_wen_i;
      rd_src_o     <= rd_src_i;
      mem_wen_o    <= mem_wen_i;
      mem_op_o     <= mem_op_i;
    end
  end

endmodule
