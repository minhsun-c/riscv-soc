`timescale 1ns / 1ps

/**
 * Module: csr (Control and Status Registers)
 *
 * Description:
 * The machine-mode CSR file, plus the read-modify-write that Zicsr defines.
 *
 * Unlike the general-purpose register file, this one both reads and writes in
 * the same pipeline stage (WB). That is deliberate: it removes the hazard
 * entirely. Two back-to-back CSR instructions touching the same address are
 * one cycle apart in WB, so the second reads what the first just wrote --
 * without forwarding, without stalling, without anything.
 *
 * Reading in ID and writing in WB, the way the register file works, would put
 * three cycles between them and reintroduce exactly the RAW problem week 13
 * solved. Doing both here is cheaper than solving it twice.
 *
 * All six Zicsr instructions are the same three operations with two operand
 * sources, which csrop.vh encodes directly as funct3:
 *
 *     CSRRW  rd, csr, rs1     csr <- rs1              rd <- old
 *     CSRRS  rd, csr, rs1     csr <- old | rs1        rd <- old
 *     CSRRC  rd, csr, rs1     csr <- old & ~rs1       rd <- old
 *     CSRRWI / CSRRSI / CSRRCI    same, operand is a 5-bit immediate
 *
 * rd always gets the value from *before* the write. That is what makes
 * "read and clear a bit atomically" a single instruction.
 *
 * @port raddr_i    [Input]  [11:0]     CSR being accessed.
 * @port rdata_o    [Output] [XLEN-1:0] Its value before this instruction's write.
 * @port wen_i      [Input]             1 if this instruction writes a CSR.
 * @port op_i       [Input]  [2:0]      Which Zicsr operation (see csrop.vh).
 * @port operand_i  [Input]  [XLEN-1:0] rs1 value, or the zero-extended uimm.
 */

/* verilator lint_off UNUSEDPARAM */

module csr #(
    parameter XLEN = 32
) (
    input clk_i,
    input rst_i,

    // Read port (combinational, in WB)
    input  [    11:0] raddr_i,
    output [XLEN-1:0] rdata_o,

    // Write port (same stage, on the clock edge)
    input            wen_i,
    input [     2:0] op_i,
    input [XLEN-1:0] operand_i
);

  `include "csraddr.vh"
  `include "csrop.vh"

  // Only the CSRs this core actually implements get storage. Everything else
  // reads zero and swallows writes -- which is what the spec allows for
  // unimplemented machine CSRs, and keeps the decoder from needing a list.
  reg [XLEN-1:0] mstatus  /* verilator public */;
  reg [XLEN-1:0] mie  /* verilator public */;
  reg [XLEN-1:0] mtvec  /* verilator public */;
  reg [XLEN-1:0] mscratch  /* verilator public */;
  reg [XLEN-1:0] mepc  /* verilator public */;
  reg [XLEN-1:0] mcause  /* verilator public */;
  reg [XLEN-1:0] mtval  /* verilator public */;
  reg [XLEN-1:0] mip  /* verilator public */;

  reg [XLEN-1:0] rdata;
  assign rdata_o = rdata;

  always @(*) begin
    case (raddr_i)
      CSR_MSTATUS:  rdata = mstatus;
      CSR_MIE:      rdata = mie;
      CSR_MTVEC:    rdata = mtvec;
      CSR_MSCRATCH: rdata = mscratch;
      CSR_MEPC:     rdata = mepc;
      CSR_MCAUSE:   rdata = mcause;
      CSR_MTVAL:    rdata = mtval;
      CSR_MIP:      rdata = mip;
      default:      rdata = {XLEN{1'b0}};
    endcase
  end

  // The three operations, applied to whatever rdata just read. Note this uses
  // the pre-write value for all three -- rd gets the same thing.
  reg [XLEN-1:0] wdata;
  always @(*) begin
    case (op_i)
      CSR_RW, CSR_RWI: wdata = operand_i;
      CSR_RS, CSR_RSI: wdata = rdata | operand_i;
      CSR_RC, CSR_RCI: wdata = rdata & ~operand_i;
      default:         wdata = rdata;
    endcase
  end

  // CSRRS/CSRRC with rs1 = x0 must not write at all, so that reading a CSR
  // with side effects stays side-effect free. ctrl handles that by clearing
  // csr_wen_o, which is why this module can just trust wen_i.
  always @(posedge clk_i) begin
    if (rst_i) begin
      mstatus  <= {XLEN{1'b0}};
      mie      <= {XLEN{1'b0}};
      mtvec    <= {XLEN{1'b0}};
      mscratch <= {XLEN{1'b0}};
      mepc     <= {XLEN{1'b0}};
      mcause   <= {XLEN{1'b0}};
      mtval    <= {XLEN{1'b0}};
      mip      <= {XLEN{1'b0}};
    end else if (wen_i) begin
      case (raddr_i)
        CSR_MSTATUS:  mstatus <= wdata;
        CSR_MIE:      mie <= wdata;
        CSR_MTVEC:    mtvec <= wdata;
        CSR_MSCRATCH: mscratch <= wdata;
        CSR_MEPC:     mepc <= wdata;
        CSR_MCAUSE:   mcause <= wdata;
        CSR_MTVAL:    mtval <= wdata;
        CSR_MIP:      mip <= wdata;
        default:      ;  // unimplemented CSR: write discarded
      endcase
    end
  end

endmodule

/* verilator lint_on UNUSEDPARAM */
