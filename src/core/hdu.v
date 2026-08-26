`timescale 1ns / 1ps

/**
 * Module: hdu (Hazard Detection Unit)
 *
 * Description:
 * Detects the one data hazard that forwarding cannot fix.
 *
 * Before the forwarding unit existed this module stalled on every RAW
 * dependency against EX or MEM. Now fwd routes those values back into the EX
 * operand mux, so the pipeline no longer has to wait for them -- with a single
 * exception.
 *
 * A load's data does not exist until its MEM stage. If the very next
 * instruction consumes it, that consumer is in EX during the load's MEM cycle,
 * and there is nothing to forward yet. One stall cycle pushes the consumer back
 * far enough that the load has reached WB, where FWD_WB picks it up.
 *
 * "Is the instruction in EX a load" is exactly rd_src_ex_i == MEM_RDSEL: that is
 * the encoding meaning "the value written to rd comes from memory".
 *
 * @port rs1_id_i       [Input]  [4:0] rs1 address of the instruction in ID.
 * @port rs2_id_i       [Input]  [4:0] rs2 address of the instruction in ID.
 * @port rd_ex_i        [Input]  [4:0] Destination register of the instruction in EX.
 * @port reg_write_ex_i [Input]        1 if the instruction in EX writes a register.
 * @port rd_src_ex_i    [Input]  [1:0] Writeback source of the instruction in EX.
 *
 * @port stall_o        [Output]       1 to hold IF/ID and inject a bubble into EX.
 */

/* verilator lint_off UNUSEDPARAM */

module hdu (
    // From Decode Stage (the consumer)
    input [4:0] rs1_id_i,
    input [4:0] rs2_id_i,

    // From Execute Stage (the producer, one instruction ahead)
    input [4:0] rd_ex_i,
    input       reg_write_ex_i,
    input [1:0] rd_src_ex_i,

    // Output to Pipeline Control
    output reg stall_o
);

  `include "rdsel.vh"

  // A load whose result the very next instruction reads. x0 is excluded for the
  // usual reason: a write to it is discarded, so there is no dependency.
  wire load_in_ex = reg_write_ex_i && (rd_src_ex_i == MEM_RDSEL) && (rd_ex_i != 5'd0);

  always @(*) begin
    if (load_in_ex && ((rs1_id_i == rd_ex_i) || (rs2_id_i == rd_ex_i))) begin
      stall_o = 1'b1;
    end else begin
      stall_o = 1'b0;
    end
  end

endmodule

/* verilator lint_on UNUSEDPARAM */
