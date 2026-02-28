`timescale 1ns / 1ps

/**
 * Module: if_stage
 *
 * Description:
 * The Fetch stage wrapper. It calculates the next PC address based on 
 * sequential flow or control-flow redirections from Execute. 
 *
 * @port clk_i           [Input]  [1:0]      System clock.
 * @port rst_i           [Input]  [1:0]      System reset.
 * @port stall_i         [Input]  [1:0]      PC update enable (0: update, 1: stall).
 *
 * @port jb_taken_i      [Input]  [1:0]      Direct from EX: 1 if branch/jump 
 *                                           is taken.
 * @port jb_target_i     [Input]  [XLEN-1:0] Direct from EX: The target 
 *                                           address (ALU Result).
 *
 * @port pc_o            [Output] [XLEN-1:0] Current PC address for the 
 *                                           ID stage.
 * @port pc_plus4_o      [Output] [XLEN-1:0] PC + 4 for Jump-and-Link 
 *                                           return addresses.
 */

module if_stage #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,
    input stall_i,

    // Redirection from EX Stage
    input            jb_taken_i,
    input [XLEN-1:0] jb_target_i,

    // Outputs to Pipeline
    output [XLEN-1:0] pc_o,
    output [XLEN-1:0] pc_plus4_o
);

  wire [XLEN-1:0] pc_next;

  // --- Phase 1: Use Current PC ---
  // Before the clock edge, we use the current PC to calculate the sequential 
  // return address for the next stage (Link address for JAL/JALR).
  assign pc_plus4_o = pc_o + 32'd4;

  // --- Phase 2: Prepare Next PC ---
  // We determine what the PC SHOULD be after the next clock edge.
  //  [sel_i = 0]: Sequential Step (pc_plus4_o)
  //  [sel_i = 1]: Jump/Branch Target (jb_target_i)
  mux2 #(
      .WIDTH(XLEN)
  ) u_mux2 (
      .sel_i(jb_taken_i),
      .a_i  (pc_plus4_o),
      .b_i  (jb_target_i),
      .out_o(pc_next)
  );

  // --- The State Element ---
  // On the posedge of clk_i, this register captures pc_next.
  // If stall_i is high, it ignores pc_next and holds its current value.
  pc u_pc (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .jb_taken_i(jb_taken_i),
      .stall_i(stall_i),
      .pc_next_i(pc_next),
      .pc_o(pc_o)
  );


endmodule
