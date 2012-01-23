OPTIMIZATION?=-O0
DEBUG?=-g -ggdb -rdynamic
BINS=report_quota runner clone

all: $(BINS)

clean:
		rm -f *.o $(BINS)

.PHONY: all clean

report_quota: report_quota.o
		$(CC) -o $@ $^

runner: runner.o
		$(CC) -o $@ $^

clone: clone.o
		$(CC) -o $@ -lutil $^

%.o: %.c
		$(CC) -c -Wall -D_GNU_SOURCE $(OPTIMIZATION) $(DEBUG) $(CFLAGS) $<
