.section .text
.align 2

# Exporting these so lkf_driver.c can find them
.globl lkf_predict
.globl lkf_update
.globl matvec_vec
.globl mat_add_vec

# --- 1. LKF Predict Function ---
lkf_predict:
    addi sp, sp, -16
    sd ra, 8(sp)
    # Your predict logic here
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# --- 2. LKF Update Function ---
lkf_update:
    addi sp, sp, -16
    sd ra, 8(sp)
    # Your update logic here
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# --- 3. Vectorized Matrix-Vector Multiplication ---
# a0: out, a1: mat, a2: vec, a3: N
matvec_vec:
mv_loop:
    vsetvli t0, a3, e64, m1, ta, ma
    vle64.v v1, (a1)
    vle64.v v2, (a2)
    vfmul.vv v3, v1, v2
    vse64.v v3, (a0)
    
    slli t1, t0, 3          # VL * 8 bytes
    add a0, a0, t1          # Move pointer by vector length
    add a1, a1, t1
    add a2, a2, t1
    sub a3, a3, t0          # Reduce count by vector length
    bnez a3, mv_loop
    ret

# --- 4. Vectorized Addition ---
mat_add_vec:
add_loop:
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
    bnez a3, add_loop
    ret
