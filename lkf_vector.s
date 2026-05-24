# --- lkf_vector.s ---
# Vectorized implementation of LKF Kernels
# N = 276, M = 69

.section .text
.globl vector_mat_vec_mul
.globl vector_mat_add

# 1. Vectorized Matrix-Vector Multiplication: y = A * x
# a0: out_y, a1: mat_A, a2: vec_x, a3: N
vector_mat_vec_mul:
    li t0, 0                # i = 0 (row counter)
row_loop:
    beq t0, a3, end_rows
    
    fmv.d.x f0, zero        # Clear scalar accumulator
    vsetvli t1, a3, e64, m1, ta, ma
    vfmv.v.f v0, f0         # Clear vector accumulator v0

    mv t2, a3               # k = remaining columns
    mv t3, a2               # t3 = ptr to vec_x
    mul t4, t0, a3
    slli t4, t4, 3
    add t4, a1, t4          # t4 = ptr to mat_A[i][0]

col_loop:
    vsetvli t1, t2, e64, m1, ta, ma
    vle64.v v1, (t4)        # Load A[i][k...]
    vle64.v v2, (t3)        # Load x[k...]
    
    vfmul.vv v1, v1, v2     # v1 = A * x
    # vfredosum.vs for numerical reproducibility (Section 2.2)
    vfredosum.vs v0, v1, v0 

    slli t5, t1, 3          # VL * 8
    add t4, t4, t5
    add t3, t3, t5
    sub t2, t2, t1
    bnez t2, col_loop

    vfmv.f.s f1, v0         # Extract result
    fsd f1, 0(a0)           # Store to out_y[i]
    
    addi a0, a0, 8
    addi t0, t0, 1
    j row_loop
end_rows:
    ret

# 2. Vectorized Matrix Addition: C = A + B
# a0: mat_C, a1: mat_A, a2: mat_B, a3: TotalElements (N*N)
vector_mat_add:
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
    bnez a3, vector_mat_add
    ret
