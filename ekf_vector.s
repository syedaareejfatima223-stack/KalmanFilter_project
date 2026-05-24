# --- ekf_vector.s ---
# Vectorized implementation of EKF Kernels

.section .text
.globl vector_ekf_predict_p
.globl vector_scale_mat

# 1. P = F * P * F' + Q (Simplified Part: P = F * P_scalar_scale)
# Illustrates vfmacc.vf (Fused Multiply-Accumulate Vector-Scalar)
# a0: mat_P, a1: mat_F, fa0: scalar_scale, a2: total_elements
vector_scale_mat:
v_scale_loop:
    vsetvli t0, a2, e64, m1, ta, ma
    vle64.v v1, (a1)
    vfmul.vf v2, v1, fa0    # Vector * Scalar
    vse64.v v2, (a0)
    
    slli t1, t0, 3
    add a0, a0, t1
    add a1, a1, t1
    sub a2, a2, t0
    bnez a2, v_scale_loop
    ret

# 2. Strided Load Example (for Transpose access in EKF)
# a0: out_vec, a1: mat_src, a2: stride_in_elements, a3: VL
.globl vector_load_column
vector_load_column:
    slli t0, a2, 3          # stride in bytes = elements * 8
    vsetvli t1, a3, e64, m1, ta, ma
    vlse64.v v1, (a1), t0   # Strided load: loads a column as a vector
    vse64.v v1, (a0)
    ret
