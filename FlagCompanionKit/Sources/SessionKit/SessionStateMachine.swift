/// What the state machine found in a terminal session, ready to become log
/// events (`command_start`, `command_end` and `raw_chunk` in the spec).
public enum SessionEvent: Equatable, Sendable {
    /// A command was confirmed. `directory` is the last one the shell reported
    /// with OSC 7, or `nil` before the first report.
    case commandStart(id: String, command: String, directory: String?)
    /// The command finished. `exitCode` is `nil` when the shell never said:
    /// the shell exited (`exit`, a closed `ssh` tab) or a `D` marker was lost.
    /// `output` is still raw; `OutputCleaner` turns it into the log's text.
    case commandEnd(id: String, exitCode: Int?, output: CommandOutput)
    /// Output printed while no command was running, such as a background job
    /// finishing.
    case rawChunk(output: [UInt8])
}

/// Turns the pieces from `OSCScanner` into commands, following the spec
/// ("Terminal capture", point 4):
///
/// | State     | Piece      | Does                       | Next      |
/// | --------- | ---------- | -------------------------- | --------- |
/// | `idle`    | A          | nothing                    | `prompt`  |
/// | `idle`    | output     | emits `rawChunk`           | `idle`    |
/// | `idle`    | D          | nothing (empty Enter)      | `idle`    |
/// | `prompt`  | output     | drops it (prompt, typing)  | `prompt`  |
/// | `prompt`  | C          | emits `commandStart`       | `running` |
/// | `running` | output     | keeps it, within the limit | `running` |
/// | `running` | D          | emits `commandEnd`         | `idle`    |
///
/// ```swift
/// var machine = SessionStateMachine()
/// for piece in scanner.feed(chunk) {
///     for event in machine.handle(piece) { log.write(event) }
/// }
/// ```
public struct SessionStateMachine: Sendable {
    private enum State: Sendable {
        case idle
        case prompt
        case running(id: String)
    }

    private var state = State.idle
    /// What the open command printed so far. It lives outside `State` because
    /// a buffer copied out of an enum case is shared with it, and appending to
    /// a shared array copies the whole array: on every chunk, up to the limit.
    private var output: HeadTailBuffer
    private let outputLimit: Int
    private var directory: String?
    private var commandCount = 0

    /// `outputLimit` is the most bytes kept per command (the start and the end).
    public init(outputLimit: Int = CommandOutputLimit.maxBytesPerCommand) {
        self.outputLimit = outputLimit
        output = HeadTailBuffer(limit: outputLimit)
    }

    public mutating func handle(_ piece: ScannedPiece) -> [SessionEvent] {
        switch (state, piece) {
        case (.running, .output(let bytes)):
            output.append(bytes)
            return []

        case (.idle, .output(let bytes)):
            return [.rawChunk(output: bytes)]

        case (.prompt, .output):
            return []

        case (_, .marker(let marker)):
            return handle(marker)
        }
    }

    /// Ends the session: a command still open is closed with its output, so
    /// nothing printed is lost when the shell exits before sending `D`.
    public mutating func shellExited() -> [SessionEvent] {
        let events = closeOpenCommand(exitCode: nil)
        state = .idle
        return events
    }

    private mutating func handle(_ marker: ShellMarker) -> [SessionEvent] {
        switch marker {
        case .promptStart:
            // A prompt while running means the D was lost: close the command
            // rather than take the prompt for its output.
            let events = closeOpenCommand(exitCode: nil)
            state = .prompt
            return events

        case .commandStart(let command):
            // Also closes a command left open, so two never overlap.
            var events = closeOpenCommand(exitCode: nil)
            commandCount += 1
            let id = "c\(commandCount)"
            events.append(.commandStart(id: id, command: command, directory: directory))
            output = HeadTailBuffer(limit: outputLimit)
            state = .running(id: id)
            return events

        case .commandEnd(let exitCode):
            // With no open command (first prompt, empty Enter) this emits nothing.
            let events = closeOpenCommand(exitCode: exitCode)
            state = .idle
            return events

        case .currentDirectory(let path):
            directory = path
            return []

        case .promptEnd:
            return []
        }
    }

    private func closeOpenCommand(exitCode: Int?) -> [SessionEvent] {
        guard case .running(let id) = state else { return [] }
        return [.commandEnd(id: id, exitCode: exitCode, output: output.contents)]
    }
}
