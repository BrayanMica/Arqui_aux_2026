.include "utils.s"

.global _start

.data

outfile:
    .asciz "resultado_media.txt"

str_mod:
    .ascii "MODULE=WEIGHTED_MEAN\n"
    len_mod = . - str_mod

str_tot:
    .ascii "TOTAL_VALUES=30\n"
    len_tot = . - str_tot

str_sumx:
    .ascii "SUM_X="
    len_sumx = . - str_sumx

str_wsum:
    .ascii "WEIGHT_SUM=465\n"
    len_wsum = . - str_wsum

str_wmean:
    .ascii "WEIGHTED_MEAN="
    len_wmean = . - str_wmean

nl:
    .ascii "\n"

.text

_start:

    ldr x10, [sp]
    cmp x10, #2
    blt fail_arg

    ldr x21, [sp, #16]
    mov x5, #10
    bl atoi_csv
    cbz x7, fail_arg
    mov x11, x10

    bl read_column_to_stack
    mov x24, x0
    mov x25, x1
    mov x26, x2

    sub x24, x25, #16

    mov x22, #0
    mov x23, #0
    mov x27, #0

calc_loop:
    cmp x27, #29
    bgt calc_done

    ldr x10, [x24]

    add x22, x22, x10

    add x11, x27, #1
    mul x12, x10, x11
    add x23, x23, x12

    add x27, x27, #1
    sub x24, x24, #16
    b calc_loop

calc_done:

    mov x10, #100
    mul x28, x23, x10
    mov x10, #465
    udiv x28, x28, x10

    ldr x0, =outfile
    mov x1, #577
    mov x2, #438
    bl open_file
    mov x19, x0

    mov x0, x19
    ldr x1, =str_mod
    mov x2, len_mod
    bl write_file

    mov x0, x19
    ldr x1, =str_tot
    mov x2, len_tot
    bl write_file

    mov x0, x19
    ldr x1, =str_sumx
    mov x2, len_sumx
    bl write_file

    mov x0, x22
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =nl
    mov x2, #1
    bl write_file

    mov x0, x19
    ldr x1, =str_wsum
    mov x2, len_wsum
    bl write_file

    mov x0, x19
    ldr x1, =str_wmean
    mov x2, len_wmean
    bl write_file

    mov x0, x28
    ldr x1, =num_buffer
    bl itoa_fixed
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =nl
    mov x2, #1
    bl write_file

    mov x0, x19
    bl close_file

    mov x0, #0
    mov x8, #93
    svc #0

fail_arg:
    mov x0, #1
    mov x8, #93
    svc #0
