.data

gas_array:      .quad 0, 0, 0, 0, 0
gas_count:      .quad 0
soil1_array:    .quad 0, 0, 0, 0, 0
soil1_count:    .quad 0
luz_array:      .quad 0, 0, 0, 0, 0
luz_count:      .quad 0
temp_array:     .quad 0, 0, 0, 0, 0
temp_count:     .quad 0
hum_array:      .quad 0, 0, 0, 0, 0
hum_count:      .quad 0

gas_avg:        .quad 0
gas_trend:      .quad 0
gas_amp:        .quad 0
soil1_avg:      .quad 0
soil1_trend:    .quad 0
soil1_amp:      .quad 0
luz_avg:        .quad 0
luz_trend:      .quad 0
luz_amp:        .quad 0
temp_avg:       .quad 0
temp_trend:     .quad 0
temp_amp:       .quad 0
hum_avg:        .quad 0
hum_trend:      .quad 0
hum_amp:        .quad 0

umbral_gas_alto:    .quad 300
umbral_gas_amp:     .quad 100
umbral_soil_bajo:   .quad 25
umbral_soil_amp:    .quad 10
umbral_luz_baja:    .quad 500
umbral_luz_amp:     .quad 50
umbral_temp_alta:   .quad 28

msg_status_ok:
    .ascii "STATUS=OK\n"
    len_status_ok = . - msg_status_ok

msg_act_alarm:
    .ascii "ACTION=ALARM_ON\n"
    len_act_alarm = . - msg_act_alarm
msg_act_riego:
    .ascii "ACTION=RIEGO_1_ON\n"
    len_act_riego = . - msg_act_riego
msg_act_light:
    .ascii "ACTION=LIGHT_ON\n"
    len_act_light = . - msg_act_light
msg_act_fan:
    .ascii "ACTION=FAN_ON\n"
    len_act_fan = . - msg_act_fan
msg_act_led_green:
    .ascii "ACTION=LED_GREEN\n"
    len_act_led_green = . - msg_act_led_green
msg_act_led_red:
    .ascii "ACTION=LED_RED\n"
    len_act_led_red = . - msg_act_led_red

msg_reason_gas_avg:
    .ascii "REASON=GAS_AVG_HIGH\n"
    len_reason_gas_avg = . - msg_reason_gas_avg
msg_reason_gas_amp:
    .ascii "REASON=GAS_AMP_HIGH\n"
    len_reason_gas_amp = . - msg_reason_gas_amp
msg_reason_soil:
    .ascii "REASON=SOIL_LOW_AND_STABLE\n"
    len_reason_soil = . - msg_reason_soil
msg_reason_luz:
    .ascii "REASON=LUZ_LOW_AND_STABLE\n"
    len_reason_luz = . - msg_reason_luz
msg_reason_temp:
    .ascii "REASON=TEMP_HIGH_AND_UP\n"
    len_reason_temp = . - msg_reason_temp
msg_reason_normal:
    .ascii "REASON=NORMAL\n"
    len_reason_normal = . - msg_reason_normal

msg_gas_avg:    .ascii "GAS_AVG="
    len_gas_avg = . - msg_gas_avg
msg_gas_trend:  .ascii "GAS_TREND="
    len_gas_trend = . - msg_gas_trend
msg_gas_amp:    .ascii "GAS_AMP="
    len_gas_amp = . - msg_gas_amp

msg_soil1_avg:    .ascii "SOIL1_AVG="
    len_soil1_avg = . - msg_soil1_avg
msg_soil1_trend:  .ascii "SOIL1_TREND="
    len_soil1_trend = . - msg_soil1_trend
msg_soil1_amp:    .ascii "SOIL1_AMP="
    len_soil1_amp = . - msg_soil1_amp

msg_luz_avg:    .ascii "LUZ_AVG="
    len_luz_avg = . - msg_luz_avg
msg_luz_trend:  .ascii "LUZ_TREND="
    len_luz_trend = . - msg_luz_trend
msg_luz_amp:    .ascii "LUZ_AMP="
    len_luz_amp = . - msg_luz_amp

msg_temp_avg:    .ascii "TEMP_AVG="
    len_temp_avg = . - msg_temp_avg
