.data
    // -------------------------------------------------------------
    // SECCION DE DATOS (.data): Variables inicializadas y umbrales
    // -------------------------------------------------------------

    // Buffers circulares para almacenar el historial de 5 lecturas (5 * 8 bytes = 40 bytes c/u)
    soil_array: .quad 0, 0, 0, 0, 0
    gas_array:  .quad 0, 0, 0, 0, 0
    temp_array: .quad 0, 0, 0, 0, 0
    luz_array:  .quad 0, 0, 0, 0, 0
    
    // Índice actual para los buffers circulares
    array_index: .quad 0
    
    // Contador de datos en el buffer (máximo 5)
    array_count: .quad 0

    // Umbrales físicos basados en config.py y los requisitos
    t_suelo_seco: .quad 25          // Umbral para encender el riego
    t_gas_adv:    .quad 300         // Umbral para activar advertencia
    t_gas_emg:    .quad 500         // Umbral promedio de gas para emergencia
    t_gas_amp:    .quad 300         // Umbral de amplitud de gas para emergencia
    t_temp_vent:  .quad 28          // Umbral de temperatura para ventilador
    t_luz_baja:   .quad 500         // Umbral de luz para encender luces

    // Cadenas de texto para armar la respuesta por stdout
    str_decision: .ascii "DECISION:"
    .equ len_decision, . - str_decision
    str_normal: .ascii "NORMAL"
    .equ len_normal, . - str_normal
    str_advertencia: .ascii "ADVERTENCIA"
    .equ len_advertencia, . - str_advertencia
    str_emergencia: .ascii "EMERGENCIA"
    .equ len_emergencia, . - str_emergencia
    str_modo_manual: .ascii "MODO_MANUAL"
    .equ len_modo_manual, . - str_modo_manual
    str_riego_activo: .ascii "RIEGO_ACTIVO"
    .equ len_riego_activo, . - str_riego_activo

    str_coma: .ascii ","
    
    str_riego_on: .ascii "RIEGO_ON"
    .equ len_riego_on, . - str_riego_on
    str_riego_off: .ascii "RIEGO_OFF"
    .equ len_riego_off, . - str_riego_off
    str_vent_on: .ascii "VENT_ON"
    .equ len_vent_on, . - str_vent_on
    str_vent_off: .ascii "VENT_OFF"
    .equ len_vent_off, . - str_vent_off
    str_alarma_on: .ascii "ALARMA_ON"
    .equ len_alarma_on, . - str_alarma_on
    str_alarma_off: .ascii "ALARMA_OFF"
    .equ len_alarma_off, . - str_alarma_off
    str_luces_on: .ascii "LUCES_ON"
    .equ len_luces_on, . - str_luces_on
    str_luces_off: .ascii "LUCES_OFF"
    .equ len_luces_off, . - str_luces_off
    
    str_sugestion: .ascii "SUGESTION:"
    .equ len_sugestion, . - str_sugestion
    str_no_action: .ascii "NO_ACTION"
    .equ len_no_action, . - str_no_action
    str_encender_bomba: .ascii "ENCENDER_BOMBA"
    .equ len_encender_bomba, . - str_encender_bomba
    str_encender_luz: .ascii "ENCENDER_LUZ"
    .equ len_encender_luz, . - str_encender_luz
    str_encender_vent: .ascii "ENCENDER_VENTILADOR"
    .equ len_encender_vent, . - str_encender_vent
    str_y: .ascii "_Y_"
    .equ len_y, . - str_y
    
    str_newline: .ascii "\n"

.bss
    // Buffer para leer la entrada CSV desde Python (hasta 128 bytes)
    input_buffer: .skip 128
    
    // Buffer para armar la cadena de respuesta final (hasta 256 bytes)
    output_buffer: .skip 256

.text
.global _start

