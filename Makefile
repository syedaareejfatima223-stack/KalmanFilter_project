CC = riscv64-linux-gnu-gcc
CFLAGS = -march=rv64gcv -mabi=lp64d -O2 -static
LDFLAGS = -lm

TARGET = kalman_m4
OBJS = lkf_driver.o lkf_vector.o ekf_vector.o

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(TARGET)
