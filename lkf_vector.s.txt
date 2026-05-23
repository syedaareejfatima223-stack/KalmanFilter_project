# ===========================================================
#  lkf_vector.s  -  RISC-V Vector (RVV) Assembly: LKF Core
#  Milestone 4 - Vectorised implementation
#
#  Vectorised functions:
#    mat_add_vec      - vfadd.vv over n doubles
#    mat_sub_vec      - vfsub.vv over n doubles
#    mat_scale_vec    - vfmul.vf over n doubles
#    mat_dot_vec      - vfmul.vv + vfredosum.vs
#    vec_axpy_vec     - vfmacc.vf: y += alpha*x
#    matvec_vec       - general M×N matrix-vector product
#    matmul_vec       - general P×Q×R matrix multiply
#    predict_x_vec    - vectorised constant-jerk F*x per joint
#    update_x_vec     - vectorised x += K*y correction per joint
#    covar_scale_vec  - vectorised diagonal P scaling
#
#  RISC-V ABI LP64D + V extension:
#    a0-a7  : integer args        fa0-fa7  : FP args
#    s0-s11 : callee-saved int    fs0-fs11 : callee-saved FP
#    t0-t6  : int temporaries     ft0-ft11 : FP temporaries
#    v0-v31 : vector registers (caller-saved unless noted)
#
#  All vector ops use SEW=64 (double), LMUL=1 unless stated.
# ===========================================================

    .section .text
    .align 2

# -----------------------------------------------------------
# mat_add_vec(double *C, const double *A, const double *B, int n)
#   C[i] = A[i] + B[i],  i = 0..n-1
#
#   Uses vle64.v / vfadd.vv / vse64.v with tail-agnostic policy.
#   a0=C, a1=A, a2=B, a3=n
# -----------------------------------------------------------
    .globl mat_add_vec
    .type  mat_add_vec, @function
mat_add_vec:
    mv      t0, a3                    # remaining = n
mav_loop:
    beqz    t0, mav_done
    vsetvli t1, t0, e64, m1, ta, ma  # vl = min(t0, VLMAX), SEW=64
    vle64.v v0, (a1)                  # v0 = A[0..vl-1]
    vle64.v v1, (a2)                  # v1 = B[0..vl-1]
    vfadd.vv v2, v0, v1               # v2 = v0 + v1
    vse64.v v2, (a0)                  # C[0..vl-1] = v2
    slli    t2, t1, 3                 # bytes = vl * 8
    add     a0, a0, t2
    add     a1, a1, t2
    add     a2, a2, t2
    sub     t0, t0, t1
    j       mav_loop
mav_done:
    ret

# -----------------------------------------------------------
# mat_sub_vec(double *C, const double *A, const double *B, int n)
#   C[i] = A[i] - B[i]
#   a0=C, a1=A, a2=B, a3=n
# -----------------------------------------------------------
    .globl mat_sub_vec
    .type  mat_sub_vec, @function
mat_sub_vec:
    mv      t0, a3
msv_loop:
    beqz    t0, msv_done
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
    j       msv_loop
msv_done:
    ret

# -----------------------------------------------------------
# mat_scale_vec(double *A, double scalar, int n)
#   A[i] *= scalar
#   a0=A, fa0=scalar, a1=n
# -----------------------------------------------------------
    .globl mat_scale_vec
    .type  mat_scale_vec, @function
mat_scale_vec:
    mv      t0, a1
mscv_loop:
    beqz    t0, mscv_done
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (a0)
    vfmul.vf v0, v0, fa0             # v0[i] *= scalar
    vse64.v v0, (a0)
    slli    t2, t1, 3
    add     a0, a0, t2
    sub     t0, t0, t1
    j       mscv_loop
mscv_done:
    ret

# -----------------------------------------------------------
# mat_dot_vec(const double *A, const double *B, int n) -> fa0
#   Returns sum of A[i]*B[i]
#   Uses vfmul.vv + vfredosum.vs (ordered reduction for reproducibility)
#   a0=A, a1=B, a2=n
# -----------------------------------------------------------
    .globl mat_dot_vec
    .type  mat_dot_vec, @function
