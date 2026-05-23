# ===========================================================
#  ekf_vector.s  -  RISC-V Vector (RVV) Assembly: EKF Core
#  Milestone 4 - Vectorised implementation
#
#  Vectorised functions:
#    mat_add_vec      - C[n] = A[n] + B[n]  (shared with LKF)
#    mat_sub_vec      - C[n] = A[n] - B[n]
#    mat_scale_vec    - A[n] *= scalar
#    mat_dot_vec      - dot product with reduction
#    vec_axpy_vec     - y += alpha*x
#    matvec_vec       - y = A*x (general)
#    matmul_vec       - C = A*B (general)
#    predict_x_vec    - vectorised constant-jerk F*x per joint
#    ekf_update_x_vec - x12 += K(12x3) * innov3, vectorised
#    build_jblock_vec - 3x12 Jacobian block (scalar, unchanged)
#    h_func_asm       - spherical measurement (scalar, unchanged)
#    atan2_asm        - full atan2 (scalar, unchanged)
#    atan_poly_asm    - 9-term minimax atan (scalar, unchanged)
#    wrap_angle_asm   - angle wrapping (scalar, unchanged)
#    inv3x3_asm       - exact 3x3 Cramer inversion (scalar)
#
#  RISC-V ABI LP64D + V extension (SEW=64 throughout).
# ===========================================================

    .section .text
    .align 2

# ===========================================================
#  VECTORISED KERNELS
# ===========================================================

# -----------------------------------------------------------
# mat_add_vec(double *C, const double *A, const double *B, int n)
# -----------------------------------------------------------
    .globl mat_add_vec
    .type  mat_add_vec, @function
mat_add_vec:
    mv      t0, a3
ekf_mav_loop:
    beqz    t0, ekf_mav_done
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (a1)
    vle64.v v1, (a2)
    vfadd.vv v2, v0, v1
    vse64.v v2, (a0)
    slli    t2, t1, 3
    add     a0, a0, t2
    add     a1, a1, t2
    add     a2, a2, t2
    sub     t0, t0, t1
    j       ekf_mav_loop
ekf_mav_done:
    ret

# -----------------------------------------------------------
# mat_sub_vec(double *C, const double *A, const double *B, int n)
# -----------------------------------------------------------
    .globl mat_sub_vec
    .type  mat_sub_vec, @function
mat_sub_vec:
    mv      t0, a3
ekf_msv_loop:
    beqz    t0, ekf_msv_done
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (a1)
    vle64.v v1, (a2)
    vfsub.vv v2, v0, v1
    vse64.v v2, (a0)
    slli    t2, t1, 3
    add     a0, a0, t2
    add     a1, a1, t2
    add     a2, a2, t2
    sub     t0, t0, t1
    j       ekf_msv_loop
ekf_msv_done:
    ret

# -----------------------------------------------------------
# mat_scale_vec(double *A, double scalar, int n)
#   fa0=scalar, a1=n
# -----------------------------------------------------------
    .globl mat_scale_vec
    .type  mat_scale_vec, @function
mat_scale_vec:
    mv      t0, a1
ekf_mscv_loop:
    beqz    t0, ekf_mscv_done
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (a0)
    vfmul.vf v0, v0, fa0
    vse64.v v0, (a0)
    slli    t2, t1, 3
    add     a0, a0, t2
    sub     t0, t0, t1
    j       ekf_mscv_loop
ekf_mscv_done:
    ret

# -----------------------------------------------------------
# mat_dot_vec(const double *A, const double *B, int n) -> fa0
# -----------------------------------------------------------
    .globl mat_dot_vec
    .type  mat_dot_vec, @function
mat_dot_vec:
    fmv.d.x fa0, zero
    mv      t0, a2
    beqz    t0, ekf_mdv_done
    vsetvli t1, t0, e64, m1, ta, ma
    vfmv.v.f v4, fa0
