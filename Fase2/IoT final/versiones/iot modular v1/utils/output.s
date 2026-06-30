// x0 = destino, x1 = origen, x2 = longitud
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
