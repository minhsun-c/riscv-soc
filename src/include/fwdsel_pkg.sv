`timescale 1ns / 1ps

// 常數包：每個使用者只會用到其中幾個，沒用到的不是錯誤。
// 這條只關在 package 檔裡，模組自己的參數仍然受檢。
/* verilator lint_off UNUSEDPARAM */
package fwdsel_pkg;

  // Forwarding source selection (Defined by Implementation)
  localparam [1:0] FWD_NONE = 2'd0;  // use the value id_ex latched from the register file
  localparam [1:0] FWD_MEM = 2'd1;  // take it from the MEM stage (one instruction ahead)
  localparam [1:0] FWD_WB = 2'd2;  // take it from the WB stage (two instructions ahead)
endpackage
