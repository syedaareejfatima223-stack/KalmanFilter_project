# ===========================================================
#  Milestone-4 Makefile (Vectorized RISC-V)
# ===========================================================

CC      = riscv64-linux-gnu-gcc
AS      = riscv64-linux-gnu-gcc
LD      = riscv64-linux-gnu-gcc

MARCH   = rv64gcv
MABI    = lp64d

CFLAGS  = -march=$(MARCH) -mabi=$(MABI) -O2 -Wall -static -lm
ASFLAGS = -march=$(MARCH) -mabi=$(MABI) -c

QEMU    = qemu-riscv64 -cpu rv64,v=true,vlen=128 -L /usr/riscv64-linux-gnu

# Build only LKF for now since we know you have those files
LKF_CSRC  = lkf_driver.c
LKF_SSRC  = lkf_vector.s
LKF_OBJ   = lkf_driver.o lkf_vector.o
LKF_BIN   = lkf_filter

.PHONY: all clean run
all: $(LKF_BIN)

$(LKF_BIN): $(LKF_OBJ)
	$(LD) $(CFLAGS) -o $@ $^ -lm

lkf_driver.o: $(LKF_CSRC)
	$(CC) $(CFLAGS) -c -o $@ $<

lkf_vector.o: $(LKF_SSRC)
	$(AS) $(ASFLAGS) -o $@ $<

run: $(LKF_BIN)
	@echo "---------- Running LKF (Vectorised) ----------"
	$(QEMU) ./$(LKF_BIN)

clean:
	rm -f *.o $(LKF_BIN)