ekf_mdv_loop:
    beqz    t0, ekf_mdv_reduce
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (a0)
    vle64.v v1, (a1)
    vfmul.vv v2, v0, v1
    vfredosum.vs v4, v2, v4
    slli    t2, t1, 3
    add     a0, a0, t2
    add     a1, a1, t2
    sub     t0, t0, t1
    j       ekf_mdv_loop
ekf_mdv_reduce:
    vfmv.f.s fa0, v4
ekf_mdv_done:
    ret

# -----------------------------------------------------------
# vec_axpy_vec(double *y, double alpha, const double *x, int n)
#   a0=y, fa0=alpha, a2=x, a3=n
# -----------------------------------------------------------
    .globl vec_axpy_vec
    .type  vec_axpy_vec, @function
vec_axpy_vec:
    mv      t0, a3
ekf_vav_loop:
    beqz    t0, ekf_vav_done
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (a2)
    vle64.v v1, (a0)
    vfmacc.vf v1, fa0, v0
    vse64.v v1, (a0)
    slli    t2, t1, 3
    add     a0, a0, t2
    add     a2, a2, t2
    sub     t0, t0, t1
    j       ekf_vav_loop
ekf_vav_done:
    ret

# -----------------------------------------------------------
# matvec_vec(double *y, const double *A, const double *x,
#            int rows, int cols)
#   y = A * x
#   a0=y, a1=A, a2=x, a3=rows, a4=cols
# -----------------------------------------------------------
    .globl matvec_vec
    .type  matvec_vec, @function
matvec_vec:
    addi    sp, sp, -16
    sd      ra,  8(sp)
    sd      s0,  0(sp)
    mv      s0, a0
    li      t6, 0
ekf_mvv_row:
    bge     t6, a3, ekf_mvv_done
    fmv.d.x fa0, zero
    vsetvli t1, a4, e64, m1, ta, ma
    vfmv.v.f v8, fa0

    mv      t0, a4
    mul     t3, t6, a4
    slli    t3, t3, 3
    add     t4, a1, t3
    mv      t5, a2

ekf_mvv_dot:
    beqz    t0, ekf_mvv_dot_done
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (t4)
    vle64.v v1, (t5)
    vfmul.vv v2, v0, v1
    vfredosum.vs v8, v2, v8
    slli    t2, t1, 3
    add     t4, t4, t2
    add     t5, t5, t2
    sub     t0, t0, t1
    j       ekf_mvv_dot
ekf_mvv_dot_done:
    vfmv.f.s fa0, v8
    slli    t2, t6, 3
    add     t2, s0, t2
    fsd     fa0, 0(t2)
    addi    t6, t6, 1
    j       ekf_mvv_row
ekf_mvv_done:
    ld      ra,  8(sp)
    ld      s0,  0(sp)
    addi    sp, sp, 16
    ret

# -----------------------------------------------------------
# matmul_vec(double *C, const double *A, const double *B,
#            int P, int Q, int R)
#   C = A*B
# -----------------------------------------------------------
    .globl matmul_vec
    .type  matmul_vec, @function
matmul_vec:
    addi    sp, sp, -32
    sd      ra, 24(sp)
    sd      s0, 16(sp)
    sd      s1,  8(sp)
    sd      s2,  0(sp)

    mv      s0, a0
    mv      s1, a1
    mv      s2, a2

    # Zero C: P*R doubles
    mul     t0, a3, a5
    slli    t0, t0, 3
ekf_mmv_zero:
    beqz    t0, ekf_mmv_zero_done
    addi    t0, t0, -8
    add     t1, s0, t0
    sd      zero, 0(t1)
    j       ekf_mmv_zero
ekf_mmv_zero_done:

    li      t6, 0
ekf_mmv_i:
    bge     t6, a3, ekf_mmv_done
    li      t5, 0
ekf_mmv_j:
    bge     t5, a5, ekf_mmv_i_next

    mul     t0, t6, a4
    slli    t0, t0, 3
    add     t0, s1, t0               # &A[i][0]

    slli    t1, t5, 3
    add     t1, s2, t1               # &B[0][j]
    slli    t2, a5, 3                # B col stride = R*8

    fmv.d.x fa0, zero
    vsetvli t3, a4, e64, m1, ta, ma
    vfmv.v.f v8, fa0

    mv      t4, a4
