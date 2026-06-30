.data

filename:
    .asciz "lecturas.csv"

err_open:
    .ascii "Error al abrir el archivo\n"
    len_err_open = . - err_open

err_read:
    .ascii "Error al leer el archivo\n"
    len_err_read = . - err_read

.data

msg_read_failed:
    .asciz "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=READ_FAILED\nDETAIL=FAILED_TO_READ_FILE\n" 
    len_err_read_failed = . - msg_read_failed

msg_empty_file:
    .asciz "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=EMPTY_FILE\nDETAIL=FAILED_TO_READ_FILE_EMPTY\n" 
    len_err_empty_file = . - msg_empty_file 

msg_file_not_found:
    .asciz "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=FAILED_TO_READ_FILE_NOT_FOUND\n" 
    len_err_file_not_found = . - msg_file_not_found 

msg_error_ve:
    .asciz "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=VALIDATE_HEADER\nDETAIL=THE_HEADER_DOES_NOT_HAVE_A_VALID_FORMAT\n" 
    len_ve_error = . - msg_error_ve    

msg_error_linea_invalida:
    .asciz "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=INVALID_LINE\nDETAIL=THE_INITIAL_LINE_MUST_BE_GREATER_THAN_OR_EQUAL_TO_1\n" 
    len_error_linea_invalida = . - msg_error_linea_invalida

msg_error_linea_final_invalida:
    .asciz "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=INVALID_FINAL_LINE\nDETAIL=THE_FINAL_LINE_MUST_BE_GREATER_THAN_OR_EQUAL_TO_INITIAL_LINE\n" 
    len_error_linea_final_invalida = . - msg_error_linea_final_invalida

msg_error_linea_final_menor:
    .asciz "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=INVALID_FINAL_LINE\nDETAIL=THE_FINAL_LINE_MUST_BE_GREATER_THAN_OR_EQUAL_TO_THE_INITIAL_LINE\n" 
    len_error_linea_final_menor = . - msg_error_linea_final_menor    

msg_error_linea_no_existe:
    .asciz "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=INVALID_LINE\nDETAIL=THE_LINEA_NO_EXIST\n" 
    len_error_linea_no_existe = . - msg_error_linea_no_existe     

msg_error_archivo_sin_simbolo_final:
    .asciz "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=INVALID_LINE\nDETAIL=THE_FILE_DOES_NOT_HAVE_A_$_SYMBOL\n" 
    len_error_archivo_sin_simbolo_final = . - msg_error_archivo_sin_simbolo_final   


msg_error_columna_invalida:
    .asciz "MODULE=HISTORICAL_ANALYZER\nSTATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=THE_COLUMN_NO_EXIST\n" 
    len_error_columna_invalida = . - msg_error_columna_invalida                      


.section .rodata
    encabezado_esperado:  .ascii "ID,TEMP,HUM_AIRE,HUM_SUELO_1,HUM_SUELO_2,LUZ,GAS\n"
    len_encabezado = . - encabezado_esperado    

    // Cadenas de las columnas validas
    col_temp:        .asciz "TEMP"
    col_hum_aire:    .asciz "HUM_AIRE"
    col_hum_suelo1:  .asciz "HUM_SUELO_1"
    col_hum_suelo2:  .asciz "HUM_SUELO_2"
    col_luz:         .asciz "LUZ"
    col_gas:         .asciz "GAS"


.bss

buffer:
    .skip 4096

num_buffer:
    .skip 32

.text

