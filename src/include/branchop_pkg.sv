`timescale 1ns / 1ps

// 常數包：每個使用者只會用到其中幾個，沒用到的不是錯誤。
// 這條只關在 package 檔裡，模組自己的參數仍然受檢。
/* verilator lint_off UNUSEDPARAM */
package branchop_pkg;

  // RISC-V BRANCH Opcodes
  localparam [2:0] BEQ_OP = 3'b000;
  localparam [2:0] BNE_OP = 3'b001;
  localparam [2:0] BLT_OP = 3'b100;
  localparam [2:0] BGE_OP = 3'b101;
  localparam [2:0] BLTU_OP = 3'b110;
  localparam [2:0] BGEU_OP = 3'b111;
  localparam [2:0] NOBR_OP = 3'b010;  // Not a Branch
endpackage
