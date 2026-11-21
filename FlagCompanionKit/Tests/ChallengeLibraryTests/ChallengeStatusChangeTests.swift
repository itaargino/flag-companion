import ChallengeLibrary
import Foundation
import Testing

private let createdAt = Date(timeIntervalSince1970: 1_792_074_878)
private let solvedAt = Date(timeIntervalSince1970: 1_792_160_000)

private func newChallenge() -> Challenge {
    Challenge(name: "enc", category: "crypto", createdAt: createdAt)
}

@Test func solvingStampsSolvedDate() {
    let solved = newChallenge().withStatus(.solved, at: solvedAt)
    #expect(solved.status == .solved)
    #expect(solved.solvedAt == solvedAt)
}

@Test func solvingAgainKeepsFirstSolvedDate() {
    let solved = newChallenge().withStatus(.solved, at: solvedAt)
    let again = solved.withStatus(.solved, at: solvedAt.addingTimeInterval(60))
    #expect(again.solvedAt == solvedAt)
}

@Test func recordingFlagMarksChallengeSolved() {
    let solved = newChallenge().solved(withFlag: "picoCTF{x}", at: solvedAt)
    #expect(solved.status == .solved)
    #expect(solved.flag == "picoCTF{x}")
    #expect(solved.solvedAt == solvedAt)
}

@Test func correctingFlagKeepsFirstSolvedDate() {
    let corrected = newChallenge()
        .solved(withFlag: "picoCTF{typo}", at: solvedAt)
        .solved(withFlag: "picoCTF{x}", at: solvedAt.addingTimeInterval(60))
    #expect(corrected.flag == "picoCTF{x}")
    #expect(corrected.solvedAt == solvedAt)
}

@Test func leavingSolvedClearsSolvedDate() {
    let reopened = newChallenge()
        .withStatus(.solved, at: solvedAt)
        .withStatus(.inProgress, at: solvedAt)
    #expect(reopened.status == .inProgress)
    #expect(reopened.solvedAt == nil)
}