ekf_mmv_dot:
    beqz    t4, ekf_mmv_dot_done
    vsetvli t3, t4, e64, m1, ta, ma
    vle64.v  v0, (t0)
    vlse64.v v1, (t1), t2
    vfmul.vv v2, v0, v1
    vfredosum.vs v8, v2, v8
    slli    t9, t3, 3
    add     t0, t0, t9
    mul     t9, t3, t2
    add     t1, t1, t9
    sub     t4, t4, t3
    j       ekf_mmv_dot
ekf_mmv_dot_done:
    vfmv.f.s fa0, v8

    mul     t0, t6, a5
    add     t0, t0, t5
    slli    t0, t0, 3
    add     t0, s0, t0
    fsd     fa0, 0(t0)

    addi    t5, t5, 1
    j       ekf_mmv_j
ekf_mmv_i_next:
    addi    t6, t6, 1
    j       ekf_mmv_i
ekf_mmv_done:
    ld      ra, 24(sp)
    ld      s0, 16(sp)
    ld      s1,  8(sp)
    ld      s2,  0(sp)
    addi    sp, sp, 32
    ret

# -----------------------------------------------------------
# predict_x_vec
#   Vectorised constant-jerk F*x for one joint (12-state).
#   Same logic as lkf_vector.s predict_x_vec.
#
#   void predict_x_vec(double *x12, double dt)
#     a0 = double *x12,  fa0 = dt
# -----------------------------------------------------------
    .globl predict_x_vec
    .type  predict_x_vec, @function
predict_x_vec:
    addi    sp, sp, -32
    sd      ra, 24(sp)
    fsd     fs0, 16(sp)
    fsd     fs1,  8(sp)
    fsd     fs2,  0(sp)

    fmv.d   fs0, fa0

    fmul.d  fs1, fs0, fs0
    la      t0, ekf_vec_half
    fld     ft6, 0(t0)
    fmul.d  fs1, fs1, ft6

    fmul.d  fs2, fs1, fs0
    la      t0, ekf_vec_third
    fld     ft6, 0(t0)
    fmul.d  fs2, fs2, ft6

    # Strided vector loads: vl=3, stride=32
    vsetivli zero, 3, e64, m1, ta, ma
    li      t2, 32

    vlse64.v v0, (a0), t2
    addi    t3, a0, 8
    vlse64.v v1, (t3), t2
    addi    t3, a0, 16
    vlse64.v v2, (t3), t2
    addi    t3, a0, 24
    vlse64.v v3, (t3), t2

    vfmacc.vf v0, fs0, v1
    vfmacc.vf v0, fs1, v2
    vfmacc.vf v0, fs2, v3

    vfmacc.vf v1, fs0, v2
    vfmacc.vf v1, fs1, v3

    vfmacc.vf v2, fs0, v3

    vsse64.v v0, (a0), t2
    addi    t3, a0, 8
    vsse64.v v1, (t3), t2
    addi    t3, a0, 16
    vsse64.v v2, (t3), t2

    fld     fs0, 16(sp)
    fld     fs1,  8(sp)
    fld     fs2,  0(sp)
    ld      ra, 24(sp)
    addi    sp, sp, 32
    ret

# -----------------------------------------------------------
# ekf_update_x_vec
#   Vectorised EKF state correction for one joint.
#   x12[i] += sum_m K[i][m]*innov[m],  i=0..11
#
#   Uses column-wise AXPY:
#     for m in 0..2: x12 += innov[m] * K_col_m
#
#   void ekf_update_x_vec(double *x12,
#                         const double *K12x3,
#                         const double *innov3)
#     a0=x12, a1=K (12x3 row-major), a2=innov3
# -----------------------------------------------------------
    .globl ekf_update_x_vec
    .type  ekf_update_x_vec, @function
