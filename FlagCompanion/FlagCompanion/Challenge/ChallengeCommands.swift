import SwiftUI

/// Terminal tab commands for the challenge window in front, with the shortcuts
/// from the spec. They are disabled when the library window is in front.
struct ChallengeCommands: Commands {
    @FocusedValue(\.challengeWorkspace) private var workspace
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
            Button("New Tab") { workspace?.openTab() }
                .keyboardShortcut("t")
                .disabled(workspace == nil)
            // Listed before the system "Close" item, so ⌘W closes the tab while a
            // challenge window is in front and the window otherwise.
            Button("Close Tab") { workspace?.requestCloseSelectedTab() }
                .keyboardShortcut("w")
                .disabled(workspace?.selectedTab == nil)
        }
        CommandGroup(after: .toolbar) {
            ForEach(0..<9, id: \.self) { position in
                Button("Show Tab \(position + 1)") { workspace?.selectTab(atPosition: position) }
                    .keyboardShortcut(KeyEquivalent(Character("\(position + 1)")))
                    .disabled(workspace == nil)
            }
        }
        CommandGroup(after: .windowArrangement) {
            // From a challenge window this also closes it; from the library it just shows it.
            Button("Back to Library") {
                if let workspace { workspace.requestLeave() } else { openWindow(id: "library") }
            }
            .keyboardShortcut("[")
        }
    }
}
