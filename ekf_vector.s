.section .text
.align 2

# These labels MUST match what is in lkf_driver.c
.globl ekf_update
.globl ekf_predict
.globl asm_atan2
.globl h_func_asm

ekf_update:
    addi sp, sp, -16
    sd ra, 8(sp)
    # EKF Logic here
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

ekf_predict:
    addi sp, sp, -16
    sd ra, 8(sp)
    # Predict Logic here
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

asm_atan2:
    addi sp, sp, -16
    sd ra, 8(sp)
    # Atan2 logic
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

h_func_asm:
    ret
