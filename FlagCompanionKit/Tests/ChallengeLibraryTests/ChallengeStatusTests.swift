import ChallengeLibrary
import Testing

@Test func inProgressStatusUsesSnakeCaseText() {
    #expect(ChallengeStatus.inProgress.rawValue == "in_progress")
}
