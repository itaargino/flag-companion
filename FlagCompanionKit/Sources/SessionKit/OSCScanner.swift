/// A piece of the terminal stream: bytes the shell or a program printed, or
/// one of the app's markers.
public enum ScannedPiece: Equatable, Sendable {
    case output([UInt8])
    case marker(ShellMarker)
}

/// Finds the app's markers in the bytes read from the PTY, which arrive in
/// chunks of any size: a marker can start in one read and end in the next.
///
/// The scanner keeps its place between calls, so feeding the stream in any
/// split gives the same pieces. Everything that is not one of the app's
/// markers, other OSC sequences included, comes back as `.output`.
///
/// ```swift
/// var scanner = OSCScanner()
/// scanner.feed(Array("ls\u{1B}]13".utf8))  // [.output("ls")]
/// scanner.feed(Array("3;D;0\u{07}".utf8)) // [.marker(.commandEnd(exitCode: 0))]
/// ```
///
/// Only the 7-bit introducer `ESC ]` is recognised. The 8-bit one (`0x9D`)
/// also appears inside UTF-8 characters, so treating it as OSC would cut text.
public struct OSCScanner: Sendable {
    /// A pasted command of a few hundred KB still fits once URL-escaped.
    public static let defaultMaxSequenceBytes = 1024 * 1024

    private enum State {
        case ground, escape, sequence, escapeInSequence
    }

    private static let esc: UInt8 = 0x1B
    private static let bel: UInt8 = 0x07
    private static let introducer: [UInt8] = [esc, 0x5D]  // ESC ]
    private static let stringTerminatorEnd: UInt8 = 0x5C  // the "\" of ESC \

    private let maxSequenceBytes: Int
    private var state = State.ground
    private var sequence: [UInt8] = []
    private var output: [UInt8] = []
    private var pieces: [ScannedPiece] = []

    public init(maxSequenceBytes: Int = defaultMaxSequenceBytes) {
        self.maxSequenceBytes = maxSequenceBytes
    }

    /// Returns the pieces this chunk completes, in stream order. A sequence
    /// still open at the end of the chunk is kept for the next call.
    public mutating func feed(_ chunk: some Sequence<UInt8>) -> [ScannedPiece] {
        for byte in chunk {
            consume(byte)
        }
        flushOutput()
        let completed = pieces
        pieces = []
        return completed
    }

    private mutating func consume(_ byte: UInt8) {
        switch state {
        case .ground: consumeInGround(byte)
        case .escape: consumeAfterEscape(byte)
        case .sequence: consumeInSequence(byte)
        case .escapeInSequence: consumeAfterEscapeInSequence(byte)
        }
    }

    private mutating func consumeInGround(_ byte: UInt8) {
        if byte == Self.esc {
            state = .escape
        } else {
            output.append(byte)
        }
    }

    /// The byte after `ESC` decides: `]` opens an OSC, anything else (a color,
    /// a cursor move) is ordinary output.
    private mutating func consumeAfterEscape(_ byte: UInt8) {
        switch byte {
        case Self.introducer[1]:
            state = .sequence
        case Self.esc:
            output.append(Self.esc)
        default:
            output += [Self.esc, byte]
            state = .ground
        }
    }

    private mutating func consumeInSequence(_ byte: UInt8) {
        switch byte {
        case Self.bel:
            finishSequence(terminator: [Self.bel])
        case Self.esc:
            state = .escapeInSequence
        default:
            sequence.append(byte)
            if sequence.count > maxSequenceBytes { abandonSequence() }
        }
    }

    /// `ESC \` ends the sequence. Any other escape cancels it, as in xterm,
    /// and is read again as the start of a new one.
    private mutating func consumeAfterEscapeInSequence(_ byte: UInt8) {
        guard byte != Self.stringTerminatorEnd else {
            finishSequence(terminator: [Self.esc, byte])
            return
        }
        abandonSequence()
        state = .escape
        consumeAfterEscape(byte)
    }

    private mutating func finishSequence(terminator: [UInt8]) {
        if let marker = ShellMarker(oscPayload: sequence) {
            flushOutput()
            pieces.append(.marker(marker))
        } else {
            output += Self.introducer + sequence + terminator
        }
        sequence = []
        state = .ground
    }

    /// Gives up on a sequence that never ended or grew past the limit, and
    /// hands its bytes back as output so nothing printed is lost.
    private mutating func abandonSequence() {
        output += Self.introducer + sequence
        sequence = []
        state = .ground
    }

    private mutating func flushOutput() {
        guard !output.isEmpty else { return }
        pieces.append(.output(output))
        output = []
    }
}
