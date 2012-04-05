#include <sys/param.h>
#include <sys/mount.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include "mount.h"

typedef struct mount_lines_s mount_lines_t;

struct mount_lines_s {
  char **mount_lines;
  size_t mount_len;
};

static void mount__load_proc_mounts(mount_lines_t *dst, const char *proc_mounts_path) {
  char **mount_lines = NULL;
  size_t mount_len = 0;
  FILE *proc_mounts_file;
  char buf[MAXPATHLEN];

  proc_mounts_file = fopen(proc_mounts_path, "r");
  assert(proc_mounts_file != NULL);

  while (fgets(buf, sizeof(buf), proc_mounts_file) != NULL) {
    char *target, *eol;

    target = strchr(buf, ' ');
    assert(target != NULL);
    target = strchr(target, '/');
    assert(target != NULL);
    eol = strchr(target, ' ');
    assert(eol != NULL);

    /* Terminate target at eol */
    *eol = '\0';

    mount_lines = realloc(mount_lines, sizeof(char*) * (mount_len + 1));
    assert(mount_lines != NULL);
    mount_lines[mount_len] = malloc(strlen(target) + 1);
    assert(mount_lines[mount_len] != NULL);
    memcpy(mount_lines[mount_len], target, strlen(target) + 1);
    mount_len++;
  }

  fclose(proc_mounts_file);

  dst->mount_lines = mount_lines;
  dst->mount_len = mount_len;
}

static void mount__remove_line(mount_lines_t *dst, int i) {
  char **mount_lines = dst->mount_lines;
  size_t mount_len = dst->mount_len;

  assert(i < mount_len);

  free(mount_lines[i]);

  /* Move tail elements closer to head */
  if (i < (mount_len - 1)) {
    char **src, **dst;

    dst = &mount_lines[i];
    src = &mount_lines[i + 1];
    memmove(dst, src, (mount_len - 1 - i) * sizeof(char*));
  }

  mount_len--;
  mount_lines = realloc(mount_lines, sizeof(char*) * mount_len);
  assert(mount_lines != NULL);

  dst->mount_lines = mount_lines;
  dst->mount_len = mount_len;
}

static void mount__filter_proc_mounts(mount_lines_t *dst, const char *prefix) {
  size_t i;

  for (i = 0; i < dst->mount_len; i++) {
    /* Remove entry if equal to the current entry. This should never happen
     * when the list of mounts is read from a pivoted proc, and "path" is
     * not equal to "/". However, when executed against a non-pivoted root
     * and "path" equals "/", we may see more than one entry for "/". */
    if (i > 0 && strcmp(dst->mount_lines[i], dst->mount_lines[i - 1]) == 0) {
      mount__remove_line(dst, i);
      i--; /* Retry this index */
      continue;
    }

    /* Only compare the prefix, hence strncmp(3) */
    if (strncmp(dst->mount_lines[i], prefix, strlen(prefix)) != 0) {
      mount__remove_line(dst, i);
      i--; /* Retry this index */
      continue;
    }
  }
}

static int mount__compare_proc_mounts(const void *a, const void *b) {
  /* Negate strcmp(2) for lexicographically descending order */
  return -strcmp(*((char**)a), *((char**)b));
}

static void mount__umount_paths_for_pivoted_root(mount_lines_t *dst, const char *path) {
  char proc_mounts_path[MAXPATHLEN];
  int rv;

  rv = snprintf(proc_mounts_path, sizeof(proc_mounts_path), "%s/proc/mounts", path);
  assert(rv < sizeof(proc_mounts_path));

  mount__load_proc_mounts(dst, proc_mounts_path);

  qsort(dst->mount_lines, dst->mount_len, sizeof(char*), &mount__compare_proc_mounts);

  mount__filter_proc_mounts(dst, path);
}

int mount_umount_pivoted_root(const char *path) {
  mount_lines_t dst;
  size_t i;
  int rv;

  mount__umount_paths_for_pivoted_root(&dst, path);

  /* Iterate over paths to umount */
  for (i = 0; i < dst.mount_len; i++) {
    rv = umount(dst.mount_lines[i]);

    if (rv == -1) {
      fprintf(stderr, "umount(%s): %s\n", dst.mount_lines[i], strerror(errno));
      return rv;
    }
  }

  return 0;
}

#ifdef TEST

int main(int argc, char **argv) {
  mount_lines_t dst;
  size_t i;
  int rv;

  mount__umount_paths_for_pivoted_root(&dst, "/");

  for (i = 0; i < dst.mount_len; i++) {
    printf("entry %lu: %s\n", i, dst.mount_lines[i]);
  }

  return 0;
}

#endif
