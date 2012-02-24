#ifndef BARRIER_H
#define BARRIER_H 1

/*
 * This type implements a barrier-like primitive on top of a pipe.
 *
 * It is intended to be used by processes in need of ridiculously simple
 * synchronization. Either process can only wait for the other process, or let
 * the other process know it can continue. Because a pipe is used, either
 * process will be notified by the OS when the other process dies.
 */

typedef struct barrier_s barrier_t;

struct barrier_s {
  int fd[2];
};

int barrier_open(barrier_t *bar);
void barrier_close(barrier_t *bar);

void barrier_close_wait(barrier_t *bar);
void barrier_close_signal(barrier_t *bar);

int barrier_wait(barrier_t *bar);
int barrier_signal(barrier_t *bar);

#endif
