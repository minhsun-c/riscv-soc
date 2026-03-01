`timescale 1ns / 1ps

/**
 * Module: decoder
 *
 * Description:
 * Instruction unpacker. Slices the raw 32-bit RISC-V instruction into 
 * its standard architectural fields.
 *
 * @port inst_i   [Input]  [31:0] Raw 32-bit RISC-V instruction.
 *
 * @port opcode_o [Output] [6:0]  Instruction opcode field (bits 6:0).
 * @port rd_o     [Output] [4:0]  Destination register address (bits 11:7).
 * @port funct3_o [Output] [2:0]  Function 3 field (bits 14:12).
 * @port rs1_o    [Output] [4:0]  Source register 1 address (bits 19:15).
 * @port rs2_o    [Output] [4:0]  Source register 2 address (bits 24:20).
 * @port funct7_o [Output] [6:0]  Function 7 field (bits 31:25).
 */

module decoder #(
    parameter XLEN = 32
) (
    input [XLEN-1:0] inst_i,

    output [6:0] opcode_o,
    output [4:0] rd_o,
    output [2:0] funct3_o,
    output [4:0] rs1_o,
    output [4:0] rs2_o,
    output [6:0] funct7_o
);

  assign opcode_o = inst_i[6:0];
  assign rd_o = inst_i[11:7];
  assign funct3_o = inst_i[14:12];
  assign rs1_o = inst_i[19:15];
  assign rs2_o = inst_i[24:20];
  assign funct7_o = inst_i[31:25];

endmodule