historical_analyzer_validate:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]

    // Se respaldan los argumentos de entrada inmediatamente en registros seguros
    mov x19, x0          // x19 = archivo_entrada  (string)
    mov x20, x1          // x20 = linea_inicial
    mov x21, x2          // x21 = linea_final
    mov x22, x3          // x22 = columna_sensor (string) TEMP

    //Pasar la linea_inicial, linea_final a enteros
    // Valida la linea inicial
    mov x0, x20                 
    bl cadena_a_entero          
    cmp x0, #1                  
    blt error_linea_invalida   
    mov x20, x0          // x20 ahora guarda el entero de linea_inicial

    // valida la linea final
    mov x0, x21
    bl cadena_a_entero
    cmp x0, #1
    blt error_linea_final_invalida
    mov x21, x0          // x21 ahora guarda el entero de linea_final


    // valida que la linea final sea mayor o igual a linea inicial
    cmp x21, x20         // Compara linea_final con linea_inicial
    blt error_linea_final_menor


    // Abrir archivo
    mov x0, #-100               // AT_FDCWD
    mov x1, x19                 // Nombre del archivo recuperado
    mov x2, #0                  // O_RDONLY
    mov x3, #0
    mov x8, #56                 // openat
    svc #0

    cmp x0, #0
    blt error_file_not_found

    mov x23, x0  // en x0 esta la llamada devuelta, se la pasamos a x23

    // leer archivo
    mov x0, x23
    ldr x1, =buffer
    mov x2, #4096
    mov x8, #63
    svc #0

    cmp x0, #0
    blt error_read_failed      // error real del kernel

    //cbz x0, error_empty_file   // archivo vacío

    mov x24, x0              // bytes leídos

    // Cerrar archivo
    mov x0, x23
    mov x8, #57
    svc #0

    bl validar_encabezado

    // validar que las lineas existan en el archivo
    mov x0, x21                  //se pasa la linea final como argumento
    bl validar_existen_lineas

    mov x0, x22
    bl validar_columna
    mov x22, x0

    // Todo salio bien 
    mov x0, X22
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Validar que la columna ingresada sea una opción permitida
validar_columna:
    stp x29, x30, [sp, #-16]!   
    mov x29, sp
    mov x19, x0                 // Guardar el argumento del usuario en x19


    mov x0, x19
    ldr x1, =col_temp
    bl comparar_cadenas
    mov x25, #1
    cbz x0, columna_valida      // Si x0 es 0, son iguales


    mov x0, x19
    ldr x1, =col_hum_aire
    bl comparar_cadenas
    mov x25, #2
    cbz x0, columna_valida


    mov x0, x19
    ldr x1, =col_hum_suelo1
    bl comparar_cadenas
    mov x25, #3
    cbz x0, columna_valida


    mov x0, x19
    ldr x1, =col_hum_suelo2
    bl comparar_cadenas
    mov x25, #4
    cbz x0, columna_valida


    mov x0, x19
    ldr x1, =col_luz
    bl comparar_cadenas
    mov x25, #5
    cbz x0, columna_valida


    mov x0, x19
    ldr x1, =col_gas
    bl comparar_cadenas
    mov x25, #6
    cbz x0, columna_valida


    b error_columna_invalida

columna_valida:
    mov x0, x25
    ldp x29, x30, [sp], #16
    ret

// compara las cadenas
// x0 es la cadena1. x1 es la cadena2
comparar_cadenas:
    mov x2, #0                  // Índice
cad_loop:
    ldrb w3, [x0, x2]           // Leer caracter de string1
    ldrb w4, [x1, x2]           // Leer caracter de string2

    cmp w3, w4                  // comparar los caracteres
    bne cad_distintos           // Si son distintos termina

    cbz w3, cad_iguales         // Si w3 es \0 y eran iguales, se llega al final con éxito

    add x2, x2, #1              // Siguiente carácter
    b cad_loop

cad_distintos:
    mov x0, #1                  // Retornar 1 porque son diferentes
    ret

cad_iguales:
    mov x0, #0                  // Retornar 0 porque son iguales
    ret


// valida que existan las lineas
validar_existen_lineas:
    ldr x1, =buffer         // Puntero al inicio del buffer
    mov x2, x24             // total de bytes leídos en el archivo

    // Si el archivo está vacío
    cbz x2, error_empty_file

    mov x3, #0              // bytes procesados (contador del ciclo)
    mov x4, #0              // contador de líneas actuales. se empieza en la linea 0 (el encabezado)

vel_loop:
    cmp x3, x2              // compara para ver si ya se proceso todo el buffer
    beq vel_fin_buffer

    ldrb w5, [x1], #1       // Leer byte actual y avanzar puntero
    add x3, x3, #1          // Incrementar bytes procesados

    // Si sale $ se deja de procesar lo demas
    cmp w5, '$'            
    beq vel_fin_datos       // se salta al final de los datos

    cmp w5, #10             // se compara si es un salto de linea en ascii
    bne vel_loop            // Si no es, continuar al siguiente carácter

    add x4, x4, #1          // Si es '\n' es una nueva linea
    b vel_loop

vel_fin_buffer:
    // el bucle terminó y nunca se leyó el $
    b error_archivo_sin_simbolo_final

vel_fin_datos:
    // $ fue encontrado. x4 tiene el índice máximo real
    cmp x0, #0
    blt error_linea_no_existe

    // Si x0 es mayor que el indice maximo entonces da error
    cmp x0, x4
    bgt error_linea_no_existe // Si linea_buscada es mayor a max_linea_valida entonces da error
    
    ret            // Si es menor o igual, la línea existe de forma segura


// validar que la linea sea mayor que 1
cadena_a_entero:
    mov x1, x0                  // x1 apuntará al string
    mov x0, #0                  // x0 acumulará el resultado numerico
    mov x2, #10                 // Base 10 para multiplicar

conversion_loop:
    ldrb w3, [x1], #1                  // Leer un byte/carácter y avanzar puntero
    cbz w3, terminar_conversion        // Si es el fin de la cadena (\0) terminar
    
    // Validar si el caracter está entre '0' (48) y '9' (57)
    cmp w3, #48
    blt terminar_conversion           // Si es menor que '0' terminar
    cmp w3, #57 
    bgt terminar_conversion           // Si es mayor que '9' terminar

    sub w3, w3, #48             // Convertir caracter ascii a valor numerico (0-9)
    mul x0, x0, x2              // Resultado actual * 10
    add x0, x0, x3              // Sumar el nuevo dígito

    b conversion_loop           // vuelve a iterar el siguiente digito del numero 

terminar_conversion :
    ret


// Validar el encabezado del archivo
validar_encabezado:
    ldr x9, =buffer                 // Puntero al buffer del archivo leído
    ldr x10, =encabezado_esperado   // Puntero al encabezado correcto
    mov x11, #0                     // Contador de bytes validados
    ldr x12, =len_encabezado       // Longitud total que debe coincidir

ve_loop:
    // Si se compararon todos los bytes del encabezado esperado con exito
    cmp x11, x12
    beq ve_ok

    // Leer un byte de cada lado
    ldrb w1, [x9], #1          // Byte del archivo
    ldrb w2, [x10], #1          // Byte del molde esperado

    // Comparar los dos caracteres
    cmp w1, w2
    bne error_encabezado_invalido       // Si un solo byte no coincide, el header está mal

    add x11, x11, #1                    // Incrementar contador
    b ve_loop

ve_ok:
    ret


// Errores
error_columna_invalida:
    mov x0, #2                     
    ldr x1, =msg_error_columna_invalida 
    ldr x2, =len_error_columna_invalida
    b abortar_con_error


error_linea_no_existe:
    mov x0, #2                     
    ldr x1, =msg_error_linea_no_existe
    ldr x2, =len_error_linea_no_existe
    b abortar_con_error


error_linea_final_menor:
    mov x0, #2                     
    ldr x1, =msg_error_linea_final_menor
    ldr x2, =len_error_linea_final_menor
    b abortar_con_error

error_linea_invalida:
    mov x0, #2                     
    ldr x1, =msg_error_linea_invalida
    ldr x2, =len_error_linea_invalida
    b abortar_con_error

error_linea_final_invalida:
    mov x0, #2                     
    ldr x1, =msg_error_linea_final_invalida
    ldr x2, =len_error_linea_final_invalida
    b abortar_con_error

error_archivo_sin_simbolo_final:
    mov x0, #2                     
    ldr x1, =msg_error_archivo_sin_simbolo_final
    ldr x2, =len_error_archivo_sin_simbolo_final
    b abortar_con_error    


error_encabezado_invalido:
    mov x0, #2                     
    ldr x1, =msg_error_ve
    ldr x2, =len_ve_error 
    b abortar_con_error

error_file_not_found:   
    mov x0, #2                     
    ldr x1, =msg_file_not_found
    ldr x2, =len_err_file_not_found  
    b abortar_con_error

error_read_failed:
    mov x0, #2                 
    ldr x1, =msg_read_failed
    ldr x2, =len_err_read_failed
    b abortar_con_error

error_empty_file:
    mov x0, #2                 
    ldr x1, =msg_empty_file
    ldr x2, =len_err_empty_file
    b abortar_con_error   

// limpiar la pila antes de ir a print_error
abortar_con_error:
    // Se desapila
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    
    // Se salta a la funcion de error
    b print_error


print_error:
    mov x8, #64
    svc #0

    mov x0, #1
    mov x8, #93
    svc #0   


atoi_csv:
    mov x10, #0
    mov x7, #0

atoi_loop:
    ldrb w23, [x21], #1

    cmp w23, #0
    beq atoi_done
    cmp w23, ','
    beq atoi_done
    cmp w23, #10
    beq atoi_done
    cmp w23, '$'
    beq atoi_done

    cmp w23, '0'
    blt atoi_loop
    cmp w23, '9'
    bgt atoi_loop

    sub w23, w23, '0'
    mov x4, x10
    mul x10, x4, x5
    add x10, x10, x23
    mov x7, #1
    b atoi_loop

atoi_done:
    ret

atoi_signed:
    mov x21, x0
    mov x10, #0
    mov x7, #0              // flag se leyó algún dígito
    mov x6, #0              // 0 = positivo

    ldrb w23, [x21], #1
    cmp w23, #'-'
    bne atoi_s_check_digit
    mov x6, #1              // es negativo
    ldrb w23, [x21], #1     // leer siguiente carácter

atoi_s_loop:
    cmp w23, #0
    beq atoi_s_done
    cmp w23, ','
    beq atoi_s_done
    cmp w23, #10
    beq atoi_s_done

atoi_s_check_digit:
    cmp w23, '0'
    blt atoi_s_next
    cmp w23, '9'
    bgt atoi_s_next

    sub w23, w23, '0'
    mov x4, x10
    mov x5, #10
    mul x10, x4, x5
    add x10, x10, x23
    mov x7, #1

atoi_s_next:
    ldrb w23, [x21], #1
    b atoi_s_loop

atoi_s_done:
    cmp x6, #1
    bne atoi_s_ret
    neg x10, x10

atoi_s_ret:
    mov x0, x10
    ret    

read_column_to_stack:
    stp x29, x30, [sp, #-32]!
    stp x25, x26, [sp, #16]
    mov x29, sp

    mov x28, sp
    add x27, x28, #32    


    mov x25, x13         // x25 = linea_inicial
    mov x26, x14         // x26 = linea_final
    mov x15, x11         

    mov x5, #10
    mov x22, #0          // Contador de datos en stack
    mov x24, #1          // Contador de línea actual

    mov x0, #-100
    ldr x1, =filename
    mov x2, #0
    mov x3, #0
    mov x8, #56
    svc #0
    cmp x0, #0
    blt open_error
    mov x19, x0

    mov x0, x19
    ldr x1, =buffer
    mov x2, #4096
    mov x8, #63
    svc #0
    cmp x0, #0
    blt read_error
    mov x20, x0

    mov x0, x19
    mov x8, #57
    svc #0

    ldr x21, =buffer

skip_header:
    ldrb w23, [x21], #1
    cmp w23, #10
    beq process_line
    cmp w23, '$'
    beq utils_done
    b skip_header

process_line:
    cmp x24, x26         // Comparar con linea_final
    bgt utils_done

    cmp x24, x25         // Comparar con linea_inicial 
    blt skip_entire_line

    mov x12, #1          // Reiniciar contador de columna

find_column:
    cmp x12, x15         // Comparar con columna deseada
    beq read_column

skip_to_delim:
    ldrb w23, [x21], #1
    cmp w23, '$'
    beq utils_done
    cmp w23, #10
    beq line_completed
    cmp w23, ','
    bne skip_to_delim

    add x12, x12, #1
    b find_column

read_column:
    bl atoi_csv
    cbz x7, after_column

    sub sp, sp, #16
    str x10, [sp]
    add x22, x22, #1

after_column:
    cmp w23, '$'
    beq utils_done
    cmp w23, #10
    beq line_completed

skip_rest:
    ldrb w23, [x21], #1
    cmp w23, '$'
    beq utils_done
    cmp w23, #10
    beq line_completed
    b skip_rest

skip_entire_line:
    ldrb w23, [x21], #1
    cmp w23, '$'
    beq utils_done
    cmp w23, #10
    bne skip_entire_line

line_completed:
    add x24, x24, #1
    b process_line

utils_done:
    mov x0, sp
    mov x1, x28
    mov x2, x22
    mov x3, x27

    ldp x25, x26, [x29, #16]
    ldp x29, x30, [x29]
    add sp, sp, #32
    ret


integer_sqrt:
    mov x1, #1

sqrt_loop:
    mul x2, x1, x1
    cmp x2, x0
    bgt sqrt_done
    add x1, x1, #1
    b sqrt_loop

sqrt_done:
    sub x1, x1, #1
    mov x0, x1
    ret

itoa:
    mov x2, #0
    mov x3, x0
    mov x4, x1

    cmp x3, #0
    blt itoa_neg

    b itoa_pos

itoa_neg:

    mov w6, '-'
    strb w6, [x4]
    add x4, x4, #1
    add x2, x2, #1
    mov x10, #0
    sub x3, x10, x3

itoa_pos:

    ldr x1, =num_buffer
    add x1, x1, #31
    mov w6, #0
    strb w6, [x1]

    mov x5, #10
    mov x12, #0
    mov x10, x3

    cmp x10, #0
    bne itoa_push

    sub x1, x1, #1
    mov w6, '0'
    strb w6, [x1]
    mov x12, #1
    b itoa_pop

itoa_push:
    udiv x7, x10, x5
    msub x8, x7, x5, x10
    add x8, x8, '0'
    sub x1, x1, #1
    strb w8, [x1]
    add x12, x12, #1
    mov x10, x7
    cbnz x10, itoa_push

itoa_pop:

    ldrb w8, [x1]
    add x1, x1, #1
    strb w8, [x4]
    add x4, x4, #1
    add x2, x2, #1
    sub x12, x12, #1
    cbnz x12, itoa_pop

    ret

itoa_fixed:
    mov x2, #0
    mov x4, x1
    mov x3, x0

    cmp x3, #0
    blt fixed_neg

    b fixed_pos

fixed_neg:
    mov w6, '-'
    strb w6, [x4]
    add x4, x4, #1
    add x2, x2, #1
    mov x10, #0
    sub x3, x10, x3

fixed_pos:

    mov x6, #100
    udiv x7, x3, x6
    msub x8, x7, x6, x3

    ldr x1, =num_buffer
    add x1, x1, #31
    mov w6, #0
    strb w6, [x1]

    mov x5, #10
    mov x12, #0
    mov x10, x7

    cmp x10, #0
    bne fixed_push

    sub x1, x1, #1
    mov w6, '0'
    strb w6, [x1]
    mov x12, #1
    b fixed_pop

fixed_push:
    udiv x7, x10, x5
    msub x11, x7, x5, x10
    add x11, x11, '0'
    sub x1, x1, #1
    strb w11, [x1]
    add x12, x12, #1
    mov x10, x7
    cbnz x10, fixed_push

fixed_pop:
    ldrb w10, [x1]
    add x1, x1, #1
    strb w10, [x4]
    add x4, x4, #1
    add x2, x2, #1
    sub x12, x12, #1
    cbnz x12, fixed_pop

    mov w6, '.'
    strb w6, [x4]
    add x4, x4, #1
    add x2, x2, #1

    mov x5, #10
    udiv x7, x8, x5
    msub x6, x7, x5, x8
    add w7, w7, '0'
    add w6, w6, '0'
    strb w7, [x4]
    add x4, x4, #1
    add x2, x2, #1
    strb w6, [x4]
    add x4, x4, #1
    add x2, x2, #1

    ret

open_file:
    mov x3, x2
    mov x2, x1
    mov x1, x0
    mov x0, #-100
    mov x8, #56
    svc #0
    ret

write_file:
    mov x8, #64
    svc #0
    ret

close_file:
    mov x8, #57
    svc #0
    ret

// escribe cadena terminada en '\0'
write_str_null:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    mov x20, x1

    mov x2, #0
wsn_len:
    ldrb w3, [x20, x2]
    cbz w3, wsn_write
    add x2, x2, #1
    b wsn_len

wsn_write:
    cbz x2, wsn_done
    mov x0, x19
    mov x1, x20
    bl write_file

wsn_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret    
    
open_error:
    mov x0, #1
    ldr x1, =err_open
    mov x2, len_err_open
    mov x8, #64
    svc #0
    mov x0, #1
    mov x8, #93
    svc #0

read_error:
    mov x0, #1
    ldr x1, =err_read
    mov x2, len_err_read
    mov x8, #64
    svc #0
    mov x0, #1
    mov x8, #93
    svc #0
