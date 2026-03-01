`timescale 1ns / 1ps

/**
 * Module: bcu (Branch Control Unit)
 *
 * Description:
 * Evaluates branch outcomes based on the ALU's computed result.
 * - BEQ/BNE:  Expects ALU to perform SUB (A-B). Checks for zero.
 * - BLT/BLTU: Expects ALU to perform SLT/SLTU. Checks if result is 1.
 * - BGE/BGEU: Expects ALU to perform SLT/SLTU. Checks if result is 0.
 *
 * @port alu_result_i   [Input]  [XLEN-1:0] The result from the ALU.
 * @port branch_op_i    [Input]  [2:0]      3-bit branch type (funct3).
 * @port branch_i       [Input]  [1:0]      Control: Instruction is a branch.
 * @port jump_i         [Input]  [1:0]      Control: Instruction is a jump.
 *
 * @port jb_taken_o     [Output] [1:0]      Control: 1 to redirect PC, 0 to 
 *                                          continue PC+4.
 */
module bcu #(
    parameter XLEN = 32
) (
    input  [XLEN-1:0] alu_result_i,
    input  [     2:0] branch_op_i,
    input             branch_i,
    input             jump_i,
    output            jb_taken_o
);

  `include "branchop.vh"

  // Helper wire: In SLT/SLTU mode, the ALU result LSB is the "Less Than" flag.
  wire alu_less_than = alu_result_i[0];
  // Helper wire: In SUB mode, all bits zero means equality.
  wire alu_is_zero = (alu_result_i == {XLEN{1'b0}});

  reg  branch_taken;

  always @(*) begin
    case (branch_op_i)
      // Equality checks (ALU did SUB)
      BEQ_OP: branch_taken = alu_is_zero;
      BNE_OP: branch_taken = ~alu_is_zero;

      // Signed comparison (ALU did SLT)
      BLT_OP: branch_taken = alu_less_than;
      BGE_OP: branch_taken = ~alu_less_than;

      // Unsigned comparison (ALU did SLTU)
      BLTU_OP: branch_taken = alu_less_than;
      BGEU_OP: branch_taken = ~alu_less_than;

      NOBR_OP: branch_taken = 1'b0;
      default: branch_taken = 1'b0;
    endcase
  end

  // Combinational redirection signal
  assign jb_taken_o = jump_i | (branch_i & branch_taken);

endmodule
