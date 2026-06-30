.text
.global calcular_tendencia
calcular_tendencia:
    cmp x1, #2
    blt tendencia_cero
    mov x2, #0          // suma acumulada de diferencias
    mov x3, #1          // indice i (empezamos en 1)
    ldr x4, [x0, #0]    // X_(i-1)  (inicial = array[0])

tendencia_loop:
    cmp x3, x1
    bge tendencia_fin

    mov x7, #8
    mul x7, x3, x7
    add x7, x0, x7
    ldr x5, [x7]
    sub x6, x5, x4              // DIF_i = X_i - X_(i-1)
    add x2, x2, x6
    mov x4, x5                  // actualizar anterior
    add x3, x3, #1
    b tendencia_loop

tendencia_fin:
    mov x0, x2
    ret

tendencia_cero:
    mov x0, #0
    ret