mat_dot_vec:
    fmv.d.x fa0, zero                 # accumulator = 0.0
    mv      t0, a2
    beqz    t0, mdv_done
    # initialise scalar vector v4[0] = 0.0 for reduction seed
    vsetvli t1, t0, e64, m1, ta, ma
    vfmv.v.f v4, fa0                  # v4 = {0.0, 0.0, ...}
mdv_loop:
    beqz    t0, mdv_reduce
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (a0)
    vle64.v v1, (a1)
    vfmul.vv v2, v0, v1               # v2 = A*B element-wise
    vfredosum.vs v4, v2, v4           # v4[0] += sum(v2)
    slli    t2, t1, 3
    add     a0, a0, t2
    add     a1, a1, t2
    sub     t0, t0, t1
    j       mdv_loop
mdv_reduce:
    vfmv.f.s fa0, v4                  # extract scalar from v4[0]
mdv_done:
    ret

# -----------------------------------------------------------
# vec_axpy_vec(double *y, double alpha, const double *x, int n)
#   y[i] += alpha * x[i]
#   a0=y, fa0=alpha, a2=x, a3=n
# -----------------------------------------------------------
    .globl vec_axpy_vec
    .type  vec_axpy_vec, @function
vec_axpy_vec:
    mv      t0, a3
vav_loop:
    beqz    t0, vav_done
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (a2)                  # v0 = x[0..vl-1]
    vle64.v v1, (a0)                  # v1 = y[0..vl-1]
    vfmacc.vf v1, fa0, v0             # v1 += alpha * v0  (fused)
    vse64.v v1, (a0)
    slli    t2, t1, 3
    add     a0, a0, t2
    add     a2, a2, t2
    sub     t0, t0, t1
    j       vav_loop
vav_done:
    ret

# -----------------------------------------------------------
# matvec_vec(double *y, const double *A, const double *x,
#            int rows, int cols)
#   y = A * x   (A is rows×cols, row-major)
#   Uses vfmul.vv + vfredosum.vs per output row.
#
#   a0=y, a1=A, a2=x, a3=rows, a4=cols
# -----------------------------------------------------------
    .globl matvec_vec
    .type  matvec_vec, @function
matvec_vec:
    addi    sp, sp, -16
    sd      ra,  8(sp)
    sd      s0,  0(sp)

    mv      s0, a0                    # save y ptr
    li      t6, 0                     # row = 0
mvv_row:
    bge     t6, a3, mvv_done

    # dot product of A_row[t6] with x, length=cols
    fmv.d.x fa0, zero
    vsetvli t1, a4, e64, m1, ta, ma
    vfmv.v.f v8, fa0                  # v8 = 0.0 (reduction accumulator)

    mv      t0, a4                    # remaining = cols
    # row ptr: a1 + row*cols*8
    li      t3, 0
    mul     t3, t6, a4
    slli    t3, t3, 3
    add     t4, a1, t3                # t4 = &A[row][0]
    mv      t5, a2                    # t5 = &x[0]

mvv_dot:
    beqz    t0, mvv_dot_done
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (t4)
    vle64.v v1, (t5)
    vfmul.vv v2, v0, v1
    vfredosum.vs v8, v2, v8
    slli    t2, t1, 3
    add     t4, t4, t2
    add     t5, t5, t2
    sub     t0, t0, t1
    j       mvv_dot

mvv_dot_done:
    vfmv.f.s fa0, v8                  # extract result
    # store y[row]
    slli    t2, t6, 3
    add     t2, s0, t2
    fsd     fa0, 0(t2)

    addi    t6, t6, 1
    j       mvv_row
mvv_done:
    ld      ra,  8(sp)
    ld      s0,  0(sp)
    addi    sp, sp, 16
    ret

# -----------------------------------------------------------
# matmul_vec(double *C, const double *A, const double *B,
#            int P, int Q, int R)
#   C[P×R] = A[P×Q] * B[Q×R]   (all row-major)
#   Strategy: for each row i of A, for each col j of B,
#             C[i][j] = dot(A_row_i, B_col_j)
#   B columns accessed with stride R (vlse64.v).
#
#   a0=C, a1=A, a2=B, a3=P, a4=Q, a5=R
# -----------------------------------------------------------
    .globl matmul_vec
    .type  matmul_vec, @function
