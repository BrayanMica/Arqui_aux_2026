.include "utils.s"

.global _start

.data

outfile:
    .asciz "resultado_tendencia.txt"

str_mod:
    .ascii "MODULE=ADVANCED_TREND\n"
    len_mod = . - str_mod

str_tot:
    .ascii "TOTAL_VALUES=30\n"
    len_tot = . - str_tot

str_inc:
    .ascii "INCREMENTS="
    len_inc = . - str_inc

str_dec:
    .ascii "DECREMENTS="
    len_dec = . - str_dec

str_maxup:
    .ascii "MAX_UP_STREAK="
    len_maxup = . - str_maxup

str_maxdn:
    .ascii "MAX_DOWN_STREAK="
    len_maxdn = . - str_maxdn

str_accum:
    .ascii "ACCUM_DIFF="
    len_accum = . - str_accum

str_trend:
    .ascii "TREND="
    len_trend = . - str_trend

val_up:
    .ascii "UP\n"
    len_up = . - val_up

val_down:
    .ascii "DOWN\n"
    len_down = . - val_down

val_stable:
    .ascii "STABLE\n"
    len_stable = . - val_stable

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

    mov x24, x25
    sub x24, x24, #16

    ldr x22, [x24]
    sub x24, x24, #16
    mov x28, #1

    mov x26, #0
    mov x27, #0
    mov x11, #0
    mov x12, #0
    mov x25, #0
    mov x3,  #0

trend_loop:
    cmp x28, #29
    bgt trend_done

    ldr x23, [x24]
    sub x24, x24, #16
    add x28, x28, #1

    sub x10, x23, x22
    add x11, x11, x10
    mov x22, x23

    cmp x10, #0
    bgt trend_up
    blt trend_down

    mov x12, #0
    b trend_next

trend_up:
    add x26, x26, #1

    cmp x12, #0
    blt trend_up_reset

    add x12, x12, #1
    b trend_up_check
trend_up_reset:
    mov x12, #1
trend_up_check:
    cmp x12, x25
    ble trend_next
    mov x25, x12
    b trend_next

trend_down:
    add x27, x27, #1

    cmp x12, #0
    bgt trend_down_reset

    sub x12, x12, #1
    b trend_down_check
trend_down_reset:
    mov x12, #0
    sub x12, x12, #1
trend_down_check:

    mov x10, #0
    sub x10, x10, x12
    cmp x10, x3
    ble trend_next
    mov x3, x10

trend_next:
    b trend_loop

trend_done:

    mov x28, x3

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
    ldr x1, =str_inc
    mov x2, len_inc
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
    ldr x1, =str_dec
    mov x2, len_dec
    bl write_file

    mov x0, x27
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
    ldr x1, =str_maxup
    mov x2, len_maxup
    bl write_file

    mov x0, x25
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
    ldr x1, =str_maxdn
    mov x2, len_maxdn
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
    ldr x1, =str_accum
    mov x2, len_accum
    bl write_file

    mov x0, x11
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
    ldr x1, =str_trend
    mov x2, len_trend
    bl write_file

    cmp x11, #0
    beq print_stable
    bgt print_up

print_down:
    mov x0, x19
    ldr x1, =val_down
    mov x2, len_down
    bl write_file
    b close_out

print_up:
    mov x0, x19
    ldr x1, =val_up
    mov x2, len_up
    bl write_file
    b close_out

print_stable:
    mov x0, x19
    ldr x1, =val_stable
    mov x2, len_stable
    bl write_file

close_out:
    mov x0, x19
    bl close_file

    mov x0, #0
    mov x8, #93
    svc #0

fail_arg:
    mov x0, #1
    mov x8, #93
    svc #0
