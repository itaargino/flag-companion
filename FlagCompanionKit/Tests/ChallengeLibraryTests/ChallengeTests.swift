import ChallengeLibrary
import Foundation
import Testing

private let solvedChallengeJSON = """
    {
        "v": 1,
        "name": "enc",
        "category": "crypto",
        "points": 100,
        "status": "solved",
        "flag": "academy{16_bits_inst34d_of_8}",
        "created_at": "2026-10-15T10:34:38-04:00",
        "solved_at": "2026-10-16T11:40:02-04:00",
        "tabs": ["context", "findings", "prints", "tools"],
        "encrypted_logs": false
    }
    """

private let newChallengeJSON = """
    {
        "v": 1,
        "name": "enc",
        "category": "crypto",
        "status": "todo",
        "created_at": "2026-10-15T10:34:38-04:00",
        "tabs": ["context", "findings", "prints", "tools"],
        "encrypted_logs": false
    }
    """

// The spec stores dates as ISO 8601 with offset; JSONDecoder's default expects seconds since 2001.
private func decodeChallenge(from json: String) throws -> Challenge {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Challenge.self, from: Data(json.utf8))
}

@Test func solvedChallengeIsDecodedFromSpecExample() throws {
    let challenge = try decodeChallenge(from: solvedChallengeJSON)
    #expect(challenge.formatVersion == 1)
    #expect(challenge.name == "enc")
    #expect(challenge.category == "crypto")
    #expect(challenge.points == 100)
    #expect(challenge.status == .solved)
    #expect(challenge.flag == "academy{16_bits_inst34d_of_8}")
    #expect(challenge.createdAt == Date(timeIntervalSince1970: 1_792_074_878))
    #expect(challenge.tabs == ["context", "findings", "prints", "tools"])
    #expect(challenge.encryptedLogs == false)
}

@Test func newChallengeIsDecodedWithoutOptionalFields() throws {
    let challenge = try decodeChallenge(from: newChallengeJSON)
    #expect(challenge.points == nil)
    #expect(challenge.flag == nil)
    #expect(challenge.solvedAt == nil)
}

@Test func challengeSurvivesEncodingAndDecoding() throws {
    let original = try decodeChallenge(from: solvedChallengeJSON)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let json = String(decoding: try encoder.encode(original), as: UTF8.self)
    #expect(try decodeChallenge(from: json) == original)
}
