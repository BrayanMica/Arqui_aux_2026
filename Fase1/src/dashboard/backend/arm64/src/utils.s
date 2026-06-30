// utils.s - Biblioteca comun para modulos ARM64 (Bare-Metal)
// Se compila por separado:  as utils.s -o utils.o
// Cada modulo enlaza con utils.o (Requisito Seccion 11 del PDF)
//
// Funciones exportadas:
//   open_file    - abre un archivo (syscall openat)
//   read_file    - lee bytes de un fd
//   write_file   - escribe bytes a un fd
//   close_file   - cierra un fd
//   exit_program - termina el proceso limpiamente
//   parse_csv    - extrae 30 valores de una columna del CSV
//   atoi         - convierte ASCII a entero con signo
//   itoa         - convierte entero a cadena ASCII
//   itoa_fixed   - convierte entero escalado x100 a cadena con 2 decimales
//   integer_sqrt - raiz cuadrada entera por busqueda binaria
//
// Buffers globales exportados:
//   csv_buffer (4096 bytes)
//   str_buffer (32 bytes)

.data

_err_open_msg: .ascii "Error al abrir archivo\n"
_len_err_open = . - _err_open_msg

_err_read_msg: .ascii "Error al leer archivo\n"
_len_err_read = . - _err_read_msg

.bss

.global csv_buffer
csv_buffer: .skip 4096   // buffer global de lectura del CSV

.global str_buffer
str_buffer: .skip 32     // buffer global para conversiones itoa

.text

.global open_file
.global read_file
.global write_file
.global close_file
.global exit_program
.global parse_csv
.global atoi
.global itoa
.global itoa_fixed
.global integer_sqrt

// ============================================================
// open_file
// Entrada: x0 = puntero al nombre del archivo (string)
//          x1 = flags  (0 = O_RDONLY, 65 = O_WRONLY|O_CREAT,
//                       1089 = O_WRONLY|O_CREAT|O_TRUNC)
//          x2 = mode   (ej. 438 = 0o666)
// Salida:  x0 = file descriptor (>= 0) o termina con error
// ============================================================
open_file:
    mov x3, x2          // mode → x3
    mov x2, x1          // flags → x2
    mov x1, x0          // path  → x1
    mov x0, #-100       // AT_FDCWD = -100
    mov x8, #56         // syscall openat
    svc #0
    cmp x0, #0
    blt _open_error
    ret

_open_error:
    mov x0, #2          // stderr fd
    ldr x1, =_err_open_msg
    mov x2, _len_err_open
    mov x8, #64
    svc #0
    b exit_program

// ============================================================
// read_file
// Entrada: x0 = fd, x1 = buffer, x2 = tamanio max
// Salida:  x0 = bytes leidos
// ============================================================
read_file:
    mov x8, #63         // syscall read
    svc #0
    cmp x0, #0
    blt _read_error
    ret

_read_error:
    mov x0, #2
    ldr x1, =_err_read_msg
    mov x2, _len_err_read
    mov x8, #64
    svc #0
    b exit_program

// ============================================================
// write_file
// Entrada: x0 = fd, x1 = buffer, x2 = longitud
// ============================================================
write_file:
    mov x8, #64         // syscall write
    svc #0
    ret

// ============================================================
// close_file
// Entrada: x0 = fd
// ============================================================
close_file:
    mov x8, #57         // syscall close
    svc #0
    ret

// ============================================================
// exit_program
// Termina el proceso con codigo 0
// ============================================================
exit_program:
    mov x0, #0
    mov x8, #93         // syscall exit
    svc #0

// ============================================================
// integer_sqrt
// Calcula la raiz cuadrada entera por busqueda binaria.
// Entrada: x0 = numero
// Salida:  x0 = raiz cuadrada entera (floor)
// ============================================================
integer_sqrt:
    cmp x0, #0
    b.le isqrt_zero
    mov x1, #0    // L
    mov x2, x0    // R
    mov x3, #0    // ans