// -------------------------------------------------------------
// MACRO / RUTINA PRINCIPAL
// -------------------------------------------------------------
_start:
main_loop:
    // read(0, input_buffer, 128)
    mov x0, #0
    ldr x1, =input_buffer
    mov x2, #128
    mov x8, #63
    svc #0
    
    cmp x0, #0
    ble end_program
    
    // Parsear CSV: TEMP(X20), HUM(X21), SOIL1(X22), SOIL2(X23), LUZ(X24), GAS(X25), MODO(X26)
    ldr x1, =input_buffer
    bl parse_int
    mov x20, x0
    bl parse_int
    mov x21, x0
    bl parse_int
    mov x22, x0
    bl parse_int
    mov x23, x0
    bl parse_int
    mov x24, x0
    bl parse_int
    mov x25, x0
    bl parse_int
    mov x26, x0

    // -------------------------------------------------------------
    // GUARDADO EN BUFFERS Y CALCULO DE TENDENCIAS
    // -------------------------------------------------------------
    ldr x10, =array_index
    ldr x2, [x10]           // X2 = index
    ldr x11, =array_count
    ldr x3, [x11]           // X3 = count
    
    mov x4, #8
    mul x5, x2, x4          // X5 = offset en bytes
    
    // Calcular Tendencias con el valor antiguo antes de sobreescribir
    ldr x6, =soil_array
    add x6, x6, x5
    ldr x9, [x6]            // Leer valor antiguo de soil
    sub x9, x22, x9         // X9 = TEND_SOIL (Nuevo - Viejo)
    
    ldr x6, =luz_array
    add x6, x6, x5
    ldr x8, [x6]            // Leer valor antiguo de luz
    sub x8, x24, x8         // X8 = TEND_LUZ (Nuevo - Viejo)
    
    ldr x6, =temp_array
    add x6, x6, x5
    ldr x7, [x6]            // Leer valor antiguo de temp
    sub x7, x20, x7         // X7 = TEND_TEMP (Nuevo - Viejo)
    
    // Guardar nuevos valores en la posicion actual (offset)
    ldr x6, =soil_array
    add x6, x6, x5
    str x22, [x6]
    
    ldr x6, =luz_array
    add x6, x6, x5
    str x24, [x6]
    
    ldr x6, =temp_array
    add x6, x6, x5
    str x20, [x6]
    
    ldr x6, =gas_array
    add x6, x6, x5
    str x25, [x6]
    
    // Actualizar index de forma circular
    add x2, x2, #1
    cmp x2, #5
    blt skip_wrap
    mov x2, #0
skip_wrap:
    str x2, [x10]
    
    // Actualizar count (hasta 5)
    cmp x3, #5
    bge skip_inc
    add x3, x3, #1
    str x3, [x11]
skip_inc:
    mov x29, x3             // X29 = COUNT_FINAL
    
    // -------------------------------------------------------------
    // CALCULO DE PROMEDIOS Y AMPLITUD DE GAS
    // -------------------------------------------------------------
    mov x0, #0              // Acumulador SOIL
    mov x1, #0              // Acumulador LUZ
    mov x2, #0              // Acumulador TEMP
    mov x3, #0              // Acumulador GAS
    mov x4, #0              // Max GAS
    ldr x5, =999999         // Min GAS
    mov x6, #0              // i = 0
    
calc_loop:
    cmp x6, x29
    bge calc_done
    mov x10, #8
    mul x10, x6, x10        // offset actual = i * 8
    
    ldr x11, =soil_array
    ldr x11, [x11, x10]
    add x0, x0, x11
    
    ldr x11, =luz_array
    ldr x11, [x11, x10]
    add x1, x1, x11
    
    ldr x11, =temp_array
    ldr x11, [x11, x10]
    add x2, x2, x11
    
    ldr x11, =gas_array
    ldr x11, [x11, x10]
    add x3, x3, x11
    
    // Evaluar max y min gas
    cmp x11, x4
    ble skip_max
    mov x4, x11
skip_max:
    cmp x11, x5
    bge skip_min
    mov x5, x11
skip_min:
    
    add x6, x6, #1
    b calc_loop
    
calc_done:
    // Calcular promedios finales
    udiv x27, x0, x29       // X27 = PROM_SOIL
    udiv x14, x1, x29       // X14 = PROM_LUZ
    udiv x13, x2, x29       // X13 = PROM_TEMP
    udiv x12, x3, x29       // X12 = PROM_GAS
    sub x11, x4, x5         // X11 = AMP_GAS (Max - Min)

    // -------------------------------------------------------------
    // LOGICA DE ESTADOS, ACTUADORES Y SUGERENCIAS
    // -------------------------------------------------------------
    mov x17, #0             // RIEGO
    mov x18, #0             // VENT
    mov x19, #0             // ALARMA
    mov x28, #0             // LUCES

    // Prioridad 1: EMERGENCIA
    ldr x1, =t_gas_emg
    ldr x2, [x1]
    cmp x12, x2             // Comparar PROM_GAS con 500
    bge set_emergencia
    ldr x1, =t_gas_amp
    ldr x2, [x1]
    cmp x11, x2             // Comparar AMP_GAS con 300
    bge set_emergencia
    
    // Verificar Modo
    cmp x26, #1
    beq set_manual
    
    // MODO AUTOMATICO (Prioridades inferiores a Emergencia)
    ldr x15, =str_normal
    ldr x16, =len_normal
    
    // LUZ Baja -> Enciende Luz
    ldr x1, =t_luz_baja
    ldr x2, [x1]
    cmp x14, x2
    bge check_riego_auto
    mov x28, #1
    
