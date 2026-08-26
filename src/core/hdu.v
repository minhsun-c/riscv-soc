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
 * Week 16 added a second source with the same problem: a Zicsr read produces
 * its value in WB, so there is nothing at MEM to forward. rd_src says so, and
 * the same stall covers it.
 *
 * @port rs1_id_i       [Input]  [4:0] rs1 address of the instruction in ID.
 * @port rs2_id_i       [Input]  [4:0] rs2 address of the instruction in ID.
 * @port rd_ex_i        [Input]  [4:0] Destination register of the instruction in EX.
 * @port reg_write_ex_i [Input]        1 if the instruction in EX writes a register.
 * @port rd_src_ex_i    [Input]  [2:0] Writeback source of the instruction in EX.
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
    input [2:0] rd_src_ex_i,

    // Output to Pipeline Control
    output reg stall_o
);

  `include "rdsel.vh"

  // Two writeback sources produce their value too late for the next
  // instruction to forward from MEM:
  //
  //   MEM_RDSEL  a load -- data arrives at the end of MEM
  //   CSR_RDSEL  a Zicsr read -- the CSR file lives in WB, so nothing exists
  //              at MEM to forward at all
  //
  // Both are the same hazard wearing different clothes, and both are fixed by
  // the same single stall: it pushes the consumer back far enough that the
  // producer has reached WB, where FWD_WB picks the value up.
  wire late_value = (rd_src_ex_i == MEM_RDSEL) || (rd_src_ex_i == CSR_RDSEL);
  wire load_in_ex = reg_write_ex_i && late_value && (rd_ex_i != 5'd0);

  always @(*) begin
    if (load_in_ex && ((rs1_id_i == rd_ex_i) || (rs2_id_i == rd_ex_i))) begin
      stall_o = 1'b1;
    end else begin
      stall_o = 1'b0;
    end
  end

endmodule

/* verilator lint_on UNUSEDPARAM */
