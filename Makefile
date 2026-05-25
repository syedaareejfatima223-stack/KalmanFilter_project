CC = riscv64-linux-gnu-gcc
# Critical: Enables Vector (v) extension and static linking
CFLAGS = -march=rv64gcv -mabi=lp64d -O2 -static
LDFLAGS = -lm

# Files to compile
SRCS = lkf_driver.c lkf_vector.s ekf_vector.s
OBJS = lkf_driver.o lkf_vector.o ekf_vector.o
TARGET = lkf_filter

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(LDFLAGS)
	@echo "----------------------------------------------------------------"
	@echo "Build successful! Run with:"
	@echo "qemu-riscv64 -cpu rv64,v=true,vlen=128 ./lkf_filter"
	@echo "----------------------------------------------------------------"

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(TARGET) trace.txt