matmul_vec:
    addi    sp, sp, -32
    sd      ra, 24(sp)
    sd      s0, 16(sp)
    sd      s1,  8(sp)
    sd      s2,  0(sp)

    mv      s0, a0                   # C
    mv      s1, a1                   # A
    mv      s2, a2                   # B

    # Zero C
    mul     t0, a3, a5               # P*R elements
    slli    t0, t0, 3
mmv_zero:
    beqz    t0, mmv_zero_done
    addi    t0, t0, -8
    add     t1, s0, t0
    sd      zero, 0(t1)
    j       mmv_zero
mmv_zero_done:

    li      t6, 0                    # i = 0 (row of A/C)
mmv_i:
    bge     t6, a3, mmv_done

    li      t5, 0                    # j = 0 (col of B/C)
mmv_j:
    bge     t5, a5, mmv_i_next

    # dot product: A[i][0..Q-1] . B[0..Q-1][j]
    # A row: s1 + i*Q*8,  stride=8 (contiguous)
    # B col: s2 + j*8,    stride=R*8
    mul     t0, t6, a4
    slli    t0, t0, 3
    add     t0, s1, t0               # &A[i][0]

    slli    t1, t5, 3
    add     t1, s2, t1               # &B[0][j]
    slli    t2, a5, 3                # stride = R*8

    fmv.d.x fa0, zero
    vsetvli t3, a4, e64, m1, ta, ma
    vfmv.v.f v8, fa0

    mv      t4, a4                   # remaining = Q
    mv      t0, t0                   # current A ptr
mmv_dot:
    beqz    t4, mmv_dot_done
    vsetvli t3, t4, e64, m1, ta, ma
    vle64.v  v0, (t0)                # load Q elems from A row (contiguous)
    vlse64.v v1, (t1), t2            # load Q elems from B col (strided)
    vfmul.vv v2, v0, v1
    vfredosum.vs v8, v2, v8
    slli    t9, t3, 3
    add     t0, t0, t9               # advance A ptr
    # advance B ptr: vl * stride
    mul     t9, t3, t2
    add     t1, t1, t9
    sub     t4, t4, t3
    j       mmv_dot
mmv_dot_done:
    vfmv.f.s fa0, v8

    # C[i][j] = fa0
    mul     t0, t6, a5
    add     t0, t0, t5
    slli    t0, t0, 3
    add     t0, s0, t0
    fsd     fa0, 0(t0)

    addi    t5, t5, 1
    j       mmv_j
mmv_i_next:
    addi    t6, t6, 1
    j       mmv_i
mmv_done:
    ld      ra, 24(sp)
    ld      s0, 16(sp)
    ld      s1,  8(sp)
    ld      s2,  0(sp)
    addi    sp, sp, 32
    ret

# -----------------------------------------------------------
# predict_x_vec
#   Vectorised constant-jerk state transition for one joint.
#   Operates on the 12-element per-joint state vector:
#     For each axis b in {0,1,2} (offset o = b*4):
#       x[o]   += dt*x[o+1] + (dt²/2)*x[o+2] + (dt³/6)*x[o+3]
#       x[o+1] +=             dt*x[o+2]        + (dt²/2)*x[o+3]
#       x[o+2] +=                                dt*x[o+3]
#
#   Vectorisation: process all 3 axes simultaneously by
#   loading the "jerk" states into a vector and doing
#   fused multiply-accumulate in parallel.
#
#   void predict_x_vec(double *x12, double dt)
#     a0 = double *x12,  fa0 = dt
#
#   Register allocation:
#     fs0=dt, fs1=dt²/2, fs2=dt³/6
#     v0=x_pos(3), v1=x_vel(3), v2=x_acc(3), v3=x_jrk(3)
# -----------------------------------------------------------
    .globl predict_x_vec
    .type  predict_x_vec, @function
