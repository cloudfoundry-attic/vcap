#include <sys/param.h>
#include <sys/mount.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include "mount.h"

static int mount__load_proc_mounts(const char *proc_mounts_path, char ***dst) {
  char **mount_lines = NULL;
  size_t mount_len = 0;
  FILE *proc_mounts_file = fopen(proc_mounts_path, "r");
  char buf[1024];

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
    mount_lines[mount_len] = malloc(strlen(target)+1);
    assert(mount_lines[mount_len] != NULL);
    memcpy(mount_lines[mount_len], target, strlen(target)+1);
    mount_len++;
  }

  fclose(proc_mounts_file);

  *dst = mount_lines;
  return mount_len;
}

static void mount__remove_line(char **mount_lines, size_t mount_len, int i) {
  char **src, **dst;

  assert(i < mount_len);

  dst = &mount_lines[i];
  src = &mount_lines[i + 1];

  /* "mount_lines" can be realloc'd after removing an element, but we don't
   * care about leaking some memory here */
  memmove(dst, src, (mount_len - 1 - i) * sizeof(char*));
}

static void mount__swap_line(char **mount_lines, size_t mount_len, int i, int j) {
  char *aux;

  assert(i < mount_len);
  assert(j < mount_len);

  aux = mount_lines[i];
  mount_lines[i] = mount_lines[j];
  mount_lines[j] = aux;
}

static void mount__umount_paths_for_pivoted_root(const char *path, char ***dst_mount_lines, size_t *dst_mount_len) {
  char proc_mounts_path[MAXPATHLEN];
  int rv;

  rv = snprintf(proc_mounts_path, sizeof(proc_mounts_path), "%s/proc/mounts", path);
  assert(rv < sizeof(proc_mounts_path));

  char **mount_lines = NULL;
  size_t mount_len = mount__load_proc_mounts(proc_mounts_path, &mount_lines);

  size_t i, j;

  /* Sort mounts according to unmountability */
  for (i = 0; i < mount_len; i++) {

    /* Remove entries that don't have "path" as prefix */
    while (i < mount_len && strncmp(mount_lines[i], path, strlen(path)) != 0) {
      mount__remove_line(mount_lines, mount_len, i);
      mount_len--;
    }

    do {
      for (j = i + 1; j < mount_len; j++) {
        /* Remove entry if equal to the current entry. This should never happen
         * when the list of mounts is read from a pivoted proc, and "path" is
         * not equal to "/". However, when executed against a non-pivoted root
         * and "path" equals "/", we may see more than one entry for "/". */
        if (strcmp(mount_lines[i], mount_lines[j]) == 0) {
          mount__remove_line(mount_lines, mount_len, j);
          mount_len--;
          break;
        }

        /* Swap entry if it has the current entry as prefix. For example, if
         * the entry at index "i" equals "/dev", and the entry at index "j"
         * equals "/dev/pts", they need to be swapped. It is not possible to
         * unmount "/dev" before unmounting "/dev/pts". */
        if (strncmp(mount_lines[i], mount_lines[j], strlen(mount_lines[i])) == 0) {
          mount__swap_line(mount_lines, mount_len, i, j);
          break;
        }
      }

      /* Break from outer loop when inner loop finished without breaking */
    } while(j < mount_len);
  }

  *dst_mount_lines = mount_lines;
  *dst_mount_len = mount_len;
}

int mount_umount_pivoted_root(const char *path) {
  char **mount_lines;
  size_t mount_len;
  size_t i;
  int rv;

  mount__umount_paths_for_pivoted_root(path, &mount_lines, &mount_len);

  /* Iterate over paths to umount */
  for (i = 0; i < mount_len; i++) {
    rv = umount(mount_lines[i]);

    if (rv == -1) {
      fprintf(stderr, "umount(%s): %s\n", mount_lines[i], strerror(errno));
      return rv;
    }
  }

  return 0;
}

#ifdef TEST

int main(int argc, char **argv) {
  char **mount_lines;
  size_t mount_len;
  size_t i;

  mount__umount_paths_for_pivoted_root("/", &mount_lines, &mount_len);

  for (i = 0; i < mount_len; i++) {
    printf("entry %lu: %s\n", i, mount_lines[i]);
  }

  return 0;
}

#endif
