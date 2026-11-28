import SessionKit
import Testing

private func bytes(_ text: String) -> [UInt8] { Array(text.utf8) }

private func output(_ text: String) -> ScannedPiece { .output(bytes(text)) }

private let prompt = ScannedPiece.marker(.promptStart)

private func command(_ text: String) -> ScannedPiece { .marker(.commandStart(command: text)) }

private func end(_ exitCode: Int?) -> ScannedPiece { .marker(.commandEnd(exitCode: exitCode)) }

private func directory(_ path: String) -> ScannedPiece { .marker(.currentDirectory(path: path)) }

/// Hands every piece to one machine, then ends the session when asked, and
/// returns all the events in order.
private func run(
    _ pieces: [ScannedPiece], thenShellExits: Bool = false, outputLimit: Int = 1024
) -> [SessionEvent] {
    var machine = SessionStateMachine(outputLimit: outputLimit)
    var events = pieces.flatMap { machine.handle($0) }
    if thenShellExits { events += machine.shellExited() }
    return events
}

// MARK: - The table: one test per transition

@Test func commandBetweenPromptAndEndBecomesAStartEndPair() {
    let events = run([
        prompt, output("isaque@mac ~ % "), output("ls"),  // prompt and typing echo: dropped
        command("ls"), output("capture.py  hooks.zsh\r\n"), end(0),
    ])
    #expect(
        events == [
            .commandStart(id: "c1", command: "ls", directory: nil),
            .commandEnd(id: "c1", exitCode: 0, output: CommandOutput(bytes("capture.py  hooks.zsh\r\n"))),
        ])
}

@Test func outputArrivingInPiecesIsJoinedInOneEnd() {
    let events = run([prompt, command("ls"), output("one "), output("two "), output("three"), end(0)])
    #expect(events.last == .commandEnd(id: "c1", exitCode: 0, output: CommandOutput(bytes("one two three"))))
}

@Test func failingCommandKeepsItsExitCode() {
    let events = run([prompt, command("false"), end(1)])
    #expect(events.last == .commandEnd(id: "c1", exitCode: 1, output: CommandOutput([])))
}

@Test func endWithNoOpenCommandIsIgnored() {
    // zsh sends D before the first prompt, and again after an empty Enter.
    let events = run([end(0), prompt, output("isaque@mac ~ % "), end(0), prompt])
    #expect(events == [])
}

@Test func outputOutsideACommandBecomesARawChunk() {
    let events = run([output("[1]  + done       sleep 10\r\n"), prompt])
    #expect(events == [.rawChunk(output: bytes("[1]  + done       sleep 10\r\n"))])
}

// MARK: - Beyond the table

@Test func commandStartsInTheLastReportedDirectory() {
    let events = run([directory("/Users/me/ctf/files"), prompt, command("ls"), end(0)])
    #expect(events.first == .commandStart(id: "c1", command: "ls", directory: "/Users/me/ctf/files"))
}

@Test func eachCommandGetsTheNextID() {
    let events = run([prompt, command("ls"), end(0), prompt, command("pwd"), end(0)])
    #expect(
        events.map(\.commandID) == ["c1", "c1", "c2", "c2"])
}

@Test func promptWhileRunningClosesTheLostCommand() {
    // If a D is ever lost, the next prompt closes the command instead of the
    // machine staying in `running` and taking the prompt as output.
    let events = run([prompt, command("ls"), output("a\r\n"), prompt, output("isaque@mac ~ % ")])
    #expect(events.last == .commandEnd(id: "c1", exitCode: nil, output: CommandOutput(bytes("a\r\n"))))
}

@Test func shellExitClosesTheOpenCommandWithItsOutput() {
    // `exit` sends C, then the shell is gone before it can send D. The same
    // happens when a tab running `ssh` is closed: its output must not be lost.
    let events = run([prompt, command("ssh box"), output("remote session")], thenShellExits: true)
    #expect(events.last == .commandEnd(id: "c1", exitCode: nil, output: CommandOutput(bytes("remote session"))))
}

@Test func shellExitWithNoOpenCommandEmitsNothing() {
    let events = run([prompt, command("ls"), end(0), prompt], thenShellExits: true)
    #expect(events.count == 2)
}

// MARK: - Output limit

@Test func outputOverTheLimitKeepsItsStartAndEnd() {
    let events = run([prompt, command("yes"), output("y\n"), output("y\n"), output("y\ny\ny\nend\n")],
        thenShellExits: true, outputLimit: 8)
    #expect(
        events.last
            == .commandEnd(
                id: "c1", exitCode: nil,
                output: CommandOutput(head: bytes("y\ny\n"), tail: bytes("end\n"), totalBytes: 14)))
}

@Test func eachCommandStartsWithAnEmptyBuffer() {
    let events = run([prompt, command("a"), output("123456789"), end(0), prompt, command("b"), output("ok"), end(0)], outputLimit: 8)
    #expect(events.last == .commandEnd(id: "c2", exitCode: 0, output: CommandOutput(bytes("ok"))))
}

extension SessionEvent {
    fileprivate var commandID: String? {
        switch self {
        case .commandStart(let id, _, _), .commandEnd(let id, _, _): id
        case .rawChunk: nil
        }
    }
}
