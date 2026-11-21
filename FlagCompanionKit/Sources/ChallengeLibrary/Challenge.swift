import Foundation

/// The metadata of one challenge, stored as `challenge.json` in the challenge folder.
///
/// ```swift
/// let challenge = try MetadataJSON.decoder().decode(Challenge.self, from: data)
/// ```
public struct Challenge: Codable, Equatable, Sendable {
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

    /// The note tabs a new challenge starts with, in display order.
    public static let defaultTabs = ["context", "findings", "prints"]

    /// Creates the metadata for a new challenge in the current format version.
    public init(
        name: String,
        category: String,
        points: Int? = nil,
        status: ChallengeStatus = .todo,
        createdAt: Date,
        tabs: [String] = Challenge.defaultTabs
    ) {
        self.formatVersion = MetadataJSON.currentFormatVersion
        self.name = name
        self.category = category
        self.points = points
        self.status = status
        self.createdAt = createdAt
        self.tabs = tabs
        self.encryptedLogs = false
    }

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
