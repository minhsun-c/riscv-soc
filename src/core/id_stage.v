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
 * @port rd_src_o      [Output] [2:0]      Control: Selects the data source 
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
    output       alu_sub_o,

    // CSR access, assembled here because this is where the instruction is
    output [11:0] csr_addr_o,
    output        csr_wen_o,
    output [ 2:0] csr_op_o,
    output [XLEN-1:0] csr_operand_o,
    output [XLEN-1:0] rs1_data_o,
    output [XLEN-1:0] rs2_data_o,
    output [XLEN-1:0] imm_o,
    output [     4:0] rd_addr_o,

    // Control Signals to EX
    output       rd_wen_o,
    output [2:0] rd_src_o,
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

  // --- Raw register fields, before format masking ---
  wire [4:0] dec_rs1;
  wire [4:0] dec_rs2;
  wire       ctrl_rs1_ren;
  wire       ctrl_csr_wen;
  wire [2:0] ctrl_csr_op;
  wire       ctrl_rs2_ren;

  decoder u_decoder (
      .inst_i  (inst_i),
      .opcode_o(dec_opcode),
      .rd_o    (rd_addr_o),
      .funct3_o(dec_funct3),
      .rs1_o   (dec_rs1),
      .rs2_o   (dec_rs2),
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
      .rs1_ren_o(ctrl_rs1_ren),
      .rs2_ren_o(ctrl_rs2_ren),
      .csr_wen_o(ctrl_csr_wen),
      .csr_op_o (ctrl_csr_op),

      // ALU Signals
      .alu_src_a_o(alu_src_a_o),
      .alu_src_b_o(alu_src_b_o),
      .alu_op_o   (alu_op_o),
      .alu_shift_o(alu_shift_o),
      .alu_sub_o  (alu_sub_o),

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

  // The decoder slices rs1/rs2 out of fixed bit positions, but not every
  // instruction format actually stores a register there: U and J types spend
  // inst[19:15] on the immediate, and I types spend inst[24:20] on it. Feeding
  // those bits to the register file makes LUI read a pseudo-random register and
  // add it to the immediate, and makes the HDU stall on dependencies that do
  // not exist. Forcing the address to x0 yields the zero operand LUI needs and
  // keeps the hazard comparison honest.
  assign rs1_addr_o = ctrl_rs1_ren ? dec_rs1 : 5'd0;
  assign rs2_addr_o = ctrl_rs2_ren ? dec_rs2 : 5'd0;

  // Both operands leave this stage raw. Subtraction used to negate rs2 here,
  // but the EX operand can now also come from the forwarding path, and a value
  // arriving from MEM/WB has never been through this mux. The two's complement
  // therefore belongs after the forwarding mux, in ex_stage.
  assign rs1_data_o = rs1_data_i;
  assign rs2_data_o = rs2_data_i;

  // --- CSR access ---
  // The address is a plain slice of the instruction. It deliberately does not
  // go through imm_gen: imm_gen is busy producing the *operand* for the
  // immediate forms, and one module cannot hand out two different fields.
  `include "csrop.vh"

  assign csr_addr_o = inst_i[31:20];
  assign csr_op_o   = ctrl_csr_op;

  // Bit 2 of funct3 says where the operand comes from: 0xx reads rs1, 1xx uses
  // the 5-bit zero-extended immediate that imm_gen produced.
  assign csr_operand_o = ctrl_csr_op[2] ? imm_o : rs1_data_i;

  // A set or clear whose operand is zero changes nothing, and the spec says it
  // must not write at all -- so that reading a CSR with side effects stays
  // side-effect free. Nothing here has side effects yet, but the rule is free
  // to obey and expensive to retrofit.
  wire csr_is_set_clear = (ctrl_csr_op == CSR_RS) || (ctrl_csr_op == CSR_RC)
      || (ctrl_csr_op == CSR_RSI) || (ctrl_csr_op == CSR_RCI);
  assign csr_wen_o = ctrl_csr_wen && !(csr_is_set_clear && (csr_operand_o == {XLEN{1'b0}}));

endmodule

/* verilator lint_on UNUSEDPARAM */
/* verilator lint_on UNUSEDSIGNAL */
