# --- Milestone 4 Makefile ---
CC = riscv64-unknown-elf-gcc
AS = riscv64-unknown-elf-as
# -march=rv64gcv: Enables General, Compressed, and Vector extensions
# -mabi=lp64d: 64-bit ABI with Double-precision FP
CFLAGS = -march=rv64gcv -mabi=lp64d -O2 -static
ASFLAGS = -march=rv64gcv -mabi=lp64d

SRCS = lkf_vector.s ekf_vector.s main.c
OBJS = lkf_vector.o ekf_vector.o main.o

all: kalman_m4

kalman_m4: $(OBJS)
	$(CC) $(CFLAGS) -o kalman_m4 $(OBJS) -lm

%.o: %.s
	$(CC) $(ASFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o kalman_m4
