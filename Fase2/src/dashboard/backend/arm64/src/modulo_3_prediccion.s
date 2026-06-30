//modulo de nueva subrutina de la fase 2
//modulo_3_prediccion

.include "utils.s"

.global _start

.data

outfile:
    .asciz "resultado_prediccion.txt"

str_calc:
    .ascii "CALC=PREDICTION\n"
    len_calc = . - str_calc

str_col:
    .ascii "COLUMN="
    len_col = . - str_col

str_wstart:
    .ascii "WINDOW_START="
    len_wstart = . - str_wstart

str_wend:
    .ascii "WINDOW_END="
    len_wend = . - str_wend

str_count:
    .ascii "COUNT="
    len_count = . - str_count

str_k:
    .ascii "K="
    len_k = . - str_k

str_slope:
    .ascii "SLOPE_X100="
    len_slope = . - str_slope

str_intercept:
    .ascii "INTERCEPT_X100="
    len_intercept = . - str_intercept

str_pred:
    .ascii "PREDICTED_"
    len_pred = . - str_pred

str_eq:
    .ascii "="
    len_eq = . - str_eq

str_status:
    .ascii "STATUS=OK\n"
    len_status = . - str_status

nl:
    .ascii "\n"

salvar_mx100: .quad 0      // almacena M_X100 entre llamadas
salvar_k:     .quad 0      // almacena K entre llamadas    


