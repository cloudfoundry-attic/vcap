#include <sched.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
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
#include "mount.h"
#include "util.h"

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

  /* Setup hook script paths */
  char hook_before_pivot[PATH_MAX];
  char hook_after_pivot[PATH_MAX];

  /* Use verbatim path for before hook */
  realpath("./hook-child-before-pivot.sh", hook_before_pivot);

  /* Prefix /mnt to path for after hook */
  strcpy(hook_after_pivot, "/mnt");
  realpath("./hook-child-after-pivot.sh", hook_after_pivot + strlen(hook_after_pivot));

  rv = run(hook_before_pivot);
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

  rv = run(hook_after_pivot);
  if (rv == -1) {
    exit(1);
  }

  rv = mount_umount_pivoted_root("/mnt");
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

  /* Add PID to (parent) environment */
  char buf[8];
  int rv;

  snprintf(buf, sizeof(buf), "%d", h->pid);
  rv = setenv("PID", buf, 1);
  if (rv == -1) {
    fprintf(stderr, "setenv: %s\n", strerror(errno));
    return -1;
  }

  return 0;
}

int daemonize(clone_helper_t *h) {
  int rv;

  rv = barrier_open(&h->barrier_parent);
  if (rv == -1) {
    fprintf(stderr, "cannot create barrier\n");
    exit(1);
  }

  rv = barrier_open(&h->barrier_child);
  if (rv == -1) {
    fprintf(stderr, "cannot create barrier\n");
    exit(1);
  }

  /* Unshare mount namespace, so the before clone hook is free to mount
   * whatever it needs without polluting the global mount namespace. */
  rv = unshare(CLONE_NEWNS);
  if (rv == -1) {
    fprintf(stderr, "unshare: %s\n", strerror(errno));
    exit(1);
  }

  rv = run("./hook-parent-before-clone.sh");
  if (rv == -1) {
    fprintf(stderr, "unable to run before clone hook\n");
    exit(1);
  }

  rv = parent_clone_child(h);
  if (rv == -1) {
    fprintf(stderr, "unable to clone child\n");
    exit(1);
  }

  rv = run("./hook-parent-after-clone.sh");
  if (rv == -1) {
    fprintf(stderr, "unable to run after clone hook\n");
    exit(1);
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
    rv = barrier_wait(&h->barrier_daemon);
    if (rv == -1) {
      fprintf(stderr, "error waiting for daemon\n");
      exit(1);
    }
  }

  return 0;
}
