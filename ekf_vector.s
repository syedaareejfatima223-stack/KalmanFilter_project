# ==============================================================================
# ekf_vector.s - RISC-V Vector (RVV) Assembly: EKF Core logic
# Milestone 4 - Vectorised implementation
# ==============================================================================

.section .text
.align 2

# Export the main EKF function so the C driver can see it
.globl ekf_update

# ==============================================================================
# EKF UPDATE KERNEL
# This is the main function called by the driver
# ==============================================================================
ekf_update:
    # --- Function Prologue ---
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    # (Add other saved registers if your specific code uses them)

    # --------------------------------------------------------------------------
    # YOUR EKF LOGIC GOES HERE
    # Note: When you need to add or multiply matrices, your code should 
    # 'jal' (jump) to the functions in lkf_vector.s
    # --------------------------------------------------------------------------

    # --- Function Epilogue ---
    ld ra, 56(sp)
    ld s0, 48(sp)
    addi sp, sp, 64
    ret

# ==============================================================================
# EKF SPECIFIC HELPER KERNELS (Keep these if you have them)
# ==============================================================================

.globl ekf_predict
ekf_predict:
    # Your vectorized prediction logic
    ret

.globl h_func_asm
h_func_asm:
    # Your measurement function logic
    ret

# ------------------------------------------------------------------------------
# IMPORTANT: DO NOT INCLUDE mat_add_vec, matmul_vec, etc. IN THIS FILE.
# They are already defined in lkf_vector.s. 
# The linker will automatically find them there.
# ------------------------------------------------------------------------------
