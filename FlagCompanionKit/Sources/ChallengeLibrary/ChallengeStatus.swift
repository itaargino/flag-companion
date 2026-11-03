/// Classifies which status current challenge is
///
/// ```swift
/// let status = ChallengeStatus.inProgress
/// print(status.rawValue) // "in_progress"
/// ```
public enum ChallengeStatus: String, Codable {
    case todo
    case inProgress = "in_progress"
    case solved
    case abandoned
}
