import Foundation

/// Creates folders and files that only the current user can read, as the spec
/// requires for everything inside the root folder: `0700` for folders and
/// `0600` for files.
///
/// ```swift
/// try ProtectedFiles.createFolder(at: root.appending(path: "picoctf-2026"))
/// try ProtectedFiles.write(Data("{}".utf8), to: folder.appending(path: "ctf.json"))
/// ```
public enum ProtectedFiles {
    public static let folderPermissions = 0o700
    public static let filePermissions = 0o600

    /// Creates a folder with `0700`, failing when anything already exists at `url`.
    public static func createFolder(at url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw LibraryError.itemAlreadyExists(received: url, expected: "a free path")
        }
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: folderPermissions]
        )
    }

    /// Writes `contents` atomically and sets the file to `0600`.
    public static func write(_ contents: Data, to url: URL) throws {
        // An atomic write renames a new file into place, so the new file gets the default
        // umask permissions. Every folder above it is 0700, so no other user can read it
        // before the permissions below are applied.
        try contents.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: filePermissions],
            ofItemAtPath: url.path
        )
    }
}
