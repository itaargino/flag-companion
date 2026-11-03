import Foundation

/// The metadata of one challenge, stored as `challenge.json` in the challenge folder.
///
/// ```swift
/// let decoder = JSONDecoder()
/// decoder.dateDecodingStrategy = .iso8601
/// let challenge = try decoder.decode(Challenge.self, from: data)
/// print(challenge.status) // solved
/// ```
public struct Challenge: Codable, Equatable {
    public let formatVersion: Int
    public var name: String
    public var category: String
    public var points: Int?
    public var status: ChallengeStatus
    public var flag: String?
    public let createdAt: Date
    public var solvedAt: Date?
    public var tabs: [String]
    public var encryptedLogs: Bool

    // The JSON uses short and snake_case keys from the spec; Swift names follow the API guidelines.
    private enum CodingKeys: String, CodingKey {
        case formatVersion = "v"
        case name
        case category
        case points
        case status
        case flag
        case createdAt = "created_at"
        case solvedAt = "solved_at"
        case tabs
        case encryptedLogs = "encrypted_logs"
    }
}
