.include "utils.s"

.global _start

.data

outfile:
    .asciz "resultado_anomalias.txt"

str_mod:
    .ascii "MODULE=ANOMALY_DETECTION\n"
    len_mod = . - str_mod

str_tot:
    .ascii "TOTAL_VALUES=30\n"
    len_tot = . - str_tot

str_mean:
    .ascii "MEAN="
    len_mean = . - str_mean

str_std:
    .ascii "STD_DEV="
    len_std = . - str_std

str_anom:
    .ascii "ANOMALIES="
    len_anom = . - str_anom

str_risk:
    .ascii "SYSTEM_RISK="
    len_risk = . - str_risk

val_normal:
    .ascii "NORMAL\n"
    len_normal = . - val_normal

val_medium:
    .ascii "MEDIUM\n"
    len_medium = . - val_medium

val_high:
    .ascii "HIGH\n"
    len_high = . - val_high

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
    mov x26, x2

    sub x24, x25, #16
    mov x22, #0
    mov x27, #0

sum_loop:
    cmp x27, #29
    bgt sum_done
    ldr x10, [x24]
    add x22, x22, x10
    add x27, x27, #1
    sub x24, x24, #16
    b sum_loop

sum_done:
    mov x10, #100
    mul x28, x22, x10
    mov x10, #30
    udiv x28, x28, x10

    sub x24, x25, #16
    mov x22, #0
    mov x27, #0

var_loop:
    cmp x27, #29
    bgt var_done
    ldr x10, [x24]

    mov x11, #100
    mul x10, x10, x11
    sub x10, x10, x28
    mul x10, x10, x10
    add x22, x22, x10

    add x27, x27, #1
    sub x24, x24, #16
    b var_loop

var_done:
    mov x10, #30
    udiv x23, x22, x10

    mov x0, x23
    bl integer_sqrt
    mov x26, x0

    cmp x26, #0
    beq no_anomalies

    sub x24, x25, #16
    mov x22, #0
    mov x27, #0

    mov x12, #2
    mul x23, x26, x12

anom_loop:
    cmp x27, #29
    bgt anom_done
    ldr x10, [x24]

    mov x11, #100
    mul x10, x10, x11
    sub x10, x10, x28

    cmp x10, #0
    bgt anom_abs_done
    mov x11, #0
    sub x10, x11, x10
anom_abs_done:

    cmp x10, x23
    blt not_anom
    add x22, x22, #1

not_anom:
    add x27, x27, #1
    sub x24, x24, #16
    b anom_loop

no_anomalies:
    mov x22, #0

anom_done:

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
    ldr x1, =str_mean
    mov x2, len_mean
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
    ldr x1, =str_std
    mov x2, len_std
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
    ldr x1, =str_anom
    mov x2, len_anom
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
    ldr x1, =str_risk
    mov x2, len_risk
    bl write_file

    cmp x22, #0
    beq risk_normal
    cmp x22, #3
    ble risk_medium
    b risk_high

risk_normal:
    mov x0, x19
    ldr x1, =val_normal
    mov x2, len_normal
    bl write_file
    b close_out

risk_medium:
    mov x0, x19
    ldr x1, =val_medium
    mov x2, len_medium
    bl write_file
    b close_out

risk_high:
    mov x0, x19
    ldr x1, =val_high
    mov x2, len_high
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