msg_temp_trend:  .ascii "TEMP_TREND="
    len_temp_trend = . - msg_temp_trend
msg_temp_amp:    .ascii "TEMP_AMP="
    len_temp_amp = . - msg_temp_amp

msg_hum_avg:    .ascii "HUM_AVG="
    len_hum_avg = . - msg_hum_avg
msg_hum_trend:  .ascii "HUM_TREND="
    len_hum_trend = . - msg_hum_trend
msg_hum_amp:    .ascii "HUM_AMP="
    len_hum_amp = . - msg_hum_amp

msg_up:
    .ascii "UP\n"
    len_up = . - msg_up
msg_down:
    .ascii "DOWN\n"
    len_down = . - msg_down
msg_stable:
    .ascii "STABLE\n"
    len_stable = . - msg_stable

msg_newline:
    .ascii "\n"

msg_end:
    .ascii "END\n"
    len_end = . - msg_end

msg_error:
    .ascii "STATUS=ERROR\nERROR=INVALID_INPUT\nEND\n"
    len_error = . - msg_error

.bss

input_buffer:
    .skip 128

num_buffer:
    .skip 32

.text
.global _start

.include "utils/atoi.s"
.include "utils/array.s"
.include "utils/promedio.s"
.include "utils/tendencia.s"
.include "utils/amplitud.s"
.include "utils/print_uint.s"

_start:

main_loop:
    mov x0, #0
    ldr x1, =input_buffer
    mov x2, #128
    mov x8, #63
    svc #0

    cmp x0, #0
    ble end_program

    ldr x21, =input_buffer
    mov x5, #10

    bl atoi_csv
    cbz x7, print_error
    mov x19, x10

    bl atoi_csv
    cbz x7, print_error
    mov x20, x10

    bl atoi_csv
    cbz x7, print_error
    mov x24, x10

    bl atoi_csv
    cbz x7, print_error
    mov x25, x10

    bl atoi_csv
    cbz x7, print_error
    mov x26, x10

    mov x0, x19
    ldr x1, =gas_count
    ldr x3, =gas_array
    bl guardar_dato

    mov x0, x20
    ldr x1, =soil1_count
    ldr x3, =soil1_array
    bl guardar_dato

    mov x0, x24
    ldr x1, =luz_count
    ldr x3, =luz_array
    bl guardar_dato

    mov x0, x25
    ldr x1, =temp_count
    ldr x3, =temp_array
    bl guardar_dato

    mov x0, x26
    ldr x1, =hum_count
    ldr x3, =hum_array
    bl guardar_dato

    ldr x0, =gas_array
    ldr x1, =gas_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x1, =gas_avg
    str x0, [x1]

    ldr x0, =gas_array
    ldr x1, =gas_count
    ldr x1, [x1]
    bl calcular_tendencia
    ldr x1, =gas_trend
    str x0, [x1]

    ldr x0, =gas_array
    ldr x1, =gas_count
    ldr x1, [x1]
    bl calcular_amplitud
    ldr x1, =gas_amp
    str x0, [x1]

    ldr x0, =soil1_array
    ldr x1, =soil1_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x1, =soil1_avg
    str x0, [x1]

    ldr x0, =soil1_array
    ldr x1, =soil1_count
    ldr x1, [x1]
    bl calcular_tendencia
    ldr x1, =soil1_trend
    str x0, [x1]

    ldr x0, =soil1_array
    ldr x1, =soil1_count
    ldr x1, [x1]
    bl calcular_amplitud
    ldr x1, =soil1_amp
    str x0, [x1]

    ldr x0, =luz_array
    ldr x1, =luz_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x1, =luz_avg
    str x0, [x1]

    ldr x0, =luz_array
    ldr x1, =luz_count
    ldr x1, [x1]
    bl calcular_tendencia
    ldr x1, =luz_trend
    str x0, [x1]

    ldr x0, =luz_array
    ldr x1, =luz_count
    ldr x1, [x1]
    bl calcular_amplitud
    ldr x1, =luz_amp
    str x0, [x1]

    ldr x0, =temp_array
    ldr x1, =temp_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x1, =temp_avg
    str x0, [x1]

    ldr x0, =temp_array
    ldr x1, =temp_count
    ldr x1, [x1]
    bl calcular_tendencia
    ldr x1, =temp_trend
    str x0, [x1]

    ldr x0, =temp_array
    ldr x1, =temp_count
    ldr x1, [x1]
    bl calcular_amplitud
    ldr x1, =temp_amp
    str x0, [x1]

    ldr x0, =hum_array
    ldr x1, =hum_count
    ldr x1, [x1]
    bl calcular_promedio
    ldr x1, =hum_avg
    str x0, [x1]

    ldr x0, =hum_array
    ldr x1, =hum_count
    ldr x1, [x1]
    bl calcular_tendencia
    ldr x1, =hum_trend
    str x0, [x1]

    ldr x0, =hum_array
    ldr x1, =hum_count
    ldr x1, [x1]
    bl calcular_amplitud
    ldr x1, =hum_amp
    str x0, [x1]

    mov x0, #1
    ldr x1, =msg_status_ok
    mov x2, len_status_ok
    mov x8, #64
    svc #0

    ldr x0, =gas_avg
    ldr x0, [x0]
    ldr x1, =umbral_gas_alto
    ldr x1, [x1]
    cmp x0, x1
    bge decide_alarm_avg

    ldr x0, =gas_amp
    ldr x0, [x0]
    ldr x1, =umbral_gas_amp
    ldr x1, [x1]
    cmp x0, x1
    bge decide_alarm_amp

    ldr x0, =soil1_avg
    ldr x0, [x0]
    ldr x1, =umbral_soil_bajo
    ldr x1, [x1]
    cmp x0, x1
    bge check_luz

    ldr x0, =soil1_amp
    ldr x0, [x0]
    ldr x1, =umbral_soil_amp
    ldr x1, [x1]
    cmp x0, x1
    bge check_luz
    b decide_riego

