.section .data

outfile:
    .asciz "resultado_rmse.txt"

msg_calc:
    .ascii "CALC=RMSE\n"
len_calc = . - msg_calc

msg_column:
    .ascii "COLUMN="
len_column = . - msg_column

msg_start:
    .ascii "WINDOW_START="
len_start = . - msg_start

msg_end:
    .ascii "WINDOW_END="
len_end = . - msg_end

msg_count:
    .ascii "COUNT="
len_count = . - msg_count

msg_ideal:
    .ascii "IDEAL="
len_ideal = . - msg_ideal

msg_rmse:
    .ascii "RMSE="
len_rmse = . - msg_rmse

msg_status_ok:
    .ascii "STATUS=OK\n"
len_status_ok = . - msg_status_ok

msg_error_missing:
    .ascii "STATUS=ERROR\nERROR=MISSING_ARGUMENTS\nDETAIL=EXPECTED_START_END_COLUMN_IDEAL\n"
len_error_missing = . - msg_error_missing

msg_error_range:
    .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=INVALID_WINDOW_RANGE\n"
len_error_range = . - msg_error_range

msg_error_column:
    .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_MUST_BE_2_TEMP_3_HUM_AIRE_4_SOIL1_6_LUZ_OR_7_GAS\n"
len_error_column = . - msg_error_column

msg_error_data:
    .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=RMSE_REQUIRES_AT_LEAST_2_VALUES\n"
len_error_data = . - msg_error_data

newline:
    .ascii "\n"
len_newline = . - newline


.section .bss

buffer_num:
    .skip 32

save_window_start:
    .skip 8

save_window_end:
    .skip 8

save_column:
    .skip 8

save_ideal:
    .skip 8

save_count:
    .skip 8

save_rmse:
    .skip 8

save_expected_count:
    .skip 8


.section .text

.include "utils.s"

.global _start

