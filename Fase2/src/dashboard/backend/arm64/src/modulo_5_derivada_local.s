.include "utils.s"

.data
    outfile:        .asciz "resultado_derivada.txt"

    msg_mod:        .asciz "MODULE=LOCAL_DERIVATIVE\n"
    len_msg_mod     = . - msg_mod

    msg_calc:       .asciz "CALC=LOCAL_DERIVATIVE\n"
    len_msg_calc    = . - msg_calc

    msg_max:        .asciz "MAX_LOCAL_SLOPE_X100="
    len_msg_max     = . - msg_max

    msg_status:     .asciz "STATUS=OK\n"
    len_msg_status  = . - msg_status

    msg_error_data: .asciz "STATUS=ERROR;ERROR=INSUFFICIENT_DATA;DETAIL=LOCAL_DERIVATIVE_REQUIRES_AT_LEAST_5_VALUES\n"
    len_error_data  = . - msg_error_data

    newline:        .asciz "\n"

.text
.global _start

_start:

    ldr x0, [sp]
    cmp x0, #4
    blt error_insuficiente

    ldr x0, [sp, #16]
    bl cadena_a_entero
    mov x11, x0

    ldr x0, [sp, #24]
    bl cadena_a_entero
    mov x13, x0

    ldr x0, [sp, #32]
    bl cadena_a_entero
    mov x14, x0

    bl read_column_to_stack
    mov x24, x0
    mov x25, x1
    mov x26, x2

    cmp x26, #5
    blt error_insuficiente

    mov x22, #0
    sub x28, x25, #64

window_loop:
    cmp x24, x28
    bge print_max

    ldr x10, [x24]
    ldr x11, [x24, #16]
    ldr x12, [x24, #32]
    ldr x13, [x24, #48]
    ldr x14, [x24, #64]
    
    add x15, x10, x11
    add x15, x15, x12
    add x15, x15, x13
    add x15, x15, x14

    mov x16, #0

    mov x9, #1
    mul x17, x11, x9
    add x16, x16, x17

    mov x9, #2
    mul x17, x12, x9
    add x16, x16, x17

    mov x9, #3
    mul x17, x13, x9
    add x16, x16, x17

    mov x9, #4
    mul x17, x14, x9
    add x16, x16, x17

    mov x9, #5
    mul x18, x16, x9

    mov x9, #10
    mul x19, x15, x9

    sub x20, x18, x19

    mov x9, #100
    mul x20, x20, x9

    mov x19, #0
    cmp x20, #0
    bge do_division
    mov x19, #1
    neg x20, x20

do_division:
    mov x9, #50
    udiv x20, x20, x9

    cmp x19, #1
    bne update_max
    neg x20, x20

update_max:
    mov x18, x20
    cmp x18, #0
    bge check_greater
    neg x18, x18

check_greater:
    mov x17, x22
    cmp x17, #0
    bge do_compare
    neg x17, x17

do_compare:
    cmp x18, x17
    ble next_window
    mov x22, x20

next_window:
    add x24, x24, #16
    b window_loop

print_max:
    ldr x0, =outfile
    mov x1, #577              // O_WRONLY|O_CREAT|O_TRUNC
    mov x2, #438               // 0666
    bl open_file
    mov x21, x0                // x21 = fd del archivo de salida

    mov x0, x21
    ldr x1, =msg_mod
    mov x2, len_msg_mod
    mov x8, #64
    svc #0

    mov x0, x21
    ldr x1, =msg_calc
    mov x2, len_msg_calc
    mov x8, #64
    svc #0

    mov x0, x21
    ldr x1, =msg_max
    mov x2, len_msg_max
    mov x8, #64
    svc #0

    mov x0, x22
    bl print_int

    mov x0, x21
    ldr x1, =newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, x21
    ldr x1, =msg_status
    mov x2, len_msg_status
    mov x8, #64
    svc #0

    mov x0, x21
    bl close_file

    b exit_ok

error_insuficiente:
    mov x0, #1
    ldr x1, =msg_error_data
    mov x2, len_error_data
    mov x8, #64
    svc #0
    b exit_error

exit_ok:
    mov x0, #0
    mov x8, #93
    svc #0

exit_error:
    mov x0, #1
    mov x8, #93
    svc #0

print_int:
    ldr x1, =num_buffer
    add x1, x1, #31
    mov w2, #0
    strb w2, [x1]
    mov x3, #10
    mov x4, #0
    mov x19, #0
    cmp x0, #0
    bge convert_loop
    mov x19, #1
    neg x0, x0

convert_loop:
    udiv x5, x0, x3
    msub x6, x5, x3, x0
    add x6, x6, '0'
    sub x1, x1, #1
    strb w6, [x1]
    add x4, x4, #1
    mov x0, x5
    cbnz x0, convert_loop

    cmp x19, #1
    bne write_number
    sub x1, x1, #1
    mov w2, '-'
    strb w2, [x1]
    add x4, x4, #1

write_number:
    mov x0, x21
    mov x2, x4
    mov x8, #64
    svc #0
    ret