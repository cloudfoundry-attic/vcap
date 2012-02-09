#include <sched.h>
#include <pty.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/mount.h>
#include <sys/prctl.h>
#include <sys/param.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <errno.h>

/* This function doesn't get declared anywhere... */
extern int pivot_root(const char *new_root, const char *put_old);

typedef struct console_s console_t;
typedef struct clone_helper_s clone_helper_t;

struct console_s {
  int master;
  int slave;
  char path[MAXPATHLEN];
};

struct clone_helper_s {
  int argc;
  char **argv;

  char *new_root_path;
  char *asset_path;

  console_t console;

  int pipe_daemon[2];
  int pipe_parent[2];
  int pipe_child[2];
  pid_t pid;
};

int pipe_wakeup(int pipe[2]) {
  int rv;
  char byte = 'x';

  rv = write(pipe[1], &byte, 1);
  if (rv == -1) {
    fprintf(stderr, "write: %s\n", strerror(errno));
    return -1;
  }

  return 0;
}

int pipe_wait(int pipe[2]) {
  char buf[1];
  int nread;

  nread = read(pipe[0], buf, sizeof(buf));
  if (nread == -1) {
    fprintf(stderr, "read: %s\n", strerror(errno));
    return -1;
  } else if (nread == 0) {
    fprintf(stderr, "read: eof\n");
    return -1;
  }

  return 0;
}

int child_die_with_parent(clone_helper_t *h) {
  int rv;

  rv = prctl(PR_SET_PDEATHSIG, SIGKILL);
  if (rv == -1) {
    fprintf(stderr, "prctl: %s\n", strerror(errno));
    return -1;
  }

  return 0;
}

int child_setup_dev_console(clone_helper_t *h) {
  const char *path = "dev/console";
  struct stat st;
  int rv;

  rv = stat(path, &st);
  if (rv == -1) {
    fprintf(stderr, "stat: %s\n", strerror(errno));
    return -1;
  }

  /* Mirror user/group */
  rv = chown(h->console.path, st.st_uid, st.st_gid);
  if (rv == -1) {
    fprintf(stderr, "chown: %s\n", strerror(errno));
    return -1;
  }

  /* Mirror permissions */
  rv = chmod(h->console.path, st.st_mode);
  if (rv == -1) {
    fprintf(stderr, "chmod: %s\n", strerror(errno));
    return -1;
  }

  /* Bind pty to /dev/console in the new root */
  rv = mount(h->console.path, path, NULL, MS_BIND, NULL);
  if (rv == -1) {
    fprintf(stderr, "mount: %s\n", strerror(errno));
    return -1;
  }

  return 0;
}

int child_umount_old_root(const char *old_root) {
  char path[MAXPATHLEN];
  char **mount_lines = NULL;
  size_t mount_len = 0;
  int rv;

  rv = snprintf(path, sizeof(path), "%s/proc/mounts", old_root);
  assert(rv < sizeof(path));

  /* Read /proc/mounts */
  FILE *f = fopen(path, "r");
  char buf[1024];

  while (fgets(buf, sizeof(buf), f) != NULL) {
    char *target, *eol;

    target = strchr(buf, ' ');
    assert(target != NULL);
    target = strchr(target, '/');
    assert(target != NULL);
    eol = strchr(target, ' ');
    assert(eol != NULL);

    /* Terminate target at eol */
    *eol = '\0';

    /* Only store mount points reachable from the old root */
    if (strncmp(target, old_root, strlen(old_root))) {
      continue;
    }

    mount_lines = realloc(mount_lines, sizeof(char*) * (mount_len + 1));
    assert(mount_lines != NULL);
    mount_lines[mount_len] = malloc(strlen(target)+1);
    assert(mount_lines[mount_len] != NULL);
    memcpy(mount_lines[mount_len], target, strlen(target)+1);
    mount_len++;
  }

  fclose(f);

  while (1) {
    size_t umounts = 0, candidates = 0;
    size_t i;

    for (i = 0; i < mount_len; i++) {
      char *target = mount_lines[i];
      if (target == NULL) {
        continue;
      }

      candidates++;
      rv = umount(target);
      if (rv == -1) {
        fprintf(stderr, "umount(%s): %s\n", target, strerror(errno));
      } else {
        umounts++;
        free(mount_lines[i]);
        mount_lines[i] = NULL;
      }
    }

    /* Keep going while mounts can be umounted */
    if (umounts == 0) {
      if (candidates == 0) {
        goto ok;
      } else {
        goto err;
      }
    }
  }

ok:
  return 0;

err:
  return -1;
}

