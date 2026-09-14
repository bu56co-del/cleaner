#include "PawlySpawn.h"
#include <spawn.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

int pawly_spawn(const char *executable, char *const argv[], char *const env[],
                pid_t *pid, int *out_fd, int *err_fd) {
    int out[2], err[2];
    if (pipe(out) != 0) return errno;
    if (pipe(err) != 0) { int code = errno; close(out[0]); close(out[1]); return code; }
    for (int i = 0; i < 2; i++) { fcntl(out[i], F_SETFD, FD_CLOEXEC); fcntl(err[i], F_SETFD, FD_CLOEXEC); }
    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attr;
    int code = posix_spawn_file_actions_init(&actions);
    if (code) goto close_pipes;
    code = posix_spawnattr_init(&attr);
    if (code) goto destroy_actions;
    if ((code = posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0))) goto destroy_attr;
    if ((code = posix_spawn_file_actions_adddup2(&actions, out[1], STDOUT_FILENO))) goto destroy_attr;
    if ((code = posix_spawn_file_actions_adddup2(&actions, err[1], STDERR_FILENO))) goto destroy_attr;
    if ((code = posix_spawnattr_setpgroup(&attr, 0))) goto destroy_attr;
    if ((code = posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))) goto destroy_attr;
    code = posix_spawn(pid, executable, &actions, &attr, argv, env);
destroy_attr:
    posix_spawnattr_destroy(&attr);
destroy_actions:
    posix_spawn_file_actions_destroy(&actions);
close_pipes:
    close(out[1]); close(err[1]);
    if (code) { close(out[0]); close(err[0]); return code; }
    *out_fd = out[0]; *err_fd = err[0];
    fcntl(*out_fd, F_SETFL, O_NONBLOCK);
    fcntl(*err_fd, F_SETFL, O_NONBLOCK);
    return 0;
}