predict_x_vec:
    addi    sp, sp, -48
    sd      ra, 40(sp)
    fsd     fs0, 32(sp)
    fsd     fs1, 24(sp)
    fsd     fs2, 16(sp)
    fsd     fs3,  8(sp)
    fsd     fs4,  0(sp)

    fmv.d   fs0, fa0                  # dt

    # dt²/2
    fmul.d  fs1, fs0, fs0
    la      t0, lkf_vec_half
    fld     ft6, 0(t0)
    fmul.d  fs1, fs1, ft6             # dt²/2

    # dt³/6
    fmul.d  fs2, fs1, fs0
    la      t0, lkf_vec_third
    fld     ft6, 0(t0)
    fmul.d  fs2, fs2, ft6             # dt³/6

    # Load 3 elements from each state level using stride=32 bytes
    # (stride between x[0],x[4],x[8] = 4 doubles * 8 bytes = 32)
    li      t1, 3                     # vl = 3 axes
    vsetivli zero, 3, e64, m1, ta, ma

    li      t2, 32                    # stride = 4 doubles
    vle64.v  v0, (a0)                 # *** temporary: load 12 scalars
    # Instead: use strided loads for each level
    vlse64.v v0, (a0), t2             # x_pos[0,1,2] at offsets 0,32,64
    addi    t3, a0, 8
    vlse64.v v1, (t3), t2             # x_vel[0,1,2] at offsets 8,40,72
    addi    t3, a0, 16
    vlse64.v v2, (t3), t2             # x_acc[0,1,2] at offsets 16,48,80
    addi    t3, a0, 24
    vlse64.v v3, (t3), t2             # x_jrk[0,1,2] at offsets 24,56,88

    # x_pos += dt*x_vel + dt2h*x_acc + dt3s*x_jrk
    vfmacc.vf v0, fs0, v1             # v0 += dt * v1
    vfmacc.vf v0, fs1, v2             # v0 += dt²/2 * v2
    vfmacc.vf v0, fs2, v3             # v0 += dt³/6 * v3

    # x_vel += dt*x_acc + dt2h*x_jrk
    vfmacc.vf v1, fs0, v2
    vfmacc.vf v1, fs1, v3

    # x_acc += dt*x_jrk
    vfmacc.vf v2, fs0, v3

    # Store back with same strides
    vsse64.v v0, (a0), t2
    addi    t3, a0, 8
    vsse64.v v1, (t3), t2
    addi    t3, a0, 16
    vsse64.v v2, (t3), t2
    # x_jrk unchanged, no store needed

    fld     fs0, 32(sp)
    fld     fs1, 24(sp)
    fld     fs2, 16(sp)
    fld     fs3,  8(sp)
    fld     fs4,  0(sp)
    ld      ra, 40(sp)
    addi    sp, sp, 48
    ret

# -----------------------------------------------------------
# update_x_vec
#   Vectorised Kalman correction for one joint's 12-state.
#   x12[i] += sum_{m=0}^{2} K[i][m] * innov[m],  i=0..11
#
#   Strategy: for each measurement m (3 total), do
#     x12 += innov[m] * K_col_m  (AXPY with scalar innov[m])
#   This avoids a 12×3 dot product and is more vector-friendly.
#
#   void update_x_vec(double *x12,
#                     const double *K12x3,
#                     const double *innov3)
#     a0=x12, a1=K (12×3 row-major), a2=innov3
# -----------------------------------------------------------
    .globl update_x_vec
    .type  update_x_vec, @function
