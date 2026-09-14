#include <sys/types.h>
// Spawn in a private process group, with null stdin and independent output pipes.
// argv includes argv[0]; both arrays are null-terminated. Returns a POSIX error.
int pawly_spawn(const char *executable, char *const argv[], char *const env[],
                pid_t *pid, int *out_fd, int *err_fd);
