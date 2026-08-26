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

/* verilator lint_off UNUSEDPARAM */

module core #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,

    // Instruction Memory Interface
    output            im_req_o,
    output [XLEN-1:0] im_addr_o,
    input             im_ready_i,
    input             im_rvalid_i,
    input  [XLEN-1:0] im_data_i,

    // Data Memory Interface
    output            dm_req_o,
    output [XLEN-1:0] dm_addr_o,
    output [XLEN-1:0] dm_wdata_o,
    output [     3:0] dm_wstrb_o,
    input             dm_ready_i,
    input             dm_rvalid_i,
    input  [XLEN-1:0] dm_rdata_i,

    // Level from the machine timer. The first thing in this design that
    // asks for attention without an instruction having caused it.
    input             mtip_i
);

  `include "rdsel.vh"
  `include "excause.vh"

  // --- Pipeline Control Wires ---   
  // Exposed so the testbench can count stall cycles: the whole point of the
  // forwarding unit is that this number drops.
  wire stall_all  /* verilator public */;
  // Only a wrong guess costs a flush now. A correctly predicted taken branch
  // keeps the two instructions IF already fetched, which is the entire point --
  // flushing on ex_jb_taken would throw them away and undo the prediction.
  wire flush_jb = ex_redirect;

  // A trap or mret in WB squashes every instruction behind it. Declared here
  // and driven further down, once trap_take exists.
  wire flush_trap;
  wire flush_if_id  = flush_jb | flush_trap;
  wire flush_ex_mem = flush_trap;
  wire flush_mem_wb = flush_trap;
  // An instruction enters EX exactly when this is low, which is how the
  // testbench counts retired instructions without adding a valid bit.
  wire flush_id_ex  /* verilator public */;
  // Nothing may be flushed while memory is holding the pipeline still. ex_mem
  // is frozen during a memory stall, so the instruction in EX has not moved on
  // yet -- injecting a bubble here would delete it rather than delay it. The
  // redirect stays asserted for as long as the stall lasts, so the flush
  // simply happens on the cycle the pipeline resumes.
  assign flush_id_ex = ~mem_stall & (flush_jb | flush_trap | load_use_stall);

  // Two different kinds of wait, and they do different things to the pipeline.
  //
  //   load-use   IF and ID freeze, and a bubble goes into EX. The instructions
  //              already past ID keep moving -- that is how the bubble opens up
  //              the cycle the consumer needs.
  //   memory     nothing moves at all. Injecting a bubble here would drop the
  //              instruction that is waiting.
  wire load_use_stall;
  wire im_wait = im_req_o && !(im_ready_i && im_rvalid_i);
  // A request goes out once per instruction, not once per cycle. Without the
  // issued flag, two memory instructions in a row see rvalid still high from
  // the first one and the second accepts data that belongs to its predecessor.
  reg dm_issued;
  wire dm_access;
  wire dm_wait = dm_access && !dm_rvalid_i;

  always @(posedge clk_i) begin
    if (rst_i) dm_issued <= 1'b0;
    else if (!mem_stall) dm_issued <= 1'b0;             // a new instruction reached MEM
    else if (dm_req_o && dm_ready_i) dm_issued <= 1'b1;  // this one has been asked
  end
  wire mem_stall = im_wait || dm_wait;

  stall_ctrl u_stall_ctrl (
      .load_use_i(load_use_stall),
      .im_wait_i (im_wait),
      .dm_wait_i (dm_wait),
      .stall_o   (stall_all)
  );

  hdu u_hdu (
      // From Decode Stage (the consumer)
      .rs1_id_i(rf_rs1_addr),
      .rs2_id_i(rf_rs2_addr),

      // From Execute Stage (the producer)
      .rd_ex_i       (ex_rd_addr),
      .reg_write_ex_i(ex_rd_wen),
      .rd_src_ex_i   (ex_rd_src),

      // Output to Pipeline Control
      .stall_o(load_use_stall)
  );

  // --- Forwarding Unit ---
  // Compares the source registers of the instruction in EX against the
  // destinations still in flight in MEM and WB.
  wire [1:0] fwd_a, fwd_b;

  fwd u_fwd (
      .rs1_addr_ex_i(ex_rs1_addr),
      .rs2_addr_ex_i(ex_rs2_addr),
      .rd_addr_mem_i(mem_rd_addr),
      .rd_wen_mem_i (mem_rd_wen),
      .rd_addr_wb_i (wb_rd_addr),
      .rd_wen_wb_i  (wb_rd_wen),
      .fwd_a_o      (fwd_a),
      .fwd_b_o      (fwd_b)
  );

  // What the instruction in MEM is going to write back. For most instructions
  // that is the ALU result, but JAL/JALR write pc+4 -- forwarding alu_result
  // there would hand the next instruction the jump target instead of the return
  // address. Loads never reach this mux: hdu stalls them, and by the time the
  // consumer runs the load is in WB.
  wire [XLEN-1:0] mem_fwd_data = (mem_rd_src == PC4_RDSEL) ? mem_pc_plus4 : mem_alu_result;

  // --- Branch Prediction ---
  // Looked up with the PC being fetched, because that is all IF has.
  wire            btb_hit;
  wire [XLEN-1:0] btb_target;
  wire            bht_taken;

  // A prediction needs both halves: bht says whether, btb says where. Missing
  // either one leaves IF with nowhere to go, so it falls back to pc+4.
  wire            pred_taken  /* verilator public */;
  wire [XLEN-1:0] pred_target  /* verilator public */;
  assign pred_taken  = btb_hit && bht_taken;
  assign pred_target = btb_target;

  // EX resolves every control-flow instruction, and that is when both tables
  // learn. Unconditional jumps train the bht too -- they saturate to strongly
  // taken after a couple of executions, which is how IF comes to predict them
  // at all.
  wire cf_resolved  /* verilator public */;
  assign cf_resolved = ex_branch || ex_jump;

  btb #(
      .XLEN(XLEN)
  ) u_btb (
      .clk_i       (clk_i),
      .rst_i       (rst_i),
      .pc_i        (if_pc),
      .hit_o       (btb_hit),
      .target_o    (btb_target),
      // Only taken branches have a target worth recording.
      .upd_valid_i (cf_resolved && ex_jb_taken),
      .upd_pc_i    (ex_pc),
      .upd_target_i(ex_jb_target)
  );

  bht #(
      .XLEN(XLEN)
  ) u_bht (
      .clk_i          (clk_i),
      .rst_i          (rst_i),
      .pc_i           (if_pc),
      .predict_taken_o(bht_taken),
      .upd_valid_i    (cf_resolved),
      .upd_pc_i       (ex_pc),
      .upd_taken_i    (ex_jb_taken)
  );

  // --- IF Stage ---
  wire [XLEN-1:0] if_pc  /* verilator public */, if_pc_plus4;
  if_stage u_if_stage (
      .clk_i      (clk_i),
      .rst_i      (rst_i),
      .stall_i    (stall_all),
      .trap_i       (trap_take || mret_take),
      .trap_pc_i    (trap_take ? wb_mtvec : wb_mepc),
      .redirect_i   (ex_redirect),
      .redirect_pc_i(ex_redirect_pc),
      .pred_taken_i (pred_taken),
      .pred_target_i(pred_target),
      .pc_o       (if_pc),
      .pc_plus4_o (if_pc_plus4)
  );
  assign im_req_o  = 1'b1;   // fetch every cycle; the memory keeps up
  assign im_addr_o = if_pc;

  // --- IF/ID Register ---
  wire [XLEN-1:0] id_pc, id_inst, id_pc_plus4;
  if_id u_if_id (
      .clk_i     (clk_i),
      .rst_i     (rst_i),
      .stall_i   (stall_all),
      .flush_i   (flush_if_id),
      .pc_i      (if_pc),
      .inst_i    (im_data_i),
      .pc_plus4_i(if_pc_plus4),
      .pred_taken_i (pred_taken),
      .pred_target_i(pred_target),
      .pc_o      (id_pc),
      .inst_o    (id_inst),
      .pred_taken_o (id_pred_taken),
      .pred_target_o(id_pred_target),
      .pc_plus4_o(id_pc_plus4)
  );

  // --- ID Stage ---
  wire [XLEN-1:0] rf_rs1_data, rf_rs2_data;
  wire [XLEN-1:0] id_rs1_data_o, id_rs2_data_o, id_imm_o;
  wire id_exc_valid, id_is_mret;  wire [3:0] id_exc_cause;
  wire [11:0] id_csr_addr;  wire id_csr_wen;  wire [2:0] id_csr_op;
  wire [XLEN-1:0] id_csr_operand;
  wire            id_pred_taken;
  wire [XLEN-1:0] id_pred_target;
  wire id_alu_sub;
  wire [4:0] rf_rs1_addr, rf_rs2_addr;
  wire [4:0] id_rd_addr_o;
  wire [2:0] id_alu_op, id_branch_op, id_mem_op;
  wire [2:0] id_rd_src;
  wire id_rd_wen, id_alu_src_a, id_alu_src_b, id_alu_shift, id_branch, id_jump, id_mem_wen;

  id_stage u_id_stage (
      .inst_i     (id_inst),
      .rs1_addr_o (rf_rs1_addr),
      .rs2_addr_o (rf_rs2_addr),
      .rs1_data_i (rf_rs1_data),
      .rs2_data_i (rf_rs2_data),
      .alu_sub_o  (id_alu_sub),
      .csr_addr_o (id_csr_addr),
      .csr_wen_o  (id_csr_wen),
      .csr_op_o   (id_csr_op),
      .csr_operand_o(id_csr_operand),
      .exc_valid_o(id_exc_valid),
      .exc_cause_o(id_exc_cause),
      .is_mret_o  (id_is_mret),
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
      // A trapping instruction retires nothing: its rd write is the first
      // thing that must not happen.
      .rd_we_i   (wb_rd_wen && !trap_take),
      .rd_addr_i (wb_rd_addr),
      .rd_data_i (wb_final_data)
  );

  // --- ID/EX Register ---
  // (Latching all signals for the Execute stage) 
  wire [XLEN-1:0] ex_pc  /* verilator public */, ex_pc_plus4, ex_rs1_data, ex_rs2_data, ex_imm;
  wire [4:0] ex_rs1_addr, ex_rs2_addr;
  wire ex_exc_valid_r, ex_is_mret;  wire [3:0] ex_exc_cause_r;
  wire [11:0] ex_csr_addr;  wire ex_csr_wen;  wire [2:0] ex_csr_op;
  wire [XLEN-1:0] ex_csr_operand;
  wire       ex_pred_taken;
  wire [XLEN-1:0] ex_pred_target;
  wire ex_alu_sub;
  wire [4:0] ex_rd_addr;
  wire [2:0] ex_alu_op, ex_branch_op, ex_mem_op;
  wire [2:0] ex_rd_src;
  wire ex_rd_wen, ex_alu_src_a, ex_alu_src_b, ex_alu_shift, ex_branch, ex_jump, ex_mem_wen;

  id_ex u_id_ex (
      .clk_i      (clk_i),
      .rst_i      (rst_i),
      .flush_i    (flush_id_ex),
      .stall_i    (mem_stall),
      .pc_i       (id_pc),
      .pc_plus4_i (id_pc_plus4),
      .rs1_data_i (id_rs1_data_o),
      .rs2_data_i (id_rs2_data_o),
      .rs1_addr_i (rf_rs1_addr),
      .rs2_addr_i (rf_rs2_addr),
      .pred_taken_i (id_pred_taken),
      .pred_target_i(id_pred_target),
      .alu_sub_i  (id_alu_sub),
      .csr_addr_i (id_csr_addr),
      .csr_wen_i  (id_csr_wen),
      .csr_op_i   (id_csr_op),
      .csr_operand_i(id_csr_operand),
      .exc_valid_i(id_exc_valid),
      .exc_cause_i(id_exc_cause),
      .is_mret_i  (id_is_mret),
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
      .rs1_addr_ex_o (ex_rs1_addr),
      .rs2_addr_ex_o (ex_rs2_addr),
      .pred_taken_ex_o (ex_pred_taken),
      .pred_target_ex_o(ex_pred_target),
      .alu_sub_ex_o  (ex_alu_sub),
      .csr_addr_ex_o (ex_csr_addr),
      .csr_wen_ex_o  (ex_csr_wen),
      .csr_op_ex_o   (ex_csr_op),
      .csr_operand_ex_o(ex_csr_operand),
      .exc_valid_ex_o(ex_exc_valid_r),
      .exc_cause_ex_o(ex_exc_cause_r),
      .is_mret_ex_o  (ex_is_mret),
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
  wire            ex_redirect  /* verilator public */;
  wire [XLEN-1:0] ex_redirect_pc  /* verilator public */;
  wire [XLEN-1:0] ex_alu_result;
  wire [XLEN-1:0] ex_rs1_fwd;
  wire [XLEN-1:0] ex_rs2_fwd;
  wire [XLEN-1:0] ex_jb_target  /* verilator public */;
  wire            ex_jb_taken  /* verilator public */;

  ex_stage u_ex_stage (
      .alu_op_i    (ex_alu_op),
      .alu_src_a_i (ex_alu_src_a),
      .alu_src_b_i (ex_alu_src_b),
      .alu_shift_i (ex_alu_shift),
      .alu_sub_i   (ex_alu_sub),
      .branch_i    (ex_branch),
      .branch_op_i (ex_branch_op),
      .jump_i      (ex_jump),
      .pc_i        (ex_pc),
      .pc_plus4_i  (ex_pc_plus4),
      .pred_taken_i (ex_pred_taken),
      .pred_target_i(ex_pred_target),
      .rs1_data_i  (ex_rs1_data),
      .rs2_data_i  (ex_rs2_data),
      .imm_i       (ex_imm),

      .fwd_a_i       (fwd_a),
      .fwd_b_i       (fwd_b),
      .fwd_mem_data_i(mem_fwd_data),
      .fwd_wb_data_i (wb_final_data),

      .rs1_fwd_o   (ex_rs1_fwd),
      .rs2_fwd_o   (ex_rs2_fwd),
      .alu_result_o(ex_alu_result),
      .jb_target_o (ex_jb_target),
      .jb_taken_o  (ex_jb_taken),
      .redirect_o    (ex_redirect),
      .redirect_pc_o (ex_redirect_pc)
  );

  // --- Misaligned data address (detected in EX, where the address exists) ---
  // mem_op[1:0] is the access width: 00 byte, 01 half, 10 word. A byte access
  // can never be misaligned, which is why there is no case for it.
  wire ex_is_mem = (ex_rd_src == MEM_RDSEL) || ex_mem_wen;
  wire ex_misaligned = ex_is_mem
      && (((ex_mem_op[1:0] == 2'b10) && (ex_alu_result[1:0] != 2'b00))
       || ((ex_mem_op[1:0] == 2'b01) && (ex_alu_result[0] != 1'b0)));

  // An exception raised earlier wins: the instruction never got far enough to
  // compute an address, so reporting a misaligned one would be a lie.
  wire       ex_exc_valid = ex_exc_valid_r || ex_misaligned;
  wire [3:0] ex_exc_cause = ex_exc_valid_r ? ex_exc_cause_r
                          : ex_mem_wen     ? EXC_STORE_MISALIGNED
                                           : EXC_LOAD_MISALIGNED;

  // The CSR operand is picked here, not in ID, because rs1 has to come through
  // the forwarding mux. id_ex carries the immediate half; this picks between it
  // and the forwarded register value.
  wire [XLEN-1:0] ex_csr_operand_sel = ex_csr_op[2] ? ex_csr_operand : ex_rs1_fwd;

  // --- EX/MEM Register ---
  wire [XLEN-1:0] mem_pc_plus4, mem_alu_result, mem_rs2_data;
  wire [4:0] mem_rd_addr;
  wire [2:0] mem_mem_op;
  wire [2:0] mem_rd_src;
  wire mem_exc_valid, mem_is_mret;  wire [3:0] mem_exc_cause;
  wire [11:0] mem_csr_addr;  wire mem_csr_wen;  wire [2:0] mem_csr_op;
  wire [XLEN-1:0] mem_csr_operand;
  wire mem_rd_wen, mem_mem_wen;

  ex_mem u_ex_mem (
      .clk_i       (clk_i),
      .rst_i       (rst_i),
      .stall_i     (mem_stall),
      .flush_i     (flush_ex_mem),
      .pc_plus4_i  (ex_pc_plus4),
      .alu_result_i(ex_alu_result),
      .rs2_data_i  (ex_rs2_fwd),
      .rd_addr_i   (ex_rd_addr),
      .rd_wen_i    (ex_rd_wen),
      .rd_src_i    (ex_rd_src),
      .csr_addr_i  (ex_csr_addr),
      .csr_wen_i   (ex_csr_wen),
      .csr_op_i    (ex_csr_op),
      .csr_operand_i(ex_csr_operand_sel),
      .exc_valid_i(ex_exc_valid),
      .exc_cause_i(ex_exc_cause),
      .is_mret_i  (ex_is_mret),
      .mem_op_i    (ex_mem_op),
      .mem_wen_i   (ex_mem_wen),

      .pc_plus4_o  (mem_pc_plus4),
      .alu_result_o(mem_alu_result),
      .rs2_data_o  (mem_rs2_data),
      .rd_addr_o   (mem_rd_addr),
      .rd_wen_o    (mem_rd_wen),
      .rd_src_o    (mem_rd_src),
      .csr_addr_o  (mem_csr_addr),
      .csr_wen_o   (mem_csr_wen),
      .csr_op_o    (mem_csr_op),
      .csr_operand_o(mem_csr_operand),
      .exc_valid_o(mem_exc_valid),
      .exc_cause_o(mem_exc_cause),
      .is_mret_o  (mem_is_mret),
      .mem_op_o    (mem_mem_op),
      .mem_wen_o   (mem_mem_wen)
  );

  // --- MEM Stage (Data SRAM Interface) ---
  // A load or store is in MEM this cycle. Anything else leaves the port idle.
  wire mem_is_load  = (mem_rd_src == MEM_RDSEL);
  wire mem_is_store = mem_mem_wen;
  assign dm_access = mem_is_load || mem_is_store;
  assign dm_req_o  = dm_access && !dm_issued;
  assign dm_addr_o = mem_alu_result;

  wire [XLEN-1:0] lsu_rdata;
  wire [     3:0] lsu_wstrb;

  lsu #(
      .XLEN(XLEN)
  ) u_lsu (
      .mem_op_i    (mem_mem_op),
      .addr_i      (mem_alu_result),
      .wdata_i     (mem_rs2_data),
      .wstrb_o     (lsu_wstrb),
      .wdata_lane_o(dm_wdata_o),
      .rdata_raw_i (dm_rdata_i),
      .rdata_o     (lsu_rdata)
  );

  // WSTRB all zero means a read, so the store path and the read path share one
  // request. Nothing else has to say which it is.
  assign dm_wstrb_o = mem_is_store ? lsu_wstrb : 4'b0000;

  // --- MEM/WB Register ---
  wire [XLEN-1:0] wb_pc_plus4, wb_alu_result, wb_mem_data;
  wire [4:0] wb_rd_addr;
  wire [2:0] wb_rd_src;
  wire       wb_is_store;
  wire wb_exc_valid  /* verilator public */;
  wire wb_is_mret  /* verilator public */;
  wire [3:0] wb_exc_cause  /* verilator public */;
  wire [XLEN-1:0] wb_mtvec  /* verilator public */, wb_mepc  /* verilator public */;
  wire [11:0] wb_csr_addr;  wire wb_csr_wen;  wire [2:0] wb_csr_op;
  wire [XLEN-1:0] wb_csr_operand, wb_csr_rdata;
  wire       wb_rd_wen;

  mem_wb u_mem_wb (
      .clk_i       (clk_i),
      .rst_i       (rst_i),
      .stall_i     (mem_stall),
      .flush_i     (flush_mem_wb),
      .pc_plus4_i  (mem_pc_plus4),
      .alu_result_i(mem_alu_result),
      .mem_data_i  (lsu_rdata),
      .rd_addr_i   (mem_rd_addr),
      .rd_wen_i    (mem_rd_wen),
      .rd_src_i    (mem_rd_src),
      .is_store_i  (mem_is_store),
      .csr_addr_i  (mem_csr_addr),
      .csr_wen_i   (mem_csr_wen),
      .csr_op_i    (mem_csr_op),
      .csr_operand_i(mem_csr_operand),
      .exc_valid_i(mem_exc_valid),
      .exc_cause_i(mem_exc_cause),
      .is_mret_i  (mem_is_mret),
      .pc_plus4_o  (wb_pc_plus4),
      .alu_result_o(wb_alu_result),
      .mem_data_o  (wb_mem_data),
      .rd_addr_o   (wb_rd_addr),
      .rd_wen_o    (wb_rd_wen),
      .rd_src_o    (wb_rd_src),
      .is_store_o  (wb_is_store),
      .csr_addr_o  (wb_csr_addr),
      .csr_wen_o   (wb_csr_wen),
      .csr_op_o    (wb_csr_op),
      .csr_operand_o(wb_csr_operand),
      .exc_valid_o(wb_exc_valid),
      .exc_cause_o(wb_exc_cause),
      .is_mret_o  (wb_is_mret)
  );

  // --- CSR File ---
  // Sits in WB, reading and writing in the same stage, so two back-to-back CSR
  // instructions on the same address need no forwarding and no stall.
  csr #(
      .XLEN(XLEN)
  ) u_csr (
      .clk_i    (clk_i),
      .rst_i    (rst_i),
      .raddr_i  (wb_csr_addr),
      .rdata_o  (wb_csr_rdata),
      .wen_i    (wb_csr_wen && !trap_take),
      .op_i     (wb_csr_op),
      // A trapping instruction must not also perform its CSR write.
      .operand_i(wb_csr_operand),

      .trap_i      (trap_take),
      .trap_cause_i(trap_cause),
      .trap_pc_i   (trap_pc),
      .trap_tval_i (trap_tval),
      .mret_i      (mret_take),
      .trap_is_irq_i(take_irq),
      .mtip_i      (mtip_i),
      .instret_i   (instret),
      .irq_pending_o(irq_pending),
      .mtvec_o     (wb_mtvec),
      .mepc_o      (wb_mepc)
  );

  // --- Trap commit ---
  // Taken in WB, the same stage the CSR file lives in, so mepc and mcause are
  // written by the same edge that would have retired the instruction.
  //
  // Precise means: everything before this instruction has already committed,
  // and everything after it is squashed. Since WB is the last stage, "before"
  // needs no work -- those instructions are gone. "After" is the four flushes
  // below.
  // A bubble in WB has pc_plus4 = 0, because mem_wb flushes to zero and no
  // real instruction can have pc + 4 == 0. That is the validity signal, and it
  // costs nothing -- an explicit valid bit through three pipeline registers
  // would say the same thing for 3 more flops.
  wire wb_valid = (wb_pc_plus4 != {XLEN{1'b0}});

  // An interrupt differs from an exception in two ways that matter here.
  //
  // First, the instruction in WB is not at fault, so it retires normally and
  // mepc points at the *next* instruction. Squashing it instead would mean
  // mret re-executes it -- and a store performs its write in MEM, so
  // re-executing one would write twice.
  //
  // Second, it can wait. mtip is a level, so holding off until no memory
  // access is in flight costs a few cycles and removes the case where the
  // pipeline is flushed with a bus transaction half finished.
  wire exc_take = wb_exc_valid;

  // An interrupt is taken the same way an exception is -- the instruction in
  // WB is squashed and mepc points at it, so mret re-executes it. Setting mepc
  // to pc+4 and letting it retire looks simpler until the instruction is a
  // taken branch, where pc+4 is not the next instruction at all.
  //
  // Re-executing is only safe for an instruction that has left no trace, so
  // two cases are refused. A store commits in MEM, so by the time it reaches
  // WB the write has happened and running it again would write twice; and an
  // access still in flight would be flushed half finished. mtip is a level, so
  // waiting a cycle or two for a quiet moment costs nothing.
  wire take_irq = irq_pending && wb_valid && !exc_take && !wb_is_mret
      && !dm_access && !wb_is_store;

  wire trap_take  /* verilator public */;
  assign trap_take = exc_take || take_irq;
  assign flush_trap = trap_take || mret_take;
  wire mret_take  /* verilator public */;
  assign mret_take = wb_is_mret && !wb_exc_valid;

  // mtval carries the address for a misaligned access and nothing otherwise.
  // The spec allows 0 when the implementation has nothing useful to say.
  wire misaligned_cause = !take_irq && (wb_exc_cause == EXC_LOAD_MISALIGNED)
      || (wb_exc_cause == EXC_STORE_MISALIGNED);
  wire [XLEN-1:0] trap_tval = misaligned_cause ? wb_alu_result : {XLEN{1'b0}};

  // pc_plus4 - 4 is the instruction's own PC. Carrying pc through two more
  // pipeline registers to say the same thing would cost 64 flops.
  // An exception returns to the faulting instruction; an interrupt returns
  // to the one after the instruction that happened to be committing.
  wire [XLEN-1:0] trap_pc = wb_pc_plus4 - 32'd4;

  wire [3:0] trap_cause = take_irq ? IRQ_MACHINE_TIMER : wb_exc_cause;

  // Retired means committed: reached WB and was not squashed.
  wire instret = wb_valid && !trap_take;

  wire irq_pending;

  // --- WB Stage ---
  wire [XLEN-1:0] wb_final_data;
  wb_stage u_wb_stage (
      .alu_result_i(wb_alu_result),
      .csr_rdata_i (wb_csr_rdata),
      .mem_data_i  (wb_mem_data),
      .pc_plus4_i  (wb_pc_plus4),
      .rd_src_i    (wb_rd_src),
      .wb_data_o   (wb_final_data)
  );


endmodule

/* verilator lint_on UNUSEDPARAM */
