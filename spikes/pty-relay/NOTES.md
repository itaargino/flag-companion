# PTY relay spike: notes

What I learned in backlog item E1, while building a minimal terminal in C (`main.c`) that runs zsh inside a pseudo-terminal and records its output.

## File descriptors

### What it is

A file descriptor (fd) is a number that the kernel gives a process to represent something the process has opened: a file, a terminal, a pipe or a network connection. The process only knows the number; the kernel knows what is behind it.

1. A process asks the kernel to open a resource (for example, with `open` or `openpty`).
2. The kernel opens it and returns the lowest free number.
3. From then on, the process uses that number with `read`, `write` and `close`.

Every process starts with three fds already open, inherited from the process that created it (usually the shell): 0 for input (stdin), 1 for output (stdout) and 2 for errors (stderr).

### How I saw it

- `ls -l /dev/fd/` showed fds 0, 1 and 2 pointing to my terminal.
- `ls -l /dev/fd/ > /tmp/fichas.txt` showed fd 1 pointing to a regular file instead. The shell swapped what was behind fd 1 before starting `ls`, and `ls` never noticed.
- `openpty` returned fds 3 and 4, because 0, 1 and 2 were already taken.

### What breaks without it

Without fds, a process would have no way to refer to anything it has opened. And because programs only know the numbers, the same program can write to a terminal, a file or a pty without changing a single line of code. Redirection with `>` and the `dup2` trick in this spike both depend on that.

## Line discipline

### What it is

A layer inside the kernel that sits between the two sides of every terminal. Before input reaches the program, it:

- holds the line until Enter (`icanon`);
- applies editing such as Backspace;
- echoes what is typed back to the screen (`echo`);
- turns control keys into signals, such as Ctrl+C into `SIGINT` (`isig`).

On the way back to the screen, it also adjusts the output, for example turning `\n` into `\r\n` (`onlcr`).

### How I saw it

- `cat` only repeated a line after Enter, and received `abc` after I typed `abx`, Backspace, `c`.
- `stty -echo; cat; stty echo` hid what I typed.
- Writing `hi\n` to the master: the slave received `68 69 0a`, and the echo back on the master was `68 69 0d 0a`. The extra `0d` came from `onlcr`.

### What breaks without it

Programs like `cat` would receive every key the moment it is pressed, including Backspace as a raw byte. Nothing would be echoed, and Ctrl+C would arrive as a plain byte instead of interrupting the program.

## Pseudo-terminal (PTY)

### What it is

A terminal emulated by the kernel, with two ends connected through the line discipline:

- **Slave side** (`/dev/ttysNNN`): looks like a real terminal. The program (zsh) runs with its fds 0, 1 and 2 connected to it.
- **Master side**: held by the program that plays the role of the old teletype. It writes what the user types and reads what must appear on the screen. In a Terminal.app tab, Terminal.app holds the master; in this spike, `pty-relay` does.

Whoever holds the master sees every byte of the session. That is how Flag Companion can record it.

### How I saw it

- `openpty` created the pair and `ttyname` returned `/dev/ttys002` for the slave.
- `script /tmp/sessao.txt` started a new pty: `tty` inside it showed a different `/dev/ttysNNN` from my tab, and the file recorded everything zsh printed.

### What breaks without it

Bytes could still be passed through a pipe, but the program would not believe it is in a terminal: zsh would not enable its line editor, `vim` would not work, and there would be no echo, line editing or Ctrl+C.

## fork, exec and dup2

### What it is

- **`fork`**: creates a child process that is a copy of the parent, including its open fds (same numbers, pointing to the same resources). It returns 0 to the child and the child's PID to the parent.
- **`exec`**: replaces the program running in the current process. No new process is created: the PID, the parent and the open fds stay the same; the old code and memory are gone.
- **`dup2(a, b)`**: makes fd `b` point to the same open resource as fd `a`. It does not create a resource; it only changes what is behind a number.

### How I saw it

- `fork_demo.c` printed the same PID for the parent and for the child's `parent`.
- `zsh -c '...; exec ps ...'` showed the same PID before and after `exec`, with a different command.
- `fork_demo.c` reproduced `ls -l > /tmp/listing.txt` with `open`, `dup2(file_fd, STDOUT_FILENO)` and `exec`.
- In the relay, the child calls `dup2(slave_fd, ...)` on fds 0, 1 and 2 before `exec` of zsh.

### What breaks without it

Without the three `dup2` calls, zsh would keep the fds inherited from `pty-relay`, which point to my tab. It would read straight from my keyboard and write straight to my screen, bypassing the pty: nothing would pass through the relay or be recorded.

## Closing the unused ends

### What it is

After `fork`, both processes hold both ends of the pty. Each one closes the end it does not use: the parent closes `slave_fd` and the child closes `master_fd`.

### How I saw it

In `main.c`, one `close` call on each side of the `fork`.

### What breaks without it

