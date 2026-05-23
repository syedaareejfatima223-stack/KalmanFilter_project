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
LKF_BIN   = lkf_filter

# Note: If your EKF driver has a different name, change it here
EKF_CSRC  = ekf_driver.c
EKF_SSRC  = ekf_vector.s
EKF_OBJ   = ekf_driver.o ekf_vector.o
EKF_BIN   = ekf_filter

# ---------- Output directories ----------------------------------
LKF_OUT   = LKF_Output
EKF_OUT   = EKF_Output

# ===========================================================
# Default target: build both filters
# ===========================================================
.PHONY: all
all: $(LKF_BIN) $(EKF_BIN)
	@echo ""
	@echo "Milestone 4 Build complete."
	@echo "  LKF binary : $(LKF_BIN)"
	@echo "  EKF binary : $(EKF_BIN)"
	@echo "  Run with   : make run"

# ===========================================================
# LKF build
# ===========================================================
$(LKF_BIN): $(LKF_OBJ)
	$(LD) $(CFLAGS) -o $@ $^ -lm
	@echo "Linked: $@"

lkf_driver.o: $(LKF_CSRC)
	$(CC) $(CFLAGS) -c -o $@ $<

lkf_vector.o: $(LKF_SSRC)
	$(AS) $(ASFLAGS) -o $@ $<

# ===========================================================
# EKF build
# ===========================================================
$(EKF_BIN): $(EKF_OBJ)
	$(LD) $(CFLAGS) -o $@ $^ -lm
	@echo "Linked: $@"

ekf_driver.o: $(EKF_CSRC)
	$(CC) $(CFLAGS) -c -o $@ $<

ekf_vector.o: $(EKF_SSRC)
	$(AS) $(ASFLAGS) -o $@ $<

# ===========================================================
# Run filters (Uses QEMU with Vector support enabled)
# ===========================================================
.PHONY: run run_lkf run_ekf

run: run_lkf run_ekf

run_lkf: $(LKF_BIN)
	@mkdir -p $(LKF_OUT)
	@echo "---------- Running LKF (Vectorised) ----------"
	$(QEMU) ./$(LKF_BIN)

run_ekf: $(EKF_BIN)
	@mkdir -p $(EKF_OUT)
	@echo "---------- Running EKF (Vectorised) ----------"
	$(QEMU) ./$(EKF_BIN)

# ===========================================================
# Assembly listing (for report verification)
# ===========================================================
.PHONY: listing
listing:
	riscv64-linux-gnu-objdump -d lkf_vector.o > lkf_vector.lst
	riscv64-linux-gnu-objdump -d ekf_vector.o > ekf_vector.lst
	@echo "Listings generated: lkf_vector.lst, ekf_vector.lst"

# ===========================================================
# Clean
# ===========================================================
.PHONY: clean distclean
clean:
	rm -f $(LKF_OBJ) $(EKF_OBJ)
	rm -f *.lst *.o

distclean: clean
	rm -f $(LKF_BIN) $(EKF_BIN)
	rm -rf $(LKF_OUT) $(EKF_OUT)
