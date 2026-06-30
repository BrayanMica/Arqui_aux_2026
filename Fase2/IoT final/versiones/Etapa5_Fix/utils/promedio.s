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

    mov x5, #8
    mul x6, x3, x5
    add x6, x0, x6
    ldr x4, [x6]
    add x2, x2, x4
    add x3, x3, #1
    b promedio_loop

promedio_div:
    udiv x0, x2, x1
    ret

promedio_cero:
    mov x0, #0
    ret
