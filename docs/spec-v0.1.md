# Flag Companion — v0.1 Specification

*Last updated: 2026-10-17*

## Overview

Flag Companion is a native macOS app that brings a terminal, notes and session recording together in one place for CTF players. Each challenge is a real folder on disk, with embedded terminals that record commands and their output, Markdown notes and screenshots.

**Problem.** Today, notes from a challenge end up as a loose block of text: commands, repeated output, typos, hints and screenshots all mixed together. In the picoCTF `enc` challenge, the reasoning that led to the flag (`xxd`, the `<< 8`, the `// 256` and `% 256`) was buried between consecutive `cd ..` commands, three identical `SyntaxError`s and one output repeated 19 times.

**Proposal.** The app records the session in a structured way (command, output, exit code, directory, timestamp), lets the user highlight what mattered and keeps notes next to the terminal. In later versions, it generates an on-device report from that record.

**Audience.** First, the author. Then, any CTF player who uses a Mac.

**Personal goal.** An open-source project on GitHub that solves a real problem and exercises SwiftUI and AppKit, pseudo-terminals and Unix processes, applied security and the new technologies in macOS 27.

## Principles

Seven rules guide product and code decisions. When in doubt, the higher rule wins.

1. **Local-first.** Nothing leaves the machine: no account, no server, on-device processing.
2. **The folder belongs to the user.** Open file formats (Markdown, JSON Lines, PNG), readable and editable outside the app. The disk is the source of truth.
3. **Honest records.** Whatever the app could not track appears as an explicit gap, never as silence.
4. **The terminal comes first.** The app never gets in the way of typing. Every action has a keyboard shortcut.
5. **Highlighting is cheap.** Marking something important costs one click or one shortcut, without leaving the flow.
6. **Secure by default.** Keystrokes are never recorded, files have restricted permissions, recording can be paused, encryption is optional.
7. **Native to the Mac.** Menu bar, shortcuts, windows and settings follow macOS conventions.

## v0.1 Scope

v0.1 is done when a real picoCTF challenge can be solved entirely inside the app and, at the end, the challenge folder contains structured commands, highlights, notes and screenshots, with nothing lost if the app quits halfway.

**In v0.1**

- Library of CTFs and challenges, backed by real folders on disk
- First-run setup (root folder, shell, recording policy)
- Embedded terminal with multiple tabs per challenge
- Shell integration for local zsh (prompt, command and output boundaries)
- Append-only event log in JSON Lines, one file per terminal
- Detection of full-screen programs (`vim`, `less`, `htop`), recorded as an "untracked" event
- `ssh` working in raw recording mode
- Notes panel with Context, Findings and Screenshots tabs plus custom tabs, all in Markdown
- Bottom bar: highlight input, highlight output, pause and resume recording
- Menu bar and keyboard shortcuts
- Restricted permissions on created files and folders

**Out of v0.1**

| Item | Planned for |
| --- | --- |
| Optional log encryption | v0.2 |
| Shell integration on the remote side of `ssh` | v0.2 |
| Session view (timeline of events) | v0.2 |
| Noise cleanup and on-device report | v0.2 |
| Screenshot capture by shortcut | v0.2 |
| PDF and Obsidian export | v0.3 |
| Search across challenges | v0.3 |
| bash and fish support | v0.3 |
| iPhone companion to reread sessions | Later |
| Restore terminals when reopening the app | Later |

## Interface

A challenge window has two columns: the terminal on the left, larger, and notes on the right, resizable and collapsible. Frequent actions live in the bottom bar; everything else goes to the menu bar, always with a shortcut.

**Screens**

1. **Library** (home screen): list of CTFs and, inside each one, its challenges with name, category and status. Buttons for new CTF and new challenge.
2. **Challenge window**: opens when a challenge is selected. The back button (←) returns to the library.
3. **Settings** (⌘,): standard macOS window with the first-run choices.

**Terminal column**

- Tabs at the top, one per terminal, with a + button for a new tab. Editable names (for example "local", "thinkpad").
- Recording indicator on each tab: red dot while recording, gray while paused.
- The terminal fills the remaining space.
- Bottom bar with action buttons (table below).

**Notes column**

