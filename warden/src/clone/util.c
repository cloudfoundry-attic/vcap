#include <sys/types.h>
#include <sys/wait.h>
#include <stdlib.h>
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

int run(char *path) {
  char *argv[2] = { path, NULL };
  int rv;

  rv = fork();
  if (rv == -1) {
    fprintf(stderr, "fork: %s\n", strerror(errno));
    return -1;
  }

  if (rv == 0) {
    execvp(argv[0], argv);
    fprintf(stderr, "execvp: %s\n", strerror(errno));
    exit(1);
  } else {
    int status;

    rv = waitpid(rv, &status, 0);
    if (rv == -1) {
      fprintf(stderr, "waitpid: %s\n", strerror(errno));
      return -1;
    }

    if (WEXITSTATUS(status) != 0) {
      fprintf(stderr, "non-zero exit status from %s\n", argv[0]);
      return -1;
    }
  }

  return 0;
}
