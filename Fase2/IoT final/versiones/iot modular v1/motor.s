.data

soil_array:  .quad 0, 0, 0, 0, 0
soil_count:  .quad 0

gas_array:   .quad 0, 0, 0, 0, 0
gas_count:   .quad 0

temp_array:  .quad 0, 0, 0, 0, 0
temp_count:  .quad 0

luz_array:   .quad 0, 0, 0, 0, 0
luz_count:   .quad 0

t_suelo_seco: .quad 25
t_gas_adv:    .quad 100
t_gas_emg:    .quad 300
t_gas_amp:    .quad 100
t_temp_vent:  .quad 26
t_luz_baja:   .quad 500

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
input_buffer:  .skip 128
output_buffer: .skip 256

.text
.global _start

.include "utils/atoi.s"
.include "utils/array.s"
.include "utils/promedio.s"
.include "utils/tendencia.s"
.include "utils/amplitud.s"
.include "utils/output.s"

_start:

main_loop:
    mov x0, #0
    ldr x1, =input_buffer
    mov x2, #128
    mov x8, #63
    svc #0

    cmp x0, #0
    ble end_program

    // parsear CSV: TEMP,HUM,SOIL,SOIL2,LUZ,GAS,MODO
    ldr x21, =input_buffer
    mov x5, #10

    bl atoi_csv
    mov x19, x10
    bl atoi_csv
    mov x20, x10
    bl atoi_csv
    mov x22, x10
    bl atoi_csv
    mov x24, x10
    bl atoi_csv
    mov x25, x10
    bl atoi_csv
    mov x26, x10
    bl atoi_csv
    mov x27, x10

    // guardar sensores en arrays
    mov x0, x22
    ldr x1, =soil_count
    ldr x3, =soil_array
    bl guardar_dato

    mov x0, x25
    ldr x1, =luz_count
    ldr x3, =luz_array
    bl guardar_dato

    mov x0, x19
    ldr x1, =temp_count
    ldr x3, =temp_array
    bl guardar_dato

    mov x0, x26
    ldr x1, =gas_count
    ldr x3, =gas_array
    bl guardar_dato

    // promedios
    ldr x0, =soil_array
    ldr x1, =soil_count
    ldr x1, [x1]
    bl calcular_promedio
    mov x19, x0

    ldr x0, =luz_array
    ldr x1, =luz_count
    ldr x1, [x1]
    bl calcular_promedio
    mov x20, x0

    ldr x0, =temp_array
    ldr x1, =temp_count
    ldr x1, [x1]
    bl calcular_promedio
    mov x22, x0

    ldr x0, =gas_array
    ldr x1, =gas_count
    ldr x1, [x1]
    bl calcular_promedio
    mov x24, x0

    // amplitud gas
    ldr x0, =gas_array
    ldr x1, =gas_count
    ldr x1, [x1]
    bl calcular_amplitud
    mov x25, x0

    // tendencias
    ldr x0, =soil_array
    ldr x1, =soil_count
    ldr x1, [x1]
    bl calcular_tendencia
    mov x26, x0

    ldr x0, =luz_array
    ldr x1, =luz_count
    ldr x1, [x1]
    bl calcular_tendencia
    mov x28, x0

    ldr x0, =temp_array
    ldr x1, =temp_count
    ldr x1, [x1]
    bl calcular_tendencia
    mov x29, x0

    // flags actuadores
    mov x9, #0
    mov x10, #0
    mov x11, #0
    mov x12, #0

    // EMERGENCIA: prom_gas >= 500 o amp_gas >= 300
    ldr x1, =t_gas_emg
    ldr x2, [x1]
    cmp x24, x2
    bge set_emergencia
    ldr x1, =t_gas_amp
    ldr x2, [x1]
    cmp x25, x2
    bge set_emergencia

    // MODO MANUAL
    cmp x27, #1
    beq set_manual

    // MODO AUTOMATICO
    ldr x13, =str_normal
    mov x23, len_normal

    // luz baja -> luces ON
    ldr x1, =t_luz_baja
    ldr x2, [x1]
    cmp x20, x2
    bge check_riego_auto
    mov x12, #1

check_riego_auto:
    ldr x1, =t_suelo_seco
    ldr x2, [x1]
    cmp x19, x2
    bge check_adv_auto
    mov x9, #1
    ldr x13, =str_riego_activo
    mov x23, len_riego_activo

check_adv_auto:
    ldr x1, =t_gas_adv
    ldr x2, [x1]
    cmp x24, x2
    bge is_adv
    ldr x1, =t_temp_vent
    ldr x2, [x1]
    cmp x22, x2
    blt finish_auto
