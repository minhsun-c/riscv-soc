`timescale 1ns / 1ps

/**
 * Module: wb_stage
 *
 * Description:
 * The Write-Back (WB) stage logic. This is a purely combinational module 
 * that acts as the final multiplexer for the datapath, selecting the 
 * data to be retired into the Register File.
 *
 * @port rd_src_i       [Input]  [1:0]  Control signal selecting the WB source 
 *                                      (e.g., ALU, Memory, or PC+4).
 * @port alu_result_i   [Input]  [31:0] Result from the Execute stage.
 * @port mem_data_i     [Input]  [31:0] Data retrieved from Data Memory.
 * @port pc_plus4_i     [Input]  [31:0] Return address for jump/link instructions.
 *
 * @port wb_data_o      [Output] [31:0] Final data to be written to Reg[rd].
 */

module wb_stage #(
    parameter XLEN = 32
) (
    input [     1:0] rd_src_i,
    input [XLEN-1:0] alu_result_i,
    input [XLEN-1:0] mem_data_i,
    input [XLEN-1:0] pc_plus4_i,

    output reg [XLEN-1:0] wb_data_o
);
  `include "rdsel.vh"

  always @(*) begin
    case (rd_src_i)
      ALU_RDSEL: wb_data_o = alu_result_i;
      MEM_RDSEL: wb_data_o = mem_data_i;
      PC4_RDSEL: wb_data_o = pc_plus4_i;
      NO_RDSEL:  wb_data_o = {XLEN{1'b0}};
    endcase
  end

endmodule