check_luz:
    ldr x0, =luz_avg
    ldr x0, [x0]
    ldr x1, =umbral_luz_baja
    ldr x1, [x1]
    cmp x0, x1
    bge check_fan

    ldr x0, =luz_amp
    ldr x0, [x0]
    ldr x1, =umbral_luz_amp
    ldr x1, [x1]
    cmp x0, x1
    bge check_fan
    b decide_luz

check_fan:
    ldr x0, =temp_avg
    ldr x0, [x0]
    ldr x1, =umbral_temp_alta
    ldr x1, [x1]
    cmp x0, x1
    blt decide_led_green

    ldr x0, =temp_trend
    ldr x0, [x0]
    cmp x0, #0
    ble decide_led_green
    b decide_fan

decide_alarm_avg:
    mov x0, #1
    ldr x1, =msg_act_alarm
    mov x2, len_act_alarm
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_act_led_red
    mov x2, len_act_led_red
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_reason_gas_avg
    mov x2, len_reason_gas_avg
    mov x8, #64
    svc #0
    b print_indicators

decide_alarm_amp:
    mov x0, #1
    ldr x1, =msg_act_alarm
    mov x2, len_act_alarm
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_act_led_red
    mov x2, len_act_led_red
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_reason_gas_amp
    mov x2, len_reason_gas_amp
    mov x8, #64
    svc #0
    b print_indicators

decide_riego:
    mov x0, #1
    ldr x1, =msg_act_riego
    mov x2, len_act_riego
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_reason_soil
    mov x2, len_reason_soil
    mov x8, #64
    svc #0
    b print_indicators

decide_luz:
    mov x0, #1
    ldr x1, =msg_act_light
    mov x2, len_act_light
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_reason_luz
    mov x2, len_reason_luz
    mov x8, #64
    svc #0
    b print_indicators

decide_fan:
    mov x0, #1
    ldr x1, =msg_act_fan
    mov x2, len_act_fan
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_reason_temp
    mov x2, len_reason_temp
    mov x8, #64
    svc #0
    b print_indicators

decide_led_green:
    mov x0, #1
    ldr x1, =msg_act_led_green
    mov x2, len_act_led_green
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =msg_reason_normal
    mov x2, len_reason_normal
    mov x8, #64
    svc #0

