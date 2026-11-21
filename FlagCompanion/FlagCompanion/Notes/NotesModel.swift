import ChallengeLibrary
import Foundation
import Observation
import os

/// The notes column of a challenge window: which note tab is open, its text,
/// and saving it to `notes/<tab>.md` one second after the user stops typing.
///
/// ```swift
/// let notes = NotesModel(challengeFolder: folder, library: library)
/// notes.load()
/// notes.text += "\n- key is 0x42"
/// ```
@Observable
final class NotesModel {
    let challengeFolder: URL
    private(set) var selectedTab = ChallengeNotes.fixedNoteTabs[0]
    var isPreviewing = false
    var failureMessage: String?

    var text = "" {
        didSet { scheduleSave() }
    }

    @ObservationIgnored private let library: LibraryModel
    @ObservationIgnored private let saveDelay: Duration
    @ObservationIgnored private var savedText = ""
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    private let logger = Logger(subsystem: "FlagCompanion", category: "Notes")

    init(challengeFolder: URL, library: LibraryModel, saveDelay: Duration = .seconds(1)) {
        self.challengeFolder = challengeFolder
        self.library = library
        self.saveDelay = saveDelay
    }

    var tabs: [String] {
        guard let challenge else { return ChallengeNotes.fixedNoteTabs }
        return ChallengeNotes.noteTabs(of: challenge.metadata)
    }

    var hasUnsavedChanges: Bool { text != savedText }

    func isCustomTab(_ tab: String) -> Bool { !ChallengeNotes.fixedNoteTabs.contains(tab) }

    func select(_ tab: String) {
        guard tab != selectedTab else { return }
        saveNow()
        selectedTab = tab
        load()
    }

    /// Reads the open tab's file, replacing the text in the editor.
    func load() {
        guard let challenge else { return }
        do {
            let fileText = try ChallengeNotes.read(tab: selectedTab, of: challenge)
            savedText = fileText
            text = fileText
        } catch {
            report(error)
        }
    }

    /// Picks up edits made in another app, such as Obsidian. Text typed here and
    /// not saved yet wins, so returning to the app never discards typing.
    func reloadFromDisk() {
        guard !hasUnsavedChanges else { return }
        if !tabs.contains(selectedTab) { selectedTab = ChallengeNotes.fixedNoteTabs[0] }
        load()
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard hasUnsavedChanges, let challenge else { return }
        do {
            try ChallengeNotes.write(text, tab: selectedTab, of: challenge)
            savedText = text
        } catch {
            report(error)
        }
    }

    private func scheduleSave() {
        guard hasUnsavedChanges else { return }
        pendingSave?.cancel()
        pendingSave = Task { [weak self, saveDelay] in
            try? await Task.sleep(for: saveDelay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private var challenge: LibraryChallenge? { library.challenge(at: challengeFolder) }

    fileprivate func report(_ error: Error) {
        logger.error("Notes action failed: \(error, privacy: .private)")
        failureMessage = notesFailureMessage(for: error)
    }
}

// MARK: - Custom tabs

extension NotesModel {
    func addTab(named name: String) {
        changeTabs { challenge in
            let tab = try ChallengeNotes.addCustomTab(named: name, to: &challenge)
            return tab
        }
    }

    func renameTab(_ tab: String, to name: String) {
        changeTabs { challenge in
            try ChallengeNotes.renameCustomTab(tab, to: name, in: &challenge)
        }
    }

    func removeTab(_ tab: String) {
        changeTabs { challenge in
            try ChallengeNotes.removeCustomTab(tab, from: &challenge)
            return ChallengeNotes.fixedNoteTabs[0]
        }
    }

    /// Saves pending text, applies the change, rereads the library so `tabs`
    /// updates, and opens the tab the change returns.
    private func changeTabs(_ change: (inout LibraryChallenge) throws -> String) {
        saveNow()
        guard var changed = challenge else { return }
        do {
            let tabToOpen = try change(&changed)
            library.reload()
            selectedTab = tabToOpen
            load()
        } catch {
            report(error)
        }
    }
}

/// Turns an error from a notes action into a sentence for an alert.
nonisolated func notesFailureMessage(for error: Error) -> String {
    switch error {
    case NotesError.tabAlreadyExists(let tab, _):
        return "A tab named “\(tab)” already exists."
    case NotesError.notACustomTab:
        return "Context and Findings cannot be renamed or removed."
    default:
        return libraryFailureMessage(for: error)
    }
}
