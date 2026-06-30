// modulo_4_prediccion.s

.extern open_file
.extern read_file
.extern write_file
.extern close_file
.extern exit_program
.extern parse_csv
.extern atoi
.extern itoa
.extern itoa_fixed
.extern csv_buffer
.extern str_buffer

.global _start

.data
filename: .asciz "lecturas.csv"
outfile:  .asciz "resultado_prediccion.txt"

str_mod:  .ascii "MODULE=PREDICTION\n"
len_mod = . - str_mod
str_init: .ascii "INITIAL_VALUE="
len_init = . - str_init
str_final:.ascii "FINAL_VALUE="
len_final= . - str_final
str_diff: .ascii "TOTAL_DIFF="
len_diff = . - str_diff
str_avg:  .ascii "AVG_CHANGE="
len_avg  = . - str_avg
str_next: .ascii "NEXT_VALUE="
len_next = . - str_next

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

    // -------------------------------------------------------------
    // PREDICCION
    // -------------------------------------------------------------
    ldr x27, =data_array
    ldr x25, [x27]               // X_0 (INITIAL)
    mov x28, #29
    ldr x26, [x27, x28, LSL #3]  // X_29 (FINAL)

    // INITIAL Y FINAL ESCALADOS
    mov x22, #100
    mul x25, x25, x22 // INITIAL_100
    mul x26, x26, x22 // FINAL_100

    sub x29, x26, x25 // TOTAL_DIFF_100 (puede ser negativo)

    mov x22, #29
    // AVG_CHANGE = DIF / 29. Como DIF puede ser negativo y sdiv
    // no esta en lessons/projects, separamos signo y usamos udiv
    cmp x29, #0
    b.ge dif_no_neg
    sub x23, xzr, x29     // valor absoluto de TOTAL_DIFF
    udiv x23, x23, x22    // division entera positiva
    sub x23, xzr, x23     // restaurar signo negativo
    b calc_next
dif_no_neg:
    udiv x23, x29, x22    // AVG_CHANGE_100

calc_next:
    add x22, x26, x23 // NEXT_VALUE_100

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
    ldr x1, =str_init
    mov x2, len_init
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

    mov x0, x19
    ldr x1, =str_final
    mov x2, len_final
    bl write_file

    mov x0, x26
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
    ldr x1, =str_diff
    mov x2, len_diff
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
    ldr x1, =str_avg
    mov x2, len_avg
    bl write_file

    mov x0, x23
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
    ldr x1, =str_next
    mov x2, len_next
    bl write_file

    mov x0, x22
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