ekf_update_x_vec:
    # vl = 12, m4 fits all 12 doubles
    li      t0, 24                   # stride = 3 doubles = 24 bytes

    # Measurement 0
    fld     fa1, 0(a2)
    vsetvli t1, zero, e64, m4, ta, ma
    li      t1, 12
    vsetivli zero, 12, e64, m4, ta, ma
    vle64.v  v8, (a0)
    vlse64.v v4, (a1), t0            # K col 0
    vfmacc.vf v8, fa1, v4
    vse64.v  v8, (a0)

    # Measurement 1
    fld     fa1, 8(a2)
    addi    t2, a1, 8
    vle64.v  v8, (a0)
    vlse64.v v4, (t2), t0            # K col 1
    vfmacc.vf v8, fa1, v4
    vse64.v  v8, (a0)

    # Measurement 2
    fld     fa1, 16(a2)
    addi    t2, a1, 16
    vle64.v  v8, (a0)
    vlse64.v v4, (t2), t0            # K col 2
    vfmacc.vf v8, fa1, v4
    vse64.v  v8, (a0)

    ret

# ===========================================================
#  SCALAR FUNCTIONS (carried from ekf_asm.s unchanged)
#  Scalar functions are reused as-is; only the above kernels
#  are vectorised per Milestone 4 requirements.
# ===========================================================

# -----------------------------------------------------------
# atan_poly_asm(double x) -> fa0
# -----------------------------------------------------------
    .globl atan_poly_asm
    .type  atan_poly_asm, @function
atan_poly_asm:
    fmul.d  ft0, fa0, fa0
    la      t0, ekf_atan_c
    fld     ft2,  0(t0)
    fld     ft3,  8(t0)
    fld     ft4, 16(t0)
    fld     ft5, 24(t0)
    fld     ft6, 32(t0)
    fld     ft7, 40(t0)
    fld     ft8, 48(t0)
    fld     ft9, 56(t0)
    fld     ft10,64(t0)
    fmv.d   ft1, ft10
    fmadd.d ft1, ft1, ft0, ft9
    fmadd.d ft1, ft1, ft0, ft8
    fmadd.d ft1, ft1, ft0, ft7
    fmadd.d ft1, ft1, ft0, ft6
    fmadd.d ft1, ft1, ft0, ft5
    fmadd.d ft1, ft1, ft0, ft4
    fmadd.d ft1, ft1, ft0, ft3
    fmadd.d ft1, ft1, ft0, ft2
    fmul.d  fa0, ft1, fa0
    ret

# -----------------------------------------------------------
# atan2_asm(double y, double x) -> fa0
# -----------------------------------------------------------
    .globl atan2_asm
    .type  atan2_asm, @function
atan2_asm:
    addi    sp, sp, -48
    sd      ra, 40(sp)
    fsd     fs0, 32(sp)
    fsd     fs1, 24(sp)
    fsd     fs2, 16(sp)
    fsd     fs3,  8(sp)
    fsd     fs4,  0(sp)
    fmv.d   fs0, fa0
    fmv.d   fs1, fa1
    fmv.d.x ft0, zero
    feq.d   t0, fs1, ft0
    beqz    t0, ekf_at2_nonzero
    la      t1, ekf_const_pi_half
    fld     ft1, 0(t1)
    flt.d   t0, ft0, fs0
    beqz    t0, ekf_at2_x0_neg
    fmv.d   fa0, ft1
    j       ekf_at2_done
ekf_at2_x0_neg:
    flt.d   t0, fs0, ft0
    beqz    t0, ekf_at2_x0_zero
    fneg.d  fa0, ft1
    j       ekf_at2_done
ekf_at2_x0_zero:
    fmv.d.x fa0, zero
    j       ekf_at2_done
ekf_at2_nonzero:
    fsgnjx.d fs2, fs1, fs1
    fsgnjx.d fs3, fs0, fs0
    la      t0, ekf_const_eps300
    fld     ft2, 0(t0)
    fle.d   t0, fs3, fs2
    beqz    t0, ekf_at2_else
    fadd.d  ft0, fs2, ft2
    fdiv.d  fa0, fs3, ft0
    call    atan_poly_asm
    fmv.d   fs4, fa0
    j       ekf_at2_quad
