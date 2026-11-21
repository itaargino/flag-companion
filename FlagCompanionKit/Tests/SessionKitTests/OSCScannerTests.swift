import SessionKit
import Testing

private let esc: UInt8 = 0x1B
private let bel: UInt8 = 0x07

private func bytes(_ text: String) -> [UInt8] { Array(text.utf8) }

/// `ESC ] <payload> BEL`, the way the app's zsh hooks end every marker.
private func osc(_ payload: String) -> [UInt8] { [esc, 0x5D] + bytes(payload) + [bel] }

/// Feeds each chunk to one scanner and joins neighbouring `.output` pieces,
/// so results compare the same however the bytes were split.
private func scan(_ chunks: [[UInt8]], maxSequenceBytes: Int = OSCScanner.defaultMaxSequenceBytes)
    -> [ScannedPiece]
{
    var scanner = OSCScanner(maxSequenceBytes: maxSequenceBytes)
    return joined(chunks.flatMap { scanner.feed($0) })
}

private func joined(_ pieces: [ScannedPiece]) -> [ScannedPiece] {
    pieces.reduce(into: []) { result, piece in
        if case .output(let new) = piece, case .output(let old)? = result.last {
            result[result.count - 1] = .output(old + new)
        } else {
            result.append(piece)
        }
    }
}

// MARK: - Markers

@Test func plainOutputPassesThroughUnchanged() {
    let text = bytes("capture.py  hooks.zsh\r\n\u{1B}[1;32mgreen\u{1B}[0m")
    #expect(scan([text]) == [.output(text)])
}

@Test(arguments: [
    ("133;A", ShellMarker.promptStart),
    ("133;B", .promptEnd),
    ("133;C", .commandStart(command: "")),
    (
        "133;C;cmdline_url=python3%20-c%20%27print%281%29%27",
        .commandStart(command: "python3 -c 'print(1)'")
    ),
    ("133;C;cmdline_url=echo%20%27%C3%A1%27%20%3B%20x", .commandStart(command: "echo 'á' ; x")),
    ("133;D;0", .commandEnd(exitCode: 0)),
    ("133;D;130", .commandEnd(exitCode: 130)),
    ("133;D", .commandEnd(exitCode: nil)),
    (
        "7;file://MacBook-Pro-67.local/Users/isaque/My CTF",
        .currentDirectory(path: "/Users/isaque/My CTF")
    ),
])
func appMarkersAreRead(payload: String, marker: ShellMarker) {
    #expect(scan([osc(payload)]) == [.marker(marker)])
}

@Test func stringTerminatorEndsAMarkerLikeBEL() {
    let marker: [UInt8] = [esc, 0x5D] + bytes("133;D;1") + [esc, 0x5C]
    #expect(scan([marker]) == [.marker(.commandEnd(exitCode: 1))])
}

@Test func invalidPercentEscapesKeepTheTextAsSent() {
    #expect(scan([osc("133;C;cmdline_url=cat%FF")]) == [.marker(.commandStart(command: "cat%FF"))])
}

@Test func otherOSCSequencesStayInTheOutput() {
    let title = osc("0;vim notes.md")
    #expect(scan([title, bytes("x")]) == [.output(title + bytes("x"))])
}

@Test func markersKeepTheirPlaceBetweenOutput() {
    let stream = osc("133;C;cmdline_url=ls") + bytes("a.txt\r\n") + osc("133;D;0") + bytes("% ")
    #expect(
        scan([stream]) == [
            .marker(.commandStart(command: "ls")), .output(bytes("a.txt\r\n")),
            .marker(.commandEnd(exitCode: 0)), .output(bytes("% ")),
        ])
}

// MARK: - Chunks split anywhere

@Test func splittingTheStreamAtAnyByteGivesTheSameResult() {
    let stream =
        bytes("out\u{1B}[0m") + osc("133;D;0") + osc("7;file://h/tmp") + osc("133;A")
        + bytes("% ") + osc("133;B") + [esc, 0x5D] + bytes("133;C;cmdline_url=ls") + [esc, 0x5C]
    let whole = scan([stream])
    for cut in 0...stream.count {
        #expect(scan([Array(stream[..<cut]), Array(stream[cut...])]) == whole, "cut at \(cut)")
    }
    #expect(scan(stream.map { [$0] }) == whole, "one byte per chunk")
}

@Test func aLoneEscapeAtTheEndOfAChunkWaitsForTheNextByte() {
    var scanner = OSCScanner()
    #expect(scanner.feed(bytes("ok") + [esc]) == [.output(bytes("ok"))])
    #expect(scanner.feed(bytes("[0m")) == [.output([esc] + bytes("[0m"))])
}

// MARK: - Broken sequences

@Test func anEscapeInsideASequenceAbandonsIt() {
    let stream = [esc, 0x5D] + bytes("133;A") + [esc] + bytes("[0m")
    #expect(scan([stream]) == [.output(stream)])
}

@Test func aSequenceLongerThanTheLimitBecomesOutputAndScanningRecovers() {
    let unterminated = [esc, 0x5D] + bytes(String(repeating: "x", count: 20))
    let pieces = scan([unterminated, osc("133;D;2")], maxSequenceBytes: 8)
    #expect(pieces == [.output(unterminated), .marker(.commandEnd(exitCode: 2))])
}
