"""Records real zsh sessions as test fixtures for SessionKit.

Each scenario starts /bin/zsh as a login shell inside an 80x24 PTY, with the
app's shell integration installed the way the app installs it, types a fixed
list of keys and saves every byte zsh printed to
Tests/SessionKitTests/Fixtures/<scenario>.raw.

    python3 -I scripts/record-session-fixtures.py           # every scenario
    python3 -I scripts/record-session-fixtures.py basic     # just one

The repository is public, so nothing personal may end up in a fixture:

- The `.zshenv` and `hooks.zsh` come from ShellIntegration.swift itself, so a
  fixture always shows the hooks the app really installs.
- HOME is a fake folder at a fixed path, with a `.zshrc` that sets HOST and a
  fixed PROMPT, since `%n` would print the real user name.
- The environment starts empty instead of copying the caller's.

After recording, check the output for names and paths before committing:

    grep -c "$USER" Tests/SessionKitTests/Fixtures/*.raw   # every count must be 0
"""

import fcntl
import os
import pty
import re
import select
import shutil
import struct
import sys
import tempfile
import termios
import time

PACKAGE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHELL_INTEGRATION = os.path.join(PACKAGE, "Sources", "TerminalKit", "ShellIntegration.swift")
FIXTURES = os.path.join(PACKAGE, "Tests", "SessionKitTests", "Fixtures")
FAKE_HOME = "/tmp/flag-companion-fixture-home"

FAKE_ZSHRC = """\
HOST=ctf-box
PROMPT='ctf@box %~ %# '
"""

# Each step is what to type and how long to keep reading output afterwards.
SCENARIOS = {
    # The "Done when" of E5: three pairs with exit codes 0, 1 and 0.
    "basic": [
        (b"", 1.5),  # first prompt
        (b"ls\r", 0.8),
        (b"false\r", 0.8),
        (b"python3 -c 'print(1)'\r", 1.0),
        (b"exit\r", 0.8),
    ],
    "edges": [
        (b"", 1.5),
        (b"\r", 0.8),  # empty Enter: a D with no command open
        (b"sleep 5\r", 0.5),
        (b"\x03", 0.8),  # Ctrl+C mid-run: D;130
        (b"echo 'two\r", 0.5),  # multi-line command, closed on the next line
        (b"lines'\r", 0.8),
        (b"cd /tmp\r", 0.8),  # OSC 7 follows the new directory
        (b"exit\r", 0.8),  # C with no D: the shell is gone
    ],
    # Over the 64 KB limit: 20000 lines are 108894 bytes.
    "large": [
        (b"", 1.5),
        (b"seq 1 20000\r", 2.0),
        (b"exit\r", 0.8),
    ],
}


def swift_string(source, name):
    """The value of a multi-line `static let <name>` string in a Swift file.

    Swift removes the closing delimiter's indentation from every line, so this
    does the same."""
    match = re.search(
        r'static let ' + name + r' = #?"""\n(.*?)\n( *)"""#?', source, re.DOTALL
    )
    if not match:
        sys.exit(f"{name} not found in {SHELL_INTEGRATION}")
    body, indent = match.group(1), match.group(2)
    lines = [line[len(indent):] if line.startswith(indent) else line.lstrip() for line in body.split("\n")]
    return "\n".join(lines) + "\n"


def install_integration(folder):
    with open(SHELL_INTEGRATION) as file:
        source = file.read()
    for filename, name in ((".zshenv", "zshenv"), ("hooks.zsh", "hooks")):
        with open(os.path.join(folder, filename), "w") as file:
            file.write(swift_string(source, name))


def make_fake_home():
    shutil.rmtree(FAKE_HOME, ignore_errors=True)
    os.makedirs(FAKE_HOME)
    with open(os.path.join(FAKE_HOME, ".zshrc"), "w") as file:
        file.write(FAKE_ZSHRC)
    # Something for `ls` to list.
    for name in ("exploit.py", "flag.txt", "notes.md"):
        open(os.path.join(FAKE_HOME, name), "w").close()


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


def record(scenario, integration):
    make_fake_home()
    env = {
        "HOME": FAKE_HOME,
        "PWD": FAKE_HOME,
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        "TERM": "xterm-256color",
        "LANG": "en_US.UTF-8",
        "SHELL": "/bin/zsh",
        "ZDOTDIR": integration,
    }
    pid, fd = pty.fork()
    if pid == 0:
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        os.chdir(FAKE_HOME)
        os.execve("/bin/zsh", ["-zsh", "-i"], env)  # a login shell, like the app's tabs

    captured = bytearray()
    for typed, wait in SCENARIOS[scenario]:
        if typed:
            os.write(fd, typed)
        if not read_for(fd, wait, captured):
            break
    os.waitpid(pid, 0)

    path = os.path.join(FIXTURES, scenario + ".raw")
    with open(path, "wb") as file:
        file.write(captured)
    print(f"{path}: {len(captured)} bytes")


def main():
    names = sys.argv[1:] or list(SCENARIOS)
    os.makedirs(FIXTURES, exist_ok=True)
    with tempfile.TemporaryDirectory() as integration:
        install_integration(integration)
        for name in names:
            record(name, integration)
    shutil.rmtree(FAKE_HOME, ignore_errors=True)


if __name__ == "__main__":
    main()
