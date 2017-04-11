!
! Bart's Custom Sega Saturn Start-Up Code
! Bart Trzynadlowski, 2001
! Public domain
!
! For use with the GNU C Compiler. This code has been tested with gcc version
! cygnus-2.7-96q3.
!
! Make sure this is the first file linked into your project, so that it is at
! the very beginning. Use the BART.LNK linker script. Load the resulting
! binary at 0x6004000 on the Sega Saturn and begin execution there.
!

.section .text

!
! Entry point
!
.global start
start:
    !
    ! Clear BSS
    !
    mov.l   bss_start,r0
    mov.l   bss_end,r1
    mov     #0,r2
lbss:
    cmp/ge  r0,r1
    bt      lbss_end
    add     #1,r0
    mov.b   r2,@r0
    bra     lbss
lbss_end:

    !
    ! Set initial stack pointer. Stack is from 0x6002000-0x6003FFF
    !
    mov.l   stack_ptr,r15

    !
    ! Jump to main()
    !
    mov.l   main_ptr,r0
    jsr @r0
    nop

    !
    ! When main() terminates, jump back to the ARP entry point
    !
    mov.l   arp_ptr,r0
    jmp @r0
    nop
    nop

    !
    ! Following is never reached, it was the from the original
    ! version of crt0.s
    !

    !
    ! Once _main() has terminated, disable interrupts and loop infinitely
    !
    mov     #0xf,r0
    shll2   r0
    shll2   r0
    ldc     r0,sr
end:
    bra     end
    nop

arp_ptr:    .long 0x02000100
main_ptr:   .long _main
stack_ptr:  .long 0x6004000 ! stack is from 0x6002000-0x6003FFF
bss_start:  .long __bss_start
bss_end:    .long __bss_end

! This is to keep libc happy

.global _atexit
   bra end
   nop
