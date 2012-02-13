#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include "barrier.h"
#include "util.h"

int barrier_open(barrier_t *bar) {
  int rv;
  int aux[2] = { -1, -1 };

  rv = pipe(aux);
  if (rv == -1) {
    fprintf(stderr, "pipe: %s\n", strerror(errno));
    goto err;
  }

  if (fcntl_mix_cloexec(aux[0]) == -1) {
    goto err;
  }

  if (fcntl_mix_cloexec(aux[1]) == -1) {
    goto err;
  }

  bar->fd[0] = aux[0];
  bar->fd[1] = aux[1];
  return 0;

err:
  if (aux[0] >= 0) close(aux[0]);
  if (aux[1] >= 0) close(aux[1]);
  return -1;
}

void barrier_close(barrier_t *bar) {
  close(bar->fd[0]);
  close(bar->fd[1]);
}

void barrier_close_wait(barrier_t *bar) {
  close(bar->fd[0]);
}

void barrier_close_signal(barrier_t *bar) {
  close(bar->fd[1]);
}

int barrier_wait(barrier_t *bar) {
  char buf[1];
  int nread;

  /* Close signal side of pipe on wait */
  barrier_close_signal(bar);

  nread = read(bar->fd[0], buf, sizeof(buf));
  if (nread == -1) {
    fprintf(stderr, "read: %s\n", strerror(errno));
    return -1;
  } else if (nread == 0) {
    fprintf(stderr, "read: eof\n");
    return -1;
  }

  return 0;
}

int barrier_signal(barrier_t *bar) {
  int rv;
  char byte = '\0';

  /* Close wait side of pipe on signal */
  barrier_close_wait(bar);

  rv = write(bar->fd[1], &byte, 1);
  if (rv == -1) {
    fprintf(stderr, "write: %s\n", strerror(errno));
    return -1;
  }

  return 0;
}
