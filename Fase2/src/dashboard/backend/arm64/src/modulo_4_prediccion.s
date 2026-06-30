.include "utils.s"

.global _start

.data

outfile:
    .asciz "resultado_prediccion.txt"

str_mod:
    .ascii "MODULE=PREDICTION\n"
    len_mod = . - str_mod

str_init:
    .ascii "INITIAL_VALUE="
    len_init = . - str_init

str_final:
    .ascii "FINAL_VALUE="
    len_final = . - str_final

str_diff:
    .ascii "TOTAL_DIFF="
    len_diff = . - str_diff

str_avg:
    .ascii "AVG_CHANGE="
    len_avg = . - str_avg

str_next:
    .ascii "NEXT_VALUE="
    len_next = . - str_next

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

    sub x10, x25, #16
    ldr x22, [x10]

    ldr x23, [x24]

    mov x10, #100
    mul x22, x22, x10
    mul x23, x23, x10

    sub x24, x23, x22

    mov x10, #29
    cmp x24, #0
    bgt diff_no_neg

    mov x12, #0
    sub x25, x12, x24
    udiv x25, x25, x10
    sub x25, x12, x25
    b calc_next

diff_no_neg:
    udiv x25, x24, x10

calc_next:

    add x26, x23, x25

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
    ldr x1, =str_init
    mov x2, len_init
    bl write_file

    mov x0, x22
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
    ldr x1, =str_final
    mov x2, len_final
    bl write_file

    mov x0, x23
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
    ldr x1, =str_diff
    mov x2, len_diff
    bl write_file

    mov x0, x24
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
    ldr x1, =str_avg
    mov x2, len_avg
    bl write_file

    mov x0, x25
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
    ldr x1, =str_next
    mov x2, len_next
    bl write_file

    mov x0, x26
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
