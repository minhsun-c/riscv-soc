/* link.ld */
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
    /* Force the code to start at address 0x00000000 */
    . = 0x00000000;

    .text : { 
        *(.text.init)  /* start.S must be the very first thing! */
        *(.text)       /* The compiled C code follows */
    }

    .data : { *(.data) *(.rodata) *(.sdata) }
    .bss  : { *(.bss) *(.sbss) }
}