is_adv:
    mov x10, #1
    ldr x1, =str_normal
    cmp x13, x1
    bne finish_auto
    ldr x13, =str_advertencia
    mov x23, len_advertencia
finish_auto:
    b build_output

set_manual:
    ldr x13, =str_modo_manual
    mov x23, len_modo_manual

    mov x21, #0
    mov x24, #0
    mov x25, #0

    // sugerencias solo si buffer lleno
    ldr x0, =gas_count
    ldr x0, [x0]
    cmp x0, #5
    blt no_sug

    // bomba: prom_soil bajo Y tend_soil descendente
    ldr x1, =t_suelo_seco
    ldr x2, [x1]
    cmp x19, x2
    bge check_luz_sug
    cmp x26, #0
    bge check_luz_sug
    mov x21, #1

check_luz_sug:
    ldr x1, =t_luz_baja
    ldr x2, [x1]
    cmp x20, x2
    bge check_vent_sug
    cmp x28, #0
    bge check_vent_sug
    mov x24, #1

check_vent_sug:
    ldr x1, =t_temp_vent
    ldr x2, [x1]
    cmp x22, x2
    blt no_sug
    cmp x29, #0
    ble no_sug
    mov x25, #1

no_sug:
    b build_output

set_emergencia:
    ldr x13, =str_emergencia
    mov x23, len_emergencia
    mov x11, #1
    mov x10, #1
    mov x9, #0
    mov x12, #0
    mov x21, #0
    mov x24, #0
    mov x25, #0
    b build_output

build_output:
    ldr x0, =output_buffer

    ldr x1, =str_decision
    mov x2, len_decision
    bl copy_str

    mov x1, x13
    mov x2, x23
    bl copy_str
    bl add_coma

    // riego
    cmp x9, #1
    beq out_riego_on
    ldr x1, =str_riego_off
    mov x2, len_riego_off
    b out_riego
out_riego_on:
    ldr x1, =str_riego_on
    mov x2, len_riego_on
out_riego:
    bl copy_str
    bl add_coma

    // ventilador
    cmp x10, #1
    beq out_vent_on
    ldr x1, =str_vent_off
    mov x2, len_vent_off
    b out_vent
out_vent_on:
    ldr x1, =str_vent_on
    mov x2, len_vent_on
out_vent:
    bl copy_str
    bl add_coma

    // alarma
    cmp x11, #1
    beq out_alarma_on
    ldr x1, =str_alarma_off
    mov x2, len_alarma_off
    b out_alarma
out_alarma_on:
    ldr x1, =str_alarma_on
    mov x2, len_alarma_on
out_alarma:
    bl copy_str
    bl add_coma

    // luces
    cmp x12, #1
    beq out_luces_on
    ldr x1, =str_luces_off
    mov x2, len_luces_off
    b out_luces
out_luces_on:
    ldr x1, =str_luces_on
    mov x2, len_luces_on
out_luces:
    bl copy_str
    bl add_coma

    // sugestion
    ldr x1, =str_sugestion
    mov x2, len_sugestion
    bl copy_str

    cmp x27, #1
    beq write_sug
    ldr x1, =str_no_action
    mov x2, len_no_action
    bl copy_str
    b finish_output

write_sug:
    add x6, x21, x24
    add x6, x6, x25
    cmp x6, #0
    bne parse_sug
    ldr x1, =str_no_action
    mov x2, len_no_action
    bl copy_str
    b finish_output

parse_sug:
    mov x8, #0

    cmp x21, #1
    bne sug_luz
    ldr x1, =str_encender_bomba
    mov x2, len_encender_bomba
    bl copy_str
    mov x8, #1

sug_luz:
    cmp x24, #1
    bne sug_vent
    cmp x8, #0
    beq sug_luz_direct
    ldr x1, =str_y
    mov x2, len_y
    bl copy_str
sug_luz_direct:
    ldr x1, =str_encender_luz
    mov x2, len_encender_luz
    bl copy_str
    mov x8, #1

sug_vent:
    cmp x25, #1
    bne finish_output
    cmp x8, #0
    beq sug_vent_direct
    ldr x1, =str_y
    mov x2, len_y
    bl copy_str
sug_vent_direct:
    ldr x1, =str_encender_vent
    mov x2, len_encender_vent
    bl copy_str

finish_output:
    ldr x1, =str_newline
    mov x2, #1
    bl copy_str

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
