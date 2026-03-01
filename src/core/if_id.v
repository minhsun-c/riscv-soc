`timescale 1ns / 1ps

/**
 * Module: if_id
 *
 * Description:
 * This is the IF/ID pipeline register, buffering the program counter 
 * and the fetched instruction for the Decode stage.
 *
 * @port clk_i           [Input]  [1:0]      System clock.
 * @port rst_i           [Input]  [1:0]      System reset; initializes 
 *                                           instruction to NOP.
 * @port stall_i         [Input]  [1:0]      Stall signal; when high, the 
 *                                           register holds its current value. 
 * @port flush_i         [Input]  [1:0]      Flush signal; when high, the 
 *                                           instruction is replaced with a NOP. 
 *
 * @port inst_i          [Input]  [XLEN-1:0] Raw instruction data fetched 
 *                                           from I-memory (SRAM).
 * @port pc_i            [Input]  [XLEN-1:0] Current program counter value 
 *                                           from the PC unit.
 * @port pc_plus4_i      [Input]  [XLEN-1:0] PC + 4 for Jump-and-Link 
 *                                           return addresses.
 *
 * @port pc_o            [Output] [XLEN-1:0] Registered PC for ID stage.
 * @port pc_plus4_o      [Output] [XLEN-1:0] Registered PC + 4 for ID stage.
 * @port inst_o          [Output] [XLEN-1:0] Registered instruction for ID stage.
 */

module if_id #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,

    // Control signals
    input stall_i,
    input flush_i,

    // From I-Memory (SRAM) and PC Unit
    input [XLEN-1:0] inst_i,
    input [XLEN-1:0] pc_i,
    input [XLEN-1:0] pc_plus4_i,

    // To Decode (ID) Stage
    output reg [XLEN-1:0] pc_o,
    output reg [XLEN-1:0] pc_plus4_o,
    output reg [XLEN-1:0] inst_o
);

  // RISC-V NOP instruction: addi x0, x0, 0
  localparam [31:0] NOP = 32'h00000013;

  always @(posedge clk_i) begin
    if (rst_i || flush_i) begin
      pc_o       <= {XLEN{1'b0}};
      pc_plus4_o <= {XLEN{1'b0}};
      inst_o     <= NOP;
    end else if (stall_i) begin
      pc_o       <= pc_o;
      pc_plus4_o <= pc_plus4_o;
      inst_o     <= inst_o;
    end else begin
      pc_o       <= pc_i;
      pc_plus4_o <= pc_plus4_i;
      inst_o     <= inst_i;
    end
  end


endmodule
