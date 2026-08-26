# Which rv32ui tests run against this core.
#
# The list below is the upstream rv32ui_sc_tests set from
# vendor/riscv-tests/isa/rv32ui/Makefrag, minus the two entries that depend
# on hardware this core does not implement (see EXCLUDED below).

RV32UI_TESTS := \
	simple \
	add addi \
	and andi \
	auipc \
	beq bge bgeu blt bltu bne \
	jal jalr \
	lb lbu lh lhu lw ld_st \
	lui \
	or ori \
	sb sh sw st_ld \
	sll slli \
	slt slti sltiu sltu \
	sra srai \
	srl srli \
	sub \
	xor xori

# Deliberately excluded, with reasons:
#
#   fence_i  Requires the Zifencei extension. The test rewrites its own
#            instruction stream and executes FENCE.I to make the change
#            visible. This core has no FENCE.I (SYSTEM/MISC-MEM opcodes
#            decode to NOP), and the test does not even assemble for plain
#            rv32i: `unrecognized opcode 'fence.i', extension 'zifencei'
#            required`.
#
#   ma_data  Requires hardware support for misaligned loads and stores. The
#            test performs e.g. `lw` at an address ending in 1 and expects
#            the correctly assembled value. src/core/sram.v ignores the low
#            address bits for word accesses, and this core has no trap
#            mechanism to emulate the access in software, so neither of the
#            two behaviours the RISC-V spec permits (handle it, or trap) is
#            available.
#
# Both are genuine gaps in the hardware rather than harness limitations;
# implementing Zifencei or a misalignment trap would let them move into the
# list above.

RV32UI_EXCLUDED := fence_i ma_data
