.section .text
.align 2

# Global Math functions
.globl mat_add_vec
.globl matmul_vec
.globl matvec_vec

# --- Vectorized Matrix-Vector Multiplication (y = A * x) ---
# a0: out, a1: mat, a2: vec, a3: N
matvec_vec:
    vsetvli t0, a3, e64, m1, ta, ma
    vle64.v v1, (a1)
    vle64.v v2, (a2)
    vfmul.vv v3, v1, v2
    vse64.v v3, (a0)
    
    slli t1, t0, 3      # VL * 8 bytes
    add a0, a0, t1      # Move pointers by VL
    add a1, a1, t1
    add a2, a2, t1
    sub a3, a3, t0      # Decrease count by VL
    bnez a3, matvec_vec
    ret

# --- Vectorized Matrix Addition (C = A + B) ---
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

# (Add your other LKF logic below)
