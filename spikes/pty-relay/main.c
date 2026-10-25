#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>
#include <util.h>

// Runs in the child: turns the slave side into this process's terminal,
// then replaces the process with zsh. Never returns.
static void run_shell_on_slave(int slave_fd) {
    setsid();
    ioctl(slave_fd, TIOCSCTTY, 0);

    dup2(slave_fd, STDIN_FILENO);
    dup2(slave_fd, STDOUT_FILENO);
    dup2(slave_fd, STDERR_FILENO);
    close(slave_fd);

    execlp("zsh", "zsh", NULL);
    perror("execlp");
    _exit(EXIT_FAILURE);
}

int main(void) {
    int master_fd;
    int slave_fd;

    if (openpty(&master_fd, &slave_fd, NULL, NULL, NULL) == -1) {
        perror("openpty");
        return EXIT_FAILURE;
    }

    pid_t child_pid = fork();
    if (child_pid == -1) {
        perror("fork");
        return EXIT_FAILURE;
    }

    if (child_pid == 0) {
        close(master_fd);
        run_shell_on_slave(slave_fd);
    }

    close(slave_fd);

    const char *typed_text = "echo hi; exit\n";
    write(master_fd, typed_text, strlen(typed_text));

    char buffer[256];
    ssize_t count;
    while ((count = read(master_fd, buffer, sizeof buffer)) > 0) {
        write(STDOUT_FILENO, buffer, count);
    }

    if (count == -1) {
        perror("read");
    }

    int status;
    waitpid(child_pid, &status, 0);
    fprintf(stderr, "child exit status: %d\n", WEXITSTATUS(status));

    close(master_fd);
    return EXIT_SUCCESS;
}