ekf_at2_else:
    la      t0, ekf_const_pi_half
    fld     ft1, 0(t0)
    fadd.d  ft0, fs3, ft2
    fdiv.d  fa0, fs2, ft0
    call    atan_poly_asm
    fsub.d  fs4, ft1, fa0
ekf_at2_quad:
    fmv.d.x ft0, zero
    la      t0, ekf_const_pi
    fld     ft1, 0(t0)
    flt.d   t0, fs1, ft0
    beqz    t0, ekf_at2_check_y
    fsub.d  fs4, ft1, fs4
ekf_at2_check_y:
    fmv.d.x ft0, zero
    flt.d   t0, fs0, ft0
    beqz    t0, ekf_at2_result
    fneg.d  fs4, fs4
ekf_at2_result:
    fmv.d   fa0, fs4
ekf_at2_done:
    ld      ra, 40(sp)
    fld     fs0, 32(sp)
    fld     fs1, 24(sp)
    fld     fs2, 16(sp)
    fld     fs3,  8(sp)
    fld     fs4,  0(sp)
    addi    sp, sp, 48
    ret

# -----------------------------------------------------------
# h_func_asm(double px, double py, double pz, double *z_sph)
# -----------------------------------------------------------
    .globl h_func_asm
    .type  h_func_asm, @function
h_func_asm:
    addi    sp, sp, -48
    sd      ra, 40(sp)
    sd      s0, 32(sp)
    fsd     fs0, 24(sp)
    fsd     fs1, 16(sp)
    fsd     fs2,  8(sp)
    fsd     fs3,  0(sp)
    fmv.d   fs0, fa0
    fmv.d   fs1, fa1
    fmv.d   fs2, fa2
    mv      s0,  a0
    la      t0, ekf_const_eps300
    fld     ft3, 0(t0)
    fmul.d  ft0, fs0, fs0
    fmadd.d ft0, fs1, fs1, ft0
    fsqrt.d ft0, ft0
    fadd.d  fs3, ft0, ft3
    fmul.d  ft1, fs0, fs0
    fmadd.d ft1, fs1, fs1, ft1
    fmadd.d ft1, fs2, fs2, ft1
    fsqrt.d ft1, ft1
    fadd.d  ft1, ft1, ft3
    fsd     ft1, 0(s0)
    fmv.d   fa0, fs1
    fmv.d   fa1, fs0
    call    atan2_asm
    fsd     fa0, 8(s0)
    fmv.d   fa0, fs2
    fmv.d   fa1, fs3
    call    atan2_asm
    fsd     fa0, 16(s0)
    ld      ra, 40(sp)
    ld      s0, 32(sp)
    fld     fs0, 24(sp)
    fld     fs1, 16(sp)
    fld     fs2,  8(sp)
    fld     fs3,  0(sp)
    addi    sp, sp, 48
    ret

# -----------------------------------------------------------
# wrap_angle_asm(double v) -> fa0
# -----------------------------------------------------------
    .globl wrap_angle_asm
    .type  wrap_angle_asm, @function
wrap_angle_asm:
    la      t0, ekf_const_pi
    fld     ft1, 0(t0)
    la      t0, ekf_const_two_pi
    fld     ft0, 0(t0)
    fneg.d  ft2, ft1
ekf_wrap_pos:
    flt.d   t0, ft1, fa0
    beqz    t0, ekf_wrap_neg
    fsub.d  fa0, fa0, ft0
    j       ekf_wrap_pos
ekf_wrap_neg:
    flt.d   t0, fa0, ft2
    beqz    t0, ekf_wrap_done
    fadd.d  fa0, fa0, ft0
    j       ekf_wrap_neg
ekf_wrap_done:
    ret

# -----------------------------------------------------------
# build_jblock_asm (scalar, unchanged - contains branching)
# -----------------------------------------------------------
    .globl build_jblock_asm
    .type  build_jblock_asm, @function
