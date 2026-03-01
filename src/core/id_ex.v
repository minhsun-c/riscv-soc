`timescale 1ns / 1ps

/**
 * Module: id_ex
 *
 * Description:
 * Sequential pipeline register between Instruction Decode (ID) and Execute (EX).
 * This module latches all data and control signals to be used in the EX stage.
 * It supports flushing (synchronous reset) to insert NOPs into the pipeline.
 *
 * @port clk_i          [Input]  [1:0]      Clock signal.
 * @port rst_i          [Input]  [1:0]      Synchronous reset (Hard reset).
 * @port flush_i        [Input]  [1:0]      Pipeline flush (Synchronous). When 
 *                                          high, clears control signals.
 *
 * @port pc_i           [Input]  [XLEN-1:0] Program Counter from ID stage.
 * @port pc_plus4_i     [Input]  [XLEN-1:0] PC + 4 from ID stage.
 * @port rs1_data_i     [Input]  [XLEN-1:0] Processed rs1 data from ID stage.
 * @port rs2_data_i     [Input]  [XLEN-1:0] Processed rs2 data from ID stage.
 * @port imm_i          [Input]  [XLEN-1:0] Immediate value from ID stage.
 * @port rd_addr_i      [Input]  [4:0]      Destination register address.
 *
 * @port rd_wen_i       [Input]  [1:0]      Control: Register write enable.
 * @port rd_src_i       [Input]  [1:0]      Control: Selects the data source 
 *                                          for rd.
 * @port alu_src_a_i    [Input]  [1:0]      Control: ALU operand A source.
 * @port alu_src_b_i    [Input]  [1:0]      Control: ALU operand B source.
 * @port alu_op_i       [Input]  [2:0]      Control: 3-bit ALU operation.
 * @port alu_shift_i    [Input]  [1:0]      Control: Shift mode (L/A).
 * @port branch_i       [Input]  [1:0]      Control: Branch flag.
 * @port branch_op_i    [Input]  [2:0]      Control: Branch condition type.
 * @port jump_i         [Input]  [1:0]      Control: Jump flag.
 * @port mem_wen_i      [Input]  [1:0]      Control: Memory write enable.
 * @port mem_op_i       [Input]  [2:0]      Control: 3-bit Memory operation.
 *
 * @port ..._ex_o       [Output] [Various]  Registered versions of the above 
 *                                          inputs passed to the EX stage.
 */

/* verilator lint_off UNUSEDPARAM */

module id_ex #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,
    input flush_i,

    // Data Inputs from ID
    input [XLEN-1:0] pc_i,
    input [XLEN-1:0] pc_plus4_i,
    input [XLEN-1:0] rs1_data_i,
    input [XLEN-1:0] rs2_data_i,
    input [XLEN-1:0] imm_i,
    input [     4:0] rd_addr_i,

    // Control Inputs from ID
    input       rd_wen_i,
    input [1:0] rd_src_i,
    input       alu_src_a_i,
    input       alu_src_b_i,
    input [2:0] alu_op_i,
    input       alu_shift_i,
    input       branch_i,
    input [2:0] branch_op_i,
    input       jump_i,
    input       mem_wen_i,
    input [2:0] mem_op_i,

    // Data Outputs to EX
    output reg [XLEN-1:0] pc_ex_o,
    output reg [XLEN-1:0] pc_plus4_ex_o,
    output reg [XLEN-1:0] rs1_data_ex_o,
    output reg [XLEN-1:0] rs2_data_ex_o,
    output reg [XLEN-1:0] imm_ex_o,
    output reg [     4:0] rd_addr_ex_o,

    // Control Outputs to EX
    output reg       rd_wen_ex_o,
    output reg [1:0] rd_src_ex_o,
    output reg       alu_src_a_ex_o,
    output reg       alu_src_b_ex_o,
    output reg [2:0] alu_op_ex_o,
    output reg       alu_shift_ex_o,
    output reg       branch_ex_o,
    output reg [2:0] branch_op_ex_o,
    output reg       jump_ex_o,
    output reg       mem_wen_ex_o,
    output reg [2:0] mem_op_ex_o
);
  `include "branchop.vh"

  always @(posedge clk_i) begin
    if (rst_i || flush_i) begin
      pc_ex_o        <= {XLEN{1'b0}};
      pc_plus4_ex_o  <= {XLEN{1'b0}};
      rs1_data_ex_o  <= {XLEN{1'b0}};
      rs2_data_ex_o  <= {XLEN{1'b0}};
      imm_ex_o       <= {XLEN{1'b0}};
      rd_addr_ex_o   <= 5'b0;

      rd_wen_ex_o    <= 1'b0;
      rd_src_ex_o    <= 2'b0;
      alu_src_a_ex_o <= 1'b0;
      alu_src_b_ex_o <= 1'b0;
      alu_op_ex_o    <= 3'b0;
      alu_shift_ex_o <= 1'b0;
      branch_ex_o    <= 1'b0;
      branch_op_ex_o <= NOBR_OP;
      jump_ex_o      <= 1'b0;
      mem_wen_ex_o   <= 1'b0;
      mem_op_ex_o    <= 3'b0;
    end else begin
      pc_ex_o        <= pc_i;
      pc_plus4_ex_o  <= pc_plus4_i;
      rs1_data_ex_o  <= rs1_data_i;
      rs2_data_ex_o  <= rs2_data_i;
      imm_ex_o       <= imm_i;
      rd_addr_ex_o   <= rd_addr_i;
      rd_wen_ex_o    <= rd_wen_i;
      rd_src_ex_o    <= rd_src_i;
      alu_src_a_ex_o <= alu_src_a_i;
      alu_src_b_ex_o <= alu_src_b_i;
      alu_op_ex_o    <= alu_op_i;
      alu_shift_ex_o <= alu_shift_i;
      branch_ex_o    <= branch_i;
      branch_op_ex_o <= branch_op_i;
      jump_ex_o      <= jump_i;
      mem_wen_ex_o   <= mem_wen_i;
      mem_op_ex_o    <= mem_op_i;
    end
  end

endmodule

/* verilator lint_on UNUSEDPARAM */
