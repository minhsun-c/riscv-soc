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
 * @port rd_src_i     [Input]  [2:0]      Control: Selects the data source for rd.
 * @port mem_op_i     [Input]  [2:0]      Control: 3-bit Memory operation selector.
 * @port mem_wen_i    [Input]  [1:0]      Control: Write to Data SRAM?
 *
 * @port ..._o        [Output] [Various]  Registered versions of the above inputs 
 *                                        passed to the MEM stage.
 */

/* verilator lint_off UNUSEDPARAM */

module ex_stage #(
    parameter XLEN = 32
) (
    // Control Inputs (from id_ex)
    input [2:0] alu_op_i,
    input       alu_src_a_i,
    input       alu_src_b_i,
    input       alu_shift_i,
    input       alu_sub_i,
    input       branch_i,
    input [2:0] branch_op_i,
    input       jump_i,

    // Data Inputs (from id_ex)
    input [XLEN-1:0] pc_i,
    input [XLEN-1:0] pc_plus4_i,

    // What IF guessed for this instruction, carried down by if_id and id_ex
    input            pred_taken_i,
    input [XLEN-1:0] pred_target_i,
    input [XLEN-1:0] rs1_data_i,
    input [XLEN-1:0] rs2_data_i,
    input [XLEN-1:0] imm_i,

    // Forwarding: selectors from fwd, and the two in-flight values they pick from
    input [      1:0] fwd_a_i,
    input [      1:0] fwd_b_i,
    input [XLEN-1:0] fwd_mem_data_i,
    input [XLEN-1:0] fwd_wb_data_i,

    // Outputs (to ex_mem and PC mux)
    output [XLEN-1:0] rs1_fwd_o,
    output [XLEN-1:0] rs2_fwd_o,
    output [XLEN-1:0] alu_result_o,
    output [XLEN-1:0] jb_target_o,
    output            jb_taken_o,

    // Was the guess wrong, and if so where should fetch actually be
    output            redirect_o,
    output [XLEN-1:0] redirect_pc_o
);
  `include "fwdsel.vh"

  // --- Forwarding Multiplexers ---
  // rs1_data_i / rs2_data_i are what id_ex latched from the register file. If a
  // still-in-flight instruction is going to overwrite that register, fwd says so
  // and the newer value is taken from MEM or WB instead. Written as a case rather
  // than a mux3 module: this is the operand-selection stage, and the selection
  // logic belongs here in plain sight.
  reg [XLEN-1:0] rs1_fwd;
  always @(*) begin
    case (fwd_a_i)
      FWD_MEM: rs1_fwd = fwd_mem_data_i;
      FWD_WB:  rs1_fwd = fwd_wb_data_i;
      default: rs1_fwd = rs1_data_i;
    endcase
  end

  reg [XLEN-1:0] rs2_fwd;
  always @(*) begin
    case (fwd_b_i)
      FWD_MEM: rs2_fwd = fwd_mem_data_i;
      FWD_WB:  rs2_fwd = fwd_wb_data_i;
      default: rs2_fwd = rs2_data_i;
    endcase
  end

  // Store data leaves here, after forwarding but before the two's complement.
  // ex_mem used to take rs2 straight from id_ex, which would store the stale
  // value for `sw` on a register the previous instruction just computed.
  // Anything outside this module that consumes a register value has to take
  // it from here, not from id_ex. The CSR operand learned that the hard way:
  // reading rs1_data_i directly in id_stage gave it the stale value whenever
  // the previous instruction had just computed it.
  assign rs1_fwd_o = rs1_fwd;
  assign rs2_fwd_o = rs2_fwd;

  // --- Operand A Multiplexer ---
  // If alu_src_a_i is 1, we use the pc. Otherwise, we use the forwarded rs1
  wire [XLEN-1:0] alu_operand_a;
  mux2 #(
      .WIDTH(XLEN)
  ) u_mux2_a (
      .sel_i(alu_src_a_i),
      .a_i  (rs1_fwd),
      .b_i  (pc_i),
      .out_o(alu_operand_a)
  );

  // --- Operand B Multiplexer ---
  // If alu_src_b_i is 1, we use the immediate. Otherwise, we use rs2_operand
  wire [XLEN-1:0] alu_operand_b;
  mux2 #(
      .WIDTH(XLEN)
  ) u_mux2_b (
      .sel_i(alu_src_b_i),
      .a_i  (rs2_fwd),
      .b_i  (imm_i),
      .out_o(alu_operand_b)
  );

  alu u_alu (
      .a_i         (alu_operand_a),
      .b_i         (alu_operand_b),
      .op_i        (alu_op_i),
      .shift_mode_i(alu_shift_i),
      .sub_i       (alu_sub_i),
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

  // --- Checking the guess ---
  // jb_taken_o / jb_target_o are the truth: this is where the branch was
  // actually resolved. The prediction is only worth acting on if it agreed
  // with both halves of that truth.
  //
  // Getting "taken" right is not enough on its own -- a btb entry can survive
  // from a different branch that mapped to the same index and hand back the
  // wrong target, so the target has to be checked too.
  wire target_ok = (pred_target_i == jb_target_o);

  assign redirect_o = jb_taken_o ? !(pred_taken_i && target_ok)  // guessed not-taken, or right idea wrong target
                                 : pred_taken_i;                 // guessed taken, but it was not

  // Where fetch should have gone. Note this is the correct PC either way, not
  // "the target" -- a branch predicted taken that turns out not to be has to
  // send fetch back to the instruction after itself.
  assign redirect_pc_o = jb_taken_o ? jb_target_o : pc_plus4_i;

endmodule

/* verilator lint_on UNUSEDPARAM */
