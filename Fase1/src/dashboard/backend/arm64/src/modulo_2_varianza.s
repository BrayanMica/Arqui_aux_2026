// modulo_2_varianza.s

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
outfile:  .asciz "resultado_varianza.txt"

str_mod:  .ascii "MODULE=VARIANCE\n"
len_mod = . - str_mod
str_tot:  .ascii "TOTAL_VALUES=30\n"
len_tot = . - str_tot
str_mean: .ascii "MEAN="
len_mean = . - str_mean
str_var:  .ascii "VARIANCE="
len_var = . - str_var
str_std:  .ascii "STD_DEV="
len_std = . - str_std
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

    // CALCULO MEDIA (escalado * 100)
    mov x25, #0 // suma
    mov x26, #0 // indice
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
    mul x25, x25, x26 // suma * 100
    mov x26, #30
    udiv x28, x25, x26 // x28 = MEDIA (escalada x100)

    // CALCULO VARIANZA
    mov x25, #0 // suma_diferencias_cuadradas
    mov x26, #0 // indice

var_loop:
    cmp x26, #30
    b.ge var_done
    ldr x22, [x27, x26, LSL #3] // X_i
    mov x23, #100
    mul x22, x22, x23           // X_i * 100
    sub x22, x22, x28           // (X_i * 100) - MEDIA_100
    mul x22, x22, x22           // Diferencia cuadrada (escala 10000)
    add x25, x25, x22
    add x26, x26, #1
    b var_loop

var_done:
    mov x26, #30
    udiv x25, x25, x26 // x25 = VARIANZA (escala 10000)
    
    // STD DEV
    mov x0, x25
    bl integer_sqrt
    mov x29, x0 // x29 = STD_DEV (escala 100)

    // Reducir la escala de VARIANZA a 100 para que itoa_fixed imprima bien
    mov x26, #100
    udiv x25, x25, x26 // x25 = VARIANZA (escala 100)

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

    // MEAN
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

    // VARIANCE
    mov x0, x19
    ldr x1, =str_var
    mov x2, len_var
    bl write_file

    mov x0, x25
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

    // STD_DEV
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
    bl close_file

    bl exit_program

fail_arg:
    mov x0, #1
    bl exit_program
