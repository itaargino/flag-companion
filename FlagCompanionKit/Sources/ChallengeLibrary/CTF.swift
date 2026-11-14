import Foundation

/// The metadata of one CTF, stored as `ctf.json` in the CTF folder.
///
/// ```swift
/// let ctf = try MetadataJSON.decoder().decode(CTF.self, from: data)
/// print(ctf.name) // picoCTF 2026
/// ```
public struct CTF: Codable, Equatable {
    public let formatVersion: Int
    public var name: String
    public let createdAt: Date

    // The JSON uses short and snake_case keys from the spec; Swift names follow the API guidelines.
    private enum CodingKeys: String, CodingKey {
        case formatVersion = "v"
        case name
        case createdAt = "created_at"
    }
}