isqrt_loop:
    cmp x1, x2
    bgt isqrt_done

    add x4, x1, x2 // L + R
    lsr x4, x4, #1 // M = (L + R) / 2

    mul x5, x4, x4 // M * M
    cmp x5, x0
    beq isqrt_exact

    blt isqrt_less

    sub x2, x4, #1
    b isqrt_loop

isqrt_less:
    mov x3, x4
    add x1, x4, #1
    b isqrt_loop

isqrt_exact:
    mov x0, x4
    ret

isqrt_done:
    mov x0, x3
    ret

isqrt_zero:
    mov x0, #0
    ret

// ============================================================
// parse_csv
// Carga exactamente 30 enteros de la columna indicada del CSV.
//
// Entrada: x0 = puntero al buffer con el CSV ya leido
//          x1 = bytes leidos (tamanio valido del buffer)
//          x2 = columna objetivo (1-indexed, ej. 4 = HUM_SUELO_1)
//          x3 = puntero al arreglo destino (30 * 8 bytes)
//
// El buffer debe haber sido llenado previamente con read_file.
// La primera linea (encabezado) es ignorada automaticamente.
// ============================================================
parse_csv:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x21, x0         // puntero al buffer (cursor)
    mov x22, x3         // arreglo destino
    mov x24, x2         // columna objetivo
    mov x25, #0         // contador de elementos extraidos

// --- saltar encabezado (hasta el primer '\n') ---
_csv_skip_header:
    ldrb w23, [x21], #1
    cmp w23, #10        // '\n'
    beq _csv_next_row
    cmp w23, #0         // fin de string
    beq _csv_end
    b _csv_skip_header

// --- procesar fila ---
_csv_next_row:
    cmp x25, #30        // ya tenemos 30 datos?
    b.ge _csv_end

    mov x26, #1         // columna actual = 1

// --- avanzar hasta la columna objetivo ---
_csv_find_col:
    cmp x26, x24        // llegamos a la columna buscada?
    beq _csv_read_val

    // saltar hasta la coma o fin de linea
_csv_skip_col:
    ldrb w23, [x21], #1
    cmp w23, #0
    beq _csv_end
    cmp w23, #10        // '\n' → la fila no tenia la columna
    beq _csv_next_row
    cmp w23, ','
    beq _csv_col_done
    b _csv_skip_col

_csv_col_done:
    add x26, x26, #1
    b _csv_find_col

