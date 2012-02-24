#include <sys/param.h>
#include <sys/eventfd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <errno.h>

int main(int argc, char **argv) {
  int event_fd = -1;
  char oom_control_path[PATH_MAX];
  size_t oom_control_path_len;
  int oom_control_fd = -1;
  char event_control_path[PATH_MAX];
  size_t event_control_path_len;
  int event_control_fd = -1;
  char line[LINE_MAX];
  size_t line_len;
  int rv;
  uint64_t result;

  if (argc != 2) {
    fprintf(stderr, "Usage: %s <path to cgroup>\n", argv[0]);
    exit(1);
  }

  /* Open event fd */
  event_fd = eventfd(0, 0);
  if (event_fd == -1) {
    perror("eventfd");
    goto err;
  }

  /* Open oom control file */
  oom_control_path_len = snprintf(oom_control_path, sizeof(oom_control_path), "%s/memory.oom_control", argv[1]);
  assert(oom_control_path_len < sizeof(oom_control_path));

  oom_control_fd = open(oom_control_path, O_RDONLY);
  if (oom_control_fd == -1) {
    perror("open");
    goto err;
  }

  /* Open event control file */
  event_control_path_len = snprintf(event_control_path, sizeof(event_control_path), "%s/cgroup.event_control", argv[1]);
  assert(event_control_path_len < sizeof(event_control_path));

  event_control_fd = open(event_control_path, O_WRONLY);
  if (event_control_fd == -1) {
    perror("open");
    goto err;
  }

  /* Write event fd and oom control fd to event control fd */
  line_len = snprintf(line, sizeof(line), "%d %d\n", event_fd, oom_control_fd);
  assert(line_len < sizeof(line));

  rv = write(event_control_fd, line, line_len);
  if (rv == -1) {
    perror("write");
    goto err;
  }

  /* Read oom */
  do {
    rv = read(event_fd, &result, sizeof(result));
  } while (rv == -1 && errno == EINTR);

  if (rv == -1) {
    perror("read");
    goto err;
  }

  assert(rv == sizeof(result));

  rv = access(event_control_path, W_OK);
  if (rv == -1 && errno == ENOENT) {
    /* The cgroup appears to be removed */
    perror("access");
    goto err;
  }

  if (rv == -1) {
    perror("access");
    goto err;
  }

  fprintf(stdout, "oom");

  rv = 0;
  goto out;

err:
  rv = 1;
  goto out;

out:
  if (event_fd >= 0) {
    close(event_fd);
  }

  if (oom_control_fd >= 0) {
    close(oom_control_fd);
  }

  if (event_control_fd >= 0) {
    close(event_control_fd);
  }

  return rv;
}