- **If the parent kept the slave open:** the kernel only tells the master that the session ended when nobody holds the slave anymore. After `exit`, the relay's `read` would wait forever.
- **If the child kept the master open:** fds survive `exec`, so zsh, and every program run inside it, would inherit the master and could type into the terminal or read what goes to the screen.

## select

### What it is

`read` blocks: it waits until bytes arrive. `select` receives a list of fds, waits until at least one of them has bytes to read, and reports which ones are ready. The relay then reads only from those, so `read` never blocks.

### How I saw it

The relay watches two fds at once: the keyboard (fd 0) and the master. Before `select`, the program could only do one thing at a time. On macOS, `poll` does not support terminal devices (see the BUGS section of `man poll`), so `select` is used.

### What breaks without it

With two `read` calls in a row, the relay would freeze on the keyboard `read` until a key was pressed, and everything zsh printed meanwhile would be stuck. In `vim`, the screen would not redraw until the next keystroke.

## Raw mode

### What it is

`pty-relay` itself runs inside a terminal: my tab, with its own line discipline. Raw mode (`cfmakeraw`) turns that outer line discipline off, so every keystroke reaches the relay untouched and only the inner pty handles echo, editing and signals. `restore_terminal` gives the tab back its original settings when the relay ends.

### How I saw it

Before raw mode, inside the relay:

- every command appeared twice (one echo from each line discipline);
- Tab completion only happened after Enter;
- Ctrl+C killed the whole `pty-relay`, not just the program inside;
- pasting showed `^[[200~` markers on the screen;
- running `pty-relay` inside `pty-relay` printed each command three times, one per layer.

After raw mode, each command appeared once, and Ctrl+C on `sleep 10` killed only `sleep`.

### What breaks without it

All the symptoms above. And without `restore_terminal`, my tab would stay without echo or line editing after the relay exits (fixed with `reset`).

## Signals and SIGWINCH

### What it is

A signal is a notification from the kernel to a process about an event it cannot predict. Ctrl+C becomes `SIGINT`. `SIGWINCH` means the terminal window changed size; it only notifies, it does not change anything by itself.

The resize path:

1. Terminal.app updates the size of my tab's pty, and the kernel sends `SIGWINCH` to `pty-relay`.
2. The handler only sets the flag `window_resized`, because a handler can interrupt the program at any point and must do the minimum.
3. The signal interrupts `select`, which returns `-1` with `errno == EINTR`. The loop sees the flag, reads the new size with `TIOCGWINSZ` and applies it to the inner pty with `TIOCSWINSZ`, then waits again.
4. The kernel sends `SIGWINCH` to zsh inside, which redraws.

### How I saw it

- `trap 'echo "got SIGWINCH: $(stty size)"' WINCH` in zsh printed the new size on every resize.
- Without passing a size to `openpty`, `stty size` inside the relay showed `0 0` and `$COLUMNS` was 80, so long lines were drawn in the wrong place.
- With the handler, `stty size` inside the relay changed from `57 213` to `44 213` after a resize.

### What breaks without it

The inner pty keeps its old size. zsh wraps lines at the wrong column, and full-screen programs draw for the wrong window size. And if `select` treated every `-1` as fatal, the first resize would end the relay.

## Alternate screen

### What it is

Terminals have two screens. `ESC[?1049h` switches to the alternate screen, a blank one with no history, keeping the normal screen aside; `ESC[?1049l` switches back, and the normal screen reappears untouched. Full-screen programs such as `vim`, `less` and `htop` send these markers when they start and exit.

### How I saw it

`echo before vim` was still on the screen after quitting `vim`. The recorded session contained `^[[?1049h` when `vim` started and `^[[?1049l` when it quit.

### What breaks without it

For Flag Companion: the bytes between the two markers are screen drawing, not command output. Without detecting them, the log would be filled with noise. The parser uses them to mark the command as untracked and discard its output until `ESC[?1049l`. The markers say nothing about whether the program succeeded; the exit code comes from a separate marker (`OSC 133;D`, in E5).

## Session log

### What it is

The relay copies to `session.log` only the bytes that come from the master, that is, what appears on the screen. Keystrokes going to the master are never written (`copy_bytes(STDIN_FILENO, master_fd, -1)`).

A password typed into `sudo` is not recorded for two reasons: keystrokes are never logged, and `sudo` turns off echo in the inner line discipline, so the password never comes back through the master. The `sudo` command line itself is recorded, because zsh echoes it.

### How I saw it

Running `cat -v session.log | grep 1049` inside the relay produced extra markers on every run (3, then 5, then 10 in total). The grep output was shown on the screen, recorded into `session.log` while `cat` was still reading it, and found again.

### What breaks without it

Without separating the two directions, keystrokes, including passwords typed with echo on, would end up in the log. And a log that is read inside the session being recorded feeds itself, so Flag Companion must keep logs in `logs/` and never treat them as session input.