build_jblock_asm:
    addi    sp, sp, -64
    sd      ra, 56(sp)
    sd      s0, 48(sp)
    fsd     fs0, 40(sp)
    fsd     fs1, 32(sp)
    fsd     fs2, 24(sp)
    fsd     fs3, 16(sp)
    fsd     fs4,  8(sp)
    fsd     fs5,  0(sp)
    mv      s0, a0
    fmv.d   fs0, fa0
    fmv.d   fs1, fa1
    fmv.d   fs2, fa2
    la      t0, ekf_const_eps300
    fld     ft6, 0(t0)
    fmv.d.x ft0, zero
    li      t1, 0
ekf_jblk_zero:
    li      t2, 36
    bge     t1, t2, ekf_jblk_zero_done
    slli    t2, t1, 3
    add     t2, s0, t2
    fsd     ft0, 0(t2)
    addi    t1, t1, 1
    j       ekf_jblk_zero
ekf_jblk_zero_done:
    fmul.d  ft0, fs0, fs0
    fmadd.d fs3, fs1, fs1, ft0
    fadd.d  fs3, fs3, ft6
    fsqrt.d fs4, fs3
    fmul.d  ft0, fs2, fs2
    fadd.d  fs5, fs3, ft0
    fadd.d  fs5, fs5, ft6
    fsqrt.d ft5, fs5
    fdiv.d  ft0, fs0, ft5
    fsd     ft0, 0(s0)
    fdiv.d  ft0, fs1, ft5
    fsd     ft0, 32(s0)
    fdiv.d  ft0, fs2, ft5
    fsd     ft0, 64(s0)
    fdiv.d  ft0, fs1, fs3
    fneg.d  ft0, ft0
    fsd     ft0, 96(s0)
    fdiv.d  ft0, fs0, fs3
    fsd     ft0, 128(s0)
    fmul.d  ft1, fs5, fs4
    fmul.d  ft0, fs0, fs2
    fdiv.d  ft0, ft0, ft1
    fneg.d  ft0, ft0
    fsd     ft0, 192(s0)
    fmul.d  ft0, fs1, fs2
    fdiv.d  ft0, ft0, ft1
    fneg.d  ft0, ft0
    fsd     ft0, 224(s0)
    fdiv.d  ft0, fs4, fs5
    fsd     ft0, 256(s0)
    ld      ra, 56(sp)
    ld      s0, 48(sp)
    fld     fs0, 40(sp)
    fld     fs1, 32(sp)
    fld     fs2, 24(sp)
    fld     fs3, 16(sp)
    fld     fs4,  8(sp)
    fld     fs5,  0(sp)
    addi    sp, sp, 64
    ret

# -----------------------------------------------------------
# inv3x3_asm (scalar - Cramer's rule)
# -----------------------------------------------------------
    .globl inv3x3_asm
    .type  inv3x3_asm, @function
