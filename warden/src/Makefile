OPTIMIZATION?=-O2
DEBUG?=-g -ggdb -rdynamic
BINS=report_quota runner

all: $(BINS)

clean:
		rm -f *.o $(BINS)

.PHONY: all clean

report_quota: report_quota.o
		$(CC) -o $@ $^

runner: runner.o
		$(CC) -o $@ $^

%.o: %.c
		$(CC) -c -Wall $(OPTIMIZATION) $(DEBUG) $(CFLAGS) $<
