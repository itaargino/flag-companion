import ChallengeLibrary
import SwiftUI

/// New CTF and New Challenge buttons in the window toolbar.
struct LibraryToolbar: ToolbarContent {
    let model: LibraryModel

    var body: some ToolbarContent {
        ToolbarItemGroup {
            Button("New CTF", systemImage: "folder.badge.plus") {
                model.activeSheet = .newCTF
            }
            .help("New CTF (⇧⌘N)")
            Button("New Challenge", systemImage: "plus") {
                model.activeSheet = .newChallenge(ctfFolder: nil)
            }
            .help("New Challenge (⌘N)")
            .disabled(!model.canCreateChallenge)
        }
    }
}

struct EmptyLibraryView: View {
    let model: LibraryModel

    var body: some View {
        ContentUnavailableView {
            Label("No CTFs Yet", systemImage: "flag")
        } description: {
            Text("Create a CTF to start. Each one becomes a folder in \(model.rootFolder.path).")
        } actions: {
            Button("New CTF") { model.activeSheet = .newCTF }
        }
    }
}

/// Lists metadata files the scan could not read, so a broken file is visible
/// instead of the CTF or challenge silently disappearing.
struct LibraryProblemsBar: View {
    let problems: [LibraryProblem]

    var body: some View {
        if !problems.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label("Some folders were skipped", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                ForEach(problems, id: \.file) { problem in
                    Text("\(problem.file.path) — \(problem.reason)")
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.bar)
        }
    }
}

/// File menu items for the library, with the shortcuts from the spec.
struct LibraryCommands: Commands {
    let model: LibraryModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New CTF…") { model.activeSheet = .newCTF }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("New Challenge…") { model.activeSheet = .newChallenge(ctfFolder: nil) }
                .keyboardShortcut("n")
                .disabled(!model.canCreateChallenge)
            Divider()
            Button("Open Root Folder in Finder") { model.openRootFolderInFinder() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("Choose Root Folder…") { model.chooseRootFolder() }
        }
        CommandMenu("Challenge") {
            Button("Mark as Solved and Record Flag…") { model.beginRecordingFlag() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(model.selectedChallenge == nil)
            Divider()
            Button("Move to Trash…") { model.beginTrashingSelectedChallenge() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(model.selectedChallenge == nil)
        }
    }
}