- Header with ← and the challenge name.
- Fixed tabs Context, Findings and Screenshots, plus custom tabs through +.
- Context and Findings: Markdown editor with autosave.
- Screenshots: grid of images from the `prints/` folder, with drag and drop and paste (⌘V).

**Bottom bar**

| Button | What it does | Visual feedback | Proposed shortcut |
| --- | --- | --- | --- |
| Highlight input | Marks the command of the last event as important | Margin marker on the command line and a "Highlighted: `xxd enc`" notice | ⌃⌘I |
| Highlight output | Marks the output of the last event as important | Margin marker on the output block | ⌃⌘O |
| Pause / resume | Stops recording events without closing the terminal | Tab dot turns gray and the bar shows "Recording paused" | ⌃⌘P |
| Send to Findings | Copies the event's command and output to `findings.md` as a code block | Findings tab flashes once | ⌃⌘A |

"Last event" is the most recent completed command. Selecting an earlier block before highlighting is planned for v0.2, together with the session view.

**Menu bar**

| Menu | Item | Proposed shortcut |
| --- | --- | --- |
| File | New CTF | ⇧⌘N |
| File | New challenge | ⌘N |
| File | Open root folder in Finder | ⇧⌘O |
| File | New terminal tab | ⌘T |
| File | Close tab | ⌘W |
| Edit | Copy, paste, find in terminal | macOS defaults |
| View | Show or hide notes | ⌥⌘N |
| View | Terminal tab 1 to 9 | ⌘1 to ⌘9 |
| View | Go to Context, Findings, Screenshots | ⌥⌘1, ⌥⌘2, ⌥⌘3 |
| Terminal | Highlight input, highlight output, pause, send to Findings | See bottom bar |
| Terminal | Clear screen | ⌘K |
| Challenge | Mark as solved and record flag | ⇧⌘F |
| Challenge | Back to library | ⌘[ |

Before finalizing shortcuts, check for conflicts with system defaults and with SwiftTerm.

## First-run setup

On first launch, a five-step assistant prepares the app for recording. Every choice can be changed later in Settings (⌘,).

1. **Welcome.** Explains in three lines what the app does and what it records: confirmed commands and their output. States clearly that keystrokes are never recorded.
2. **Root folder.** The user picks or creates the folder where CTFs live (suggestion: `~/CTFs`). It can live inside an Obsidian vault. The app creates the folder with permission `0700`.
3. **Shell.** The app detects the default shell (`$SHELL`). In v0.1, structured recording only works with zsh; with another shell, it warns that recording will be raw. The app **does not edit** the user's `~/.zshrc` (see "Terminal capture").
4. **Recording policy.**
    - Record output: yes (default) or commands only.
    - Output limit per command: 64 KB (default), truncated with a note in the log.
    - Start new terminals recording: yes (default) or paused.
5. **Summary.** Shows the choices and a button to create the first CTF.

In v0.2, a sixth step is added: "Do you want to encrypt session logs?", with a choice between syncing the key through iCloud Keychain or exporting it (see "Security and privacy").

Preferences are stored in `UserDefaults`. No configuration goes inside the root folder, so it remains user content only.

## Folder structure

The disk is the source of truth: the library is just a reading of the folders inside the root folder. A CTF is a folder with a `ctf.json`; a challenge is a subfolder with a `challenge.json`.

```
~/CTFs/                          root folder (chosen during setup)
└── picoCTF-2026/                CTF
    ├── ctf.json                 CTF metadata
    └── enc/                     challenge
        ├── challenge.json       challenge metadata
        ├── notes/
        │   ├── context.md
        │   ├── findings.md
        │   └── tools.md         custom tab
        ├── prints/
        │   └── 2026-10-16_11-20-25.png
        ├── files/               challenge files (enc, binaries)
        └── logs/
            ├── t1-local.jsonl
            └── t2-thinkpad.jsonl
```

**Challenge metadata** (`challenge.json`):

```json
{
  "v": 1,
  "name": "enc",
  "category": "crypto",
  "points": 100,
  "status": "solved",
  "flag": "academy{16_bits_inst34d_of_8_...}",
  "created_at": "2026-10-15T10:34:38-04:00",
  "solved_at": "2026-10-16T11:40:02-04:00",
  "tabs": ["context", "findings", "prints", "tools"],
  "encrypted_logs": false
}
```

**Rules**

- Possible statuses: `todo`, `in_progress`, `solved`, `abandoned`.
- Folder names are slugs (lowercase, hyphens). The display name lives in the JSON.
- A new terminal opens with `files/` as its current directory.
- Each terminal writes to `logs/t<N>-<tab-name>.jsonl`. Renaming the tab does not rename the file; the name is recorded in the `session_start` event.
- Custom tabs are files in `notes/`; tab order lives in `tabs`.
- Edits made outside the app are accepted. In v0.1 the app rereads files when it becomes active; in v0.2 it watches for changes with FSEvents.
- Folders are created with `0700` and files with `0600`.

## Terminal capture

The app reads the same byte stream it draws on screen and splits it into events using invisible markers emitted by the shell. Without those markers, it only sees plain text.

**1. Pseudo-terminal (PTY)**

Each tab creates a PTY pair (`openpty`/`forkpty`) and starts zsh on the slave side. The app keeps the master side: it writes what the user types into it and reads everything the shell and programs print. SwiftTerm already does this with `LocalProcess`; the recommendation is to use it in the app, but to write a minimal PTY of our own in the learning spike (see backlog, E1).

**2. Splitting the stream**

Every chunk of bytes read from the PTY goes to two places: the SwiftTerm emulator, which draws the screen, and the `SessionParser`, which looks for markers and builds events. The parser never blocks the screen: it runs off the main thread and writes through a queue.

**3. Shell integration without touching `~/.zshrc`**

The app starts zsh with the `ZDOTDIR` variable pointing to its own folder in `~/Library/Application Support/FlagCompanion/zsh/`. That folder's `.zshrc` first loads the user's `~/.zshrc` and then registers the hooks. The user keeps their prompt, aliases and plugins, and none of their files are changed.

The hooks emit OSC (Operating System Command) sequences, which the terminal does not draw:

| Marker | When | Meaning |
| --- | --- | --- |
| `OSC 133;A` | `precmd`, before the prompt | Prompt started |
| `OSC 133;B` | End of the prompt (in `PS1`) | User is about to type |
| `OSC 7770;cmd;<base64>` | `preexec` | Text of the confirmed command (app-specific marker) |
| `OSC 133;C` | `preexec`, after the command | Output started |
| `OSC 133;D;<code>` | `precmd`, first thing | Command finished with this exit code |
| `OSC 7;file://<host><cwd>` | `precmd` | Current directory |

Hook sketch, to be validated in E5:

```zsh
_fc_precmd() {
  local ec=$?
  printf '\e]133;D;%s\a' "$ec"
  printf '\e]7;file://%s%s\a' "$HOST" "$PWD"
  printf '\e]133;A\a'
}
_fc_preexec() {
  printf '\e]7770;cmd;%s\a' "$(printf '%s' "$1" | base64)"
  printf '\e]133;C\a'
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _fc_precmd
add-zsh-hook preexec _fc_preexec
PS1="$PS1%{$(printf '\e]133;B\a')%}"
```

The number `7770` is provisional; before settling on it, check that it does not collide with markers from other terminals. Prompts that rewrite `PS1` dynamically (themes such as Powerlevel10k) may drop the B marker; this needs testing.

**4. Parser state machine**

- `idle` → receives `A` → `prompt`
- `prompt` → receives `7770;cmd` → stores the command → receives `C` → writes `command_start` → `running`
- `running` → accumulates output → receives `D` → writes `command_end` → `idle`
- A `D` with no open command (the first prompt) is ignored.
- Output without a preceding `C` (for example, background job messages) becomes a `raw_chunk`.

**5. Output handling**

- ANSI color and cursor sequences are removed before writing; the log stores clean text.
- `\r` overwriting the same line (progress bars) keeps only the final version of the line.
- Output above the limit (64 KB by default) is truncated, with `truncated: true` and the total byte count.

**6. Full-screen programs**

While a command runs, if the switch to the alternate screen appears (`ESC[?1049h`, `?1047h` or `?47h`), the parser marks the command as untracked and discards output until the switch back (`ESC[?1049l`). The log receives an `untracked` event with the command, and the interface shows the gap as "not tracked, fill in if relevant".

**7. `ssh` and raw recording**

Inside `ssh`, the remote shell is running, and it emits no markers. From the parser's point of view, `ssh` is a single long command: everything becomes its output. So that a long session is not lost if the app crashes, the output of a command running longer than 30 seconds or larger than 16 KB is written as periodic `raw_chunk` events, and `command_end` closes the block. In v0.2, the app offers to copy the integration script to the remote host.

**8. What is never recorded**

Keystrokes. The command text comes from `preexec`, which only receives the line confirmed with Enter. `sudo` and `ssh` passwords are not echoed, so they do not appear in the output either.

**9. Pausing**

While paused, the parser keeps following the markers (so it does not lose track of state), but writes nothing other than `recording_paused` and `recording_resumed`.

## Log format

Each terminal writes an append-only JSON Lines file: one event per line, never rewritten. If the app crashes, at most the last incomplete line is lost.

**Fields common to every event**

| Field | Type | Description |
| --- | --- | --- |
| `v` | integer | Format version (starts at 1) |
| `seq` | integer | Increasing counter within the file |
| `ts` | ISO 8601 string | Timestamp with milliseconds and time zone |
| `type` | string | Event type (table below) |

**Event types**

| `type` | Own fields | When |
| --- | --- | --- |
| `session_start` | `term`, `tab_name`, `shell`, `cwd`, `host`, `app_version`, `integration` (`true`/`false`) | Terminal opened |
| `command_start` | `id`, `cmd`, `cwd` | Marker C received |
| `command_end` | `id`, `exit`, `output`, `truncated`, `bytes`, `duration_ms` | Marker D received |
| `raw_chunk` | `id` (optional), `output` | Output without markers, or partial block of a long command |
| `untracked` | `id`, `cmd`, `reason` (`alternate_screen`) | Full-screen program detected |
| `highlight` | `target` (command id), `part` (`input`/`output`) | Highlight button |
| `unhighlight` | `target`, `part` | Undo highlight |
| `sent_to_notes` | `target`, `file` | Send to Findings button |
| `recording_paused` | — | Pause |
| `recording_resumed` | — | Resume |
| `session_end` | `reason` (`closed`, `shell_exited`) | Terminal closed |

**Example: excerpt from the `enc` challenge**

```json
{"v":1,"seq":1,"ts":"2026-10-16T10:34:38.120-04:00","type":"session_start","term":"t1","tab_name":"local","shell":"/bin/zsh","cwd":"~/CTFs/picoCTF-2026/enc/files","host":"MacBook-Pro-67","app_version":"0.1.0","integration":true}
{"v":1,"seq":2,"ts":"2026-10-16T10:35:02.441-04:00","type":"command_start","id":"c1","cmd":"xxd enc","cwd":"~/CTFs/picoCTF-2026/enc/files"}
{"v":1,"seq":3,"ts":"2026-10-16T10:35:02.468-04:00","type":"command_end","id":"c1","exit":0,"output":"00000000: e685 a3e6 85a4 e695 ...","truncated":false,"bytes":251,"duration_ms":27}
{"v":1,"seq":4,"ts":"2026-10-16T10:35:10.002-04:00","type":"highlight","target":"c1","part":"output"}
{"v":1,"seq":5,"ts":"2026-10-16T11:21:40.300-04:00","type":"untracked","id":"c2","cmd":"vim decoder.py","reason":"alternate_screen"}
{"v":1,"seq":6,"ts":"2026-10-16T11:39:58.910-04:00","type":"command_start","id":"c3","cmd":"python3 decoder.py","cwd":"~/CTFs/picoCTF-2026/enc/files"}
{"v":1,"seq":7,"ts":"2026-10-16T11:39:59.034-04:00","type":"command_end","id":"c3","exit":0,"output":"academy{16_bits_inst34d_of_8_...}","truncated":false,"bytes":40,"duration_ms":124}
{"v":1,"seq":8,"ts":"2026-10-16T11:40:01.500-04:00","type":"highlight","target":"c3","part":"output"}
```

**Writing and reading rules**

- `command_start` and `command_end` are separate on purpose: if the app crashes during a command, its start is already saved.
- Each line is written with `write` followed by a batched `fsync` (at most once per second), on a dedicated serial queue.
- The reader ignores unknown types and discards a malformed last line.
- Command ids (`c1`, `c2`…) are unique within the file; file plus id identifies an event within the challenge.
- Format changes bump `v` and keep reading previous versions.

## Security and privacy

A security tool that leaks secrets into its own log would be the worst possible defect. v0.1 guarantees no keystroke recording, restricted permissions and pausing; v0.2 adds optional log encryption, with notes always left open.

**Threats and mitigations**

| Threat | Mitigation | Version |
| --- | --- | --- |
| A password typed into `sudo` or `ssh` ending up in the log | Never record keystrokes; the command comes from `preexec` and the password is not echoed | v0.1 |
| A token or password inside the command itself (`curl -H "Authorization: ..."`) | Pause recording button | v0.1 |
| Same case, when the user forgets to pause | Optional pattern-based redaction (`Authorization` headers, `AKIA...` keys, `password=`) and a "delete event" command | v0.2 |
| Another user or process on the Mac reading the logs | Folders `0700`, files `0600` | v0.1 |
| Folder shared, sent to someone or pushed to GitHub by mistake | Optional log encryption | v0.2 |
| Lost or stolen Mac | FileVault (outside the app's scope) | — |

**Optional encryption (v0.2)**

- **What is encrypted:** only the files in `logs/`. Notes and screenshots stay open, so they keep working in Obsidian and any editor.
- **How, without losing append-only:** each JSONL line is sealed separately with AES-GCM (CryptoKit). The written line becomes `{"v":1,"enc":"<base64 of the SealedBox>"}`. A corrupted line does not compromise the others.
- **Key:** one 256-bit `SymmetricKey` per root folder, stored in the Keychain, with access control that requires user presence (Touch ID or the Mac password) through `SecAccessControl` and `LocalAuthentication`.
- **Unlocking:** when opening a challenge with encrypted logs, the app asks for Touch ID. The key stays in memory while the app is open and is discarded when the screen locks or after a configurable idle period.
- **Not losing the key (both options):**
    - **Sync** through iCloud Keychain, to open the logs on another Mac with the same Apple Account.
    - **Export** a recovery file protected by a password. CryptoKit has no password-based key derivation; use PBKDF2 from CommonCrypto with many iterations, or an Argon2 library.
- **To validate in a spike:** whether a Keychain item can both sync through iCloud and require Touch ID. If not, syncing uses a separate item and Touch ID only protects access inside the app.
- **Setup question:** "Do you want to encrypt session logs?" Default: no. Can also be enabled per challenge from the Challenge menu.

Encryption does not replace not recording: a sealed secret is still inside the file. That is why pausing and redaction exist regardless of encryption.

## Technical stack and distribution

Swift app for macOS 27, without sandbox, distributed through GitHub under the MIT license. Session logic lives in separate, testable Swift packages that do not depend on the interface.

| Layer | Choice | Notes |
| --- | --- | --- |
| Language | Swift 6 | Strict concurrency from the start |
| Concurrency | `MainActor` as default isolation in the app target | Packages declare their isolation explicitly |
| Interface | SwiftUI, with AppKit where needed | The terminal is bridged through `NSViewRepresentable` |
| Terminal | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Emulator and `LocalProcess`; confirm MIT license and macOS 27 compatibility |
| Processes | `forkpty` / `posix_spawn` | Own spike in E1; through SwiftTerm in the app |
| Persistence | Files (`FileManager`, `FileHandle`) + `Codable` | No database: the disk is the source of truth |
| Preferences | `UserDefaults` / `@AppStorage` | Outside the root folder |
| Tests | Swift Testing | `@Test` and `#expect` |
| Encryption (v0.2) | CryptoKit, Security (Keychain), LocalAuthentication | AES-GCM per line |
| On-device report (v0.2) | Apple's on-device language model | Limited context: preprocess first |
| PDF (v0.3) | PDFKit or rendering SwiftUI views | — |
| Minimum version | macOS 27 | Required for the on-device APIs |

**Sandbox and distribution**

- App Sandbox disabled: a shell inside a sandboxed app inherits its restrictions and cannot work as a real terminal. See [ADR 0001](adr/0001-disable-app-sandbox.md).
- Hardened Runtime enabled.
- Releases on GitHub. For the app to open without Gatekeeper warnings, it must be signed with a Developer ID and notarized, which requires a paid Apple Developer Program membership. Without it, the README explains how to build from source.

**Repository structure**

Current layout, with the planned additions marked:

```
flag-companion/
├── FlagCompanion/
│   ├── FlagCompanion.xcodeproj
│   ├── FlagCompanion/          SwiftUI app: windows, menus, views
│   └── FlagCompanionTests/     app tests
├── Packages/                   (planned)
│   ├── SessionKit/             OSC parser, state machine, events
│   ├── LogStore/               append-only JSONL, reading, encryption (v0.2)
│   └── Workspace/              CTF and challenge folders, metadata
├── Resources/shell/            (planned) zsh integration scripts
├── docs/
│   ├── spec-v0.1.md            this specification
│   └── adr/                    architecture decision records
├── CONTRIBUTING.md
├── LICENSE                     MIT
└── README.md
```

**Conventions**

See [CONTRIBUTING.md](../CONTRIBUTING.md). In short:

- `SessionKit` is tested by feeding byte streams recorded from real sessions and checking the events produced. This is what gives the repository credibility.
- Each backlog epic becomes a milestone, and each task becomes a GitHub issue.
- Commits follow Conventional Commits (`feat:`, `fix:`, `docs:`).
- Each hard decision becomes a short ADR in `docs/adr/`.

## v0.1 Backlog

There are 14 epics, in the suggested order of execution. Each one ends in a verifiable done criterion; do not move to the next before meeting it. The spikes (E1 and the start of E5) are for learning: the code may be thrown away, the understanding may not.

### E0 — Repository foundation

- [x] Create the `flag-companion` repository on GitHub with MIT license and Swift `.gitignore`
- [x] Create the Xcode project for the macOS app (SwiftUI, macOS 27, Swift 6, Swift Testing)
- [x] Disable App Sandbox and enable Hardened Runtime
- [ ] Create the local packages `SessionKit`, `LogStore` and `Workspace`, each with one passing test
- [ ] Add this specification as `docs/spec-v0.1.md`
- [ ] Write ADR 0001 "Disable App Sandbox"
- [ ] Write `CONTRIBUTING.md` with workflow and code style
- [ ] Initial README: what it is, "in development" status, how to build
- [ ] Create milestones E0 to E13 and the issues in this backlog
- [ ] CI with GitHub Actions running the tests
- [ ] Single test command (`make test`)

**Done when:** the app opens an empty window, tests run in CI and the README explains the project.

### E1 — PTY spike (learning)

- [ ] Read `man openpty`, `man forkpty` and `man termios`
- [ ] Write a command-line program in Swift (or C) that creates a PTY, starts `/bin/zsh` and relays input and output
- [ ] Print the bytes zsh returns in hexadecimal and identify the prompt's escape sequences
- [ ] Run `vim` inside it and observe `ESC[?1049h` and `ESC[?1049l`
- [ ] Handle resizing with `TIOCSWINSZ` and `SIGWINCH`
- [ ] Handle the child process exiting (`waitpid`) and close the descriptors
- [ ] Write up what you learned (it can become the first blog post)

**Done when:** the spike runs zsh and vim in a usable way and you can explain the role of the master side, the slave side and the line discipline.

### E2 — Workspace: folders and library

- [ ] `CTF` and `Challenge` models with `Codable` for `ctf.json` and `challenge.json`
- [ ] Function that builds a slug from a name (lowercase, hyphens, no accents)
- [ ] Scan the root folder and build the list of CTFs and challenges
- [ ] Create a CTF and a challenge with the subfolder structure (`notes/`, `prints/`, `files/`, `logs/`)
- [ ] Apply permissions `0700` to folders and `0600` to files
- [ ] Ignore folders without JSON and report invalid JSON without crashing
- [ ] Library screen: list of CTFs, challenges with status and category, create buttons
- [ ] Open the folder in Finder from the menu
- [ ] `Workspace` tests with a temporary folder

**Done when:** you can create one CTF and three challenges in the app, see everything in Finder with the right structure and reopen the app with the list intact.

### E3 — First-run setup

- [ ] Detect first launch
- [ ] Assistant with the five steps from "First-run setup"
- [ ] Root folder selection with `NSOpenPanel` (including creating a new folder)
- [ ] Detect `$SHELL` and warn when it is not zsh
- [ ] Save preferences in `UserDefaults`
- [ ] Settings window (⌘,) with the same options

**Done when:** deleting the preferences and reopening the app leads back to the assistant, and the choices made there appear in Settings.

### E4 — Embedded terminal with tabs

- [ ] Add SwiftTerm through Swift Package Manager
- [ ] Wrap `LocalProcessTerminalView` in `NSViewRepresentable`, behind a `TerminalEmulating` protocol
- [ ] Start zsh with the challenge's `files/` as current directory
- [ ] Tabs: create (⌘T), close (⌘W), switch (⌘1 to ⌘9), rename by double-clicking
- [ ] Ask before closing a tab with a running process
- [ ] Keep processes alive when switching tabs
- [ ] Configurable font and theme (monospaced, light and dark)
- [ ] Split window: terminal on the left, notes area on the right (empty for now), resizable

**Done when:** you can work on a challenge with three tabs, including `vim` and `ssh`, with no noticeable difference from macOS Terminal.

### E5 — Shell integration and parser

- [ ] Spike: run the hook sketch in a regular zsh and see the markers with `cat -v`
- [ ] Create the app's `ZDOTDIR` folder in Application Support and the `.zshrc` that loads the user's one and then the hooks
- [ ] Test with the default prompt, with Oh My Zsh and with Powerlevel10k
- [ ] Choose and document the app's own OSC number (check for collisions)
- [ ] In `SessionKit`, an OSC parser that works with bytes arriving in arbitrary chunks
- [ ] State machine `idle` → `prompt` → `running` → `idle`
- [ ] Removal of ANSI sequences and handling of `\r`
- [ ] Output limit with `truncated` and `bytes`
- [ ] Record real session streams as fixtures in the test target
- [ ] Tests: simple command, failing command, large output, command without output, Ctrl+C mid-run, chunks split inside an OSC
- [ ] Connect the parser to the terminal stream without blocking the UI

**Done when:** running `ls`, `false` and `python3 -c 'print(1)'` in the app produces exactly three start/end pairs with exit codes 0, 1 and 0, and all fixture tests pass.

### E6 — JSONL log

- [ ] Event types as a `Codable` `enum` in `LogStore`
- [ ] Append-only writer on a serial queue, with batched `fsync` every 1 second
- [ ] `session_start` when opening and `session_end` when closing the terminal
- [ ] `seq` counter and command ids per file
- [ ] Reader that ignores unknown types and discards a malformed last line
- [ ] "Crash" test: kill the process mid-write and check that the file remains readable

**Done when:** a challenge solved in the app leaves a file in `logs/` that the `LogStore` reader rebuilds without errors, even after a `kill -9` on the app.

### E7 — Gaps: full screen and `ssh`

- [ ] Detect the alternate screen during a command and write `untracked`
- [ ] Discard output until the normal screen returns
- [ ] Visual indication on the tab that an untracked program is running
- [ ] Periodic `raw_chunk` for commands longer than 30 seconds or larger than 16 KB
- [ ] Fixture tests with `vim`, `less` and an `ssh` session

**Done when:** opening `vim`, quitting and running `ssh` into another machine produces one `untracked` event for vim and readable `raw_chunk` blocks for the remote session.

### E8 — Notes

- [ ] Context and Findings tabs reading and writing `notes/context.md` and `notes/findings.md`
- [ ] Monospaced text editor with autosave (1-second debounce)
- [ ] Rendered Markdown preview, switchable with the editor
- [ ] Create a custom tab through + (creates the file and updates `tabs`)
- [ ] Rename and remove custom tabs
- [ ] Reread files when the app becomes active (edits made in Obsidian)
- [ ] The ← button in the header returns to the library

**Done when:** a note edited in the app looks the same in Obsidian, and an edit made in Obsidian appears in the app when you return to it.

### E9 — Screenshots

- [ ] Thumbnail grid of the files in `prints/`
- [ ] Drag images from Finder or from the screenshot preview into the tab
- [ ] Paste an image from the clipboard (⌘V)
- [ ] Save with a date-and-time name
- [ ] Enlarged view with Quick Look
- [ ] Copy the `![](prints/<file>)` link to paste into notes

**Done when:** a screenshot taken with ⇧⌘4 and pasted into the app appears in the grid and can be referenced in `findings.md`.

### E10 — Bottom bar: highlights and pause

- [ ] Highlight input and highlight output buttons producing `highlight` on the last completed command
- [ ] Margin marker in the terminal on the highlighted command's line (overlay on the SwiftTerm view)
- [ ] Temporary "Highlighted: `<command>`" notice
- [ ] Undo highlight with ⌘Z, producing `unhighlight`
- [ ] Send to Findings: append a block with the command and output to `findings.md`
- [ ] Pause and resume with an indicator on the tab and in the bar
- [ ] Buttons disabled when there is no completed command

**Done when:** highlighting the output of `xxd enc` records the event in the log, shows the marker and, when sent to Findings, the block appears formatted in the Markdown.

### E11 — Menu bar and shortcuts

- [ ] File, Edit, View, Terminal and Challenge menus with the items from "Interface"
- [ ] Shortcuts through `.keyboardShortcut` and SwiftUI `Commands`
- [ ] Check for conflicts with system and SwiftTerm shortcuts
- [ ] Items disabled when they make no sense in context
- [ ] Mark challenge as solved and record the flag (⇧⌘F)

**Done when:** you can solve an entire challenge using only the keyboard.

### E12 — v0.1 security

- [ ] Audit that no code path records keyboard input
- [ ] Check the permissions of every created file in an automated test
- [ ] Test: type the `sudo` password and check that it does not appear in the log
- [ ] "What Flag Companion records" section in the README
- [ ] ADR 0002 "v0.1 threat model"

**Done when:** the three tests pass and the README describes exactly what goes to disk.

### E13 — Real-world test and v0.1.0 release

- [ ] Solve three picoCTF challenges from different categories entirely in the app
- [ ] Log every friction point as an issue labeled `dogfooding`
- [ ] Fix the friction points that prevent daily use
- [ ] Screenshots and a short GIF for the README
- [ ] Tag `v0.1.0` and GitHub release with release notes and a build (signed, or build instructions)
- [ ] Blog and LinkedIn post about the problem, the solution and what you learned about PTYs

**Done when:** the criterion in "v0.1 Scope" is met on a real challenge and the release is public.

## Roadmap and next steps

After v0.1, the project moves through three phases. Each one starts only when the previous one is in daily use on real CTFs.

| Phase | Focus | Main items | Gate to the next phase |
| --- | --- | --- | --- |
| v0.1 · Foundation | This specification | Terminal with tabs, zsh shell integration, append-only JSONL log, notes and screenshots, highlights and pause, menus and shortcuts | 3 challenges solved inside the app |
| v0.2 · Session and security | Trust in the record | Session timeline, highlight any event, remote `ssh` integration, screenshot capture by shortcut, log encryption, secret redaction, noise cleanup, on-device report | Daily use on real CTFs |
| v0.3 · Sharing | Taking it outside the app | PDF export, Obsidian export, search across challenges, bash and fish support | Stable public release |
| Later | Undated ideas | iPhone companion, restore terminals on reopen | — |

**Open decisions**

- [x] Check whether the name Flag Companion is already used on GitHub and the App Store
- [ ] Final number for the app's own OSC marker
- [ ] Findings as free text (provisional v0.1 decision) or as a list of reorderable cards
- [ ] How the session view (v0.2) shows highlights and gaps
- [ ] Whether to pay for the Apple Developer Program to distribute a signed and notarized app
- [ ] Compatibility between iCloud Keychain sync and requiring Touch ID (spike in v0.2)
- [ ] Real context size of the on-device model and the strategy for splitting a session for the report