int start(void *data) {
  clone_helper_t *h = (clone_helper_t *)data;
  int rv;

  rv = child_die_with_parent(h);
  if (rv == -1) {
    exit(1);
  }

  /* Wait for signal from parent */
  rv = pipe_wait(h->pipe_parent);
  if (rv == -1) {
    exit(1);
  }

  rv = chdir(h->new_root_path);
  if (rv == -1) {
    fprintf(stderr, "chdir: %s\n", strerror(errno));
    exit(1);
  }

  /* Redirect /dev/console to the pty the parent has set up */
  rv = child_setup_dev_console(h);
  if (rv == -1) {
    exit(1);
  }

  rv = mkdir("mnt", 0700);
  if (rv == -1 && errno != EEXIST) {
    fprintf(stderr, "mkdir: %s\n", strerror(errno));
    exit(1);
  }

  rv = pivot_root(".", "mnt");
  if (rv == -1) {
    fprintf(stderr, "pivot_root: %s\n", strerror(errno));
    exit(1);
  }

  rv = chdir("/");
  if (rv == -1) {
    fprintf(stderr, "chdir: %s\n", strerror(errno));
    exit(1);
  }

  rv = child_umount_old_root("/mnt");
  if (rv == -1) {
    exit(1);
  }

  /* Signal parent that its child is about to exec */
  rv = pipe_wakeup(h->pipe_child);
  if (rv == -1) {
    exit(1);
  }

  char * const argv[] = { "/sbin/init", "--debug", NULL };
  execvp(argv[0], argv);
  fprintf(stderr, "execvp: %s\n", strerror(errno));
  exit(1);
}

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

int parent_setup_pipe(int pipefd[2]) {
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

  pipefd[0] = aux[0];
  pipefd[1] = aux[1];
  return 0;

err:
  if (aux[0] >= 0) close(aux[0]);
  if (aux[1] >= 0) close(aux[1]);
  return -1;
}

int parent_setup_helper(clone_helper_t *h) {
  int rv;

  h->new_root_path = getenv("ROOT_PATH");
  if (h->new_root_path == NULL) {
    fprintf(stderr, "ROOT_PATH not specified\n");
    goto err;
  }

  rv = access(h->new_root_path, R_OK);
  if (rv == -1) {
    fprintf(stderr, "cannot access ROOT_PATH: %s\n", strerror(errno));
    goto err;
  }

  h->asset_path = getenv("ASSET_PATH");
  if (h->asset_path == NULL) {
    fprintf(stderr, "ASSET_PATH not specified\n");
    goto err;
  }

  rv = access(h->asset_path, R_OK);
  if (rv == -1) {
    fprintf(stderr, "cannot access ASSET_PATH: %s\n", strerror(errno));
    goto err;
  }

  rv = parent_setup_pipe(h->pipe_daemon);
  if (rv == -1) {
    goto err;
  }

  rv = parent_setup_pipe(h->pipe_parent);
  if (rv == -1) {
    goto err;
  }

  rv = parent_setup_pipe(h->pipe_child);
  if (rv == -1) {
    goto err;
  }

  return 0;

err:
  return -1;
}

int parent_openpty(console_t *c) {
  int rv;

  rv = openpty(&c->master, &c->slave, c->path, NULL, NULL);
  if (rv == -1) {
    fprintf(stderr, "openpty: %s\n", strerror(errno));
    return -1;
  }

  /* Don't leak master fd */
  if (fcntl_mix_cloexec(c->master) == -1) {
    goto err;
  }

  /* Don't leak slave fd */
  if (fcntl_mix_cloexec(c->slave) == -1) {
    goto err;
  }

  return 0;

err:
  close(c->master);
  close(c->slave);
  return -1;
}

int parent_create_console(clone_helper_t *h) {
  console_t *c = &h->console;
  return parent_openpty(c);
}

int parent_clone_child(clone_helper_t *h) {
  long pagesize;
  void *stack;
  int flags = 0;
  pid_t pid;

  pagesize = sysconf(_SC_PAGESIZE);
  stack = alloca(pagesize);
  assert(stack != NULL);

  /* Point to top of stack (it grows down) */
  stack = stack + pagesize;

  /* Setup namespaces */
  flags |= CLONE_NEWIPC;
  flags |= CLONE_NEWNET;
  flags |= CLONE_NEWNS;
  flags |= CLONE_NEWPID;
  flags |= CLONE_NEWUTS;

  pid = clone(start, stack, flags, h);
  if (pid == -1) {
    fprintf(stderr, "clone: %s\n", strerror(errno));
    return -1;
  }

  assert(pid > 0);
  h->pid = pid;

  return 0;
}

