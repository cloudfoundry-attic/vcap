#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include "util.h"

int fcntl_mix_cloexec(int fd) {
  int rv;

  rv = fcntl(fd, F_GETFD);
  if (rv == -1) {
    fprintf(stderr, "fcntl(F_GETFD): %s\n", strerror(errno));
    return -1;
  }

  int flags = rv;
  flags |= FD_CLOEXEC;

  rv = fcntl(fd, F_SETFD, flags);
  if (rv == -1) {
    fprintf(stderr, "fcntl(F_SETFD): %s\n", strerror(errno));
    return -1;
  }

  return 0;
}
