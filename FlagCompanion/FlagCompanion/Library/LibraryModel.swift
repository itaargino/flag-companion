import AppKit
import ChallengeLibrary
import Observation
import os

/// The sheets the library screen can show.
enum LibrarySheet: Hashable, Identifiable {
    case newCTF
    case newChallenge(ctfFolder: URL?)
    case recordFlag(challengeFolder: URL)

    var id: Self { self }
}

/// A CTF or a challenge waiting for the user to confirm moving it to the Trash.
enum LibraryTrashItem: Equatable {
    case ctf(LibraryCTF)
    case challenge(LibraryChallenge)

    var name: String {
        switch self {
        case .ctf(let ctf): ctf.metadata.name
        case .challenge(let challenge): challenge.metadata.name
        }
    }

    var explanation: String {
        switch self {
        case .ctf:
            "Every challenge in this CTF goes to the Trash with it, including notes, "
                + "screenshots and files. Open challenge windows close."
        case .challenge:
            "Its notes, screenshots and files go to the Trash with it. "
                + "An open window for it closes."
        }
    }
}

/// The state of the library screen: the last scan of the root folder and the
/// actions that change the folders on disk. Views read it and call its methods.
@Observable
final class LibraryModel {
    private(set) var rootFolder: URL
    private(set) var scan = LibraryScan()
    var failureMessage: String?
    var activeSheet: LibrarySheet?
    var selectedChallengeFolder: URL?
    var itemToTrash: LibraryTrashItem?

    private let logger = Logger(subsystem: "FlagCompanion", category: "Library")

    init(rootFolder: URL = RootFolderPreference.load()) {
        self.rootFolder = rootFolder
    }

    var canCreateChallenge: Bool { !scan.ctfs.isEmpty }

    var selectedChallenge: LibraryChallenge? { challenge(at: selectedChallengeFolder) }

    func challenge(at folder: URL?) -> LibraryChallenge? {
        scan.ctfs.lazy.flatMap(\.challenges).first { $0.folder == folder }
    }

    /// Opens the flag sheet for the selected challenge (⇧⌘F).
    func beginRecordingFlag() {
        guard let folder = selectedChallenge?.folder else { return }
        activeSheet = .recordFlag(challengeFolder: folder)
    }

    var isShowingFailure: Bool {
        get { failureMessage != nil }
        set { if !newValue { failureMessage = nil } }
    }

    /// Rereads the root folder, creating it first when it does not exist.
    func reload() {
        do {
            try LibraryFolders.prepareRoot(rootFolder)
            scan = try LibraryScanner.scan(root: rootFolder)
        } catch {
            report(error)
        }
    }

    /// Returns a message for the sheet when the CTF could not be created.
    func createCTF(named name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return attempt { _ = try LibraryFolders.createCTF(named: trimmed, in: rootFolder) }
    }

    /// Returns a message for the sheet when the challenge could not be created.
    func createChallenge(from draft: ChallengeDraft) -> String? {
        guard let challenge = draft.challenge(createdAt: .now),
            let ctf = scan.ctfs.first(where: { $0.folder == draft.ctfFolder })
        else { return "Fill in the name, the category and the CTF." }
        return attempt { _ = try LibraryFolders.createChallenge(challenge, in: ctf) }
    }

    func setStatus(_ status: ChallengeStatus, of challenge: LibraryChallenge) {
        var changed = challenge
        changed.metadata = challenge.metadata.withStatus(status, at: .now)
        if let message = attempt({ try LibraryFolders.save(changed) }) {
            failureMessage = message
        }
    }

    /// Moves a challenge from To Do to In Progress when it is opened; other statuses stay.
    func markStarted(_ challenge: LibraryChallenge) {
        guard challenge.metadata.status == .todo else { return }
        setStatus(.inProgress, of: challenge)
    }

    /// Marks the challenge as solved with `flag`, returning a message for the sheet on failure.
    func recordFlag(_ flag: String, forChallengeAt folder: URL) -> String? {
        let trimmed = flag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var changed = challenge(at: folder) else {
            return "Type the flag before saving."
        }
        changed.metadata = changed.metadata.solved(withFlag: trimmed, at: .now)
        return attempt { try LibraryFolders.save(changed) }
    }

    /// Asks to move the selected challenge to the Trash (⌘⌫).
    func beginTrashingSelectedChallenge() {
        guard let challenge = selectedChallenge else { return }
        itemToTrash = .challenge(challenge)
    }

    /// Moves the CTF or challenge to the Trash. Windows of challenges that are
    /// gone close themselves after the rescan.
    func moveToTrash(_ item: LibraryTrashItem) {
        let message = attempt {
            switch item {
            case .ctf(let ctf): try LibraryFolders.moveToTrash(ctf)
            case .challenge(let challenge): try LibraryFolders.moveToTrash(challenge)
            }
        }
        if let message { failureMessage = message }
        if challenge(at: selectedChallengeFolder) == nil { selectedChallengeFolder = nil }
    }

    private func attempt(_ action: () throws -> Void) -> String? {
        defer { reload() }
        do {
            try action()
            return nil
        } catch {
            logger.error("Library action failed: \(error, privacy: .private)")
            return libraryFailureMessage(for: error)
        }
    }

    private func report(_ error: Error) {
        logger.error("Library reload failed: \(error, privacy: .private)")
        failureMessage = libraryFailureMessage(for: error)
    }
}

// MARK: - Finder and Terminal

extension LibraryModel {
    func showInFinder(_ item: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([item])
    }

    func openRootFolderInFinder() {
        NSWorkspace.shared.open(rootFolder)
    }

    /// Opens Terminal in the challenge's `files/` folder, where the spec says a new
    /// terminal starts. A stand-in until the embedded terminal (E4) exists.
    func openTerminal(for challenge: LibraryChallenge) {
        let files = challenge.folder.appending(path: ChallengeSubfolder.files.rawValue)
        guard
            let terminal = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.Terminal")
        else { return showInFinder(files) }
        NSWorkspace.shared.open(
            [files], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }

    func chooseRootFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = rootFolder
        panel.prompt = "Use as Root Folder"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        RootFolderPreference.save(folder)
        rootFolder = folder
        reload()
    }
}
