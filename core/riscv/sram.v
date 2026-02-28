`timescale 1ns / 1ps

/**
 * Module: sram
 *
 * Description:
 * A RISC-V compatible Load-Store Unit (LSU) and memory wrapper. This 
 * module bridges the CPU pipeline and the physical SRAM block, handling 
 * alignment, byte-masking, and sign-extension.
 *
 * @param XLEN          Data width (32-bit for RV32I).
 * @param NUM_ENTRIES   Number of words (default 1024).
 *
 * @port clk_i          [Input]  [1:0]      System clock; triggers synchronous 
 *                                          writes.
 * @port addr_i         [Input]  [XLEN-1:0] 32-bit byte address from the 
 *                                          ALU.
 * @port wdata_i        [Input]  [XLEN-1:0] Raw data from the CPU's rs2 
 *                                          register.
 * @port we_i           [Input]  [1:0]      Master Write Enable for Store 
 *                                          instructions.
 * @port func3_i        [Input]  [2:0]      RISC-V func3 field determining 
 *                                          access width and extension.
 *
 * @port rdata_o        [Output] [XLEN-1:0] Final 32-bit data sent back to 
 *                                          the Register File.
 */

/* verilator lint_off UNUSEDSIGNAL */

module sram #(
    parameter XLEN = 32,
    parameter NUM_ENTRIES = 1024,
    parameter ADDR_W = $clog2(NUM_ENTRIES)  // 10 for 1024 entries
) (
    input clk_i,

    input      [XLEN-1:0] addr_i,
    input      [XLEN-1:0] wdata_i,
    input                 we_i,
    input      [     2:0] func3_i,
    output reg [XLEN-1:0] rdata_o
);
  `include "memop.vh"

  // Internal Memory Array (Behavioral RAM)
  // 1024 entries of 32-bit words
  reg  [  XLEN-1:0] mem                            [0:NUM_ENTRIES-1]  /* verilator public */;

  // Internal wires for word-aligned address
  wire [ADDR_W-1:0] word_addr = addr_i[ADDR_W+1:2];
  wire [       1:0] byte_offset = addr_i[1:0];

  // -------------------------------------------------------------------------
  // SYNCHRONOUS WRITE LOGIC (LSU Store Logic)
  // Handles partial writes (SB, SH, SW) using byte-masking.
  // -------------------------------------------------------------------------
  always @(posedge clk_i) begin
    if (we_i) begin

      case (func3_i)
        SB_OP: begin
          case (byte_offset)
            2'b00: mem[word_addr][7:0] <= wdata_i[7:0];
            2'b01: mem[word_addr][15:8] <= wdata_i[7:0];
            2'b10: mem[word_addr][23:16] <= wdata_i[7:0];
            2'b11: mem[word_addr][31:24] <= wdata_i[7:0];
          endcase
        end
        SH_OP: begin
          case (byte_offset[1])
            1'b0: mem[word_addr][15:0] <= wdata_i[15:0];
            1'b1: mem[word_addr][31:16] <= wdata_i[15:0];
          endcase
        end
        SW_OP: begin
          mem[word_addr] <= wdata_i;
        end
        default: begin
          mem[word_addr] <= mem[word_addr];
        end
      endcase
    end else begin
      mem[word_addr] <= mem[word_addr];
    end
  end

  // -------------------------------------------------------------------------
  // ASYNCHRONOUS READ LOGIC (LSU Load Logic)
  // Fetches the word and applies shifting/extension.
  // -------------------------------------------------------------------------
  always @(*) begin
    case (func3_i)
      LB_OP: begin
        case (byte_offset)
          2'b00: rdata_o = {{24{mem[word_addr][7]}}, mem[word_addr][7:0]};
          2'b01: rdata_o = {{24{mem[word_addr][15]}}, mem[word_addr][15:8]};
          2'b10: rdata_o = {{24{mem[word_addr][23]}}, mem[word_addr][23:16]};
          2'b11: rdata_o = {{24{mem[word_addr][31]}}, mem[word_addr][31:24]};
        endcase
      end
      LH_OP: begin
        case (byte_offset[1])
          1'b0: rdata_o = {{16{mem[word_addr][15]}}, mem[word_addr][15:0]};
          1'b1: rdata_o = {{16{mem[word_addr][31]}}, mem[word_addr][31:16]};
        endcase
      end
      LW_OP: begin
        rdata_o = mem[word_addr];
      end
      LBU_OP: begin
        case (byte_offset)
          2'b00: rdata_o = {{24{1'b0}}, mem[word_addr][7:0]};
          2'b01: rdata_o = {{24{1'b0}}, mem[word_addr][15:8]};
          2'b10: rdata_o = {{24{1'b0}}, mem[word_addr][23:16]};
          2'b11: rdata_o = {{24{1'b0}}, mem[word_addr][31:24]};
        endcase
      end
      LHU_OP: begin
        case (byte_offset[1])
          1'b0: rdata_o = {{16{1'b0}}, mem[word_addr][15:0]};
          1'b1: rdata_o = {{16{1'b0}}, mem[word_addr][31:16]};
        endcase
      end
      default: begin
        rdata_o = {XLEN{1'b0}};
      end
    endcase
  end

endmodule

/* verilator lint_on UNUSEDSIGNAL */

