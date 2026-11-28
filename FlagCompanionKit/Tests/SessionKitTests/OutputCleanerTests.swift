import SessionKit
import Testing

private func clean(_ text: String) -> String { OutputCleaner.clean(Array(text.utf8)) }

/// What zsh prints after every command (`PROMPT_SP`), copied from a capture
/// of a terminal 80 columns wide: a bold, inverted `%`, 79 spaces, `\r \r`.
private let promptSP = "\u{1B}[1m\u{1B}[7m%\u{1B}[27m\u{1B}[1m\u{1B}[0m" + String(repeating: " ", count: 79) + "\r \r"

// MARK: - ANSI sequences

@Test func colorsAreRemoved() {
    #expect(clean("\u{1B}[1;31merror\u{1B}[0m: not found\r\n") == "error: not found\n")
}

@Test func cursorAndModeSequencesAreRemoved() {
    // Clear line, vim's alternate screen, a window title (OSC) and a charset switch.
    #expect(clean("\u{1B}[Ka\u{1B}[?1049hb\u{1B}]0;title\u{07}c\u{1B}(Bd") == "abcd")
}

@Test func sequenceCutAtTheEndIsDropped() {
    #expect(clean("text\u{1B}[3") == "text")
}

// MARK: - The \r rule

@Test func progressBarKeepsOnlyItsLastVersion() {
    #expect(clean("downloading 10%\rdownloading 50%\rdownloading 100%\r\n") == "downloading 100%\n")
}

@Test func shorterTextOverwritesOnlyTheStartOfTheLine() {
    // A real terminal leaves the rest of the old line on screen.
    #expect(clean("abcdef\rxy\r\n") == "xycdef\n")
}

@Test func overwritingCountsCharactersNotBytes() {
    // "ç" and "ã" take two bytes each in UTF-8 but one column on screen.
    #expect(clean("ação\rA\r\n") == "Ação\n")
}

// MARK: - PROMPT_SP

@Test func promptSPLineAfterTheOutputIsTrimmed() {
    #expect(clean("capture.py  hooks.zsh\r\n" + promptSP) == "capture.py  hooks.zsh\n")
}

@Test func commandWithNoOutputBecomesEmpty() {
    // `false` prints nothing: only PROMPT_SP arrives between C and D.
    #expect(clean(promptSP) == "")
}

@Test func trailingSpacesAreTrimmedButInnerOnesAreKept() {
    #expect(clean("a   b\r\nc   ") == "a   b\nc")
}

// MARK: - Bytes that are not text

@Test func invalidUTF8BecomesAReplacementCharacter() {
    #expect(OutputCleaner.clean([0x61, 0xFF, 0x62]) == "a\u{FFFD}b")
}

// MARK: - Truncated output

private func truncated(head: String, tail: String, totalBytes: Int) -> CommandOutput {
    CommandOutput(head: Array(head.utf8), tail: Array(tail.utf8), totalBytes: totalBytes)
}

@Test func wholeOutputIsCleanedAsBefore() {
    #expect(OutputCleaner.clean(CommandOutput(Array("\u{1B}[31mok\u{1B}[0m\r\n".utf8))) == "ok\n")
}

@Test func truncatedOutputShowsHowManyBytesWereOmitted() {
    let output = truncated(head: "first\r\nsecond\r\n", tail: "nd\r\nlast\r\n", totalBytes: 1000)
    #expect(OutputCleaner.clean(output) == "first\nsecond\n[... 979 bytes omitted ...]\nlast\n")
}

@Test func endStartsAfterItsFirstNewlineSoNoCutSequenceIsLeft() {
    // The ring began inside `ESC[31m`: "1m" would otherwise be logged as text.
    let output = truncated(head: "start\r\n", tail: "1merror\u{1B}[0m\r\nfound: sunshine\r\n", totalBytes: 500)
    #expect(OutputCleaner.clean(output).hasSuffix("omitted ...]\nfound: sunshine\n"))
}

@Test func endWithNoNewlineDropsOnlyACutLetter() {
    // "ç" is C3 A7 in UTF-8; the ring kept only A7.
    let tail: [UInt8] = [0xA7] + Array("ao".utf8)
    let output = CommandOutput(head: Array("x".utf8), tail: tail, totalBytes: 100)
    #expect(OutputCleaner.clean(output) == "x\n[... 97 bytes omitted ...]\nao")
}