// --- leer el valor de la columna con atoi ---
_csv_read_val:
    bl atoi             // consume x21, deja resultado en x10, delimitador en w23
    str x10, [x22, x25, LSL #3]    // arreglo[x25] = x10
    add x25, x25, #1

    // si el delimitador fue '\n', pasar a la siguiente fila directamente
    cmp w23, #10
    beq _csv_next_row

    // si fue ',' o cualquier otra cosa, saltar al fin de linea
_csv_skip_rest:
    cmp w23, #0
    beq _csv_end
    cmp w23, #10
    beq _csv_next_row
    ldrb w23, [x21], #1
    b _csv_skip_rest

_csv_end:
    ldp x29, x30, [sp], #16
    ret

// ============================================================
// atoi
// Convierte texto ASCII a entero con signo.
//
// Entrada: x21 = cursor apuntando al inicio del numero en buffer
// Salida:  x10 = numero convertido
//          w23 = caracter delimitador que termino la lectura
//          x21 = apunta al caracter SIGUIENTE al delimitador
//
// Maneja el signo negativo '-'.
// ============================================================
atoi:
    mov x10, #0         // resultado acumulador = 0
    mov x11, #1         // signo = +1 por defecto
    mov x5,  #10        // base 10

    ldrb w23, [x21], #1 // leer primer caracter

    // verificar signo negativo
    cmp w23, '-'
    bne _atoi_digit
    mov x11, #-1        // signo negativo
    ldrb w23, [x21], #1 // avanzar al primer digito

_atoi_digit:
    // verificar si es digito ASCII '0'-'9'
    cmp w23, '0'
    blt _atoi_done
    cmp w23, '9'
    bgt _atoi_done

    sub w23, w23, '0'   // convertir ASCII → valor (0-9)
    mul x10, x10, x5    // resultado = resultado * 10
    add x10, x10, x23   // resultado += digito

    ldrb w23, [x21], #1 // leer siguiente caracter
    b _atoi_digit

_atoi_done:
    mul x10, x10, x11   // aplicar signo
    ret

// ============================================================
// itoa
// Convierte un entero con signo a cadena ASCII.
//
// Entrada: x0 = numero entero
//          x1 = buffer destino
// Salida:  x2 = longitud de la cadena generada (sin null terminator)
// ============================================================
itoa:
    mov x2, #0          // longitud = 0
    mov x3, x0          // copia del valor
    mov x4, x1          // puntero inicio del buffer
    mov x5, #10         // base 10

    cmp x3, #0
    b.ge _itoa_pos

    // numero negativo: escribir '-'
    mov w6, '-'
    strb w6, [x4], #1
    add x2, x2, #1
    sub x3, xzr, x3  // trabajar con el valor absoluto (neg = 0 - x)

_itoa_pos:
    mov x6, sp          // guardar sp actual (marca de inicio de digitos en pila)

_itoa_push:
    udiv x7, x3, x5     // x7 = x3 / 10
    msub x8, x7, x5, x3 // x8 = x3 mod 10
    add x8, x8, '0'     // convertir a ASCII
    strb w8, [sp, #-1]! // push al stack (de menos a mas significativo)
    mov x3, x7
    cmp x3, #0
    bne _itoa_push

    // al menos un digito fue puesto, ahora extraer del stack al buffer
_itoa_pop:
    ldrb w8, [sp], #1
    strb w8, [x4], #1
    add x2, x2, #1
    cmp sp, x6          // mientras no hayamos vaciado los digitos
    bne _itoa_pop

    ret

// ============================================================
// itoa_fixed
// Convierte un entero escalado x100 a cadena con 2 decimales.
// Ejemplos: 4474 → "44.74" | -3 → "-0.03" | 0 → "0.00"
//
// Entrada: x0 = numero escalado x100 (puede ser negativo)
//          x1 = buffer destino
// Salida:  x2 = longitud de la cadena generada
// ============================================================
itoa_fixed:
    mov x2, #0
    mov x3, x0
    mov x4, x1
    mov x5, #10

    cmp x3, #0
    b.ge _fixed_pos

    mov w6, '-'
    strb w6, [x4], #1
    add x2, x2, #1
    sub x3, xzr, x3  // valor absoluto (0 - x)

_fixed_pos:
    mov x6, sp          // marca de pila
    mov x9, #0          // cantidad de digitos extraidos

_fixed_push:
    udiv x7, x3, x5
    msub x8, x7, x5, x3
    add x8, x8, '0'
    strb w8, [sp, #-1]!
    add x9, x9, #1
    mov x3, x7
    cmp x3, #0
    bne _fixed_push

    // asegurar al menos 3 digitos (2 decimales + 1 entero)
_fixed_pad:
    cmp x9, #3
    b.ge _fixed_pop
    mov w8, '0'
    strb w8, [sp, #-1]!
    add x9, x9, #1
    b _fixed_pad

    // extraer digitos de la parte entera (todos excepto los ultimos 2)
_fixed_pop:
    sub x10, x9, #2     // cantidad de digitos de parte entera

_fixed_pop_int:
    ldrb w8, [sp], #1
    strb w8, [x4], #1
    add x2, x2, #1
    sub x10, x10, #1
    cmp x10, #0
    bgt _fixed_pop_int

    // insertar punto decimal
    mov w8, '.'
    strb w8, [x4], #1
    add x2, x2, #1

    // extraer los 2 digitos decimales
    ldrb w8, [sp], #1
    strb w8, [x4], #1
    add x2, x2, #1
    ldrb w8, [sp], #1
    strb w8, [x4], #1
    add x2, x2, #1

    ret