check_riego_auto:
    // Suelo Seco -> Riego Activo
    ldr x1, =t_suelo_seco
    ldr x2, [x1]
    cmp x27, x2
    bge check_adv_auto
    mov x17, #1
    ldr x15, =str_riego_activo
    ldr x16, =len_riego_activo
    
check_adv_auto:
    // Advertencia (Gas > 300 o Temp > 28)
    ldr x1, =t_gas_adv
    ldr x2, [x1]
    cmp x12, x2
    bge is_adv
    ldr x1, =t_temp_vent
    ldr x2, [x1]
    cmp x13, x2
    blt finish_auto
is_adv:
    mov x18, #1             // Ventilador ON
    ldr x1, =str_normal
    cmp x15, x1
    bne finish_auto         // Solo si es NORMAL lo sube a ADVERTENCIA
    ldr x15, =str_advertencia
    ldr x16, =len_advertencia
finish_auto:
    b build_output

set_manual:
    ldr x15, =str_modo_manual
    ldr x16, =len_modo_manual
    
    mov x21, #0             // X21 guardará las banderas de las sugerencias (bitmask)
    
    // Solo evalúa sugerencias si el buffer está lleno (count = 5)
    cmp x29, #5
    blt no_sug
    
    // Condicion BOMBA: Promedio Bajo Y Tendencia Descendente (< 0)
    ldr x1, =t_suelo_seco
    ldr x2, [x1]
    cmp x27, x2
    bge check_luz_sug
    cmp x9, #0              // TEND_SOIL
    bge check_luz_sug       // Si es estable (=0) o ascendente (>0), no sugiere
    orr x21, x21, #1        // Setea el Bit 0
    
check_luz_sug:
    // Condicion LUZ: Promedio Bajo Y Tendencia Descendente (< 0)
    ldr x1, =t_luz_baja
    ldr x2, [x1]
    cmp x14, x2
    bge check_vent_sug
    cmp x8, #0              // TEND_LUZ
    bge check_vent_sug
    orr x21, x21, #2        // Setea el Bit 1
    
check_vent_sug:
    // Condicion VENT: Promedio Alto Y Tendencia Ascendente (> 0)
    ldr x1, =t_temp_vent
    ldr x2, [x1]
    cmp x13, x2
    blt no_sug
    cmp x7, #0              // TEND_TEMP
    ble no_sug              // Si es estable (=0) o descendente (<0), no sugiere
    orr x21, x21, #4        // Setea el Bit 2
    
no_sug:
    b build_output

set_emergencia:
    ldr x15, =str_emergencia
    ldr x16, =len_emergencia
    mov x19, #1             // ALARMA ON
    mov x18, #1             // VENT ON
    mov x17, #0             // RIEGO OFF
    mov x28, #0             // LUCES OFF
    b build_output

    // -------------------------------------------------------------
    // CONSTRUCCION DEL STRING DE RESPUESTA
    // -------------------------------------------------------------
build_output:
    ldr x0, =output_buffer
    
    // "DECISION:"
    ldr x1, =str_decision
    ldr x2, =len_decision
    bl copy_str
    
    // ESTADO GLOBAL
    mov x1, x15
    mov x2, x16
    bl copy_str
    bl add_coma
    
    // RIEGO
    cmp x17, #1
    beq copy_riego_on
    ldr x1, =str_riego_off
    ldr x2, =len_riego_off
    b write_riego
copy_riego_on:
    ldr x1, =str_riego_on
    ldr x2, =len_riego_on
write_riego:
    bl copy_str
    bl add_coma
    
    // VENT
    cmp x18, #1
    beq copy_vent_on
    ldr x1, =str_vent_off
    ldr x2, =len_vent_off
    b write_vent
