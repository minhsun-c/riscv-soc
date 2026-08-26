`timescale 1ns / 1ps

/**
 * Module: fwd (Forwarding Unit)
 *
 * Description:
 * Decides, for each of the two source operands of the instruction in EX,
 * whether the register file value latched by id_ex is still current, or
 * whether a newer value is in flight further down the pipeline.
 *
 * The register file is written in WB, so an instruction reading a register
 * two or fewer instructions after it was written gets a stale value. The
 * newer value already exists as a wire -- in MEM as the ALU result, in WB as
 * the writeback data -- so it can be routed back to the EX operand mux
 * instead of stalling until it lands in the register file.
 *
 * MEM wins over WB: both may match, and MEM holds the more recent write.
 *
 * Loads are not handled here. Their data is not ready until MEM completes,
 * so a load feeding the next instruction is a load-use hazard and hdu stalls
 * for one cycle; by the time the consumer reaches EX the load is in WB and
 * the FWD_WB path covers it.
 *
 * @port rs1_addr_ex_i [Input]  [4:0] rs1 address of the instruction in EX.
 * @port rs2_addr_ex_i [Input]  [4:0] rs2 address of the instruction in EX.
 * @port rd_addr_mem_i [Input]  [4:0] Destination register of the instruction in MEM.
 * @port rd_wen_mem_i  [Input]        1 if the instruction in MEM writes a register.
 * @port rd_addr_wb_i  [Input]  [4:0] Destination register of the instruction in WB.
 * @port rd_wen_wb_i   [Input]        1 if the instruction in WB writes a register.
 *
 * @port fwd_a_o       [Output] [1:0] Operand A source (see fwdsel.vh).
 * @port fwd_b_o       [Output] [1:0] Operand B source (see fwdsel.vh).
 */

module fwd (
    // From the Execute stage (the consumer)
    input [4:0] rs1_addr_ex_i,
    input [4:0] rs2_addr_ex_i,

    // From the Memory stage (producer, one instruction ahead)
    input [4:0] rd_addr_mem_i,
    input       rd_wen_mem_i,

    // From the Writeback stage (producer, two instructions ahead)
    input [4:0] rd_addr_wb_i,
    input       rd_wen_wb_i,

    // To the EX operand multiplexers
    output reg [1:0] fwd_a_o,
    output reg [1:0] fwd_b_o
);

  `include "fwdsel.vh"

  // A producer is only relevant if it actually writes a register, and never
  // for x0: writes to x0 are discarded, so the register file's zero is the
  // correct value and forwarding one would be wrong.
  wire mem_writes = rd_wen_mem_i && (rd_addr_mem_i != 5'd0);
  wire wb_writes  = rd_wen_wb_i && (rd_addr_wb_i != 5'd0);

  always @(*) begin
    if (mem_writes && (rd_addr_mem_i == rs1_addr_ex_i)) fwd_a_o = FWD_MEM;
    else if (wb_writes && (rd_addr_wb_i == rs1_addr_ex_i)) fwd_a_o = FWD_WB;
    else fwd_a_o = FWD_NONE;
  end

  always @(*) begin
    if (mem_writes && (rd_addr_mem_i == rs2_addr_ex_i)) fwd_b_o = FWD_MEM;
    else if (wb_writes && (rd_addr_wb_i == rs2_addr_ex_i)) fwd_b_o = FWD_WB;
    else fwd_b_o = FWD_NONE;
  end

endmodule
