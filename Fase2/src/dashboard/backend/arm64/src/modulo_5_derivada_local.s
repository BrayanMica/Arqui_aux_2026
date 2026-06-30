.data
    msg_calc:
        .asciz "CALC=LOCAL_DERIVATIVE\n"
    len_msg_calc = . - msg_calc

    msg_column_1:
        .asciz "COLUMN=TEMP\n"
    len_column_1 = . - msg_column_1

    msg_column_2:
        .asciz "COLUMN=HUM_AIRE\n"
    len_column_2 = . - msg_column_2

    msg_column_3:
        .asciz "COLUMN=HUM_SUELO_1\n"
    len_column_3 = . - msg_column_3

    msg_column_5:
        .asciz "COLUMN=LUZ\n"
    len_column_5 = . - msg_column_5

    msg_column_6:
        .asciz "COLUMN=GAS\n"
    len_column_6 = . - msg_column_6

    msg_window_start:
        .asciz "WINDOW_START="
    len_msg_window_start = . - msg_window_start

    msg_window_end:
        .asciz "WINDOW_END="
    len_msg_window_end = . - msg_window_end

    msg_count:
        .asciz "COUNT="
    len_msg_count = . - msg_count

    msg_window_size:
        .asciz "WINDOW_SIZE=5\n"
    len_msg_window_size = . - msg_window_size

    msg_max:
        .asciz "MAX_LOCAL_SLOPE_X100="
    len_msg_max = . - msg_max

    msg_status:
        .asciz "STATUS=OK\n"
    len_msg_status = . - msg_status

    msg_error_data:
        .asciz "STATUS=ERROR;ERROR=INSUFFICIENT_DATA;DETAIL=LOCAL_DERIVATIVE_REQUIRES_AT_LEAST_5_VALUES\n"
    len_error_data = . - msg_error_data

    msg_error_column:
        .asciz "STATUS=ERROR;ERROR=INVALID_COLUMN\n"
    len_error_column = . - msg_error_column

    newline:
        .asciz "\n"

.include "utils.s"

.text
.global _start

_start:
    ldr x0, [sp]
    cmp x0, #5
    blt error_insuficiente

    ldr x0, [sp,#24]
    bl cadena_a_entero
    mov x13, x0

    ldr x0, [sp,#32]
    bl cadena_a_entero
    mov x14, x0

    ldr x0, [sp,#40]
    bl cadena_a_entero
    mov x16, x0
    mov x17, x16

    cmp x16,#1
    blt error_columna

    cmp x16,#6
    bgt error_columna

    cmp x16,#4
    beq error_columna

    mov x11,x16
    bl read_column_to_stack

    mov x24, x0
    mov x25, x1
    mov x26, x2

    mov x21, x13
    mov x23, x14

    cmp x26,#5
    blt error_datos

    mov x22,#0
    mov x20,x25
    sub x20,x20,#64

window_loop:
    cmp x24, x20
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

    mov x27, #0
    mov x9, #1
    mul x28, x11, x9
    add x27, x27, x28
    mov x9, #2
    mul x28, x12, x9
    add x27, x27, x28
    mov x9, #3
    mul x28, x13, x9
    add x27, x27, x28
    mov x9, #4
    mul x28, x14, x9
    add x27, x27, x28
    mov x9, #5
    mul x27, x27, x9
    mov x9, #10
    mul x28, x15, x9
    sub x19, x27, x28
    mov x9, #100
    mul x19, x19, x9

    mov x27, #0
    cmp x19, #0
    bge division
    mov x27, #1
    mov x9, #0
    sub x19, x9, x19

division:
    mov x9, #50
    udiv x19, x19, x9
    cmp x27, #1
    bne absolute_new
    mov x9, #0
    sub x19, x9, x19

absolute_new:
    mov x27, x19
    cmp x27, #0
    bge absolute_old
    mov x9, #0
    sub x27, x9, x27

absolute_old:
    mov x28, x22
    cmp x28, #0
    bge compare_values
    mov x9, #0
    sub x28, x9, x28

compare_values:
    cmp x27, x28
    ble next_window
    mov x22, x19

next_window:
    add x24, x24, #16
    b window_loop

print_max:
    mov x0,#1
    ldr x1,=msg_calc
    mov x2,len_msg_calc
    mov x8,#64
    svc #0

    cmp x17,#1
    beq print_temp
    cmp x17,#2
    beq print_hum
    cmp x17,#3
    beq print_suelo
    cmp x17,#5
    beq print_luz
    b print_gas

print_temp:
    ldr x1,=msg_column_1
    mov x2,len_column_1
    b print_column
print_hum:
    ldr x1,=msg_column_2
    mov x2,len_column_2
    b print_column
print_suelo:
    ldr x1,=msg_column_3
    mov x2,len_column_3
    b print_column
print_luz:
    ldr x1,=msg_column_5
    mov x2,len_column_5
    b print_column
print_gas:
    ldr x1,=msg_column_6
    mov x2,len_column_6

print_column:
    mov x0,#1
    mov x8,#64
    svc #0
    mov x0, #1
    ldr x1, =msg_window_start
    mov x2, len_msg_window_start
    mov x8, #64
    svc #0
    mov x0, x21
    bl print_int
    mov x0, #1
    ldr x1, =newline
    mov x2, #1
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_window_end
    mov x2, len_msg_window_end
    mov x8, #64
    svc #0
    mov x0, x23
    bl print_int
    mov x0, #1
    ldr x1, =newline
    mov x2, #1
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_count
    mov x2, len_msg_count
    mov x8, #64
    svc #0
    mov x0, x26
    bl print_int
    mov x0, #1
    ldr x1, =newline
    mov x2, #1
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_window_size
    mov x2, len_msg_window_size
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_max
    mov x2, len_msg_max
    mov x8, #64
    svc #0
    mov x0, x22
    bl print_int
    mov x0, #1
    ldr x1, =newline
    mov x2, #1
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_status
    mov x2, len_msg_status
    mov x8, #64
    svc #0
    b exit_ok

error_insuficiente:
    mov x0, #1
    ldr x1, =msg_error_data
    mov x2, len_error_data
    mov x8, #64
    svc #0
    b exit_error

error_datos:
    mov x0,#1
    ldr x1,=msg_error_data
    mov x2,len_error_data
    mov x8,#64
    svc #0
    b exit_error

error_columna:
    mov x0,#1
    ldr x1,=msg_error_column
    mov x2,len_error_column
    mov x8,#64
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
    mov x28, #0

    cmp x0, #0
    bge convert_loop

    mov x28, #1

    mov x9, #0
    sub x0, x9, x0

convert_loop:
    udiv x5, x0, x3
    msub x6, x5, x3, x0

    add x6, x6, #'0'

    sub x1, x1, #1
    strb w6, [x1]

    add x4, x4, #1

    mov x0, x5

    cbnz x0, convert_loop

    cmp x28, #1
    bne write_number

    sub x1, x1, #1

    mov w2, #'-'
    strb w2, [x1]

    add x4, x4, #1

write_number:
    mov x0, #1
    mov x2, x4
    mov x8, #64
    svc #0

    ret