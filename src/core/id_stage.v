`timescale 1ns / 1ps

/**
 * Module: id_stage
 *
 * Description:
 * A pure combinational Instruction Decode stage. It decodes the raw 
 * instruction, generates control signals, extracts the immediate, 
 * and prepares register data.
 *
 * @port inst_i        [Input]  [XLEN-1:0] 32-bit raw instruction from 
 *                                         instruction memory.
 * @port rs1_data_i    [Input]  [XLEN-1:0] Raw data read from Register 
 *                                         File port 1.
 * @port rs2_data_i    [Input]  [XLEN-1:0] Raw data read from Register 
 *                                         File port 2.
 * @port rs1_addr_o    [Output] [4:0]      Address of rs1 to be sent to 
 *                                         Register File.
 * @port rs2_addr_o    [Output] [4:0]      Address of rs2 to be sent to 
 *                                         Register File.
 * @port rs1_data_o    [Output] [XLEN-1:0] Final processed data for 
 *                                         operand A.
 * @port rs2_data_o    [Output] [XLEN-1:0] Final processed data for operand 
 *                                         B (pre-inverted if SUB).
 * @port imm_o         [Output] [XLEN-1:0] Sign-extended immediate value.
 * @port rd_addr_o     [Output] [4:0]      Destination register address.
 * @port rd_src_o      [Output] [1:0]      Control: Selects the data source 
 *                                         for rd.
 * @port rd_wen_o      [Output] [1:0]      Control: Enable register file 
 *                                         write-back.
 * @port alu_src_a_o   [Output] [1:0]      Control: Select ALU input A 
 *                                         (0: Reg, 1: Pc).
 * @port alu_src_b_o   [Output] [1:0]      Control: Select ALU input B 
 *                                         (0: Reg, 1: Imm).
 * @port alu_op_o      [Output] [2:0]      Control: 3-bit ALU operation code.
 * @port alu_shift_o   [Output] [1:0]      Control: Shift type (0: L, 1: A).
 * @port branch_o      [Output] [1:0]      Control: Instruction is a branch.
 * @port branch_op_o   [Output] [2:0]      Control: 3-bit branch operation code.
 * @port jump_o        [Output] [1:0]      Control: Instruction is a jump.
 * @port mem_wen_o     [Output] [1:0]      Control: Enable memory write.
 * @port mem_op_o      [Output] [2:0]      Control: 3-bit memory operation code.
 */

/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNUSEDPARAM */

module id_stage #(
    parameter XLEN = 32
) (
    // Inputs from IF/ID Pipeline Register
    input [XLEN-1:0] inst_i,

    // Combinational Outputs TO external RegFile
    output [4:0] rs1_addr_o,
    output [4:0] rs2_addr_o,

    // Combinational Inputs FROM external RegFile
    input [XLEN-1:0] rs1_data_i,
    input [XLEN-1:0] rs2_data_i,

    // Data Signals to EX
    output [XLEN-1:0] rs1_data_o,
    output [XLEN-1:0] rs2_data_o,
    output [XLEN-1:0] imm_o,
    output [     4:0] rd_addr_o,

    // Control Signals to EX
    output       rd_wen_o,
    output [1:0] rd_src_o,
    output       alu_src_a_o,
    output       alu_src_b_o,
    output [2:0] alu_op_o,
    output       alu_shift_o,
    output       branch_o,
    output [2:0] branch_op_o,
    output       jump_o,
    output       mem_wen_o,
    output [2:0] mem_op_o
);

  // --- Internal Wires from Decoder ---
  wire [6:0] dec_opcode;
  wire [2:0] dec_funct3;
  wire [6:0] dec_funct7;

  // --- Internal Wire from ImmGen ---
  wire [2:0] ctrl_imm_sel;
  wire       ctrl_alu_sub;

  decoder u_decoder (
      .inst_i  (inst_i),
      .opcode_o(dec_opcode),
      .rd_o    (rd_addr_o),
      .funct3_o(dec_funct3),
      .rs1_o   (rs1_addr_o),
      .rs2_o   (rs2_addr_o),
      .funct7_o(dec_funct7)
  );

  ctrl u_ctrl (
      // Inputs from Decoder
      .opcode_i(dec_opcode),
      .funct3_i(dec_funct3),
      .funct7_i(dec_funct7),

      // RegFile & ImmGen Signals
      .rd_src_o (rd_src_o),
      .rd_wen_o (rd_wen_o),
      .imm_sel_o(ctrl_imm_sel),

      // ALU Signals
      .alu_src_a_o(alu_src_a_o),
      .alu_src_b_o(alu_src_b_o),
      .alu_op_o   (alu_op_o),
      .alu_shift_o(alu_shift_o),
      .alu_sub_o  (ctrl_alu_sub),

      // Branch & Jump Signals
      .branch_o(branch_o),
      .branch_op_o(branch_op_o),
      .jump_o(jump_o),

      // Memory Signals
      .mem_wen_o(mem_wen_o),
      .mem_op_o (mem_op_o)
  );

  imm_gen u_imm_gen (
      .inst_i(inst_i),
      .sel_i (ctrl_imm_sel),
      .imm_o (imm_o)
  );

  assign rs1_data_o = rs1_data_i;
  assign rs2_data_o = (ctrl_alu_sub) ? ~rs2_data_i + 1 : rs2_data_i;

endmodule

/* verilator lint_on UNUSEDPARAM */
/* verilator lint_on UNUSEDSIGNAL */