.text
_start:
    ldr x0, [sp]
    cmp x0, #6
    blt fail_arg

    ldr x20, [sp, #16]      
    ldr x1,  [sp, #24]      // linea_inicial
    ldr x2,  [sp, #32]      // linea_final
    ldr x3,  [sp, #40]      // columna_sensor 

    // convertir linea_inicial 
    mov x21, x1             // cadena linea_inicial 
    mov x5, #10
    bl atoi_csv
    mov x13, x10            // linea_inicial entero
    ldr x1, [sp, #24]       // restaurar puntero cadena linea_inicial

    // convertir linea_final
    ldr x2, [sp, #32]
    mov x21, x2
    mov x5, #10
    bl atoi_csv
    mov x14, x10            // linea_final
    ldr x2, [sp, #32]       // restaurar puntero cadena linea_final

    // guarda puntero al nombre de columna para la salida
    ldr x3, [sp, #40]
    mov x17, x3             // puntero a cadena de columna

    // se lee M_X100 
    ldr x0, [sp, #48]       // M_X100
    bl atoi_signed          // soporta signo negativo
    mov x28, x0             // M_X100

    //  se lee k 
    ldr x0, [sp]
    cmp x0, #7
    blt usar_k_por_defecto

    ldr x0, [sp, #56]
    mov x21, x0
    mov x5, #10
    bl atoi_csv
    cmp x10, #0
    beq usar_k_por_defecto
    mov x16, x10            // k del usuario
    b k_listo

usar_k_por_defecto:
    mov x16, #5             // 5 por defecto  

k_listo:
    // Preservar M_X100 y K en variables .data antes de las llamadas porque las demás funciones usan registros
    // que corrompen
    ldr x0, =salvar_mx100
    str x28, [x0]           /// salva M_X100
    ldr x0, =salvar_k
    str x16, [x0]           // salva K

    // Pasar argumentos 
    mov x0, x20             
    ldr x1, [sp, #24]       
    ldr x2, [sp, #32]       
    ldr x3, [sp, #40]       
    bl historical_analyzer_validate
    mov x11, x0             // indice de columna

    // Leer columna al stack
    bl read_column_to_stack

    // se salvan los retornos de read_column_to_stack antes de restaurar M_X100/K
    mov x18, x0             // sp actual  tope de datos
    mov x19, x1             // sp original
    mov x22, x2             // cantidad de datos leidos

    // Restaurar M_X100 y K desde variables .data
    ldr x0, =salvar_mx100
    ldr x28, [x0]           // restaurar M_X100
    ldr x0, =salvar_k
    ldr x16, [x0]           // restaurar K    

// Calcula suma_y 
    mov x23, #0             
    mov x26, #0             // i contador
    sub x20, x19, #16       // puntero al primer dato

sum_loop:
    cmp x26, x22
    beq sum_done

    ldr x10, [x20]          // y_i
    add x23, x23, x10       // suma_y += Y_i

    sub x20, x20, #16       // siguiente dato
    add x26, x26, #1
    b sum_loop

sum_done:
    // calcula B_X100

    // suma_x
    sub x10, x22, #1        // N-1
    mul x24, x22, x10       // N*(N-1)
    mov x10, #2
    udiv x24, x24, x10      // suma_x

    mov x10, #100
    mul x23, x23, x10       // suma_y * 100

    mul x10, x28, x24       // M_X100 * suma_x 
    sub x10, x23, x10       // numerador = suma_y*100 - M_X100*suma_x

    // guardar signo y usar udiv
    mov x12, #0
    tst x10, x10
    bpl bx100_pos
    neg x10, x10
    mov x12, #1

bx100_pos:
    udiv x10, x10, x22      // / N
    cmp x12, #1
    bne bx100_done
    neg x10, x10

bx100_done:
    // x10 = B_X100
    
    // Calcular Y_PRED
    add x11, x22, x16       // X_FUTURE = N + K

    mul x12, x28, x11       // M_X100 * X_FUTURE
    add x12, x12, x10       // + B_X100

    mov x15, #0
    tst x12, x12
    bpl ypred_pos
    neg x12, x12
    mov x15, #1

ypred_pos:
    mov x11, #100
    udiv x12, x12, x11      // / 100

    cmp x15, #1
    bne ypred_done
    neg x12, x12

ypred_done:
    // crear la salida del archivo
    ldr x0, =outfile
    mov x1, #577            // O_WRONLY|O_CREAT|O_TRUNC
    mov x2, #438            // 0666
    bl open_file
    mov x19, x0             // x19 = fd

    // CALC=PREDICTION
    mov x0, x19
    ldr x1, =str_calc
    mov x2, len_calc
    bl write_file

    // COLUMN
    mov x0, x19
    ldr x1, =str_col
    mov x2, len_col
    bl write_file

    mov x0, x19
    mov x1, x17
    bl write_str_null

    mov x0, x19
    ldr x1, =nl
    mov x2, #1
    bl write_file

    // WINDOW_START
    mov x0, x19
    ldr x1, =str_wstart
    mov x2, len_wstart
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

    // WINDOW_END
    mov x0, x19
    ldr x1, =str_wend
    mov x2, len_wend
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

    // COUNT
    mov x0, x19
    ldr x1, =str_count
    mov x2, len_count
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

    // K
    mov x0, x19
    ldr x1, =str_k
    mov x2, len_k
    bl write_file

    mov x0, x16
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =nl
    mov x2, #1
    bl write_file

    // SLOPE_X100
    mov x0, x19
    ldr x1, =str_slope
    mov x2, len_slope
    bl write_file

    mov x0, x28             // M_X100
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =nl
    mov x2, #1
    bl write_file

    // INTERCEPT_X100
    mov x0, x19
    ldr x1, =str_intercept
    mov x2, len_intercept
    bl write_file

    mov x0, x10             // B_X100
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =nl
    mov x2, #1
    bl write_file

    // PREDICTED
    mov x0, x19
    ldr x1, =str_pred
    mov x2, len_pred
    bl write_file

    mov x0, x16
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =str_eq
    mov x2, len_eq
    bl write_file

    mov x0, x12             // Y_PRED
    ldr x1, =num_buffer
    bl itoa
    mov x0, x19
    ldr x1, =num_buffer
    bl write_file

    mov x0, x19
    ldr x1, =nl
    mov x2, #1
    bl write_file

    // STATUS=OK
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