update_x_vec:
    # Process measurement 0: x12 += innov[0] * K[:,0]
    # K[:,0] in K[i][0] = K[i*3+0], stride between rows = 3*8=24 bytes
    fld     fa1, 0(a2)                # innov[0]
    li      t0, 12                    # n = 12 states
    mv      t1, a0                    # y = x12
    mv      t2, a1                    # x = &K[0][0]
    li      t3, 24                    # stride = 3 doubles

    # AXPY with column stride: load K col 0 strided, add to x12
    vsetvli t4, t0, e64, m4, ta, ma  # m4 to fit 12 doubles in one shot
    vlse64.v v4, (t2), t3            # K col0: K[0][0],K[1][0],...K[11][0]
    vle64.v  v8, (t1)                # x12[0..11]
    vfmacc.vf v8, fa1, v4            # x12 += innov[0] * K_col0
    vse64.v  v8, (t1)

    # Process measurement 1: x12 += innov[1] * K[:,1]
    fld     fa1, 8(a2)               # innov[1]
    addi    t2, a1, 8                # &K[0][1]
    vle64.v  v8, (t1)
    vlse64.v v4, (t2), t3            # K col1
    vfmacc.vf v8, fa1, v4
    vse64.v  v8, (t1)

    # Process measurement 2: x12 += innov[2] * K[:,2]
    fld     fa1, 16(a2)              # innov[2]
    addi    t2, a1, 16               # &K[0][2]
    vle64.v  v8, (t1)
    vlse64.v v4, (t2), t3            # K col2
    vfmacc.vf v8, fa1, v4
    vse64.v  v8, (t1)

    ret

# -----------------------------------------------------------
# covar_scale_vec
#   Scale n diagonal elements of P by a factor.
#   void covar_scale_vec(double *Pdiag, double factor, int n)
#     a0=Pdiag, fa0=factor, a1=n
# -----------------------------------------------------------
    .globl covar_scale_vec
    .type  covar_scale_vec, @function
covar_scale_vec:
    mv      t0, a1
csv_loop:
    beqz    t0, csv_done
    vsetvli t1, t0, e64, m1, ta, ma
    vle64.v v0, (a0)
    vfmul.vf v0, v0, fa0
    vse64.v v0, (a0)
    slli    t2, t1, 3
    add     a0, a0, t2
    sub     t0, t0, t1
    j       csv_loop
csv_done:
    ret

# -----------------------------------------------------------
# mat_transpose_vec
#   Transpose an M×N matrix A into N×M matrix T.
#   Uses vlse64.v (strided column reads) + vse64.v.
#
#   void mat_transpose_vec(double *T, const double *A, int M, int N)
#     a0=T, a1=A, a2=M (rows of A), a3=N (cols of A)
# -----------------------------------------------------------
    .globl mat_transpose_vec
    .type  mat_transpose_vec, @function
mat_transpose_vec:
    addi    sp, sp, -16
    sd      ra,  8(sp)
    sd      s0,  0(sp)

    mv      s0, a0                    # T
    # for each column j of A, write as row j of T
    slli    t3, a3, 3                 # col stride = N*8 bytes (within A row)
    li      t6, 0                     # j = 0

mtv_col:
    bge     t6, a3, mtv_done          # j < N

    # Source column j of A: start at a1+j*8, stride=N*8
    slli    t0, t6, 3
    add     t0, a1, t0                # &A[0][j]

    # Destination row j of T: start at s0+j*M*8, contiguous
    mul     t1, t6, a2
    slli    t1, t1, 3
    add     t1, s0, t1                # &T[j][0]

    mv      t2, a2                    # remaining = M
    slli    t3, a3, 3                 # stride in A = N*8

mtv_vload:
    beqz    t2, mtv_next_col
    vsetvli t4, t2, e64, m1, ta, ma
    vlse64.v v0, (t0), t3            # load M elements from A col j
    vse64.v  v0, (t1)                # store as T row j (contiguous)
    mul     t5, t4, t3
    add     t0, t0, t5
    slli    t5, t4, 3
    add     t1, t1, t5
    sub     t2, t2, t4
    j       mtv_vload

mtv_next_col:
    addi    t6, t6, 1
    j       mtv_col
mtv_done:
    ld      ra,  8(sp)
    ld      s0,  0(sp)
    addi    sp, sp, 16
    ret

# -----------------------------------------------------------
# Read-only constants
# -----------------------------------------------------------
    .section .rodata
    .align 3
lkf_vec_half:
    .double 0.5
lkf_vec_third:
    .double 0.3333333333333333
lkf_vec_one:
    .double 1.0

# End of lkf_vector.s
