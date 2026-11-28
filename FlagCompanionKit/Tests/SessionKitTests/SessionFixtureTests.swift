import Foundation
import SessionKit
import Testing

/// What a recorded session becomes, after the whole pipeline: scanner, state
/// machine and cleaner.
private struct Command: Equatable, CustomStringConvertible {
    var text: String
    var directory: String?
    var exitCode: Int?
    var output: String

    var description: String { "\(text) → \(exitCode.map(String.init) ?? "nil"): \(output.debugDescription)" }
}

private let home = "/tmp/flag-companion-fixture-home"

private func fixture(_ name: String) throws -> [UInt8] {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "raw", subdirectory: "Fixtures"))
    return Array(try Data(contentsOf: url))
}

/// Feeds the recording in chunks of `chunkSize` bytes, as the PTY would, and
/// ends the session when the bytes run out.
private func commands(in bytes: [UInt8], chunkSize: Int = 4096) -> [Command] {
    var scanner = OSCScanner()
    var machine = SessionStateMachine()
    var events: [SessionEvent] = []
    var start = 0
    while start < bytes.count {
        let end = min(start + chunkSize, bytes.count)
        for piece in scanner.feed(Array(bytes[start..<end])) { events += machine.handle(piece) }
        start = end
    }
    events += machine.shellExited()

    var commands: [Command] = []
    for event in events {
        switch event {
        case .commandStart(_, let text, let directory):
            commands.append(Command(text: text, directory: directory, exitCode: nil, output: ""))
        case .commandEnd(_, let exitCode, let output):
            commands[commands.count - 1].exitCode = exitCode
            commands[commands.count - 1].output = OutputCleaner.clean(output)
        case .rawChunk:
            break
        }
    }
    return commands
}


@Test func basicSessionGivesThreePairsWithExitCodesZeroOneZero() throws {
    // The "Done when" of E5, plus `exit`, which never gets a D.
    #expect(
        commands(in: try fixture("basic")) == [
            Command(text: "ls", directory: home, exitCode: 0, output: "exploit.py\tflag.txt\tnotes.md\n"),
            Command(text: "false", directory: home, exitCode: 1, output: ""),
            Command(text: "python3 -c 'print(1)'", directory: home, exitCode: 0, output: "1\n"),
            Command(text: "exit", directory: home, exitCode: nil, output: ""),
        ])
}

@Test func edgeCasesSession() throws {
    #expect(
        commands(in: try fixture("edges")) == [
            // The empty Enter before it left no command.
            Command(text: "sleep 5", directory: home, exitCode: 130, output: "^C\n"),
            Command(text: "echo 'two\nlines'", directory: home, exitCode: 0, output: "two\nlines\n"),
            Command(text: "cd /tmp", directory: home, exitCode: 0, output: ""),
            Command(text: "exit", directory: "/tmp", exitCode: nil, output: ""),
        ])
}

@Test func largeOutputKeepsItsFirstAndLastLines() throws {
    let seq = try #require(commands(in: try fixture("large")).first)
    #expect(seq.text == "seq 1 20000")
    #expect(seq.exitCode == 0)
    #expect(seq.output.hasPrefix("1\n2\n3\n"))
    #expect(seq.output.hasSuffix("19999\n20000\n"))
    #expect(seq.output.contains(" bytes omitted ...]\n"))
}

@Test(arguments: [1, 7, 512])
func chunkSizeDoesNotChangeTheResult(chunkSize: Int) throws {
    for name in ["basic", "edges", "large"] {
        let bytes = try fixture(name)
        #expect(commands(in: bytes, chunkSize: chunkSize) == commands(in: bytes), "\(name)")
    }
}