copy_vent_on:
    ldr x1, =str_vent_on
    ldr x2, =len_vent_on
write_vent:
    bl copy_str
    bl add_coma
    
    // ALARMA
    cmp x19, #1
    beq copy_alarma_on
    ldr x1, =str_alarma_off
    ldr x2, =len_alarma_off
    b write_alarma
copy_alarma_on:
    ldr x1, =str_alarma_on
    ldr x2, =len_alarma_on
write_alarma:
    bl copy_str
    bl add_coma
    
    // LUCES
    cmp x28, #1
    beq copy_luces_on
    ldr x1, =str_luces_off
    ldr x2, =len_luces_off
    b write_luces
copy_luces_on:
    ldr x1, =str_luces_on
    ldr x2, =len_luces_on
write_luces:
    bl copy_str
    bl add_coma
    
    // "SUGESTION:"
    ldr x1, =str_sugestion
    ldr x2, =len_sugestion
    bl copy_str
    
    // Solo escribimos sugerencias si estamos en MANUAL
    cmp x26, #1
    beq write_sug
    // Si no es manual, la sugerencia es NO_ACTION
    ldr x1, =str_no_action
    ldr x2, =len_no_action
    bl copy_str
    b finish_output

write_sug:
    // Validar si X21 (Bitmask) tiene algo
    cmp x21, #0
    bne parse_sug
    // Si no tiene nada, NO_ACTION
    ldr x1, =str_no_action
    ldr x2, =len_no_action
    bl copy_str
    b finish_output
    
parse_sug:
    // Evaluar Bit 0 (BOMBA)
    tst x21, #1
    beq sug_luz
    ldr x1, =str_encender_bomba
    ldr x2, =len_encender_bomba
    bl copy_str
    
sug_luz:
    // Evaluar Bit 1 (LUZ)
    tst x21, #2
    beq sug_vent
    // Si la bomba fue agregada, necesitamos un _Y_
    tst x21, #1
    beq 1f
    ldr x1, =str_y
    ldr x2, =len_y
    bl copy_str
1:  ldr x1, =str_encender_luz
    ldr x2, =len_encender_luz
    bl copy_str

sug_vent:
    // Evaluar Bit 2 (VENTILADOR)
    tst x21, #4
    beq finish_output
    // Si bomba o luz fueron agregadas, necesitamos un _Y_
    tst x21, #3             // Revisa bit 0 y 1 simultaneamente
    beq 2f
    ldr x1, =str_y
    ldr x2, =len_y
    bl copy_str
2:  ldr x1, =str_encender_vent
    ldr x2, =len_encender_vent
    bl copy_str

finish_output:
    ldr x1, =str_newline
    mov x2, #1
    bl copy_str
    
    // System call Write (stdout)
    ldr x1, =output_buffer
    sub x2, x0, x1
    mov x0, #1
    mov x8, #64
    svc #0
    
    b main_loop

end_program:
    mov x0, #0
    mov x8, #93
    svc #0

// -------------------------------------------------------------
// FUNCIONES AUXILIARES (HELPERS)
// -------------------------------------------------------------
copy_str:
    mov x3, #0
copy_str_loop:
    cmp x3, x2
    bge copy_str_done
    ldrb w4, [x1, x3]
    strb w4, [x0]
    add x0, x0, #1
    add x3, x3, #1
    b copy_str_loop
copy_str_done:
    ret

add_coma:
    ldr x1, =str_coma
    mov x2, #1
    b copy_str

parse_int:
    mov x0, #0
    mov x5, #10
    mov x6, #0
parse_int_loop:
    ldrb w2, [x1]
    add x1, x1, #1
    cmp w2, #0
    beq parse_int_done
    cmp w2, #10
    beq parse_int_done
    cmp w2, #44
    beq parse_int_done
    cmp w2, #45
    bne parse_int_digit
    mov x6, #1
    b parse_int_loop
parse_int_digit:
    sub w2, w2, #48
    cmp w2, #0
    blt parse_int_loop
    cmp w2, #9
    bgt parse_int_loop
    mul x0, x0, x5
    add x0, x0, x2
    b parse_int_loop
parse_int_done:
    cmp x6, #1
    bne parse_int_ret
    neg x0, x0
parse_int_ret:
    ret
