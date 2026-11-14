import ChallengeLibrary
import Foundation
import Testing

private let ctfJSON = """
    {
      "v": 1,
      "name": "picoCTF 2026",
      "created_at": "2026-10-15T10:30:00-04:00"
    }
    """

private func decodeCTF(from json: String) throws -> CTF {
    try MetadataJSON.decoder().decode(CTF.self, from: Data(json.utf8))
}

@Test func ctfIsDecodedFromJSON() throws {
    let ctf = try decodeCTF(from: ctfJSON)
    #expect(ctf.formatVersion == 1)
    #expect(ctf.name == "picoCTF 2026")
    #expect(ctf.createdAt == Date(timeIntervalSince1970: 1_792_074_600))
}

@Test func ctfSurvivesEncodingAndDecoding() throws {
    let original = try decodeCTF(from: ctfJSON)
    let json = String(decoding: try MetadataJSON.encoder().encode(original), as: UTF8.self)
    #expect(try decodeCTF(from: json) == original)
}
