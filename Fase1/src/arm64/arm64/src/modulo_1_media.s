// modulo_1_media.s

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
outfile:  .asciz "resultado_media.txt"

// Cadenas de salida
str_mod:  .ascii "MODULE=WEIGHTED_MEAN\n"
len_mod = . - str_mod
str_tot:  .ascii "TOTAL_VALUES=30\n"
len_tot = . - str_tot
str_sumx: .ascii "SUM_X="
len_sumx = . - str_sumx
str_wsum: .ascii "WEIGHT_SUM=465\n"
len_wsum = . - str_wsum
str_wmean:.ascii "WEIGHTED_MEAN="
len_wmean = . - str_wmean
nl:       .ascii "\n"

.bss
data_array: .skip 240 // 30 * 8 bytes

.text

_start:
    // Leer argc
    ldr x19, [sp]
    cmp x19, #2
    blt fail_arg
    
    // Leer argv[1]
    ldr x20, [sp, #16] // argv[1] string pointer

    // Convertir argv[1] a entero (columna)
    mov x21, x20
    bl atoi
    mov x24, x10 // x24 = columna (1-indexed)

    // Abrir lecturas.csv
    ldr x0, =filename
    mov x1, #0 // O_RDONLY
    mov x2, #0
    bl open_file
    mov x19, x0 // fd input

    // Leer archivo
    mov x0, x19
    ldr x1, =csv_buffer
    mov x2, #4096
    bl read_file
    mov x20, x0 // bytes leidos

    // Cerrar archivo
    mov x0, x19
    bl close_file

    // Parsear CSV
    ldr x0, =csv_buffer
    mov x1, x20
    mov x2, x24
    ldr x3, =data_array
    bl parse_csv

    // -------------------------------------------------------------
    // LOGICA: Media ponderada
    // -------------------------------------------------------------
    mov x25, #1    // iterador peso = 1
    mov x26, #0    // suma ponderada = 0
    mov x20, #0    // suma simple = 0
    ldr x27, =data_array
    mov x28, #0    // indice de arreglo

calc_loop:
    cmp x25, #31
    b.ge calc_done

    ldr x22, [x27, x28, LSL #3] // x22 = X_i
    mul x23, x22, x25           // x23 = X_i * W_i
    add x26, x26, x23           // suma ponderada += X_i * W_i
    add x20, x20, x22           // suma simple += X_i
    
    add x25, x25, #1
    add x28, x28, #1
    b calc_loop

calc_done:
    // x26 = suma ponderada, x20 = suma simple
    // MEDIA_PONDERADA = suma_ponderada / 465 (con 2 decimales x100)
    mov x25, #100
    mul x26, x26, x25           // suma_ponderada * 100
    mov x22, #465
    udiv x29, x26, x22          // x29 = MEDIA_PONDERADA * 100

    // -------------------------------------------------------------
    // ESCRITURA A ARCHIVO
    // -------------------------------------------------------------
    ldr x0, =outfile
    mov x1, #577  // O_WRONLY | O_CREAT | O_TRUNC
    mov x2, #438  // 0666
    bl open_file
    mov x19, x0   // fd output

    // MODULE=...
    mov x0, x19
    ldr x1, =str_mod
    mov x2, len_mod
    bl write_file

    // TOTAL_VALUES=...
    mov x0, x19
    ldr x1, =str_tot
    mov x2, len_tot
    bl write_file

    // SUM_X=...
    mov x0, x19
    ldr x1, =str_sumx
    mov x2, len_sumx
    bl write_file

    mov x0, x20
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

    // WEIGHT_SUM=...
    mov x0, x19
    ldr x1, =str_wsum
    mov x2, len_wsum
    bl write_file

    // WEIGHTED_MEAN=...
    mov x0, x19
    ldr x1, =str_wmean
    mov x2, len_wmean
    bl write_file

    mov x0, x29 // media con 2 decimales
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

    // Cerrar output
    mov x0, x19
    bl close_file

    bl exit_program

fail_arg:
    mov x0, #1
    bl exit_program
