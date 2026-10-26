#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/wait.h>
#include <termios.h>
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

// Reads the outer terminal's size, so the shell inside can use the same one.
static struct winsize current_window_size(void) {
    struct winsize size = {0};
    ioctl(STDIN_FILENO, TIOCGWINSZ, &size);
    return size;
}

// Set by the signal handler and read by the relay loop.
// sig_atomic_t is the only type a handler can safely write.
static volatile sig_atomic_t window_resized = 0;

// Runs when the outer window changes size. Only records the event;
// the relay loop does the real work outside the handler.
static void handle_window_resize(int signal_number) {
    (void)signal_number;
    window_resized = 1;
}

// Asks the kernel to call handle_window_resize on every SIGWINCH.
static void watch_window_resizes(void) {
    struct sigaction action = {0};
    action.sa_handler = handle_window_resize;
    sigaction(SIGWINCH, &action, NULL);
}

// Copies the outer window size into the inner pty, so the shell redraws.
static void resize_pty_to_outer_window(int master_fd) {
    struct winsize size = current_window_size();
    ioctl(master_fd, TIOCSWINSZ, &size);
}

// Reads whatever is available from one fd and writes it to another.
// When copy_fd is not -1, also writes the same bytes there.
// Returns false when the source has nothing more to give.
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

// Moves keystrokes to the shell and shell output to the screen,
// until either side closes. Only the shell output is recorded:
// keystrokes are never written to the log.
static void relay_until_shell_exits(int master_fd, int log_fd) {
    while (true) {
        fd_set readable;
        FD_ZERO(&readable);
        FD_SET(STDIN_FILENO, &readable);
        FD_SET(master_fd, &readable);

        int ready = select(master_fd + 1, &readable, NULL, NULL, NULL);
        if (window_resized) {
            window_resized = 0;
            resize_pty_to_outer_window(master_fd);
        }
        // A signal interrupted select; nothing to read yet, wait again.
        if (ready == -1 && errno == EINTR) {
            continue;
        }
        if (ready == -1) {
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

// Turns off the outer terminal's line discipline so every keystroke
// reaches the relay untouched. Saves the original settings to restore later.
static void enter_raw_mode(struct termios *original) {
    tcgetattr(STDIN_FILENO, original);

    struct termios raw = *original;
    cfmakeraw(&raw);
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);
}

// Gives the outer terminal back its original settings.
static void restore_terminal(const struct termios *original) {
    tcsetattr(STDIN_FILENO, TCSANOW, original);
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
    watch_window_resizes();
    relay_until_shell_exits(master_fd, log_fd);
    restore_terminal(&original_terminal);
    close(log_fd);

    int status;
    waitpid(child_pid, &status, 0);
    fprintf(stderr, "child exit status: %d\n", WEXITSTATUS(status));

    close(master_fd);
    return EXIT_SUCCESS;
}
