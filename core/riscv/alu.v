`timescale 1ns / 1ps

/**
 * Module: alu
 *
 * Description:
 * 32-bit Arithmetic Logic Unit for RV32I Base Integer Instruction Set.
 * This module performs arithmetic, logical, and comparison operations
 * based on the RISC-V 'funct3' encoding (op_i) and 'funct7[5]'.
 *
 * Parameters:
 * XLEN : Word width (default 32)
 *
 * @port a_i          [Input]  [XLEN-1:0] First 32-bit operand (usually from rs1).
 * @port b_i          [Input]  [XLEN-1:0] Second 32-bit operand (usually from rs2
 *                                        or immediate).
 * @port op_i         [Input]  [2:0]      3-bit operation selector (typically
 *                                        matches instruction funct3).
 * @port shift_mode_i [Input]  [1:0]      Shift mode selector (0 = Logical shift,
 *                                        1 = Arithmetic shift).
 *
 * @port result_o     [Output] [XLEN-1:0] 32-bit computation result.
 */

module alu #(
    parameter XLEN = 32
) (
    input      [XLEN-1 : 0] a_i,
    input      [XLEN-1 : 0] b_i,
    input      [     2 : 0] op_i,
    input                   shift_mode_i,
    output reg [XLEN-1 : 0] result_o
);

  `include "aluop.vh"

  wire [XLEN-1:0] result_srl;
  wire [XLEN-1:0] result_sra;

  assign result_srl = a_i >> b_i[4:0];
  assign result_sra = $signed($signed(a_i) >>> b_i[4:0]);

  always @(*) begin
    case (op_i)
      ADD_OP:  result_o = a_i + b_i;
      SLL_OP:  result_o = a_i << b_i[4:0];
      SLT_OP:  result_o = {31'b0, $signed(a_i) < $signed(b_i)};
      SLTU_OP: result_o = {31'b0, a_i < b_i};
      XOR_OP:  result_o = a_i ^ b_i;
      SRL_OP:  result_o = (shift_mode_i) ? result_sra : result_srl;
      OR_OP:   result_o = a_i | b_i;
      AND_OP:  result_o = a_i & b_i;
      default: result_o = 32'b0;
    endcase
  end


endmodule
