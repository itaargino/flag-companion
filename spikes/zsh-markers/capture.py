"""Runs zsh inside a PTY with ZDOTDIR pointing at a spike folder, types a
fixed list of commands and saves every byte zsh prints, so the markers can be
read with `cat -v`.

    python3 capture.py zdotdir captures/basic.raw basic
"""

import os
import pty
import select
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))

# Each step is what to type and how long to keep reading output afterwards.
SCENARIOS = {
    "basic": [
        (b"", 1.5),  # first prompt
        (b"ls\r", 0.8),
        (b"false\r", 0.8),
        (b"python3 -c 'print(1)'\r", 1.0),
        (b"exit\r", 0.8),
    ],
    "edges": [
        (b"", 1.5),
        (b"\r", 0.8),  # empty line: does preexec run?
        (b"sleep 5\r", 0.5),
        (b"\x03", 0.8),  # Ctrl+C mid-run
        (b"echo 'two\r", 0.5),  # multi-line command, closed on the next line
        (b"lines'\r", 0.8),
        (b"cd /tmp\r", 0.8),  # OSC 7 should follow the new directory
        (b"exit\r", 0.8),
    ],
    "order": [
        (b"", 3.0),  # themes such as Powerlevel10k take longer to start
        (b"print -r -- HOOKS $precmd_functions\r", 1.0),
        (b"print -r -- HOOKS $precmd_functions\r", 1.0),
        (b"exit\r", 0.8),
    ],
    "vim": [
        (b"", 1.5),
        (b"vim -u NONE\r", 1.0),
        (b":q\r", 1.0),
        (b"exit\r", 0.8),
    ],
}


def read_for(fd, seconds, sink):
    deadline = time.monotonic() + seconds
    while (remaining := deadline - time.monotonic()) > 0:
        ready, _, _ = select.select([fd], [], [], remaining)
        if not ready:
            continue
        try:
            chunk = os.read(fd, 4096)
        except OSError:  # the slave side closed: zsh exited
            return False
        if not chunk:
            return False
        sink.extend(chunk)
    return True


def main():
    zdotdir, output, scenario = sys.argv[1], sys.argv[2], sys.argv[3]
    env = dict(os.environ)
    env.update(
        ZDOTDIR=os.path.join(HERE, zdotdir),
        FC_SPIKE_DIR=HERE,
        TERM="xterm-256color",
    )
    pid, fd = pty.fork()
    if pid == 0:
        # A login shell, like the app's terminal tabs.
        os.execve("/bin/zsh", ["-zsh", "-i"], env)

    captured = bytearray()
    for typed, wait in SCENARIOS[scenario]:
        if typed:
            os.write(fd, typed)
        if not read_for(fd, wait, captured):
            break
    os.waitpid(pid, 0)
    os.makedirs(os.path.dirname(output) or ".", exist_ok=True)
    with open(output, "wb") as file:
        file.write(captured)


if __name__ == "__main__":
    main()
