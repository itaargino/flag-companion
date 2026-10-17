# Contributing to Flag Companion

Thanks for your interest in Flag Companion. This guide explains how work flows through the repository and the conventions every change follows. When in doubt, follow Apple's API Design Guidelines and the Human Interface Guidelines.

## Workflow

We use GitHub flow:

1. `main` always builds and passes tests. Nobody commits directly to it.
2. Every change starts on its own branch, named `<type>/<short-description>`, for example `feat/workspace-slug` or `docs/contributing`.
3. Open a pull request against `main`.
4. Pull requests are merged with **squash merge**. The PR title becomes the commit message on `main`.

### Commit messages

We follow [Conventional Commits](https://www.conventionalcommits.org/). Messages are in English, lowercase, imperative mood.

| Type | Use for |
| --- | --- |
| `feat` | A new feature |
| `fix` | A bug fix |
| `test` | Adding or changing tests only |
| `docs` | Documentation only |
| `refactor` | Code change that does not change behavior |
| `chore` | Build, configuration, dependencies, project structure |

Examples:

```
feat: create challenge folder structure
fix: keep partial OSC sequences across reads
docs: record decision to disable App Sandbox
```

Keep one reason per commit. If a commit message needs the word "and", it is probably two commits.

### Pull requests

Every pull request description has three sections:

- **What**: what changed.
- **Why**: the reason, linking the backlog item or issue.
- **How to test**: steps a reviewer can follow.

Before opening a pull request, run the formatter and the tests locally.

## Code style

### Functions and files

- Functions are 4 to 20 lines. Split longer ones.
- Files stay under 500 lines. Split by responsibility.
- One thing per function, one responsibility per type and module.
- Prefer early returns (`guard`) over nested `if`s. Maximum two levels of indentation.
- No duplicated logic. Extract shared code into a function or type.

### SwiftUI views

Views only compose view elements. Any logic (formatting, filtering, deciding what to show) lives in functions or types outside the view, where it can be tested without rendering UI. Long view bodies are split into small subviews.

### Naming

- Names are specific and unique. Avoid generic names such as `data`, `handler`, `info` or `Manager`.
- A good name returns fewer than five results when searched in the codebase.
- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).

### Types

- Types are explicit. Do not use `Any`, `AnyObject` or `[String: Any]`.
- Model data with `struct` and `enum`, and use `Codable` for serialization.
- Errors are `enum`s conforming to `Error`, with associated values that carry the offending value and the expected shape:

```swift
enum SlugError: Error {
    case invalidCharacters(received: String, expected: String)
}
```

### Concurrency

- The app target uses `MainActor` as the default actor isolation.
- Work that must not block the UI (session parsing, log writing) lives in Swift packages and declares its isolation explicitly.

## Comments

- Comments explain **why**, not **what**. Skip comments that repeat the code.
- Keep existing comments when refactoring. They carry intent and history.
- Public declarations get a documentation comment (`///`, DocC format) with the intent and one usage example.
- When a line exists because of a specific bug or upstream constraint, reference the issue number or commit SHA.

## Tests

- Tests use [Swift Testing](https://developer.apple.com/xcode/swift-testing/) (`@Test`, `#expect`).
- Every new function gets a test. Every bug fix gets a regression test.
- External I/O (file system, processes, clock) is replaced with named fake types, such as `FakeFileSystem`, never inline stubs.
- Tests follow F.I.R.S.T.: fast, independent, repeatable, self-validating, timely.
- All tests run with a single command: `make test`.

## Dependencies

- Dependencies are injected through initializers or parameters, never through globals or singletons.
- Third-party libraries sit behind a protocol owned by this project. For example, the app talks to a `TerminalEmulating` protocol, not directly to SwiftTerm.
- Adding a dependency requires a short justification in the pull request.

## Formatting

Use `swift format`, which ships with the Swift toolchain. Do not discuss style beyond what the formatter enforces.

## Logging

- Debug and diagnostic logs use Apple's unified logging (`Logger` from the `os` framework), with privacy annotations for any user data.
- Session logs written to the user's challenge folder are product data, not diagnostics. Their format is defined in the specification.

## Security

Flag Companion records terminal sessions, so privacy is a core feature:

- Never record keystrokes.
- Never log user data through `Logger` without a privacy annotation.
- Files and folders created by the app use permissions `0600` and `0700`.

If you find a security issue, please open a private security advisory on GitHub instead of a public issue.

## Architecture decisions

Significant decisions are recorded as ADRs in `docs/adr/`. Accepted ADRs are not edited. To change a decision, write a new ADR that supersedes the old one.
