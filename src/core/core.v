`timescale 1ns / 1ps

/**
 * Module: core
 *
 * Description:
 * The top-level RISC-V processor core. This module integrates the 5-stage 
 * pipeline (IF, ID, EX, MEM, WB) and includes a Hazard Detection Unit (HDU) 
 * for stall and flush management.
 *
 * Parameters:
 * XLEN : Word width (default 32)
 *
 * @port clk_i        [Input]  [1:0]      Global clock signal.
 * @port rst_i        [Input]  [1:0]      Global reset signal (active high).
 *
 * @port im_addr_o    [Output] [XLEN-1:0] Instruction memory address bus.
 * @port im_data_i    [Input]  [XLEN-1:0] Instruction data returned from memory.
 *
 * @port dm_addr_o    [Output] [XLEN-1:0] Data memory address bus.
 * @port dm_wdata_o   [Output] [XLEN-1:0] Data to be written to memory.
 * @port dm_we_o      [Output] [1:0]      Data memory write enable.
 * @port dm_op_o      [Output] [2:0]      Memory operation type (size/sign 
 *                                        extension) for the SRAM interface.
 * @port data_rdata_i [Input]  [XLEN-1:0] Data read from memory.
 */

module core #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,

    // Instruction Memory Interface
    output [XLEN-1:0] im_addr_o,
    input  [XLEN-1:0] im_data_i,

    // Data Memory Interface
    output [XLEN-1:0] dm_addr_o,
    output [XLEN-1:0] dm_wdata_o,
    output            dm_we_o,
    output [     2:0] dm_op_o,
    input  [XLEN-1:0] data_rdata_i
);

  // --- Pipeline Control Wires ---   
  wire stall_all;
  wire flush_jb = ex_jb_taken;  // Flush on Branch/Jump
  wire flush_id_ex = flush_jb | stall_all;  // inject a bubble into EX

  hdu u_hdu (
      // From Decode Stage (current instruction)
      .rs1_id_i(rf_rs1_addr),
      .rs2_id_i(rf_rs2_addr),

      // From Execute Stage (older instruction 1)
      .rd_ex_i       (ex_rd_addr),
      .reg_write_ex_i(ex_rd_wen),

      // From Memory Stage (older instruction 2)
      .rd_mem_i       (mem_rd_addr),
      .reg_write_mem_i(mem_rd_wen),

      // Output to Pipeline Control
      .stall_o(stall_all)
  );

  // --- IF Stage ---
  wire [XLEN-1:0] if_pc, if_pc_plus4;
  if_stage u_if_stage (
      .clk_i      (clk_i),
      .rst_i      (rst_i),
      .stall_i    (stall_all),
      .jb_taken_i (ex_jb_taken),
      .jb_target_i(ex_jb_target),
      .pc_o       (if_pc),
      .pc_plus4_o (if_pc_plus4)
  );
  assign im_addr_o = if_pc;

  // --- IF/ID Register ---
  wire [XLEN-1:0] id_pc, id_inst, id_pc_plus4;
  if_id u_if_id (
      .clk_i     (clk_i),
      .rst_i     (rst_i),
      .stall_i   (stall_all),
      .flush_i   (flush_jb),
      .pc_i      (if_pc),
      .inst_i    (im_data_i),
      .pc_plus4_i(if_pc_plus4),
      .pc_o      (id_pc),
      .inst_o    (id_inst),
      .pc_plus4_o(id_pc_plus4)
  );

  // --- ID Stage ---
  wire [XLEN-1:0] rf_rs1_data, rf_rs2_data;
  wire [XLEN-1:0] id_rs1_data_o, id_rs2_data_o, id_imm_o;
  wire [4:0] rf_rs1_addr, rf_rs2_addr;
  wire [4:0] id_rd_addr_o;
  wire [2:0] id_alu_op, id_branch_op, id_mem_op;
  wire [1:0] id_rd_src;
  wire id_rd_wen, id_alu_src_a, id_alu_src_b, id_alu_shift, id_branch, id_jump, id_mem_wen;

  id_stage u_id_stage (
      .inst_i     (id_inst),
      .rs1_addr_o (rf_rs1_addr),
      .rs2_addr_o (rf_rs2_addr),
      .rs1_data_i (rf_rs1_data),
      .rs2_data_i (rf_rs2_data),
      .rs1_data_o (id_rs1_data_o),
      .rs2_data_o (id_rs2_data_o),
      .imm_o      (id_imm_o),
      .rd_addr_o  (id_rd_addr_o),
      .rd_wen_o   (id_rd_wen),
      .rd_src_o   (id_rd_src),
      .alu_src_a_o(id_alu_src_a),
      .alu_src_b_o(id_alu_src_b),
      .alu_op_o   (id_alu_op),
      .alu_shift_o(id_alu_shift),
      .branch_o   (id_branch),
      .branch_op_o(id_branch_op),
      .jump_o     (id_jump),
      .mem_wen_o  (id_mem_wen),
      .mem_op_o   (id_mem_op)
  );

  regfile u_regfile (
      .clk_i     (clk_i),
      .rst_i     (rst_i),
      .rs1_addr_i(rf_rs1_addr),
      .rs2_addr_i(rf_rs2_addr),
      .rs1_data_o(rf_rs1_data),
      .rs2_data_o(rf_rs2_data),
      .rd_we_i   (wb_rd_wen),
      .rd_addr_i (wb_rd_addr),
      .rd_data_i (wb_final_data)
  );

  // --- ID/EX Register ---
  // (Latching all signals for the Execute stage) 
  wire [XLEN-1:0] ex_pc, ex_pc_plus4, ex_rs1_data, ex_rs2_data, ex_imm;
  wire [4:0] ex_rd_addr;
  wire [2:0] ex_alu_op, ex_branch_op, ex_mem_op;
  wire [1:0] ex_rd_src;
  wire ex_rd_wen, ex_alu_src_a, ex_alu_src_b, ex_alu_shift, ex_branch, ex_jump, ex_mem_wen;

  id_ex u_id_ex (
      .clk_i      (clk_i),
      .rst_i      (rst_i),
      .flush_i    (flush_id_ex),
      .pc_i       (id_pc),
      .pc_plus4_i (id_pc_plus4),
      .rs1_data_i (id_rs1_data_o),
      .rs2_data_i (id_rs2_data_o),
      .imm_i      (id_imm_o),
      .rd_addr_i  (id_rd_addr_o),
      .rd_wen_i   (id_rd_wen),
      .rd_src_i   (id_rd_src),
      .alu_src_a_i(id_alu_src_a),
      .alu_src_b_i(id_alu_src_b),
      .alu_op_i   (id_alu_op),
      .alu_shift_i(id_alu_shift),
      .branch_i   (id_branch),
      .branch_op_i(id_branch_op),
      .jump_i     (id_jump),
      .mem_wen_i  (id_mem_wen),
      .mem_op_i   (id_mem_op),

      .pc_ex_o       (ex_pc),
      .pc_plus4_ex_o (ex_pc_plus4),
      .rs1_data_ex_o (ex_rs1_data),
      .rs2_data_ex_o (ex_rs2_data),
      .imm_ex_o      (ex_imm),
      .rd_addr_ex_o  (ex_rd_addr),
      .rd_wen_ex_o   (ex_rd_wen),
      .rd_src_ex_o   (ex_rd_src),
      .alu_src_a_ex_o(ex_alu_src_a),
      .alu_src_b_ex_o(ex_alu_src_b),
      .alu_op_ex_o   (ex_alu_op),
      .alu_shift_ex_o(ex_alu_shift),
      .branch_ex_o   (ex_branch),
      .branch_op_ex_o(ex_branch_op),
      .jump_ex_o     (ex_jump),
      .mem_wen_ex_o  (ex_mem_wen),
      .mem_op_ex_o   (ex_mem_op)
  );

  // --- EX Stage ---
  wire [XLEN-1:0] ex_alu_result;
  wire [XLEN-1:0] ex_jb_target;
  wire            ex_jb_taken;

  ex_stage u_ex_stage (
      .alu_op_i    (ex_alu_op),
      .alu_src_a_i (ex_alu_src_a),
      .alu_src_b_i (ex_alu_src_b),
      .alu_shift_i (ex_alu_shift),
      .branch_i    (ex_branch),
      .branch_op_i (ex_branch_op),
      .jump_i      (ex_jump),
      .pc_i        (ex_pc),
      .rs1_data_i  (ex_rs1_data),
      .rs2_data_i  (ex_rs2_data),
      .imm_i       (ex_imm),
      .alu_result_o(ex_alu_result),
      .jb_target_o (ex_jb_target),
      .jb_taken_o  (ex_jb_taken)
  );

  // --- EX/MEM Register ---
  wire [XLEN-1:0] mem_pc_plus4, mem_alu_result, mem_rs2_data;
  wire [4:0] mem_rd_addr;
  wire [2:0] mem_mem_op;
  wire [1:0] mem_rd_src;
  wire mem_rd_wen, mem_mem_wen;

  ex_mem u_ex_mem (
      .clk_i       (clk_i),
      .rst_i       (rst_i),
      .stall_i     (1'b0),
      .flush_i     (1'b0),
      .pc_plus4_i  (ex_pc_plus4),
      .alu_result_i(ex_alu_result),
      .rs2_data_i  (ex_rs2_data),
      .rd_addr_i   (ex_rd_addr),
      .rd_wen_i    (ex_rd_wen),
      .rd_src_i    (ex_rd_src),
      .mem_op_i    (ex_mem_op),
      .mem_wen_i   (ex_mem_wen),

      .pc_plus4_o  (mem_pc_plus4),
      .alu_result_o(mem_alu_result),
      .rs2_data_o  (mem_rs2_data),
      .rd_addr_o   (mem_rd_addr),
      .rd_wen_o    (mem_rd_wen),
      .rd_src_o    (mem_rd_src),
      .mem_op_o    (mem_mem_op),
      .mem_wen_o   (mem_mem_wen)
  );

  // --- MEM Stage (Data SRAM Interface) ---
  assign dm_addr_o  = mem_alu_result;
  assign dm_wdata_o = mem_rs2_data;
  assign dm_we_o    = mem_mem_wen;
  assign dm_op_o    = mem_mem_op;

  // --- MEM/WB Register ---
  wire [XLEN-1:0] wb_pc_plus4, wb_alu_result, wb_mem_data;
  wire [4:0] wb_rd_addr;
  wire [1:0] wb_rd_src;
  wire       wb_rd_wen;

  mem_wb u_mem_wb (
      .clk_i       (clk_i),
      .rst_i       (rst_i),
      .stall_i     (1'b0),
      .pc_plus4_i  (mem_pc_plus4),
      .alu_result_i(mem_alu_result),
      .mem_data_i  (data_rdata_i),
      .rd_addr_i   (mem_rd_addr),
      .rd_wen_i    (mem_rd_wen),
      .rd_src_i    (mem_rd_src),
      .pc_plus4_o  (wb_pc_plus4),
      .alu_result_o(wb_alu_result),
      .mem_data_o  (wb_mem_data),
      .rd_addr_o   (wb_rd_addr),
      .rd_wen_o    (wb_rd_wen),
      .rd_src_o    (wb_rd_src)
  );

  // --- WB Stage ---
  wire [XLEN-1:0] wb_final_data;
  wb_stage u_wb_stage (
      .alu_result_i(wb_alu_result),
      .mem_data_i  (wb_mem_data),
      .pc_plus4_i  (wb_pc_plus4),
      .rd_src_i    (wb_rd_src),
      .wb_data_o   (wb_final_data)
  );


endmodule
