#include <stdbool.h>
#include <termios.h>
#include <sys/select.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>
#include <util.h>
#include <fcntl.h>

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

static bool copy_bytes(int from_fd, int to_fd, int copy_fd) {
    char buffer[256];
    ssize_t count = read(from_fd, buffer, sizeof buffer);
    if (count <= 0) {
        return false;
    }
    write(to_fd, buffer, count);
    if (copy_fd != -1) {
        write(copy_fd, buffer, count);
    }
    return true;
}

static void relay_until_shell_exits(int master_fd, int log_fd) {
    while(true) {
        fd_set readable;
        FD_ZERO(&readable);
        FD_SET(STDIN_FILENO, &readable);
        FD_SET(master_fd, &readable);

        if (select(master_fd + 1, &readable, NULL, NULL, NULL) == -1) {
            perror("select");
            return;
        }

        if (FD_ISSET(STDIN_FILENO, &readable) && !copy_bytes(STDIN_FILENO, master_fd, -1)) {
            return;
        }

        if (FD_ISSET(master_fd, &readable) && !copy_bytes(master_fd, STDOUT_FILENO, log_fd)) {
            return;
        }
    }
}

static void enter_raw_mode(struct termios *original) {
    tcgetattr(STDIN_FILENO, original);

    struct termios raw = *original;
    cfmakeraw(&raw);
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);
}

static void restore_terminal(const struct termios *original) {
    tcsetattr(STDIN_FILENO, TCSANOW, original);
}

static struct winsize current_window_size(void) {
    struct winsize size = {0};
    ioctl(STDIN_FILENO, TIOCGWINSZ, &size);
    return size;
}

int main(void) {
    int master_fd;
    int slave_fd;

    struct winsize window_size = current_window_size();
    if (openpty(&master_fd, &slave_fd, NULL, NULL, &window_size) == -1) {
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

    int log_fd = open("session.log", O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (log_fd == -1) {
        perror("open");
        return EXIT_FAILURE;
    }

    struct termios original_terminal;
    enter_raw_mode(&original_terminal);
    relay_until_shell_exits(master_fd, log_fd);
    restore_terminal(&original_terminal);

    int status;
    waitpid(child_pid, &status, 0);
    fprintf(stderr, "child exit status: %d\n", WEXITSTATUS(status));

    close(master_fd);
    return EXIT_SUCCESS;
}
