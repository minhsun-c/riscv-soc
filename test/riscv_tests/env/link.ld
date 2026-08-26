/* Linker script for the riscv-tests rv32ui suite on this core.
 *
 * The core's PC resets to 0x00000000, so .text.init (which holds _start)
 * must be placed there. Everything else follows contiguously inside the
 * 64 KiB unified RAM modelled by test/tb_riscv_tests.cpp.
 *
 * Keep the addresses here in sync with env/riscv_test.h.
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;

  /* _start lives here and must be the first instruction in the image. */
  .text.init : { *(.text.init) }

  .text : { *(.text) *(.text.*) }

  /* Push data past the code so that `objcopy -O binary` produces one flat
   * image that can be dropped into RAM at offset 0 verbatim. */
  . = ALIGN(64);

  .data : {
    *(.data) *(.data.*)
    *(.rodata) *(.rodata.*)
    *(.sdata) *(.sdata.*)
    *(.srodata) *(.srodata.*)
  }

  /* NOLOAD keeps .bss out of the binary image; the testbench zeroes RAM
   * before loading, so uninitialised data reads as zero anyway. */
  .bss (NOLOAD) : {
    *(.bss) *(.bss.*)
    *(.sbss) *(.sbss.*)
    *(COMMON)
  }

  _end = .;

  /DISCARD/ : {
    *(.comment)
    *(.note)
    *(.note.*)
    *(.riscv.attributes)
  }
}
