`timescale 1ns / 1ps

/**
 * Module: ctrl (Control Unit)
 *
 * Description:
 * Main Control Unit for the RISC-V processor. Translates extracted 
 * instruction fields into control signals for the datapath.
 *
 * @port opcode_i      [Input]  [6:0]      7-bit opcode from the Instruction Decoder.
 * @port funct3_i      [Input]  [2:0]      3-bit funct3 from the Instruction Decoder.
 * @port funct7_i      [Input]  [6:0]      7-bit funct7 (Bit 5 is used to distinguish 
 *                                         ADD/SUB and SRL/SRA).
 *
 * @port rd_wen_o      [Output] [1:0]      Register File write enable (1 = write to rd).
 * @port rd_src_o      [Output] [2:0]      Selects the data source for rd 
 *                                         (0:ALU, 1:MEM, 2:PC+4, 3:ELSE).
 * @port imm_sel_o     [Output] [2:0]      Immediate format selector (0:I, 1:S, 2:B, 
 *                                         3:U, 4:J).
 * @port rs1_ren_o     [Output] [1:0]      1 if the rs1 field holds a real register 
 *                                         reference. U/J formats reuse those bits 
 *                                         for the immediate, so they must read x0.
 * @port csr_wen_o     [Output]            1 if this instruction writes a CSR.
 * @port csr_op_o      [Output] [2:0]      Which Zicsr operation (see csrop.vh).
 * @port rs2_ren_o     [Output] [1:0]      1 if the rs2 field holds a real register 
 *                                         reference. I/U/J formats must read x0.
 * @port alu_src_a_o   [Output] [1:0]      ALU operand A source (0 = rs1, 1 = pc).
 * @port alu_src_b_o   [Output] [1:0]      ALU operand B source (0 = rs2, 1 = immediate).
 * @port alu_op_o      [Output] [2:0]      3-bit ALU operation selector.
 * @port alu_shift_o   [Output] [1:0]      ALU shift mode (0 = logical, 1 = arithmetic).
 * @port alu_sub_o     [Output] [1:0]      ALU subtract flag (1 = force subtraction).
 *
 * @port branch_o      [Output] [1:0]      Branch instruction flag.
 * @port branch_op_o   [Output] [2:0]      3-bit branch operation selector.
 * @port jump_o        [Output] [1:0]      Unconditional jump flag (1 = JAL/JALR).
 * @port mem_wen_o     [Output] [1:0]      Data Memory write enable.
 * @port mem_op_o      [Output] [2:0]      3-bit Memory operation selector.
 */

/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNUSEDPARAM */

module ctrl (
    // Inputs from Decoder
    input [6:0] opcode_i,
    input [2:0] funct3_i,
    input [6:0] funct7_i,

    // RegFile & ImmGen Signals
    output reg       rd_wen_o,
    output reg [2:0] rd_src_o,
    output reg [2:0] imm_sel_o,
    output reg       rs1_ren_o,
    output reg       rs2_ren_o,

    // CSR Signals
    output reg       csr_wen_o,
    output reg [2:0] csr_op_o,

    // ALU Signals
    output reg       alu_src_a_o,
    output reg       alu_src_b_o,
    output reg [2:0] alu_op_o,
    output reg       alu_shift_o,
    output reg       alu_sub_o,

    // Branch & Jump Signals
    output reg       branch_o,
    output reg [2:0] branch_op_o,
    output reg       jump_o,

    // Memory Signals
    output reg       mem_wen_o,
    output reg [2:0] mem_op_o
);

  `include "opcode.vh"
  `include "aluop.vh"
  `include "immsel.vh"
  `include "branchop.vh"
  `include "memop.vh"
  `include "rdsel.vh"
  `include "csrop.vh"

  always @(*) begin

    // Two more signals to clear before the case, for the same reason as all
    // the others: a branch that forgets one of them creates a latch.
    csr_wen_o   = 1'b0;
    csr_op_o    = CSR_NONE;

    case (opcode_i)
      R_TYPE: begin
        rs1_ren_o   = 1'b1;
        rs2_ren_o   = 1'b1;
        rd_wen_o    = 1'b1;
        imm_sel_o   = NO_IMM_MODE;
        alu_src_a_o = 1'b0;  // Use rs1
        alu_src_b_o = 1'b0;  // Use rs2
        alu_op_o    = funct3_i;

        // Determine SRA (funct3=101, funct7=1)
        alu_shift_o = (funct3_i == SRL_OP && funct7_i[5] == 1'b1);

        // Determine SUB (funct3=000, funct7=1)
        alu_sub_o   = (funct3_i == ADD_OP && funct7_i[5] == 1'b1);

        branch_o    = 1'b0;
        branch_op_o = NOBR_OP;
        jump_o      = 1'b0;
        mem_wen_o   = 1'b0;
        mem_op_o    = 3'd0;
        rd_src_o    = ALU_RDSEL;
      end

      I_ALU: begin
        rs1_ren_o   = 1'b1;
        rs2_ren_o   = 1'b0;
        rd_wen_o    = 1'b1;
        imm_sel_o   = I_IMM_MODE;
        alu_src_a_o = 1'b0;  // Use rs1
        alu_src_b_o = 1'b1;  // Use imm
        alu_op_o    = funct3_i;

        // Determine SRA (funct3=101, funct7=1)
        alu_shift_o = (funct3_i == SRL_OP && funct7_i[5] == 1'b1);

        alu_sub_o   = 1'b0;
        branch_o    = 1'b0;
        branch_op_o = NOBR_OP;
        jump_o      = 1'b0;
        mem_wen_o   = 1'b0;
        mem_op_o    = 3'd0;
        rd_src_o    = ALU_RDSEL;
      end

      I_LOAD: begin
        rs1_ren_o   = 1'b1;
        rs2_ren_o   = 1'b0;
        rd_wen_o    = 1'b1;
        imm_sel_o   = I_IMM_MODE;
        alu_src_a_o = 1'b0;  // Use rs1
        alu_src_b_o = 1'b1;  // Use imm
        alu_op_o    = ADD_OP;
        alu_shift_o = 1'b0;
        alu_sub_o   = 1'b0;
        branch_o    = 1'b0;
        branch_op_o = NOBR_OP;
        jump_o      = 1'b0;
        mem_wen_o   = 1'b0;
        mem_op_o    = funct3_i;
        rd_src_o    = MEM_RDSEL;
      end

      S_TYPE: begin
        rs1_ren_o   = 1'b1;
        rs2_ren_o   = 1'b1;
        rd_wen_o    = 1'b0;
        imm_sel_o   = S_IMM_MODE;
        alu_src_a_o = 1'b0;  // Use rs1
        alu_src_b_o = 1'b1;  // Use imm
        alu_op_o    = ADD_OP;
        alu_shift_o = 1'b0;
        alu_sub_o   = 1'b0;
        branch_o    = 1'b0;
        branch_op_o = NOBR_OP;
        jump_o      = 1'b0;
        mem_wen_o   = 1'b1;
        mem_op_o    = funct3_i;
        rd_src_o    = NO_RDSEL;
      end

      B_TYPE: begin
        rs1_ren_o   = 1'b1;
        rs2_ren_o   = 1'b1;
        rd_wen_o  = 1'b0;
        imm_sel_o = B_IMM_MODE;
        alu_src_a_o    = 1'b0;  // Use rs1
        alu_src_b_o = 1'b0;  // Use rs2

        case (funct3_i)
          BEQ_OP, BNE_OP:   alu_op_o = ADD_OP;
          BLT_OP, BGE_OP:   alu_op_o = SLT_OP;
          BLTU_OP, BGEU_OP: alu_op_o = SLTU_OP;
          default:          alu_op_o = ADD_OP;
        endcase

        alu_shift_o = 1'b0;

        case (funct3_i)
          BEQ_OP, BNE_OP: alu_sub_o = 1'b1;
          default:        alu_sub_o = 1'b0;
        endcase

        branch_o    = 1'b1;
        branch_op_o = funct3_i;
        jump_o      = 1'b0;
        mem_wen_o   = 1'b0;
        mem_op_o    = 3'd0;
        rd_src_o    = NO_RDSEL;
      end

      U_LUI: begin
        rs1_ren_o   = 1'b0;
        rs2_ren_o   = 1'b0;
        rd_wen_o    = 1'b1;
        imm_sel_o   = U_IMM_MODE;
        alu_src_a_o = 1'b0;  // Use rs1
        alu_src_b_o = 1'b1;  // Use imm
        alu_op_o    = 3'd0;
        alu_shift_o = 1'b0;
        alu_sub_o   = 1'b0;
        branch_o    = 1'b0;
        branch_op_o = NOBR_OP;
        jump_o      = 1'b0;
        mem_wen_o   = 1'b0;
        mem_op_o    = 3'd0;
        rd_src_o    = ALU_RDSEL;
      end

      U_AUIPC: begin
        rs1_ren_o   = 1'b0;
        rs2_ren_o   = 1'b0;
        rd_wen_o    = 1'b1;
        imm_sel_o   = U_IMM_MODE;
        alu_src_a_o = 1'b1;  // Use pc
        alu_src_b_o = 1'b1;  // Use imm
        alu_op_o    = ADD_OP;
        alu_shift_o = 1'b0;
        alu_sub_o   = 1'b0;
        branch_o    = 1'b0;
        branch_op_o = NOBR_OP;
        jump_o      = 1'b0;
        mem_wen_o   = 1'b0;
        mem_op_o    = 3'd0;
        rd_src_o    = ALU_RDSEL;
      end

      J_JAL: begin
        rs1_ren_o   = 1'b0;
        rs2_ren_o   = 1'b0;
        rd_wen_o    = 1'b1;
        imm_sel_o   = J_IMM_MODE;
        alu_src_a_o = 1'b1;  // Use pc
        alu_src_b_o = 1'b1;  // Use imm
        alu_op_o    = ADD_OP;
        alu_shift_o = 1'b0;
        alu_sub_o   = 1'b0;
        branch_o    = 1'b0;
        branch_op_o = NOBR_OP;
        jump_o      = 1'b1;
        mem_wen_o   = 1'b0;
        mem_op_o    = 3'd0;
        rd_src_o    = PC4_RDSEL;
      end

      I_JALR: begin
        rs1_ren_o   = 1'b1;
        rs2_ren_o   = 1'b0;
        rd_wen_o    = 1'b1;
        imm_sel_o   = I_IMM_MODE;
        alu_src_a_o = 1'b0;  // Use rs1
        alu_src_b_o = 1'b1;  // Use imm
        alu_op_o    = ADD_OP;
        alu_shift_o = 1'b0;
        alu_sub_o   = 1'b0;
        branch_o    = 1'b0;
        branch_op_o = NOBR_OP;
        jump_o      = 1'b1;
        mem_wen_o   = 1'b0;
        mem_op_o    = 3'd0;
        rd_src_o    = PC4_RDSEL;
      end

      SYSTEM: begin
        // Zicsr. The CSR address is inst[31:20] and id_stage slices it out
        // directly -- it never goes through imm_gen, because imm_gen produces
        // the *operand* here, not the address.
        //
        // funct3 is the operation code, so csr_op_o is just funct3 passed on.
        // Bit 2 of it selects the operand source, which is also what decides
        // whether the rs1 field is a register or a 5-bit immediate.
        rs1_ren_o   = ~funct3_i[2];  // 0xx forms read rs1, 1xx forms do not
        rs2_ren_o   = 1'b0;
        rd_wen_o    = 1'b1;
        imm_sel_o   = Z_IMM_MODE;
        alu_src_a_o = 1'b0;
        alu_src_b_o = 1'b0;
        alu_op_o    = ADD_OP;
        alu_shift_o = 1'b0;
        alu_sub_o   = 1'b0;
        branch_o    = 1'b0;
        branch_op_o = NOBR_OP;
        jump_o      = 1'b0;
        mem_wen_o   = 1'b0;
        mem_op_o    = 3'd0;
        rd_src_o    = CSR_RDSEL;

        // funct3 = 000 is ecall / ebreak / mret, not a CSR access. Week 17.
        csr_wen_o   = (funct3_i != CSR_PRIV);
        csr_op_o    = funct3_i;
      end

      default: begin
        rs1_ren_o   = 1'b0;
        rs2_ren_o   = 1'b0;
        rd_wen_o    = 1'b0;
        imm_sel_o   = NO_IMM_MODE;
        alu_src_a_o = 1'b0;  // Don't care
        alu_src_b_o = 1'b0;  // Don't care
        alu_op_o    = 3'd0;
        alu_shift_o = 1'd0;
        alu_sub_o   = 1'd0;
        branch_o    = 1'd0;
        branch_op_o = NOBR_OP;
        jump_o      = 1'd0;
        mem_wen_o   = 1'd0;
        mem_op_o    = 3'd0;
        rd_src_o    = NO_RDSEL;
      end
    endcase
  end

endmodule

/* verilator lint_on UNUSEDPARAM */
/* verilator lint_on UNUSEDSIGNAL */

