`timescale 1ns / 1ps

// 常數包：每個使用者只會用到其中幾個，沒用到的不是錯誤。
// 這條只關在 package 檔裡，模組自己的參數仍然受檢。
/* verilator lint_off UNUSEDPARAM */
package aluop_pkg;

  // RISC-V ALU Opcodes
  localparam [2:0] ADD_OP = 3'b000;  // ADD
  localparam [2:0] SLL_OP = 3'b001;  // SLL  (Shift Left Logical)
  localparam [2:0] SLT_OP = 3'b010;  // SLT  (Set Less Than - Signed)
  localparam [2:0] SLTU_OP = 3'b011;  // SLTU (Set Less Than - Unsigned)
  localparam [2:0] XOR_OP = 3'b100;  // XOR  (Bitwise XOR)
  localparam [2:0] SRL_OP = 3'b101;  // SRL  (if shift_mode_i=0) / SRA (if shift_mode_i=1)
  localparam [2:0] OR_OP = 3'b110;  // OR   (Bitwise OR)
  localparam [2:0] AND_OP = 3'b111;  // AND  (Bitwise AND)
endpackage
