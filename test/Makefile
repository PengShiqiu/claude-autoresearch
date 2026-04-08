CC = gcc
CFLAGS = -O2 -Wall -Wextra -mavx2 -msse4.2
LDFLAGS = -lm

.PHONY: all bench test clean

all: bench test

bench: bench.c nv12_crop.c nv12_crop.h
	$(CC) $(CFLAGS) -o bench bench.c nv12_crop.c $(LDFLAGS)

test: test_correctness.c nv12_crop.c nv12_crop.h
	$(CC) $(CFLAGS) -o test_correctness test_correctness.c nv12_crop.c $(LDFLAGS)

bench-run: bench
	./bench

test-run: test
	./test_correctness

clean:
	rm -f bench test_correctness
