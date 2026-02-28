# start.S
.section .text.init
.global _start

_start:
    # Initialize Stack Pointer to 4KB (0x1000)
    # This places the stack at the very end of your dmem array!
    li sp, 0x1000  

    # Jump to the C main() function
    call main

end_loop:
    # When main() returns, trap the CPU in an infinite loop
    j end_loop