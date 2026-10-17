import SessionKit
import Testing

@Test func maxBytesPerCommandIsSixtyFourKilobytes() {
    #expect(CommandOutputLimit.maxBytesPerCommand == 64 * 1024)
}
