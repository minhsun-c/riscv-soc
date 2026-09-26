`timescale 1ns / 1ps

// 常數包：每個使用者只會用到其中幾個，沒用到的不是錯誤。
// 這條只關在 package 檔裡，模組自己的參數仍然受檢。
/* verilator lint_off UNUSEDPARAM */
package rdsel_pkg;

  // Register File Selection (Defined by Implementation)
  // Widened from 2 bits to 3 in week 16. Four sources used all four encodings,
  // and Zicsr needs a fifth: the old value of the CSR being accessed.
  localparam [2:0] ALU_RDSEL = 3'd0;
  localparam [2:0] MEM_RDSEL = 3'd1;
  localparam [2:0] PC4_RDSEL = 3'd2;
  localparam [2:0] NO_RDSEL = 3'd3;
  localparam [2:0] CSR_RDSEL = 3'd4;
endpackage
