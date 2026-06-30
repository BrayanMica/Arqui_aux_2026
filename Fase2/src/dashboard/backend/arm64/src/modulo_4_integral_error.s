.include "utils.s"

.global _start

.data

outfile:
    .asciz "resultado_integral.txt"

str_calc:
    .ascii "MODULE=ERROR_INTEGRAL\n"
    len_calc = . - str_calc

str_col:
    .ascii "COLUMN="
    len_col = . - str_col

str_start:
    .ascii "WINDOW_START="
    len_start = . - str_start

str_end:
    .ascii "WINDOW_END="
    len_end = . - str_end

str_count:
    .ascii "COUNT="
    len_count = . - str_count

str_ideal:
    .ascii "IDEAL="
    len_ideal = . - str_ideal

str_result:
    .ascii "ERROR_INTEGRAL="
    len_result = . - str_result

str_status:
    .ascii "STATUS=OK\n"
    len_status = . - str_status

nl:
    .ascii "\n"

.text

_start:

    ldr x10, [sp]
    cmp x10, #4
    blt fail_arg

    ldr x21, [sp, #16]
    mov x5, #10
    bl atoi_csv
    cbz x7, fail_arg
    mov x11, x10
    mov x26, x10

    ldr x21, [sp, #24]
    mov x5, #10
    bl atoi_csv
    cbz x7, fail_arg
    mov x13, x10

    ldr x21, [sp, #32]
    mov x5, #10
    bl atoi_csv
    cbz x7, fail_arg
    mov x14, x10

    bl read_column_to_stack
    mov x24, x0
    mov x25, x1
    mov x28, x2

    cmp x28, #2
    blt fail_arg

    mov x15, #55             // IDEAL (se fija despues de read_column_to_stack, que pisa x15)

    sub x24, x25, #16
    mov x22, #0
    mov x23, #0
    sub x19, x28, #1

calc_loop:
    cmp x23, x19
    bge calc_done

    ldr x10, [x24]
    sub x10, x10, x15
    cmp x10, #0
    bge err_current_ready
    mov x12, #0
    sub x10, x12, x10

err_current_ready:
    sub x24, x24, #16
    ldr x11, [x24]
    sub x11, x11, x15
    cmp x11, #0
    bge err_next_ready
    mov x12, #0
    sub x11, x12, x11

err_next_ready:
    add x12, x10, x11
    mov x9, #2
    udiv x12, x12, x9
    add x22, x22, x12

    add x23, x23, #1
    b calc_loop

calc_done:

    ldr x0, =outfile
    mov x1, #577
    mov x2, #438
    bl open_file
    mov x19, x0

    mov x0, x19
    ldr x1, =str_calc
    mov x2, len_calc
    bl write_file

    mov x0, x19
    ldr x1, =str_col
    mov x2, len_col
    bl write_file

    mov x0, x26
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
    ldr x1, =str_start
    mov x2, len_start
    bl write_file

    mov x0, x13
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
    ldr x1, =str_end
    mov x2, len_end
    bl write_file

    mov x0, x14
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
    ldr x1, =str_count
    mov x2, len_count
    bl write_file

    mov x0, x28
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
    ldr x1, =str_ideal
    mov x2, len_ideal
    bl write_file

    mov x0, x15
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
    ldr x1, =str_result
    mov x2, len_result
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
    ldr x1, =str_status
    mov x2, len_status
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