inv3x3_asm:
    addi    sp, sp, -80
    sd      ra,  72(sp)
    sd      s0,  64(sp)
    sd      s1,  56(sp)
    sd      s2,  48(sp)
    fsd     fs0, 40(sp)
    fsd     fs1, 32(sp)
    fsd     fs2, 24(sp)
    fsd     fs3, 16(sp)
    fsd     fs4,  8(sp)
    fsd     fs5,  0(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    fld     fs0,  0(s1)
    fld     fs1,  8(s1)
    fld     fs2, 16(s1)
    fld     fs3, 24(s1)
    fld     fs4, 32(s1)
    fld     fs5, 40(s1)
    fld     ft0, 48(s1)
    fld     ft1, 56(s1)
    fld     ft2, 64(s1)
    fmul.d  ft3, fs4, ft2
    fmul.d  ft4, fs5, ft1
    fsub.d  ft3, ft3, ft4
    fmul.d  ft3, fs0, ft3
    fmul.d  ft4, fs3, ft2
    fmul.d  ft5, fs5, ft0
    fsub.d  ft4, ft4, ft5
    fmul.d  ft4, fs1, ft4
    fmul.d  ft5, fs3, ft1
    fmul.d  ft6, fs4, ft0
    fsub.d  ft5, ft5, ft6
    fmul.d  ft5, fs2, ft5
    fsub.d  ft3, ft3, ft4
    fadd.d  ft3, ft3, ft5
    la      t0, ekf_const_1em15
    fld     ft4, 0(t0)
    fsgnjx.d ft5, ft3, ft3
    flt.d   t0, ft5, ft4
    bnez    t0, ekf_inv3_sing
    la      t0, ekf_const_one
    fld     ft6, 0(t0)
    fdiv.d  ft6, ft6, ft3
    fmul.d  ft3, fs4, ft2; fmul.d ft4, fs5, ft1; fsub.d ft3,ft3,ft4; fmul.d ft3,ft6,ft3; fsd ft3, 0(s0)
    fmul.d  ft3, fs2, ft1; fmul.d ft4, fs1, ft2; fsub.d ft3,ft3,ft4; fmul.d ft3,ft6,ft3; fsd ft3, 8(s0)
    fmul.d  ft3, fs1, fs5; fmul.d ft4, fs2, fs4; fsub.d ft3,ft3,ft4; fmul.d ft3,ft6,ft3; fsd ft3,16(s0)
    fmul.d  ft3, fs5, ft0; fmul.d ft4, fs3, ft2; fsub.d ft3,ft3,ft4; fmul.d ft3,ft6,ft3; fsd ft3,24(s0)
    fmul.d  ft3, fs0, ft2; fmul.d ft4, fs2, ft0; fsub.d ft3,ft3,ft4; fmul.d ft3,ft6,ft3; fsd ft3,32(s0)
    fmul.d  ft3, fs2, fs3; fmul.d ft4, fs0, fs5; fsub.d ft3,ft3,ft4; fmul.d ft3,ft6,ft3; fsd ft3,40(s0)
    fmul.d  ft3, fs3, ft1; fmul.d ft4, fs4, ft0; fsub.d ft3,ft3,ft4; fmul.d ft3,ft6,ft3; fsd ft3,48(s0)
    fmul.d  ft3, fs1, ft0; fmul.d ft4, fs0, ft1; fsub.d ft3,ft3,ft4; fmul.d ft3,ft6,ft3; fsd ft3,56(s0)
    fmul.d  ft3, fs0, fs4; fmul.d ft4, fs1, fs3; fsub.d ft3,ft3,ft4; fmul.d ft3,ft6,ft3; fsd ft3,64(s0)
    li      t0, 1
    sw      t0, 0(s2)
    j       ekf_inv3_done
ekf_inv3_sing:
    li      t0, 0
    sw      t0, 0(s2)
ekf_inv3_done:
    ld      ra,  72(sp)
    ld      s0,  64(sp)
    ld      s1,  56(sp)
    ld      s2,  48(sp)
    fld     fs0, 40(sp)
    fld     fs1, 32(sp)
    fld     fs2, 24(sp)
    fld     fs3, 16(sp)
    fld     fs4,  8(sp)
    fld     fs5,  0(sp)
    addi    sp, sp, 80
    ret

# ===========================================================
#  Read-only constants
# ===========================================================
    .section .rodata
    .align 3

ekf_atan_c:
    .double  1.0
    .double -0.3333314528
    .double  0.1999355085
    .double -0.1420889944
    .double  0.1065626393
    .double -0.0752896400
    .double  0.0429096138
    .double -0.0161657367
    .double  0.0028662257

ekf_const_pi:
    .double 3.14159265358979323846
ekf_const_pi_half:
    .double 1.57079632679489661923
ekf_const_two_pi:
    .double 6.28318530717958647692
ekf_const_eps300:
    .double 1.0e-300
ekf_const_1em15:
    .double 1.0e-15
ekf_const_one:
    .double 1.0
ekf_vec_half:
    .double 0.5
ekf_vec_third:
    .double 0.3333333333333333

# End of ekf_vector.s
