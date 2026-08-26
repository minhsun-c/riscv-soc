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

    // Redirection from EX -- the fetch path taken earlier turned out to be wrong
    input            redirect_i,
    input [XLEN-1:0] redirect_pc_i,

    // Prediction for the instruction being fetched this cycle, from btb/bht
    input            pred_taken_i,
    input [XLEN-1:0] pred_target_i,

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
  // Three sources now, and the order between them is the whole point:
  //
  //   1. redirect   EX has resolved a branch and the guess was wrong. This is
  //                 fact, not prediction, so nothing may override it.
  //   2. prediction btb/bht think this fetch should jump. A guess, but a guess
  //                 made from history rather than from nothing.
  //   3. pc + 4     no reason to go anywhere else.
  //
  // Written as a priority chain rather than a mux tree because more sources are
  // coming: week 17 hangs trap entry off the same decision, above redirect.
  assign pc_next = redirect_i    ? redirect_pc_i :
                   pred_taken_i  ? pred_target_i :
                                   pc_plus4_o;

  // --- The State Element ---
  // On the posedge of clk_i, this register captures pc_next.
  // If stall_i is high, it ignores pc_next and holds its current value.
  pc u_pc (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .redirect_i(redirect_i),
      .stall_i(stall_i),
      .pc_next_i(pc_next),
      .pc_o(pc_o)
  );


endmodule
