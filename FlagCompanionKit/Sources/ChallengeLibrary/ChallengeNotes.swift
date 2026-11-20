import Foundation

/// Reads and writes the Markdown notes of a challenge, one file per tab in
/// `notes/`, and manages custom tabs. Tab order lives in `challenge.json`.
///
/// ```swift
/// let text = try ChallengeNotes.read(tab: "findings", of: challenge)
/// try ChallengeNotes.write("## Key\n", tab: "findings", of: challenge)
/// ```
public enum ChallengeNotes {
    /// Note tabs every challenge has, in this order. They cannot be renamed or removed.
    public static let fixedNoteTabs = ["context", "findings"]

    /// The screenshots tab: listed in `tabs`, but backed by `prints/`, not by a note file.
    public static let screenshotsTab = "prints"

    /// The note tabs to show: the fixed ones first, then custom tabs in saved order.
    /// Fixed tabs are always included, even when an older `challenge.json` omits them.
    public static func noteTabs(of challenge: Challenge) -> [String] {
        fixedNoteTabs + customTabs(of: challenge)
    }

    public static func customTabs(of challenge: Challenge) -> [String] {
        challenge.tabs.filter { !fixedNoteTabs.contains($0) && $0 != screenshotsTab }
    }

    public static func noteFile(tab: String, of challenge: LibraryChallenge) -> URL {
        challenge.folder
            .appending(path: ChallengeSubfolder.notes.rawValue, directoryHint: .isDirectory)
            .appending(path: "\(tab).md")
    }

    /// Returns an empty note when the file does not exist yet.
    public static func read(tab: String, of challenge: LibraryChallenge) throws -> String {
        let file = noteFile(tab: tab, of: challenge)
        guard FileManager.default.fileExists(atPath: file.path) else { return "" }
        return try String(contentsOf: file, encoding: .utf8)
    }

    public static func write(_ text: String, tab: String, of challenge: LibraryChallenge) throws {
        try ensureNotesFolder(of: challenge)
        try ProtectedFiles.write(Data(text.utf8), to: noteFile(tab: tab, of: challenge))
    }

    /// Creates `notes/<slug>.md` and appends the tab to `tabs`. Returns the new tab name.
    public static func addCustomTab(
        named name: String,
        to challenge: inout LibraryChallenge
    ) throws -> String {
        let tab = try Slug(name).value
        try requireFreeTabName(tab, in: challenge)
        try write("", tab: tab, of: challenge)
        challenge.metadata.tabs = savedTabs(of: challenge.metadata) + [tab]
        try LibraryFolders.save(challenge)
        return tab
    }

    /// Renames the note file and the tab entry, keeping its position. Returns the new name.
    public static func renameCustomTab(
        _ tab: String,
        to name: String,
        in challenge: inout LibraryChallenge
    ) throws -> String {
        try requireCustomTab(tab, in: challenge)
        let newTab = try Slug(name).value
        guard newTab != tab else { return tab }
        try requireFreeTabName(newTab, in: challenge)
        try moveNoteFile(from: tab, to: newTab, of: challenge)
        challenge.metadata.tabs = savedTabs(of: challenge.metadata).map { $0 == tab ? newTab : $0 }
        try LibraryFolders.save(challenge)
        return newTab
    }

    /// Moves the note file to the Trash, so a removed tab can still be recovered.
    public static func removeCustomTab(_ tab: String, from challenge: inout LibraryChallenge) throws
    {
        try requireCustomTab(tab, in: challenge)
        let file = noteFile(tab: tab, of: challenge)
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.trashItem(at: file, resultingItemURL: nil)
        }
        challenge.metadata.tabs = savedTabs(of: challenge.metadata).filter { $0 != tab }
        try LibraryFolders.save(challenge)
    }

    /// The saved tab list with the fixed tabs restored, so editing custom tabs
    /// also repairs an older `challenge.json` that left them out.
    private static func savedTabs(of challenge: Challenge) -> [String] {
        let missing = Challenge.defaultTabs.filter { !challenge.tabs.contains($0) }
        return missing + challenge.tabs
    }

    private static func requireCustomTab(_ tab: String, in challenge: LibraryChallenge) throws {
        guard customTabs(of: challenge.metadata).contains(tab) else {
            throw NotesError.notACustomTab(received: tab, expected: "a custom tab")
        }
    }

    private static func requireFreeTabName(_ tab: String, in challenge: LibraryChallenge) throws {
        let taken = noteTabs(of: challenge.metadata) + [screenshotsTab]
        guard !taken.contains(tab) else {
            throw NotesError.tabAlreadyExists(received: tab, expected: "a name not in use")
        }
    }

    private static func moveNoteFile(
        from tab: String, to newTab: String, of challenge: LibraryChallenge
    ) throws {
        let source = noteFile(tab: tab, of: challenge)
        let destination = noteFile(tab: newTab, of: challenge)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw LibraryError.itemAlreadyExists(received: destination, expected: "a free path")
        }
        guard FileManager.default.fileExists(atPath: source.path) else {
            return try write("", tab: newTab, of: challenge)
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }

    private static func ensureNotesFolder(of challenge: LibraryChallenge) throws {
        let notes = challenge.folder.appending(path: ChallengeSubfolder.notes.rawValue)
        guard !FileManager.default.fileExists(atPath: notes.path) else { return }
        try ProtectedFiles.createFolder(at: notes)
    }
}

/// Errors thrown while changing note tabs.
public enum NotesError: Error, Equatable {
    case tabAlreadyExists(received: String, expected: String)
    case notACustomTab(received: String, expected: String)
}
