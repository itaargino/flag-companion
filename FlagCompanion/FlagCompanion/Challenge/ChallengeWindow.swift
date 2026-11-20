import ChallengeLibrary
import SwiftUI

extension FocusedValues {
    /// The workspace of the challenge window in front, read by the menu commands.
    @Entry var challengeWorkspace: ChallengeWorkspace?
}

/// A challenge window: terminal tabs on the left, notes on the right.
struct ChallengeWindow: View {
    let library: LibraryModel
    @State private var workspace: ChallengeWorkspace
    @State private var notes: NotesModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    init(challengeFolder: URL, library: LibraryModel) {
        self.library = library
        _workspace = State(initialValue: ChallengeWorkspace(challengeFolder: challengeFolder))
        _notes = State(initialValue: NotesModel(challengeFolder: challengeFolder, library: library))
    }

    var body: some View {
        HSplitView {
            TerminalArea(workspace: workspace)
                .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
            NotesPanel(notes: notes)
                .frame(minWidth: 240, idealWidth: 340, maxWidth: 700, maxHeight: .infinity)
        }
        .navigationTitle(challenge?.metadata.name ?? workspace.challengeFolder.lastPathComponent)
        .navigationSubtitle(challenge?.metadata.category ?? "")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Library", systemImage: "chevron.backward") { workspace.requestLeave() }
                    .help("Back to Library (⌘[)")
            }
        }
        .focusedSceneValue(\.challengeWorkspace, workspace)
        .onAppear { if workspace.tabs.isEmpty { workspace.openTab() } }
        .onDisappear { workspace.closeAllTabs() }
        // The challenge went to the Trash, from the library or from Finder.
        .onChange(of: workspace.isLeaving) { _, isLeaving in
            guard isLeaving else { return }
            openWindow(id: "library")
            dismiss()
        }
        .onChange(of: challenge == nil) { _, isGone in if isGone { dismiss() } }
        .frame(minWidth: 760, minHeight: 420)
    }

    private var challenge: LibraryChallenge? { library.challenge(at: workspace.challengeFolder) }
}
