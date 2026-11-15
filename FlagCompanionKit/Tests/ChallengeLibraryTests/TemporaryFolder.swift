import Foundation

/// Runs `body` with a new, empty folder under the system temporary directory
/// and deletes the folder afterwards, even when `body` throws.
///
/// Tests that touch the file system use a real folder instead of a fake, because
/// permissions and atomic writes are behavior of the operating system.
///
/// ```swift
/// try withTemporaryFolder { folder in
///     try Data().write(to: folder.appending(path: "ctf.json"))
/// }
/// ```
func withTemporaryFolder<Result>(_ body: (URL) throws -> Result) throws -> Result {
    let folder = try makeTemporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    return try body(folder)
}

private func makeTemporaryFolder() throws -> URL {
    // On macOS the temporary directory sits under /var, a symlink to /private/var.
    // Resolving it keeps paths built by tests equal to paths returned by directory scans.
    let folder = FileManager.default.temporaryDirectory
        .resolvingSymlinksInPath()
        .appending(path: "flag-companion-tests", directoryHint: .isDirectory)
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}
