# Flag Companion

A native macOS companion for CTF players: an embedded terminal that records your session as structured events, with Markdown notes and screenshots kept next to it, one folder per challenge.

> **Status: in development.** Nothing is usable yet. The project foundation is done; the embedded terminal and session recording come next. Follow the progress in [Milestones](https://github.com/itaargino/flag-companion/milestones).

## Why

Solving a CTF challenge usually leaves a mess behind: commands, repeated output, typos, hints and screenshots all mixed in one note turning hard to retake steps made.

Flag Companion records each command with its output and exit code, lets you highlight what mattered with one click, and keeps your notes beside the terminal. Later versions will turn that record into a report, processed entirely on your Mac.

## Planned for v0.1

- Library of CTFs and challenges, backed by real folders on disk
- Embedded terminal with multiple tabs per challenge
- Append-only session log in JSON Lines, one file per terminal
- Context, Findings and Screenshots notes in Markdown
- Highlight a command or its output, and pause recording
- Native menus and keyboard shortcuts

See the [v0.1 specification](docs/spec-v0.1.md) for the full design.

## Privacy

Flag Companion never records keystrokes, keeps everything on your Mac and stores session files with permissions readable only by you. Full details will be documented before the first release.

## Requirements

- macOS 27 on Apple silicon
- Xcode 27, to build from source

## Building from source

```bash
git clone https://github.com/itaargino/flag-companion.git
cd flag-companion
make test
```

Open `FlagCompanion/FlagCompanion.xcodeproj` in Xcode and run the `FlagCompanion` scheme. To sign the app locally, choose your own team under Signing & Capabilities.

## Project structure

| Path | Contents |
| --- | --- |
| `FlagCompanion/` | The macOS app (SwiftUI) |
| `FlagCompanionKit/` | Swift package with the app's logic: `SessionKit`, `LogStore`, `ChallengeLibrary` |
| `docs/` | Specification and architecture decision records |

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, code style and testing rules.

## License

[MIT](LICENSE)
