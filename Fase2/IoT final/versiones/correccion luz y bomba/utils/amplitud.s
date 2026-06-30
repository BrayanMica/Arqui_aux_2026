.text
.global calcular_amplitud
calcular_amplitud:
    cmp x1, #0
    beq amplitud_cero

    ldr x2, [x0, #0]
    ldr x3, [x0, #0]
    mov x4, #1

amplitud_loop:
    cmp x4, x1
    bge amplitud_fin

    mov x6, #8
    mul x6, x4, x6
    add x6, x0, x6
    ldr x5, [x6]

    cmp x5, x2
    bge amplitud_no_min
    mov x2, x5

amplitud_no_min:
    cmp x5, x3
    ble amplitud_no_max
    mov x3, x5

amplitud_no_max:
    add x4, x4, #1
    b amplitud_loop

amplitud_fin:
    sub x0, x3, x2
    ret

amplitud_cero:
    mov x0, #0
    ret
