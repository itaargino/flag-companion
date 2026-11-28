/// Turns the bytes a command printed into the text the log stores, following
/// the spec ("Terminal capture", point 5):
///
/// 1. ANSI sequences (colors, cursor moves, titles) are removed.
/// 2. `\r` moves back to the start of the line and the next characters write
///    over it, so a progress bar keeps only its last version.
/// 3. Spaces at the very end are trimmed. This drops the line zsh's
///    `PROMPT_SP` leaves after every command.
///
/// Run it on a finished command's whole output, not on each chunk: a sequence
/// or a `\r` can be split across two chunks.
///
/// ```swift
/// OutputCleaner.clean(Array("\u{1B}[31m10%\r100%\r\n".utf8))  // "100%\n"
/// ```
public enum OutputCleaner {
    public static func clean(_ bytes: [UInt8]) -> String {
        let text = String(decoding: removingEscapeSequences(from: bytes), as: UTF8.self)
        var result = applyingCarriageReturns(to: text)
        while result.unicodeScalars.last == " " { result.unicodeScalars.removeLast() }
        return result
    }

    /// Cleans a finished command's output. When it went over the limit, the
    /// start and the end are joined by a note with how many bytes are missing.
    ///
    /// The end begins wherever the ring buffer happened to cut, maybe inside an
    /// ANSI sequence or a letter, so it is moved to the start of its first
    /// full line. With no newline, only the bytes of a cut letter are dropped.
    public static func clean(_ output: CommandOutput) -> String {
        guard output.isTruncated else { return clean(output.head) }

        let tail = startingAtALine(output.tail)
        let omitted = output.omittedBytes + (output.tail.count - tail.count)
        var text = clean(output.head)
        if !text.isEmpty, !text.hasSuffix("\n") { text += "\n" }
        return text + "[... \(omitted) bytes omitted ...]\n" + clean(Array(tail))
    }

    private static func startingAtALine(_ bytes: [UInt8]) -> ArraySlice<UInt8> {
        if let newline = bytes.firstIndex(of: UInt8(ascii: "\n")) {
            return bytes[(newline + 1)...]
        }
        // UTF-8 continuation bytes (10xxxxxx) can only follow a letter's first byte.
        return bytes.drop { (0x80...0xBF).contains($0) }
    }

    // MARK: - Step 1: escape sequences, on bytes

    private static let escape: UInt8 = 0x1B
    private static let bell: UInt8 = 0x07

    private static func removingEscapeSequences(from bytes: [UInt8]) -> [UInt8] {
        var kept: [UInt8] = []
        kept.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            if bytes[index] == escape {
                index = endOfSequence(in: bytes, startingAt: index)
            } else {
                kept.append(bytes[index])
                index += 1
            }
        }
        return kept
    }

    /// The index just after the sequence that starts with `ESC` at `start`.
    /// A sequence cut at the end runs to the end, so it is dropped whole.
    private static func endOfSequence(in bytes: [UInt8], startingAt start: Int) -> Int {
        var index = start + 1
        guard index < bytes.count else { return bytes.count }

        switch bytes[index] {
        case UInt8(ascii: "["):
            // CSI, such as `ESC[1;31m`: parameters, then one final byte from
            // 0x40 to 0x7E (`m`, `K`, `h`, `~`...).
            index += 1
            while index < bytes.count, !(0x40...0x7E).contains(bytes[index]) { index += 1 }
            return min(index + 1, bytes.count)

        case UInt8(ascii: "]"):
            // OSC, such as a window title: ends with BEL or with `ESC \`.
            index += 1
            while index < bytes.count {
                if bytes[index] == bell { return index + 1 }
                if bytes[index] == escape, index + 1 < bytes.count, bytes[index + 1] == UInt8(ascii: "\\") {
                    return index + 2
                }
                index += 1
            }
            return bytes.count

        default:
            // Short sequences, such as `ESC(B`: optional bytes from 0x20 to
            // 0x2F, then one final byte.
            while index < bytes.count, (0x20...0x2F).contains(bytes[index]) { index += 1 }
            return min(index + 1, bytes.count)
        }
    }

    // MARK: - Step 2: the \r rule, on characters

    /// Replays each line the way a terminal draws it. This works on Unicode
    /// scalars, not `Character`s, because Swift treats `\r\n` as one Character.
    private static func applyingCarriageReturns(to text: String) -> String {
        var result = String.UnicodeScalarView()
        var line: [Unicode.Scalar] = []
        var cursor = 0

        for scalar in text.unicodeScalars {
            switch scalar {
            case "\n":
                result.append(contentsOf: line)
                result.append(scalar)
                line.removeAll(keepingCapacity: true)
                cursor = 0
            case "\r":
                cursor = 0
            default:
                if cursor < line.count { line[cursor] = scalar } else { line.append(scalar) }
                cursor += 1
            }
        }
        result.append(contentsOf: line)
        return String(result)
    }
}
