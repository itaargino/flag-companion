import ChallengeLibrary
import Foundation

/// What the user typed in the "New Challenge" sheet, kept as text until it is
/// valid enough to become a `Challenge`.
nonisolated struct ChallengeDraft: Equatable, Sendable {
    var name = ""
    var category = ""
    var points = ""
    var ctfFolder: URL?

    /// Categories offered as suggestions; any other text is accepted.
    static let suggestedCategories = [
        "web", "crypto", "pwn", "reverse", "forensics", "osint", "misc",
    ]

    var isComplete: Bool {
        ctfFolder != nil && !trimmedName.isEmpty && !trimmedCategory.isEmpty && hasValidPoints
    }

    /// Returns nil until every required field is filled and points is a whole number.
    func challenge(createdAt: Date) -> Challenge? {
        guard isComplete else { return nil }
        return Challenge(
            name: trimmedName,
            category: trimmedCategory.lowercased(),
            points: Int(trimmedPoints),
            createdAt: createdAt
        )
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedCategory: String {
        category.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var trimmedPoints: String { points.trimmingCharacters(in: .whitespaces) }

    private var hasValidPoints: Bool {
        trimmedPoints.isEmpty || (Int(trimmedPoints).map { $0 >= 0 } ?? false)
    }
}
