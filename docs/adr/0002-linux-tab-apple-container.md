# 0002. Linux tab with Apple's `container`

- **Status:** Accepted
- **Date:** 2026-11-21

## Context

macOS is not Linux. The kernel is Darwin and the command-line tools come from BSD, which breaks CTF work in three ways:

| Type | Example | Why |
|---|---|---|
| 1. Different flags | `sed -i`, `grep -P` | GNU vs BSD |
| 2. Needs the Linux kernel | `ip`, `strace`, `/proc` | Not present in Darwin |
| 3. The challenge binary | `./chall` (ELF) | macOS only runs Mach-O |

Today the user leaves the app for a VM or an `ssh` session, and that part of the work is not recorded. Installing the GNU tools with Homebrew solves only type 1.

Apple's `container` runs each container in its own lightweight Linux VM, and with Rosetta it can run x86-64 binaries on Apple Silicon. It is the only option we found that covers all three types without leaving the app.

## Decision

Add a new kind of terminal tab, the **Linux tab**. It is a normal tab with a different child process: instead of zsh, the pty starts `container exec -it` into the challenge's container.

```
Normal tab: app pty → zsh
Linux tab:  app pty → container CLI → challenge VM → Linux pty → bash
```

- **One persistent container per challenge.** The first Linux tab of a challenge creates its container (`container create --rosetta`) and starts it. Later tabs of the same challenge join it with `container exec`, so they open at once. While the app is open, the container stays on standby; when the app quits, it is stopped, not deleted, so installed packages survive between sessions.
- **Image:** a project image based on `ubuntu` for `amd64`, run with Rosetta, so the whole userland is x86-64 with glibc, like a typical CTF target. It ships the usual tools (`gdb`, `strace`, `qemu-user`, `pwntools`) so a new challenge does not start with `apt-get`.
- **Only the challenge's `files/` is mounted.** Not the user's home, not the root folder, not `logs/` or the notes. A binary running in the container cannot reach other challenges, the session logs or the rest of the Mac.
- **Translator toggle, per tab:** each Linux tab has a Rosetta / qemu toggle with a `?` that explains the trade-off. Rosetta is the default. Programs always run under Rosetta; the qemu mode changes only the tools that observe them. In a qemu tab, the image's bash defines `gdb` and `strace` as functions: when the target is an x86-64 ELF, they run it through `qemu-user` (`qemu -g` plus `gdb` with `target remote`, or `qemu -strace`) and print a line saying so. The user types `gdb ./chall` as usual. The tab turns the mode on with an environment variable (`FC_TRANSLATOR=qemu`), so switching the toggle opens a new `exec` in the same container; the container does not restart.
- **Dependency rule:** the app talks to the runtime through its own `ContainerRuntime` protocol. The first implementation calls the CLI. The `Containerization` framework can replace it later without touching the rest of the app.

### Alternatives considered

- **A disposable container per tab (`container run --rm`).** Simplest, and what the spike used. Every tab pays the boot, the CLI's download progress lands in the log, installed tools are lost, and changing the toggle means restarting.
- **One Linux VM for the whole app** (for example `container machine`). Fastest and keeps everything installed, but CTF binaries are untrusted code: a binary from one challenge could read or change the files, notes and logs of every other one. `container machine` also mounts the user's whole home read-write and reserves half of the Mac's memory by default, and its `create` command shows no Rosetta option.

## Validation (F0 spike)

Tested with `container` 1.7.1 on macOS 27, Apple Silicon, using `spikes/pty-relay/` running `container run -it --rm ...` as its child.

| Hypothesis | Result |
|---|---|
| **H1.** `container -it` works inside our pty | ✅ Prompt, Ctrl-C, Ctrl-Z, resize (`stty size` 62×210 → 27×120), `vi` in and out of the alternate screen, and the output is recorded |
| **H2.** The challenge folder is shared both ways | ✅ Files cross in both directions. Inside, every file shows uid 0; on the Mac, files created from Linux belong to the user (uid 502) |
| **H3a.** An x86-64 ELF runs in the VM | ✅ With the amd64 image and Rosetta. In an arm64 image a dynamic x86-64 binary fails because its interpreter (`ld-*-x86_64.so`) is missing |
| **H3b.** An x86-64 ELF can be debugged and traced | ❌ under Rosetta: `gdb` gets `Couldn't get registers`, `strace` shows no syscalls (`ptrace` cannot read x86-64 registers that only exist inside Rosetta). ✅ under `qemu-user`: `qemu -strace` lists syscalls, and `gdb` with `target remote` reads registers and steps |

