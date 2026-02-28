`timescale 1ns / 1ps

/**
 * Module: imm_gen
 *
 * Description:
 * Extracts and sign-extends immediates from RISC-V instructions.
 *
 * @port inst_i          [Input]  [XLEN-1:0] 32-bit raw instruction from memory.
 * @port sel_i           [Input]  [2:0]      Control signal selecting the 
 *                                           instruction format (I, S, B, U, J).
 *
 * @port imm_o           [Output] [XLEN-1:0] The resulting 32-bit sign-extended 
 * immediate.
 */

/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */

module imm_gen #(
    parameter XLEN = 32
) (
    input      [XLEN-1:0] inst_i,
    input      [     2:0] sel_i,
    output reg [XLEN-1:0] imm_o
);

  // Internal constants for selection
  `include "immsel.vh"

  always @(*) begin
    case (sel_i)
      I_IMM_MODE: begin
        imm_o = {{20{inst_i[31]}}, inst_i[31:20]};
      end
      S_IMM_MODE: begin
        imm_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
      end
      B_IMM_MODE: begin
        imm_o = {{19{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
      end
      U_IMM_MODE: begin
        imm_o = {inst_i[31:12], 12'b0};
      end
      J_IMM_MODE: begin
        imm_o = {{11{inst_i[31]}}, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
      end
      default: begin
        imm_o = {XLEN{1'b0}};
      end
    endcase
  end


endmodule

/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on UNUSEDPARAM */
