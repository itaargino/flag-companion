# 0001. Disable App Sandbox

- **Status:** Accepted
- **Date:** 2026-10-17

## Context

Flag Companion embeds a terminal. Each terminal tab starts the user's shell (zsh) inside a pseudo-terminal, and the user runs arbitrary tools from it: `file`, `xxd`, `python3`, `ssh`, `vim`, and anything else a CTF requires.

macOS apps distributed through the Mac App Store must enable App Sandbox. A sandboxed app can only access its own container and files the user explicitly grants. Child processes inherit the sandbox, so a shell started by a sandboxed app cannot freely read the user's files, run tools installed with Homebrew, or behave like a real terminal.

Terminal applications such as iTerm2 are distributed outside the Mac App Store for the same reason.

## Decision

Flag Companion runs without App Sandbox and keeps Hardened Runtime enabled.

The app is distributed through GitHub releases, not the Mac App Store.

## Consequences

- The embedded shell behaves exactly like one opened in Terminal.app.
- The app cannot be published on the Mac App Store.
- Without the sandbox, the app itself is responsible for limiting what it touches. It writes only inside the root folder chosen by the user and its own Application Support folder, and it creates files with permissions `0600` and folders with `0700`.
- To open without Gatekeeper warnings, release builds must be signed with a Developer ID and notarized, which requires a paid Apple Developer Program membership. Until then, the README explains how to build from source.
