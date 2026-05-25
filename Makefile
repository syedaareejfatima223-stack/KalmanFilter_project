CC = riscv64-linux-gnu-gcc
CFLAGS = -march=rv64gcv -mabi=lp64d -O2 -static
LDFLAGS = -lm

# List all your source files here
SRCS = main_driver.c lkf_vector.s ekf_vector.s
OBJS = main_driver.o lkf_vector.o ekf_vector.o
TARGET = kalman_filter

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(LDFLAGS)
	@echo "----------------------------------------------------------------"
	@echo "Build successful! Run with:"
	@echo "qemu-riscv64 -cpu rv64,v=true,vlen=128 ./$(TARGET)"
	@echo "----------------------------------------------------------------"

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(TARGET) trace.txt
