import Foundation

/// Reads the root folder into CTFs and challenges. The disk is the source of
/// truth: a folder is a CTF when it has `ctf.json` and a challenge when it has
/// `challenge.json`. Other folders are ignored, and unreadable metadata becomes
/// a `LibraryProblem` instead of an error.
///
/// ```swift
/// let scan = try LibraryScanner.scan(root: URL(filePath: "/Users/me/CTFs"))
/// ```
public enum LibraryScanner {
    /// Throws only when `root` itself cannot be listed.
    public static func scan(root: URL) throws -> LibraryScan {
        var scan = LibraryScan()
        for folder in try subfolders(of: root) {
            let file = folder.appending(path: MetadataJSON.ctfFileName)
            guard let ctf = readMetadata(CTF.self, from: file, problems: &scan.problems) else {
                continue
            }
            let challenges = try scanChallenges(in: folder, problems: &scan.problems)
            scan.ctfs.append(LibraryCTF(folder: folder, metadata: ctf, challenges: challenges))
        }
        scan.ctfs.sort { isOrderedByName($0.metadata.name, $1.metadata.name) }
        return scan
    }

    private static func scanChallenges(
        in ctfFolder: URL,
        problems: inout [LibraryProblem]
    ) throws -> [LibraryChallenge] {
        var challenges: [LibraryChallenge] = []
        for folder in try subfolders(of: ctfFolder) {
            let file = folder.appending(path: MetadataJSON.challengeFileName)
            guard let challenge = readMetadata(Challenge.self, from: file, problems: &problems)
            else { continue }
            challenges.append(LibraryChallenge(folder: folder, metadata: challenge))
        }
        return challenges.sorted { isOrderedByName($0.metadata.name, $1.metadata.name) }
    }

    /// Returns nil both for a missing file (not library content) and for an
    /// invalid one, which is also added to `problems`.
    private static func readMetadata<Metadata: Decodable>(
        _ type: Metadata.Type,
        from file: URL,
        problems: inout [LibraryProblem]
    ) -> Metadata? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        do {
            return try MetadataJSON.decoder().decode(type, from: Data(contentsOf: file))
        } catch {
            problems.append(LibraryProblem(file: file, reason: describe(error)))
            return nil
        }
    }

    private static func subfolders(of folder: URL) throws -> [URL] {
        let items = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        // Listing returns resolved paths (/private/var instead of /var), so rebuild each
        // URL from the folder the caller gave; otherwise scanned and created URLs differ.
        return items
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { folder.appending(path: $0.lastPathComponent, directoryHint: .isDirectory) }
    }

    private static func isOrderedByName(_ first: String, _ second: String) -> Bool {
        first.localizedStandardCompare(second) == .orderedAscending
    }
}
