/// Keeps a command's output within a fixed size: the first half of the limit
/// from the start, the second half from the end, and a count of everything.
/// The middle is dropped, since it is usually the repetitive part (attempts,
/// progress lines) and the start and the end hold headers and results.
///
/// The end lives in a ring buffer: once it is full, each new byte overwrites
/// the oldest, so memory never grows past `limit`, even under `yes`.
///
/// ```swift
/// var buffer = HeadTailBuffer(limit: 8)
/// buffer.append(Array("abcdefghij".utf8))
/// buffer.head          // "abcd"
/// buffer.tail          // "ghij"
/// buffer.omittedBytes  // 2
/// ```
public struct HeadTailBuffer: Sendable {
    /// The first bytes, up to half the limit (the extra byte of an odd limit).
    public private(set) var head: [UInt8] = []
    /// Every byte appended, kept or not.
    public private(set) var totalBytes = 0

    private let headCapacity: Int
    private let tailCapacity: Int
    private var ring: [UInt8] = []
    /// Once the ring is full: the place of the oldest byte, the next to be
    /// overwritten.
    private var oldest = 0

    public init(limit: Int = CommandOutputLimit.maxBytesPerCommand) {
        precondition(limit >= 0, "the output limit cannot be negative")
        headCapacity = (limit + 1) / 2
        tailCapacity = limit / 2
    }

    public mutating func append(_ bytes: [UInt8]) {
        totalBytes += bytes.count

        var rest = bytes[...]
        let room = headCapacity - head.count
        if room > 0 {
            head.append(contentsOf: rest.prefix(room))
            rest = rest.dropFirst(room)
        }

        // Bytes before the last `tailCapacity` would be overwritten within
        // this same call, so they are skipped.
        for byte in rest.suffix(tailCapacity) {
            if ring.count < tailCapacity {
                ring.append(byte)
            } else {
                ring[oldest] = byte
                oldest = (oldest + 1) % tailCapacity
            }
        }
    }

    /// The last bytes, in the order they arrived: from the oldest place to the
    /// end of the ring, then from its start.
    public var tail: [UInt8] { Array(ring[oldest...] + ring[..<oldest]) }

    /// How many bytes were dropped from the middle; `0` means nothing was lost.
    public var omittedBytes: Int { totalBytes - head.count - ring.count }

    /// What the log receives. Output within the limit comes back whole, in
    /// `head`, so it does not matter where the buffer split it.
    public var contents: CommandOutput {
        omittedBytes == 0
            ? CommandOutput(head + tail)
            : CommandOutput(head: head, tail: tail, totalBytes: totalBytes)
    }
}

/// A finished command's output: whole, or its start and end when it went over
/// the limit (`truncated` and `bytes` in the log).
public struct CommandOutput: Equatable, Sendable {
    public let head: [UInt8]
    /// Empty unless the output was truncated.
    public let tail: [UInt8]
    public let totalBytes: Int

    /// Output that was kept whole.
    public init(_ bytes: [UInt8]) {
        self.init(head: bytes, tail: [], totalBytes: bytes.count)
    }

    public init(head: [UInt8], tail: [UInt8], totalBytes: Int) {
        self.head = head
        self.tail = tail
        self.totalBytes = totalBytes
    }

    public var omittedBytes: Int { totalBytes - head.count - tail.count }
    public var isTruncated: Bool { omittedBytes > 0 }
}
