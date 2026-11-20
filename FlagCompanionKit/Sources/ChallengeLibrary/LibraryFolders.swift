import Foundation

/// Creates CTF and challenge folders with the structure and permissions from
/// the spec. Folder names are slugs of the display name; an existing folder is
/// never overwritten.
///
/// ```swift
/// let ctf = try LibraryFolders.createCTF(named: "picoCTF 2026", in: root)
/// let challenge = try LibraryFolders.createChallenge(
///     Challenge(name: "enc", category: "crypto", createdAt: .now),
///     in: ctf
/// )
/// ```
public enum LibraryFolders {
    /// The note files a new challenge starts with, matching `Challenge.defaultTabs`.
    public static let initialNoteFiles = ["context.md", "findings.md"]

    /// Creates the root folder with `0700` when it does not exist yet. An existing
    /// folder is left as it is, because it belongs to the user.
    public static func prepareRoot(_ root: URL) throws {
        guard !FileManager.default.fileExists(atPath: root.path) else { return }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: ProtectedFiles.folderPermissions]
        )
    }

    public static func createCTF(
        named name: String,
        in root: URL,
        createdAt: Date = .now
    ) throws -> LibraryCTF {
        let ctf = CTF(name: name, createdAt: createdAt)
        let folder = root.appending(path: try Slug(name).value, directoryHint: .isDirectory)
        try ProtectedFiles.createFolder(at: folder)
        try writeMetadata(ctf, to: folder.appending(path: MetadataJSON.ctfFileName))
        return LibraryCTF(folder: folder, metadata: ctf, challenges: [])
    }

    public static func createChallenge(
        _ challenge: Challenge,
        in ctf: LibraryCTF
    ) throws -> LibraryChallenge {
        let slug = try Slug(challenge.name).value
        let folder = ctf.folder.appending(path: slug, directoryHint: .isDirectory)
        try ProtectedFiles.createFolder(at: folder)
        try createChallengeContents(in: folder)
        try writeMetadata(challenge, to: folder.appending(path: MetadataJSON.challengeFileName))
        return LibraryChallenge(folder: folder, metadata: challenge)
    }

    /// Writes `challenge.json` again, for example after the status changes.
    public static func save(_ challenge: LibraryChallenge) throws {
        let file = challenge.folder.appending(path: MetadataJSON.challengeFileName)
        try writeMetadata(challenge.metadata, to: file)
    }

    /// Moves a challenge folder, with its notes, screenshots, files and logs, to
    /// the Trash, so a challenge removed by mistake can still be put back.
    ///
    /// ```swift
    /// try LibraryFolders.moveToTrash(challenge)
    /// ```
    public static func moveToTrash(_ challenge: LibraryChallenge) throws {
        try FileManager.default.trashItem(at: challenge.folder, resultingItemURL: nil)
    }

    /// Moves a CTF folder and every challenge in it to the Trash.
    ///
    /// ```swift
    /// try LibraryFolders.moveToTrash(ctf)
    /// ```
    public static func moveToTrash(_ ctf: LibraryCTF) throws {
        try FileManager.default.trashItem(at: ctf.folder, resultingItemURL: nil)
    }

    private static func createChallengeContents(in folder: URL) throws {
        for subfolder in ChallengeSubfolder.allCases {
            try ProtectedFiles.createFolder(at: folder.appending(path: subfolder.rawValue))
        }
        let notes = folder.appending(path: ChallengeSubfolder.notes.rawValue)
        for noteFile in initialNoteFiles {
            try ProtectedFiles.write(Data(), to: notes.appending(path: noteFile))
        }
    }

    private static func writeMetadata<Metadata: Encodable>(
        _ metadata: Metadata,
        to file: URL
    ) throws {
        try ProtectedFiles.write(MetadataJSON.encoder().encode(metadata), to: file)
    }
}
