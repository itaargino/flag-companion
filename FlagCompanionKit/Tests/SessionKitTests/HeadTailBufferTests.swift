import SessionKit
import Testing

private func bytes(_ text: String) -> [UInt8] { Array(text.utf8) }

/// A buffer with room for 8 bytes: 4 at the start and 4 at the end.
private func buffer(after chunks: [String], limit: Int = 8) -> HeadTailBuffer {
    var buffer = HeadTailBuffer(limit: limit)
    for chunk in chunks { buffer.append(bytes(chunk)) }
    return buffer
}

@Test func outputUnderTheLimitIsKeptWhole() {
    let buffer = buffer(after: ["abc"])
    #expect(buffer.head + buffer.tail == bytes("abc"))
    #expect(buffer.totalBytes == 3)
    #expect(buffer.omittedBytes == 0)
}

@Test func outputOfExactlyTheLimitIsNotTruncated() {
    let buffer = buffer(after: ["abcdefgh"])
    #expect(buffer.head + buffer.tail == bytes("abcdefgh"))
    #expect(buffer.omittedBytes == 0)
}

@Test func outputOverTheLimitKeepsTheStartAndTheEnd() {
    let buffer = buffer(after: ["abcdefghij"])
    #expect(buffer.head == bytes("abcd"))
    #expect(buffer.tail == bytes("ghij"))
    #expect(buffer.omittedBytes == 2)
    #expect(buffer.totalBytes == 10)
}

@Test func theEndIsReadInOrderAfterTheRingWraps() {
    // The example from the ring buffer explanation: the tail is "cdef" here,
    // after "ef" overwrote the first two places.
    let buffer = buffer(after: ["1234", "a", "b", "c", "d", "e", "f"])
    #expect(buffer.tail == bytes("cdef"))
}

@Test func manyWrapsKeepOnlyTheLastBytes() {
    let buffer = buffer(after: [String(repeating: "y\n", count: 1000) + "done"])
    #expect(buffer.head == bytes("y\ny\n"))
    #expect(buffer.tail == bytes("done"))
    #expect(buffer.totalBytes == 2004)
}

@Test func splittingTheOutputAnywhereGivesTheSameResult() {
    let text = "the quick brown fox jumps over the lazy dog"
    let whole = buffer(after: [text])
    for cut in 0...text.utf8.count {
        let parts = [String(decoding: bytes(text)[..<cut], as: UTF8.self),
                     String(decoding: bytes(text)[cut...], as: UTF8.self)]
        let split = buffer(after: parts)
        #expect(split.head == whole.head && split.tail == whole.tail, "cut at \(cut)")
    }
}

@Test func oddLimitGivesTheExtraByteToTheStart() {
    let buffer = buffer(after: ["abcdefghij"], limit: 5)
    #expect(buffer.head == bytes("abc"))
    #expect(buffer.tail == bytes("ij"))
}
