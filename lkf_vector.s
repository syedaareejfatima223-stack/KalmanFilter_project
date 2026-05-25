.section .text
.align 2

.globl matvec_vec
.globl mat_add_vec

# Vectorized Matrix-Vector Multiplication (y = A * x)
matvec_vec:
    # a0: out, a1: mat, a2: vec, a3: N
mv_loop:
    vsetvli t0, a3, e64, m1, ta, ma   # t0 = VL (elements processed)
    vle64.v v1, (a1)                  # Load A
    vle64.v v2, (a2)                  # Load x
    vfmul.vv v3, v1, v2               # Multiply
    vse64.v v3, (a0)                  # Store y
    
    slli t1, t0, 3                    # t1 = VL * 8 bytes
    add a0, a0, t1                    # Increment pointers by BYTES
    add a1, a1, t1
    add a2, a2, t1
    sub a3, a3, t0                    # Decrement counter by ELEMENTS
    bnez a3, mv_loop
    ret

# Vectorized Matrix Addition (C = A + B)
mat_add_vec:
    vsetvli t0, a3, e64, m1, ta, ma
    vle64.v v1, (a1)
    vle64.v v2, (a2)
    vfadd.vv v3, v1, v2
    vse64.v v3, (a0)
    slli t1, t0, 3
    add a0, a0, t1
    add a1, a1, t1
    add a2, a2, t1
    sub a3, a3, t0
    bnez a3, mat_add_vec
    ret
