`timescale 1ns / 1ps

// 常數包：每個使用者只會用到其中幾個，沒用到的不是錯誤。
// 這條只關在 package 檔裡，模組自己的參數仍然受檢。
/* verilator lint_off UNUSEDPARAM */
package memop_pkg;

  // RISC-V Load & Store Opcodes
  localparam [2:0] LB_OP = 3'b000;
  localparam [2:0] LH_OP = 3'b001;
  localparam [2:0] LW_OP = 3'b010;
  localparam [2:0] LBU_OP = 3'b100;
  localparam [2:0] LHU_OP = 3'b101;
  localparam [2:0] SB_OP = 3'b000;
  localparam [2:0] SH_OP = 3'b001;
  localparam [2:0] SW_OP = 3'b010;
endpackage