print_indicators:
    mov x0, #1
    ldr x1, =msg_gas_avg
    mov x2, len_gas_avg
    mov x8, #64
    svc #0
    ldr x0, =gas_avg
    ldr x0, [x0]
    bl print_uint
    mov x0, #1
    ldr x1, =msg_newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =msg_gas_trend
    mov x2, len_gas_trend
    mov x8, #64
    svc #0
    ldr x0, =gas_trend
    ldr x0, [x0]
    bl print_trend

    mov x0, #1
    ldr x1, =msg_gas_amp
    mov x2, len_gas_amp
    mov x8, #64
    svc #0
    ldr x0, =gas_amp
    ldr x0, [x0]
    bl print_uint
    mov x0, #1
    ldr x1, =msg_newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =msg_soil1_avg
    mov x2, len_soil1_avg
    mov x8, #64
    svc #0
    ldr x0, =soil1_avg
    ldr x0, [x0]
    bl print_uint
    mov x0, #1
    ldr x1, =msg_newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =msg_soil1_trend
    mov x2, len_soil1_trend
    mov x8, #64
    svc #0
    ldr x0, =soil1_trend
    ldr x0, [x0]
    bl print_trend

    mov x0, #1
    ldr x1, =msg_soil1_amp
    mov x2, len_soil1_amp
    mov x8, #64
    svc #0
    ldr x0, =soil1_amp
    ldr x0, [x0]
    bl print_uint
    mov x0, #1
    ldr x1, =msg_newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =msg_luz_avg
    mov x2, len_luz_avg
    mov x8, #64
    svc #0
    ldr x0, =luz_avg
    ldr x0, [x0]
    bl print_uint
    mov x0, #1
    ldr x1, =msg_newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =msg_luz_trend
    mov x2, len_luz_trend
    mov x8, #64
    svc #0
    ldr x0, =luz_trend
    ldr x0, [x0]
    bl print_trend

    mov x0, #1
    ldr x1, =msg_luz_amp
    mov x2, len_luz_amp
    mov x8, #64
    svc #0
    ldr x0, =luz_amp
    ldr x0, [x0]
    bl print_uint
    mov x0, #1
    ldr x1, =msg_newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =msg_temp_avg
    mov x2, len_temp_avg
    mov x8, #64
    svc #0
    ldr x0, =temp_avg
    ldr x0, [x0]
    bl print_uint
    mov x0, #1
    ldr x1, =msg_newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =msg_temp_trend
    mov x2, len_temp_trend
    mov x8, #64
    svc #0
    ldr x0, =temp_trend
    ldr x0, [x0]
    bl print_trend

    mov x0, #1
    ldr x1, =msg_temp_amp
    mov x2, len_temp_amp
    mov x8, #64
    svc #0
    ldr x0, =temp_amp
    ldr x0, [x0]
    bl print_uint
    mov x0, #1
    ldr x1, =msg_newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =msg_hum_avg
    mov x2, len_hum_avg
    mov x8, #64
    svc #0
    ldr x0, =hum_avg
    ldr x0, [x0]
    bl print_uint
    mov x0, #1
    ldr x1, =msg_newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =msg_hum_trend
    mov x2, len_hum_trend
    mov x8, #64
    svc #0
    ldr x0, =hum_trend
    ldr x0, [x0]
    bl print_trend

    mov x0, #1
    ldr x1, =msg_hum_amp
    mov x2, len_hum_amp
    mov x8, #64
    svc #0
    ldr x0, =hum_amp
    ldr x0, [x0]
    bl print_uint
    mov x0, #1
    ldr x1, =msg_newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =msg_end
    mov x2, len_end
    mov x8, #64
    svc #0

    b main_loop

print_trend:
    cmp x0, #0
    bgt pt_up
    blt pt_down

    mov x0, #1
    ldr x1, =msg_stable
    mov x2, len_stable
    mov x8, #64
    svc #0
    ret

pt_up:
    mov x0, #1
    ldr x1, =msg_up
    mov x2, len_up
    mov x8, #64
    svc #0
    ret

pt_down:
    mov x0, #1
    ldr x1, =msg_down
    mov x2, len_down
    mov x8, #64
    svc #0
    ret

print_error:
    mov x0, #1
    ldr x1, =msg_error
    mov x2, len_error
    mov x8, #64
    svc #0
    b main_loop

end_program:
    mov x0, #0
    mov x8, #93
    svc #0
