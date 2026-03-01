`timescale 1ns / 1ps

/**
 * Module: hdu (Hazard Detection Unit)
 *
 * Description:
 * Hazard Detection Unit (HDU) for a pipelined RISC-V processor. Since this 
 * design does not implement data forwarding, this module must detect all 
 * data hazards.
 *
 * @port rs1_id_i        [Input]  [4:0]      Source register 1 of the instruction 
 *                                           in Decode stage.
 * @port rs2_id_i        [Input]  [4:0]      Source register 2 of the instruction 
 *                                           in Decode stage.
 *
 * @port rd_ex_i         [Input]  [4:0]      Destination register of the 
 *                                           instruction in Execute stage.
 * @port reg_write_ex_i  [Input]  [1:0]      Register write enable flag from the 
 *                                           Execute stage.
 *
 * @port rd_mem_i        [Input]  [4:0]      Destination register of the 
 *                                           instruction in Memory stage.
 * @port reg_write_mem_i [Input]  [1:0]      Register write enable flag from the 
 *                                           Memory stage.
 *
 * @port stall_o         [Output] [1:0]      Stall signal sent to PC and IF/ID 
 *                                           registers.
 */

module hdu (
    // From Decode Stage (current instruction)
    input [4:0] rs1_id_i,
    input [4:0] rs2_id_i,

    // From Execute Stage (older instruction 1)
    input [4:0] rd_ex_i,
    input       reg_write_ex_i,

    // From Memory Stage (older instruction 2)
    input [4:0] rd_mem_i,
    input       reg_write_mem_i,

    // Outputs to Pipeline Registers
    output reg stall_o
);

  always @(*) begin

    if (rd_ex_i != 5'd0 && reg_write_ex_i && (rs1_id_i == rd_ex_i || rs2_id_i == rd_ex_i)) begin
      // Hazard in Execute Stage
      // If the instruction in EX is writing to a register we need (and it's not x0)
      stall_o = 1'b1;
    end  
    else if (rd_mem_i != 5'd0 && reg_write_mem_i && 
        (rs1_id_i == rd_mem_i || rs2_id_i == rd_mem_i)) begin
      // Hazard in Memory Stage
      // If the instruction in MEM is writing to a register we need (and it's not x0)
      stall_o = 1'b1;
    end else begin
      // Default: do not stall 
      stall_o = 1'b0;
    end

  end

endmodule
