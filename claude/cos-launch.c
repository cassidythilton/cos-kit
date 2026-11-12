// cos-launch: the one program launchd starts for every chief-of-staff job.
//
// macOS privacy (TCC) gives a launchd job only the access of the program launchd starts, and its children inherit
// it. Cassidy grants this program Full Disk Access once (System Settings > Privacy & Security > Full Disk Access),
// so every scheduled job can read ~/Documents, without granting /bin/zsh (which would cover every zsh script).
//
// It runs only programs in ~/cos/bin, by bare name, through a login zsh (for PATH), and returns their exit code.
//   cos-launch cos-sched pulse
// install.sh builds it from this file and rebuilds only when this file changes: macOS ties the grant to the build.
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>

extern char **environ;

int main(int argc, char **argv) {
    if (argc < 2 || argc > 60) { fprintf(stderr, "usage: cos-launch <program in ~/cos/bin> [args]\n"); return 64; }
    const char *name = argv[1];
    if (strchr(name, '/') || name[0] == '.' || name[0] == '\0') { fprintf(stderr, "cos-launch: a bare program name only\n"); return 64; }
    const char *home = getenv("HOME");
    if (!home || home[0] != '/') { fprintf(stderr, "cos-launch: HOME is not set\n"); return 64; }
    char prog[1024];
    if (snprintf(prog, sizeof prog, "%s/cos/bin/%s", home, name) >= (int)sizeof prog) return 64;

    // zsh -lc 'exec "$0" "$@"' <prog> <args...>: a login shell for PATH, then the program itself, no word splitting.
    char *args[64];
    int n = 0;
    args[n++] = "/bin/zsh";
    args[n++] = "-lc";
    args[n++] = "exec \"$0\" \"$@\"";
    args[n++] = prog;
    for (int i = 2; i < argc; i++) args[n++] = argv[i];
    args[n] = NULL;

    pid_t pid;
    int rc = posix_spawn(&pid, "/bin/zsh", NULL, NULL, args, environ);
    if (rc != 0) { fprintf(stderr, "cos-launch: could not start zsh (%d)\n", rc); return 70; }
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) return 70;
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return 128 + (WIFSIGNALED(status) ? WTERMSIG(status) : 0);
}
