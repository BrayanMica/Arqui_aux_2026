.include "utils.s"

.global _start

.data


outfile:
    .asciz "resultado_varianza.txt"

str_mod:
    .ascii "MODULE=VARIANCE\n"
    len_mod = . - str_mod

str_tot:
    .ascii "TOTAL_VALUES=\n"
    len_tot = . - str_tot

str_mean:
    .ascii "MEAN="
    len_mean = . - str_mean

str_var:
    .ascii "VARIANCE="
    len_var = . - str_var

str_std:
    .ascii "STD_DEV="
    len_std = . - str_std

nl:
    .ascii "\n"

.text

_start:
    ldr x0, [sp]              
    cmp x0, #5
    blt fail_arg

    ldr x0, [sp, #16]          // archivo_entrada cadena
    ldr x1, [sp, #24]          // linea_inicial cadena
    ldr x2, [sp, #32]          // linea_final cadena
    ldr x3, [sp, #40]          // columna_sensor cadena            


    // Convertir linea_inicial
    mov x21, x1                
    mov x5, #10                
    bl atoi_csv
    mov x13, x10               // linea_inicial entero

    // Convertir linea_final
    mov x21, x2                
    mov x5, #10
    bl atoi_csv
    mov x14, x10               // linea_final entero

    bl historical_analyzer_validate
    mov x11, x0               // la funcion regresa la columna convertida a entero

    // Llamar a la función modificada
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

    mov x10, #100
    udiv x22, x23, x10

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
    ldr x1, =str_var
    mov x2, len_var
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
    bl close_file

    mov x0, #0
    mov x8, #93
    svc #0

fail_arg:
    mov x0, #1
    mov x8, #93
    svc #0
