/* Needed for mkdtemp(3) */
#define _BSD_SOURCE
/* Needed for waitpid(2) */
#define _XOPEN_SOURCE

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

static int server_fd = -1;

/* Configuration parameters (set through the environment) */
const char *artifact_path = NULL;
uid_t run_as_uid = -1;

int create_socket(void) {
  int fd = socket(AF_LOCAL, SOCK_STREAM, 0);
  if (fd == -1) {
    perror("socket");
    exit(1);
  }

  return fd;
}

struct sockaddr_un create_addr(char *path) {
  struct sockaddr_un addr;
  addr.sun_family = AF_LOCAL;
  strncpy(addr.sun_path, path, sizeof(addr.sun_path)-1);
  return addr;
}

int copy_to_eof(int fd_in, int fd_out) {
  while (1) {
    char buf[1024];
    int nread;

    nread = read(fd_in, buf, sizeof(buf));
    if (nread == -1) {
      perror("read");
      return -1;
    } else if (nread == 0) {
      /* EOF */
      break;
    }

    int nwritten = 0;
    while (nwritten < nread) {
      int aux = write(fd_out, buf + nwritten, nread - nwritten);
      if (aux == -1) {
        perror("write");
        return -1;
      }

      nwritten += aux;
    }
  }

  return 0;
}

void exec_connect(char *path) {
  int fd = create_socket();
  struct sockaddr_un addr = create_addr(path);

  if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
    perror("connect");
    exit(1);
  }

  /* Copy stdin to socket */
  copy_to_eof(STDIN_FILENO, fd);

  /* There's nothing more to write */
  shutdown(fd, SHUT_WR);

  /* Copy socket to stdout */
  copy_to_eof(fd, STDOUT_FILENO);
}

void handle_client(int client_fd) {
  char template[1024];
  size_t len;

  /* Get directory where we can put this client's artifacts */
  len = snprintf(template, sizeof(template), "%s/runner-XXXXXX", artifact_path);
  assert(len < sizeof(template));

  char *temp = mkdtemp(template);
  if (temp == NULL) {
    perror("mkdtemp");
    exit(1);
  }

  char stdout_path[1024];
  char stderr_path[1024];
  char exit_status_path[1024];
  int stdout_fd = -1;
  int stderr_fd = -1;
  int exit_status_fd = -1;

  /* Generate artifact paths */
  len = snprintf(stdout_path, sizeof(stdout_path), "%s/stdout", temp);
  assert(len < sizeof(stdout_path));
  len = snprintf(stderr_path, sizeof(stderr_path), "%s/stderr", temp);
  assert(len < sizeof(stderr_path));
  len = snprintf(exit_status_path, sizeof(exit_status_path), "%s/exit_status", temp);
  assert(len < sizeof(exit_status_path));

  stdout_fd = open(stdout_path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR);
  if (stdout_fd == -1) goto open_error;
  stderr_fd = open(stderr_path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR);
  if (stderr_fd == -1) goto open_error;
  exit_status_fd = open(exit_status_path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR);
  if (exit_status_fd == -1) goto open_error;

  /* Write artifact path to stdout */
  int nwritten = write(client_fd, temp, strlen(temp));
  assert(nwritten == strlen(temp));

  /* Fork off handler that will reap the script's exit status */
  pid_t handler_pid = fork();
  if (handler_pid == 0) {
    /* Don't need the server fd here */
    close(server_fd);

    /* New process group */
    setsid();

    /* Fork so the server has a process to reap */
    if (fork()) exit(0);

    pid_t bash_pid = fork();
    if (bash_pid == 0) {
      dup2(client_fd, STDIN_FILENO);
      dup2(stdout_fd, STDOUT_FILENO);
      dup2(stderr_fd, STDERR_FILENO);
      close(exit_status_fd);

      if (run_as_uid > 0) {
        if (setuid(run_as_uid) == -1) {
          perror("setuid");
          exit(1);
        }
      }

      char *env = { NULL };
      execle("/bin/bash", "bash", NULL, env);
      perror("execle");
      exit(1);
    }

    close(client_fd);
    close(stdout_fd);
    close(stderr_fd);
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);

    int exit_status = -1;
    if (waitpid(bash_pid, &exit_status, 0) == -1) {
      perror("waitpid");
    }

    /* Write exit status */
    dprintf(exit_status_fd, "%d", WEXITSTATUS(exit_status));
    close(exit_status_fd);

    exit(0);
  }

  /* Reap child */
  if (waitpid(handler_pid, NULL, 0) == -1) {
    perror("waitpid");
  }

  /* Handler was forked, continue with accept(2) */
  goto close;

open_error:
  perror("open");
  exit(1);

close:
  if (client_fd >= 0) close(client_fd);
  if (stdout_fd >= 0) close(stdout_fd);
  if (stderr_fd >= 0) close(stderr_fd);
  if (exit_status_fd >= 0) close(exit_status_fd);
}

void exec_listen(char *path) {
  struct sockaddr_un server_addr = create_addr(path);
  server_fd = create_socket();

  /* Make sure bind(2) can create the socket */
  unlink(path);

  if (bind(server_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) == -1) {
    perror("bind");
    exit(1);
  }

  if (listen(server_fd, 128) == -1) {
    perror("listen");
    exit(1);
  }

  while(1) {
    struct sockaddr_un addr;
    socklen_t addrlen = sizeof(addr);
    int client_fd;

    client_fd = accept(server_fd, (struct sockaddr *)&addr, &addrlen);
    if (client_fd == -1) {
      perror("accept");
      exit(1);
    }

    handle_client(client_fd);
  }
}

void usage(int argc, char **argv) {
  assert(argc > 0);
  fprintf(stderr, "usage: %s (connect|listen) (socket)\n", argv[0]);
  exit(1);
}

int main(int argc, char **argv) {
  if (argc != 3) {
    usage(argc, argv);
  }

  artifact_path = getenv("ARTIFACT_PATH");
  if (artifact_path == NULL) {
    artifact_path = "/tmp";
  }

  struct stat st;
  if (stat(artifact_path, &st) == -1) {
    perror("stat");
    exit(1);
  }

  if (!S_ISDIR(st.st_mode)) {
    fprintf(stderr, "ARTIFACT_PATH is not a directory\n");
    exit(1);
  }

  char *env_run_as_uid = getenv("RUN_AS_UID");
  if (env_run_as_uid != NULL) {
    run_as_uid = atoi(env_run_as_uid);
    if (run_as_uid <= 0) {
      fprintf(stderr, "SETUID must be > 0\n");
      exit(1);
    }
  }

  if (strcmp(argv[1], "connect") == 0) {
    exec_connect(argv[2]);
  } else if (strcmp(argv[1], "listen") == 0) {
    exec_listen(argv[2]);
  } else {
    usage(argc, argv);
  }

  return 0;
}