Real challenge (`the-observer-test`): under Rosetta it ran and answered normally. Under qemu it printed a different result, because `qemu-user` returns `ENOSYS` for `ptrace` and the binary treats that as being observed.

Second round, with a persistent container (`container create --arch amd64 --rosetta --memory 2G -v files:/chall ubuntu sleep infinity`):

| Hypothesis | Result |
|---|---|
| **H4.** A persistent container with `exec` per tab | ✅ `create` 0.04 s, `start` 0.5 s, `exec` 0.07 s. Packages (`qemu-user`, `gdb`, `strace`) and files in `/root` survive `stop` and `start` |
| **H1 via `exec`.** `container exec -it ... bash` inside our pty | ✅ Prompt, Ctrl-C (`sleep 30` interrupted, `$?` = 130) and resize (`stty size` 54×210 → 30×120) |
| **H5a.** Running the tab's shell under qemu | ❌ Only the shell runs under qemu. Every program it starts goes back to the kernel, which hands it to Rosetta: the challenge answered `Token: Invalid.`, its Rosetta result |
| **H5b.** `gdb` and `strace` as bash functions that use qemu | ✅ `strace ./challenge` showed `ptrace(...) = -1 ENOSYS`; `gdb ./challenge` stopped at the first instruction of `ld-linux-x86-64.so.2` and read `rip` |

## Consequences

- The three types of failure are covered without leaving the app, and the session is recorded by the app's pty like any other tab.
- **Structured recording needs our own image.** A plain image has no shell integration hooks (E5), so the tab only gets raw output, recorded like `ssh` (E7) with an explicit gap. Because the project owns the image, it can ship bash hooks that emit the same markers, and the parser then sees commands and exit codes. Until that is built and tested, the Linux tab records raw.
- **The translator changes behavior.** qemu is not transparent: programs can act differently (for example, without `ptrace`). The log records the mode in `session_start` (`translator: rosetta | qemu`), so a result is never mistaken for the real one.
- **Containers are state the app must manage.** Packages and files outside `files/` live in the container, not in the challenge folder. The app must stop containers when it quits, delete a challenge's container when the challenge is deleted, and offer a reset when one gets into a bad state.
- **Containers can be left behind.** After the spike sessions, two `--rm` alpine containers were still running. When the pty side goes away without a clean `exit`, the container does not always stop. The app must not trust the child process to clean up: at launch and at quit, it lists the containers it owns (by name prefix) and stops them.
- **In the amd64 image every program is x86-64**, so the real `strace` and `gdb` never work there on their own. The functions must find the target on `PATH` (`strace ls`, not only `strace ./chall`) and handle options before the program name.
- **Each running container is a VM.** Several challenges open at once means several VMs. The app sets a fixed `--memory` and starts a container only when its first Linux tab opens.
- The CLI's download progress (`[1/6] Fetching image`…) goes through the pty. With persistent containers it appears only when the image is first downloaded, but that time it ends up in the raw log as well.
- Lines from the container arrive as `\r\r\n`. The parser already has to handle `\r`; the extra one must not create empty lines.
- Files created from Linux get the container's `umask` (`644`), not the app's `0600`, and the VM clock is in UTC. The tab passes `TZ`, and the app does not assume its own permissions for files in `files/`.
- Challenge files often arrive without the execute bit. The tab should explain `Permission denied` instead of leaving it raw.
- Works only on Apple Silicon with `container` installed and its service running (`container system start`). The app detects three states (not installed, stopped, ready) and shows a clear message for each.
- The log path is absolute, inside the challenge folder, and never overwritten.

## Open questions

- **v0.1 or v0.2.** The tab depends on the raw recording from E6/E7, which has not started. This points to v0.2.
- **Tools beyond `gdb` and `strace`.** `pwntools` starts `gdb` on its own (`gdb.debug`), and `ltrace` also uses `ptrace`. Each needs a decision in qemu mode.
- **Where the image is built and published**, and how a challenge's container picks up a new version of it.
- **Performance of qemu mode** was not measured.
