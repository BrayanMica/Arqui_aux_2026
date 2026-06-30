print_uint:
    ldr x1, =num_buffer
    add x1, x1, #31

    mov w2, #0
    strb w2, [x1]

    mov x3, #10
    mov x4, #0

    cmp x0, #0
    bne pu_convert_loop

    sub x1, x1, #1
    mov w2, '0'
    strb w2, [x1]
    mov x4, #1
    b pu_write_number

pu_convert_loop:
    udiv x9, x0, x3
    msub x6, x9, x3, x0

    add x6, x6, '0'

    sub x1, x1, #1
    strb w6, [x1]

    add x4, x4, #1

    mov x0, x9
    cbnz x0, pu_convert_loop

pu_write_number:
    mov x0, #1
    mov x2, x4
    mov x8, #64
    svc #0

    ret
