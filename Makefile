CC = riscv64-linux-gnu-gcc
CFLAGS = -march=rv64gcv -mabi=lp64d -O2 -static
LDFLAGS = -lm

TARGET = lkf_filter
# Using your existing driver and the two vector files
OBJS = lkf_driver.o lkf_vector.o ekf_vector.o

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(LDFLAGS)
	@echo "Build successful. Run with: qemu-riscv64 -cpu rv64,v=true,vlen=128 ./lkf_filter"

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(TARGET)