int daemon_log_console(clone_helper_t *h) {
  char path[MAXPATHLEN];
  size_t len;
  int fd;

  len = snprintf(path, sizeof(path), "%s/%s", h->asset_path, "console.log");
  assert(len < sizeof(path));

  fd = open(path, O_CREAT | O_WRONLY | O_CLOEXEC, S_IRUSR | S_IWUSR);
  if (fd == -1) {
    fprintf(stderr, "open: %s\n", strerror(errno));
    goto err;
  }

  char buf[1024];
  int nread, nwritten, aux;

  while (1) {
    nread = read(h->console.master, buf, sizeof(buf));
    if (nread == -1) {
      fprintf(stderr, "read: %s\n", strerror(errno));
      exit(1);
    } else if (nread == 0) {
      fprintf(stderr, "read: eof\n");
      exit(1);
    }

    nwritten = 0;
    while (nwritten < nread) {
      aux = write(fd, buf + nwritten, nread - nwritten);
      if (aux == -1) {
        fprintf(stderr, "write: %s\n", strerror(errno));
        exit(1);
      }

      nwritten += aux;
    }
  }

  return 0;

err:
  if (fd >= 0) close(fd);
  return -1;
}

int daemonize(clone_helper_t *h) {
  int rv;

  rv = parent_clone_child(h);
  if (rv == -1) {
    fprintf(stderr, "unable to clone child\n");
    exit(1);
  }

  /* Execute pre-exec script before waking up child */
  rv = fork();
  if (rv == -1) {
    fprintf(stderr, "fork: %s\n", strerror(errno));
    exit(1);
  }

  if (rv == 0) {
    char buf[8];

    snprintf(buf, sizeof(buf), "%d", h->pid);
    rv = setenv("PID", buf, 1);
    if (rv == -1) {
      fprintf(stderr, "setenv: %s\n", strerror(errno));
      exit(1);
    }

    execvp(h->argv[1], &h->argv[1]);
    fprintf(stderr, "execvp: %s\n", strerror(errno));
    exit(1);
  } else {
    int status;

    rv = waitpid(rv, &status, 0);
    if (rv == -1) {
      fprintf(stderr, "waitpid: %s\n", strerror(errno));
      exit(1);
    }

    if (WEXITSTATUS(status) != 0) {
      fprintf(stderr, "pre-exec script exited with non-zero status\n");
      exit(1);
    }
  }

  rv = pipe_wakeup(h->pipe_parent);
  if (rv == -1) {
    fprintf(stderr, "unable to wakeup child, did it die?\n");
    exit(1);
  }

  rv = pipe_wait(h->pipe_child);
  if (rv == -1) {
    fprintf(stderr, "unable to receive ACK from child, did it die?\n");
    exit(1);
  }

  /* Notify this process' parent (don't mind failure) */
  pipe_wakeup(h->pipe_daemon);

  close(fileno(stdin));
  close(fileno(stdout));
  close(fileno(stderr));
  close(h->pipe_daemon[0]);
  close(h->pipe_daemon[1]);
  close(h->pipe_parent[0]);
  close(h->pipe_parent[1]);
  close(h->pipe_child[0]);
  close(h->pipe_child[1]);

  daemon_log_console(h);
  exit(0);
}

int main(int argc, char **argv) {
  int rv;
  clone_helper_t *h;

  h = malloc(sizeof(*h));
  if (h == NULL) {
    fprintf(stderr, "malloc: %s\n", strerror(errno));
    exit(1);
  }

  rv = parent_setup_helper(h);
  if (rv == -1) {
    exit(1);
  }

  h->argc = argc;
  h->argv = argv;

  rv = parent_create_console(h);
  if (rv == -1) {
    fprintf(stderr, "unable to create console\n");
    exit(1);
  }

  rv = fork();
  if (rv == -1) {
    fprintf(stderr, "fork: %s\n", strerror(errno));
    exit(1);
  }

  if (rv == 0) {
    daemonize(h);
    exit(1);
  } else {
    close(h->pipe_parent[0]);
    close(h->pipe_parent[1]);
    close(h->pipe_child[0]);
    close(h->pipe_child[1]);

    /* Only close write side of daemon notification pipe.
     * todo: explore options different than pipes for synchronization */
    close(h->pipe_daemon[1]);

    rv = pipe_wait(h->pipe_daemon);
    if (rv == -1) {
      fprintf(stderr, "error waiting for daemon\n");
      exit(1);
    }
  }

  return 0;
}
