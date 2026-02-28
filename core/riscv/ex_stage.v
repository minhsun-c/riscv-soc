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

module ex_stage #(
    parameter XLEN = 32
) (
    // Control Inputs (from id_ex)
    input [2:0] alu_op_i,
    input       alu_src_a_i,
    input       alu_src_b_i,
    input       alu_shift_i,
    input       branch_i,
    input [2:0] branch_op_i,
    input       jump_i,

    // Data Inputs (from id_ex)
    input [XLEN-1:0] pc_i,
    input [XLEN-1:0] rs1_data_i,
    input [XLEN-1:0] rs2_data_i,
    input [XLEN-1:0] imm_i,

    // Outputs (to ex_mem and PC mux)
    output [XLEN-1:0] alu_result_o,
    output [XLEN-1:0] jb_target_o,
    output            jb_taken_o
);
  // --- Operand A Multiplexer ---
  // If alu_src_a_i is 1, we use the pc. Otherwise, we use rs1_data_i
  wire [XLEN-1:0] alu_operand_a;
  mux2 #(
      .WIDTH(XLEN)
  ) u_mux2_a (
      .sel_i(alu_src_a_i),
      .a_i  (rs1_data_i),
      .b_i  (pc_i),
      .out_o(alu_operand_a)
  );

  // --- Operand B Multiplexer ---
  // If alu_src_b_i is 1, we use the immediate. Otherwise, we use rs2_data_i
  wire [XLEN-1:0] alu_operand_b;
  mux2 #(
      .WIDTH(XLEN)
  ) u_mux2_b (
      .sel_i(alu_src_b_i),
      .a_i  (rs2_data_i),
      .b_i  (imm_i),
      .out_o(alu_operand_b)
  );

  alu u_alu (
      .a_i         (alu_operand_a),
      .b_i         (alu_operand_b),
      .op_i        (alu_op_i),
      .shift_mode_i(alu_shift_i),
      .result_o    (alu_result_o)
  );


  bcu u_bcu (
      .alu_result_i(alu_result_o),
      .branch_op_i (branch_op_i),
      .branch_i    (branch_i),
      .jump_i      (jump_i),
      .jb_taken_o  (jb_taken_o)
  );

  mux2 #(
      .WIDTH(XLEN)
  ) u_mux2 (
      .sel_i(branch_i),
      .a_i  (alu_result_o),
      .b_i  (pc_i + imm_i),
      .out_o(jb_target_o)
  );

endmodule
