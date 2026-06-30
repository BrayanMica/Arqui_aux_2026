.text

.global calcular_promedio
calcular_promedio:
    cmp x1, #0
    beq promedio_cero

    mov x2, #0          // suma acumulada
    mov x3, #0          // índice

promedio_loop:
    cmp x3, x1
    beq promedio_div

    ldr x4, [x0, x3, lsl #3]   // array[index]
    add x2, x2, x4
    add x3, x3, #1
    b promedio_loop

promedio_div:
    udiv x0, x2, x1
    ret

promedio_cero:
    mov x0, #0
    ret