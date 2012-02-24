#ifndef CONSOLE_H
#define CONSOLE_H 1

#include <sys/param.h>

typedef struct console_s console_t;

struct console_s {
  int master;
  int slave;
  char path[MAXPATHLEN];
};

int console_open(console_t *c);

int console_mount(console_t *c, const char *path);

int console_log(console_t *c, const char *output);

#endif
