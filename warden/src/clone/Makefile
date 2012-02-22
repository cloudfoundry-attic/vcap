OPTIMIZATION?=-O0
DEBUG?=-g -ggdb -rdynamic

all: clone

clean:
		rm -f *.o clone

.PHONY: all clean

clone: clone.o barrier.o util.o console.o mount.o
		$(CC) -o $@ $^ -lutil

%.o: %.c
		$(CC) -c -Wall -D_GNU_SOURCE $(OPTIMIZATION) $(DEBUG) $(CFLAGS) $<
