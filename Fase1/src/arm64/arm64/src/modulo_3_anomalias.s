// modulo_3_anomalias.s

.extern open_file
.extern read_file
.extern write_file
.extern close_file
.extern exit_program
.extern parse_csv
.extern atoi
.extern itoa
.extern itoa_fixed
.extern integer_sqrt
.extern csv_buffer
.extern str_buffer

.global _start

.data
filename: .asciz "lecturas.csv"
outfile:  .asciz "resultado_anomalias.txt"

str_mod:  .ascii "MODULE=ANOMALY_DETECTION\n"
len_mod = . - str_mod
str_tot:  .ascii "TOTAL_VALUES=30\n"
len_tot = . - str_tot
str_mean: .ascii "MEAN="
len_mean = . - str_mean
str_std:  .ascii "STD_DEV="
len_std = . - str_std
str_anom: .ascii "ANOMALIES="
len_anom = . - str_anom
str_risk: .ascii "SYSTEM_RISK="
len_risk = . - str_risk

val_norm: .ascii "NORMAL\n"
len_norm = . - val_norm
val_med:  .ascii "MEDIUM\n"
len_med  = . - val_med
val_high: .ascii "HIGH\n"
len_high = . - val_high

nl:       .ascii "\n"

.bss
data_array: .skip 240 // 30 * 8 bytes

.text

_start:
    ldr x19, [sp]
    cmp x19, #2
    blt fail_arg
    
    ldr x20, [sp, #16]
    mov x21, x20
    bl atoi
    mov x24, x10

    ldr x0, =filename
    mov x1, #0
    mov x2, #0
    bl open_file
    mov x19, x0

    mov x0, x19
    ldr x1, =csv_buffer
    mov x2, #4096
    bl read_file
    mov x20, x0

    mov x0, x19
    bl close_file

    ldr x0, =csv_buffer
    mov x1, x20
    mov x2, x24
    ldr x3, =data_array
    bl parse_csv

    // CALCULO MEDIA
    mov x25, #0
    mov x26, #0
    ldr x27, =data_array

sum_loop:
    cmp x26, #30
    b.ge sum_done
    ldr x22, [x27, x26, LSL #3]
    add x25, x25, x22
    add x26, x26, #1
    b sum_loop

sum_done:
    mov x26, #100
    mul x25, x25, x26
    mov x26, #30
    udiv x28, x25, x26 // x28 = MEDIA_100

    // CALCULO VARIANZA y STD_DEV
    mov x25, #0
    mov x26, #0

var_loop:
    cmp x26, #30
    b.ge var_done
    ldr x22, [x27, x26, LSL #3]
    mov x23, #100
    mul x22, x22, x23
    sub x22, x22, x28
    mul x22, x22, x22
    add x25, x25, x22
    add x26, x26, #1
    b var_loop

var_done:
    mov x26, #30
    udiv x25, x25, x26 // VARIANZA_10000
    
    mov x0, x25
    bl integer_sqrt
    mov x29, x0 // x29 = STD_DEV_100

    // -------------------------------------------------------------
    // ANOMALIAS
    // -------------------------------------------------------------
    // Si STD_DEV == 0 todos los datos son iguales: no hay anomalias
    cmp x29, #0
    b.eq anom_done_std_zero

    mov x25, #0 // Contador de anomalias
    mov x26, #0 // Indice
    mov x23, #2
    mul x30, x29, x23 // x30 = 2 * STD_DEV_100

anom_loop:
    cmp x26, #30
    b.ge anom_done

    ldr x22, [x27, x26, LSL #3]
    mov x23, #100
    mul x22, x22, x23 // X_i * 100

    sub x22, x22, x28 // X_i_100 - MEDIA_100
    
    // Valor absoluto
    cmp x22, #0
    b.ge anom_abs_done
    sub x22, xzr, x22  // valor absoluto (0 - x)
anom_abs_done:

    // Comparar distancia con 2 * STD_DEV_100
    cmp x22, x30
    blt not_anom
    add x25, x25, #1 // Es anomalia

not_anom:
    add x26, x26, #1
    b anom_loop

anom_done_std_zero:
    mov x25, #0  // STD_DEV=0 => sin anomalias

anom_done:
    // x25 = ANOMALIES

    // ESCRITURA A ARCHIVO
    ldr x0, =outfile
    mov x1, #577  // O_WRONLY | O_CREAT | O_TRUNC
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
    ldr x1, =str_buffer
    bl itoa_fixed
    mov x2, x2
    mov x0, x19
    ldr x1, =str_buffer
    bl write_file

    mov x0, x19
    ldr x1, =nl
    mov x2, #1
    bl write_file

    mov x0, x19
    ldr x1, =str_std
    mov x2, len_std
    bl write_file

    mov x0, x29
    ldr x1, =str_buffer
    bl itoa_fixed
    mov x2, x2
    mov x0, x19
    ldr x1, =str_buffer
    bl write_file

    mov x0, x19
    ldr x1, =nl
    mov x2, #1
    bl write_file

    mov x0, x19
    ldr x1, =str_anom
    mov x2, len_anom
    bl write_file

    mov x0, x25
    ldr x1, =str_buffer
    bl itoa
    mov x2, x2
    mov x0, x19
    ldr x1, =str_buffer
    bl write_file

    mov x0, x19
    ldr x1, =nl
    mov x2, #1
    bl write_file

    // SYSTEM_RISK
    mov x0, x19
    ldr x1, =str_risk
    mov x2, len_risk
    bl write_file

    cmp x25, #0
    beq risk_normal
    cmp x25, #3
    b.le risk_medium
    b risk_high

risk_normal:
    mov x0, x19
    ldr x1, =val_norm
    mov x2, len_norm
    bl write_file
    b end_risk

risk_medium:
    mov x0, x19
    ldr x1, =val_med
    mov x2, len_med
    bl write_file
    b end_risk

risk_high:
    mov x0, x19
    ldr x1, =val_high
    mov x2, len_high
    bl write_file

end_risk:
    mov x0, x19
    bl close_file

    bl exit_program

fail_arg:
    mov x0, #1
    bl exit_program
