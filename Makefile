# ===========================================================
#  Milestone-4 Makefile (Vectorized RISC-V)
#  Targets: lkf_filter   (lkf_driver.c + lkf_vector.s)
#           ekf_filter   (ekf_driver.c + ekf_vector.s)
#
#  Cross-compiler: riscv64-linux-gnu-gcc (LP64D ABI)
#  Emulator:       qemu-riscv64 with Vector support
# ===========================================================

# ---------- Toolchain -------------------------------------------
CC      = riscv64-linux-gnu-gcc
AS      = riscv64-linux-gnu-gcc   # Use GCC to assemble .s
LD      = riscv64-linux-gnu-gcc

# ---------- Flags (Vector Extension Enabled) --------------------
MARCH   = rv64gcv
MABI    = lp64d

CFLAGS  = -march=$(MARCH) -mabi=$(MABI) -O2 -Wall -Wextra \
           -ffreestanding -static -lm
ASFLAGS = -march=$(MARCH) -mabi=$(MABI) -c

# Emulator with Vector flags: VLEN=128 bits
QEMU    = qemu-riscv64 -cpu rv64,v=true,vlen=128 -L /usr/riscv64-linux-gnu

# ---------- Sources & Objects (Updated for M4) ------------------
LKF_CSRC  = lkf_driver.c
LKF_SSRC  = lkf_vector.s
LKF_OBJ   = lkf_driver.o lkf_vector.o
LKF_BIN
