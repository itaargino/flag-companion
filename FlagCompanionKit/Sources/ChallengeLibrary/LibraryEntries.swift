import Foundation

/// A CTF found on disk: its folder, its `ctf.json` and the challenges inside it.
///
/// ```swift
/// for ctf in scan.ctfs {
///     print(ctf.metadata.name, ctf.challenges.count)
/// }
/// ```
public struct LibraryCTF: Equatable, Sendable, Identifiable {
    public let folder: URL
    public var metadata: CTF
    public var challenges: [LibraryChallenge]

    public var id: URL { folder }

    public init(folder: URL, metadata: CTF, challenges: [LibraryChallenge]) {
        self.folder = folder
        self.metadata = metadata
        self.challenges = challenges
    }
}

/// A challenge found on disk: its folder and its `challenge.json`.
///
/// ```swift
/// let filesFolder = challenge.folder.appending(path: ChallengeSubfolder.files.rawValue)
/// ```
public struct LibraryChallenge: Equatable, Sendable, Identifiable {
    public let folder: URL
    public var metadata: Challenge

    public var id: URL { folder }

    public init(folder: URL, metadata: Challenge) {
        self.folder = folder
        self.metadata = metadata
    }
}

/// The result of reading the root folder: every valid CTF, sorted by name,
/// plus the metadata files that could not be read.
public struct LibraryScan: Equatable, Sendable {
    public var ctfs: [LibraryCTF]
    public var problems: [LibraryProblem]

    public init(ctfs: [LibraryCTF] = [], problems: [LibraryProblem] = []) {
        self.ctfs = ctfs
        self.problems = problems
    }
}

/// The folders every challenge has, from the "Folder structure" section of the spec.
public enum ChallengeSubfolder: String, CaseIterable, Sendable {
    case notes
    case prints
    case files
    case logs
}
