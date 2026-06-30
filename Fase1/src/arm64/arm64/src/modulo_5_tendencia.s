// modulo_5_tendencia.s

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
outfile:  .asciz "resultado_tendencia.txt"

str_mod:  .ascii "MODULE=ADVANCED_TREND\n"
len_mod = . - str_mod
str_tot:  .ascii "TOTAL_VALUES=30\n"
len_tot = . - str_tot
str_inc:  .ascii "INCREMENTS="
len_inc = . - str_inc
str_dec:  .ascii "DECREMENTS="
len_dec = . - str_dec
str_maxup:.ascii "MAX_UP_STREAK="
len_maxup = . - str_maxup
str_maxdn:.ascii "MAX_DOWN_STREAK="
len_maxdn = . - str_maxdn
str_accum:.ascii "ACCUM_DIFF="
len_accum = . - str_accum
str_trend:.ascii "TREND="
len_trend = . - str_trend

val_up:   .ascii "UP\n"
len_up = . - val_up
val_down: .ascii "DOWN\n"
len_down = . - val_down
val_stable:.ascii "STABLE\n"
len_stable = . - val_stable

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
    // TENDENCIA
    // -------------------------------------------------------------
    ldr x27, =data_array
    mov x28, #1 // iterador desde i=1

    mov x19, #0 // INCREMENTS
    mov x20, #0 // DECREMENTS
    
    mov x21, #0 // Current Up Streak
    mov x22, #0 // Max Up Streak
    mov x23, #0 // Current Down Streak
    mov x24, #0 // Max Down Streak
    
    mov x25, #0 // ACCUM_DIFF

trend_loop:
    cmp x28, #30
    b.ge trend_done

    sub x29, x28, #1 // i-1
    ldr x10, [x27, x29, LSL #3] // X_{i-1}
    ldr x11, [x27, x28, LSL #3] // X_i

    sub x12, x11, x10 // DIF_i = X_i - X_{i-1}
    add x25, x25, x12 // ACCUM_DIFF += DIF_i

    cmp x12, #0
    bgt trend_up
    blt trend_down

    // stable (no increment or decrement streak continues)
    mov x21, #0
    mov x23, #0
    b trend_next

trend_up:
    add x19, x19, #1 // INCREMENTS++
    add x21, x21, #1 // Curr Up Streak++
    mov x23, #0      // Curr Down Streak = 0
    cmp x21, x22
    b.le trend_next
    mov x22, x21     // Max Up Streak = Curr Up Streak
    b trend_next

trend_down:
    add x20, x20, #1 // DECREMENTS++
    add x23, x23, #1 // Curr Down Streak++
    mov x21, #0      // Curr Up Streak = 0
    cmp x23, x24
    b.le trend_next
    mov x24, x23     // Max Down Streak = Curr Down Streak

trend_next:
    add x28, x28, #1
    b trend_loop

trend_done:
    // x19: INCREMENTS
    // x20: DECREMENTS
    // x22: MAX_UP_STREAK
    // x24: MAX_DOWN_STREAK
    // x25: ACCUM_DIFF

    // ESCRITURA A ARCHIVO
    ldr x0, =outfile
    mov x1, #577  // O_WRONLY | O_CREAT | O_TRUNC
    mov x2, #438
    bl open_file
    mov x28, x0 // output fd

    mov x0, x28
    ldr x1, =str_mod
    mov x2, len_mod
    bl write_file

    mov x0, x28
    ldr x1, =str_tot
    mov x2, len_tot
    bl write_file

    mov x0, x28
    ldr x1, =str_inc
    mov x2, len_inc
    bl write_file

    mov x0, x19
    ldr x1, =str_buffer
    bl itoa
    mov x2, x2
    mov x0, x28
    ldr x1, =str_buffer
    bl write_file

    mov x0, x28
    ldr x1, =nl
    mov x2, #1
    bl write_file

    mov x0, x28
    ldr x1, =str_dec
    mov x2, len_dec
    bl write_file

    mov x0, x20
    ldr x1, =str_buffer
    bl itoa
    mov x2, x2
    mov x0, x28
    ldr x1, =str_buffer
    bl write_file

    mov x0, x28
    ldr x1, =nl
    mov x2, #1
    bl write_file

    mov x0, x28
    ldr x1, =str_maxup
    mov x2, len_maxup
    bl write_file

    mov x0, x22
    ldr x1, =str_buffer
    bl itoa
    mov x2, x2
    mov x0, x28
    ldr x1, =str_buffer
    bl write_file

    mov x0, x28
    ldr x1, =nl
    mov x2, #1
    bl write_file

    mov x0, x28
    ldr x1, =str_maxdn
    mov x2, len_maxdn
    bl write_file

    mov x0, x24
    ldr x1, =str_buffer
    bl itoa
    mov x2, x2
    mov x0, x28
    ldr x1, =str_buffer
    bl write_file

    mov x0, x28
    ldr x1, =nl
    mov x2, #1
    bl write_file

    mov x0, x28
    ldr x1, =str_accum
    mov x2, len_accum
    bl write_file

    mov x0, x25
    ldr x1, =str_buffer
    bl itoa
    mov x2, x2
    mov x0, x28
    ldr x1, =str_buffer
    bl write_file

    mov x0, x28
    ldr x1, =nl
    mov x2, #1
    bl write_file

    // TREND
    mov x0, x28
    ldr x1, =str_trend
    mov x2, len_trend
    bl write_file

    cmp x25, #0
    beq print_stable
    bgt print_up

print_down:
    mov x0, x28
    ldr x1, =val_down
    mov x2, len_down
    bl write_file
    b close_out

print_up:
    mov x0, x28
    ldr x1, =val_up
    mov x2, len_up
    bl write_file
    b close_out

print_stable:
    mov x0, x28
    ldr x1, =val_stable
    mov x2, len_stable
    bl write_file

close_out:
    mov x0, x28
    bl close_file

    bl exit_program

fail_arg:
    mov x0, #1
    bl exit_program
