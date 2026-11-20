import Foundation

extension Challenge {
    /// Returns a copy with a new status. `solvedAt` follows the status: it is set
    /// when the challenge becomes solved and cleared when it stops being solved.
    ///
    /// ```swift
    /// challenge = challenge.withStatus(.solved, at: .now)
    /// ```
    public func withStatus(_ newStatus: ChallengeStatus, at date: Date) -> Challenge {
        var copy = self
        copy.status = newStatus
        if newStatus != .solved {
            copy.solvedAt = nil
        } else if status != .solved {
            copy.solvedAt = date
        }
        return copy
    }

    /// Returns a copy marked as solved with the captured flag, keeping the first
    /// solved date when the flag is corrected later.
    ///
    /// ```swift
    /// challenge = challenge.solved(withFlag: "picoCTF{...}", at: .now)
    /// ```
    public func solved(withFlag capturedFlag: String, at date: Date) -> Challenge {
        var copy = withStatus(.solved, at: date)
        copy.flag = capturedFlag
        return copy
    }
}
