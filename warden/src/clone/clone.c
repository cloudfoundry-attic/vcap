#include <sched.h>
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
#include "barrier.h"
#include "console.h"

/* This function doesn't get declared anywhere... */
extern int pivot_root(const char *new_root, const char *put_old);

typedef struct clone_helper_s clone_helper_t;

struct clone_helper_s {
  int argc;
  char **argv;

  char *new_root_path;
  char *asset_path;

  console_t console;

  barrier_t barrier_daemon;
  barrier_t barrier_parent;
  barrier_t barrier_child;
  pid_t pid;
};

int child_die_with_parent(clone_helper_t *h) {
  int rv;

  rv = prctl(PR_SET_PDEATHSIG, SIGKILL);
  if (rv == -1) {
    fprintf(stderr, "prctl: %s\n", strerror(errno));
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
  rv = barrier_wait(&h->barrier_parent);
  if (rv == -1) {
    exit(1);
  }

  rv = chdir(h->new_root_path);
  if (rv == -1) {
    fprintf(stderr, "chdir: %s\n", strerror(errno));
    exit(1);
  }

  /* Mount the pty the parent set up on /dev/console */
  rv = console_mount(&h->console, "dev/console");
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
  rv = barrier_signal(&h->barrier_child);
  if (rv == -1) {
    exit(1);
  }

  char * const argv[] = { "/sbin/init", "--debug", NULL };
  execvp(argv[0], argv);
  fprintf(stderr, "execvp: %s\n", strerror(errno));
  exit(1);
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

  rv = barrier_open(&h->barrier_daemon);
  if (rv == -1) {
    goto err;
  }

  rv = barrier_open(&h->barrier_parent);
  if (rv == -1) {
    goto err;
  }

  rv = barrier_open(&h->barrier_child);
  if (rv == -1) {
    goto err;
  }

  return 0;

err:
  return -1;
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

  rv = barrier_signal(&h->barrier_parent);
  if (rv == -1) {
    fprintf(stderr, "unable to wakeup child, did it die?\n");
    exit(1);
  }

  rv = barrier_wait(&h->barrier_child);
  if (rv == -1) {
    fprintf(stderr, "unable to receive ACK from child, did it die?\n");
    exit(1);
  }

  /* Notify this process' parent (don't mind failure) */
  barrier_signal(&h->barrier_daemon);

  close(fileno(stdin));
  close(fileno(stdout));
  close(fileno(stderr));
  barrier_close(&h->barrier_daemon);
  barrier_close(&h->barrier_parent);
  barrier_close(&h->barrier_child);

  char console_log_path[MAXPATHLEN];
  size_t len;

  len = snprintf(console_log_path, sizeof(console_log_path), "%s/%s", h->asset_path, "console.log");
  assert(len < sizeof(console_log_path));

  console_log(&h->console, console_log_path);
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

  rv = console_open(&h->console);
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
    barrier_close(&h->barrier_parent);
    barrier_close(&h->barrier_child);

    /* Only close write side of daemon notification pipe.
     * todo: explore options different than pipes for synchronization */
    barrier_close_signal(&h->barrier_daemon);

    rv = barrier_wait(&h->barrier_daemon);
    if (rv == -1) {
      fprintf(stderr, "error waiting for daemon\n");
      exit(1);
    }
  }

  return 0;
}
