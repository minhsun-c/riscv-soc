`timescale 1ns / 1ps

/**
 * Module: pc
 *
 * Description:
 * The Program Counter (PC) register. It tracks the memory address of 
 * the instruction to be fetched and handles stall/jump priority.
 *
 * @param XLEN          Data width (32-bit for RV32I).
 *
 * @port clk_i          [Input]  [1:0]      System clock.
 * @port rst_i          [Input]  [1:0]      System reset (initializes to 0x0).
 * @port jb_taken_i     [Input]  [1:0]      Jump/Branch flag; overrides 
 *                                          stall conditions.
 * @port stall_i        [Input]  [1:0]      Stall signal; freezes PC 
 *                                          unless jumping.
 * @port pc_next_i      [Input]  [XLEN-1:0] The next address to be loaded.
 *
 * @port pc_o           [Output] [XLEN-1:0] The current address output.
 */

module pc #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,

    input                 jb_taken_i,
    input                 stall_i,
    input      [XLEN-1:0] pc_next_i,
    output reg [XLEN-1:0] pc_o
);

  always @(posedge clk_i) begin
    if (rst_i) begin
      pc_o <= {XLEN{1'b0}};
    end else if (jb_taken_i) begin
      pc_o <= pc_next_i;
    end else if (stall_i) begin
      pc_o <= pc_o;
    end else begin
      pc_o <= pc_next_i;
    end
  end


endmodule