_start:
    ldr x9, [sp]

    cmp x9, #5
    blt imprimir_error_missing

    ldr x0, [sp, #16]
    bl cadena_a_entero
    mov x19, x0

    ldr x0, [sp, #24]
    bl cadena_a_entero
    mov x21, x0

    ldr x0, [sp, #32]
    bl cadena_a_entero
    mov x15, x0

    ldr x0, [sp, #40]
    bl cadena_a_entero
    mov x20, x0

    cmp x15, #2
    blt imprimir_error_column

    cmp x15, #7
    bgt imprimir_error_column

    cmp x15, #5
    beq imprimir_error_column

    cmp x19, #1
    blt imprimir_error_range

    cmp x21, x19
    blt imprimir_error_range

    sub x18, x21, x19
    add x18, x18, #1

    ldr x12, =save_expected_count
    str x18, [x12]

    ldr x12, =save_window_start
    str x19, [x12]

    ldr x12, =save_window_end
    str x21, [x12]

    ldr x12, =save_column
    str x15, [x12]

   
    ldr x12, =save_ideal
    str x20, [x12]

    mov x13, x19
    mov x14, x21
    mov x11, x15

    bl read_column_to_stack

    mov x24, x0
    mov x26, x2

    ldr x12, =save_ideal
    ldr x20, [x12]

    ldr x12, =save_expected_count
    ldr x18, [x12]

    cmp x26, x18
    bne imprimir_error_range

    ldr x12, =save_count
    str x26, [x12]
    

    cmp x26, #2
    blt imprimir_error_data

    mov x22, #0
    mov x27, #0

loop_rmse:
    cmp x27, x26
    beq calcular_mse

    ldr x10, [x24]
    add x24, x24, #16

    sub x23, x10, x20
    mul x23, x23, x23
    add x22, x22, x23

    add x27, x27, #1
    b loop_rmse

calcular_mse:
    udiv x28, x22, x26

    mov x0, x28
    bl integer_sqrt
    mov x28, x0

    ldr x12, =save_rmse
    str x28, [x12]

    bl imprimir_ok
    bl escribir_archivo_ok

    mov x0, #0
    mov x8, #93
    svc #0


imprimir_ok:
    stp x29, x30, [sp, #-16]!

    ldr x1, =msg_calc
    mov x2, len_calc
    bl write_text

    ldr x1, =msg_column
    mov x2, len_column
    bl write_text

    ldr x12, =save_column
    ldr x0, [x12]
    ldr x1, =buffer_num
    bl uint_to_ascii
    bl write_text

    ldr x1, =newline
    mov x2, len_newline
    bl write_text

    ldr x1, =msg_start
    mov x2, len_start
    bl write_text

    ldr x12, =save_window_start
    ldr x0, [x12]
    ldr x1, =buffer_num
    bl uint_to_ascii
    bl write_text

    ldr x1, =newline
    mov x2, len_newline
    bl write_text

    ldr x1, =msg_end
    mov x2, len_end
    bl write_text

    ldr x12, =save_window_end
    ldr x0, [x12]
    ldr x1, =buffer_num
    bl uint_to_ascii
    bl write_text

    ldr x1, =newline
    mov x2, len_newline
    bl write_text

    ldr x1, =msg_count
    mov x2, len_count
    bl write_text

    ldr x12, =save_count
    ldr x0, [x12]
    ldr x1, =buffer_num
    bl uint_to_ascii
    bl write_text

    ldr x1, =newline
    mov x2, len_newline
    bl write_text

    ldr x1, =msg_ideal
    mov x2, len_ideal
    bl write_text

    ldr x12, =save_ideal
    ldr x0, [x12]
    ldr x1, =buffer_num
    bl uint_to_ascii
    bl write_text

    ldr x1, =newline
    mov x2, len_newline
    bl write_text

    ldr x1, =msg_rmse
    mov x2, len_rmse
    bl write_text

    ldr x12, =save_rmse
    ldr x0, [x12]
    ldr x1, =buffer_num
    bl uint_to_ascii
    bl write_text

    ldr x1, =newline
    mov x2, len_newline
    bl write_text

    ldr x1, =msg_status_ok
    mov x2, len_status_ok
    bl write_text

    ldp x29, x30, [sp], #16
    ret


escribir_archivo_ok:
    stp x29, x30, [sp, #-16]!

    ldr x0, =outfile
    mov x1, #577
    mov x2, #438
    bl open_file
    mov x19, x0

    mov x0, x19
    ldr x1, =msg_calc
    mov x2, len_calc
    bl write_file

    mov x0, x19
    ldr x1, =msg_column
    mov x2, len_column
    bl write_file

    ldr x12, =save_column
    ldr x0, [x12]
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =newline
    mov x2, len_newline
    bl write_file

    mov x0, x19
    ldr x1, =msg_start
    mov x2, len_start
    bl write_file

    ldr x12, =save_window_start
    ldr x0, [x12]
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =newline
    mov x2, len_newline
    bl write_file

    mov x0, x19
    ldr x1, =msg_end
    mov x2, len_end
    bl write_file

    ldr x12, =save_window_end
    ldr x0, [x12]
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =newline
    mov x2, len_newline
    bl write_file

    mov x0, x19
    ldr x1, =msg_count
    mov x2, len_count
    bl write_file

    ldr x12, =save_count
    ldr x0, [x12]
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =newline
    mov x2, len_newline
    bl write_file

    mov x0, x19
    ldr x1, =msg_ideal
    mov x2, len_ideal
    bl write_file

    ldr x12, =save_ideal
    ldr x0, [x12]
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =newline
    mov x2, len_newline
    bl write_file

    mov x0, x19
    ldr x1, =msg_rmse
    mov x2, len_rmse
    bl write_file

    ldr x12, =save_rmse
    ldr x0, [x12]
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =newline
    mov x2, len_newline
    bl write_file

    mov x0, x19
    ldr x1, =msg_status_ok
    mov x2, len_status_ok
    bl write_file

    mov x0, x19
    bl close_file

    ldp x29, x30, [sp], #16
    ret


imprimir_error_missing:
    ldr x1, =msg_error_missing
    mov x2, len_error_missing
    bl write_text

    mov x0, #1
    mov x8, #93
    svc #0


imprimir_error_range:
    ldr x1, =msg_error_range
    mov x2, len_error_range
    bl write_text

    mov x0, #1
    mov x8, #93
    svc #0


imprimir_error_column:
    ldr x1, =msg_error_column
    mov x2, len_error_column
    bl write_text

    mov x0, #1
    mov x8, #93
    svc #0


imprimir_error_data:
    ldr x1, =msg_error_data
    mov x2, len_error_data
    bl write_text

    mov x0, #1
    mov x8, #93
    svc #0


write_text:
    mov x0, #1
    mov x8, #64
    svc #0
    ret


uint_to_ascii:
    add x3, x1, #31

    mov x4, #0
    strb w4, [x3]

    mov x5, #10
    mov x2, #0

    cmp x0, #0
    bne convert_loop

    sub x3, x3, #1
    mov x4, #'0'
    strb w4, [x3]
    mov x2, #1
    mov x1, x3
    ret

convert_loop:
    cmp x0, #0
    beq convert_done

    udiv x6, x0, x5
    mul x7, x6, x5
    sub x4, x0, x7
    add x4, x4, #'0'

    sub x3, x3, #1
    strb w4, [x3]

    mov x0, x6
    add x2, x2, #1

    b convert_loop

convert_done:
    mov x1, x3
    ret

