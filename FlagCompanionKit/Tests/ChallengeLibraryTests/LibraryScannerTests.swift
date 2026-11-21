import ChallengeLibrary
import Foundation
import Testing

private let createdAt = Date(timeIntervalSince1970: 1_792_074_878)

private func write(_ text: String, to file: URL) throws {
    try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: file)
}

@Test func emptyRootHasNoCTFs() throws {
    try withTemporaryFolder { root in
        let scan = try LibraryScanner.scan(root: root)
        #expect(scan == LibraryScan())
    }
}

@Test func createdCTFsAndChallengesAreFoundSortedByName() throws {
    try withTemporaryFolder { root in
        let zeta = try LibraryFolders.createCTF(named: "Zeta CTF", in: root, createdAt: createdAt)
        let alpha = try LibraryFolders.createCTF(named: "alpha", in: root, createdAt: createdAt)
        for name in ["web 10", "web 2"] {
            let challenge = Challenge(name: name, category: "web", createdAt: createdAt)
            _ = try LibraryFolders.createChallenge(challenge, in: zeta)
        }
        let scan = try LibraryScanner.scan(root: root)
        #expect(scan.ctfs.map(\.folder) == [alpha.folder, zeta.folder])
        #expect(scan.ctfs[1].challenges.map(\.metadata.name) == ["web 2", "web 10"])
        #expect(scan.problems.isEmpty)
    }
}

@Test func foldersWithoutMetadataAndLooseFilesAreIgnored() throws {
    try withTemporaryFolder { root in
        let ctf = try LibraryFolders.createCTF(named: "pico", in: root, createdAt: createdAt)
        try FileManager.default.createDirectory(
            at: root.appending(path: "random"), withIntermediateDirectories: true)
        try write("notes", to: root.appending(path: "readme.md"))
        try write("x", to: ctf.folder.appending(path: "scratch/file.txt"))
        let scan = try LibraryScanner.scan(root: root)
        #expect(scan.ctfs.map(\.folder) == [ctf.folder])
        #expect(scan.ctfs[0].challenges.isEmpty)
        #expect(scan.problems.isEmpty)
    }
}

@Test func invalidCTFIsReportedAndOthersStillLoad() throws {
    try withTemporaryFolder { root in
        let valid = try LibraryFolders.createCTF(named: "valid", in: root, createdAt: createdAt)
        let broken = root.appending(path: "broken/ctf.json")
        try write("{ not json", to: broken)
        let scan = try LibraryScanner.scan(root: root)
        #expect(scan.ctfs.map(\.folder) == [valid.folder])
        #expect(scan.problems == [LibraryProblem(file: broken, reason: "The file is not valid JSON.")])
    }
}

@Test func challengeWithMissingKeyIsReportedByKeyName() throws {
    try withTemporaryFolder { root in
        let ctf = try LibraryFolders.createCTF(named: "pico", in: root, createdAt: createdAt)
        let broken = ctf.folder.appending(path: "enc/challenge.json")
        try write(#"{"v": 1, "name": "enc"}"#, to: broken)
        let scan = try LibraryScanner.scan(root: root)
        #expect(scan.ctfs[0].challenges.isEmpty)
        #expect(scan.problems.map(\.file) == [broken])
        #expect(scan.problems.first?.reason.hasPrefix("Missing key") == true)
    }
}

@Test func missingRootThrows() throws {
    let absentRoot = try withTemporaryFolder { $0 }
    #expect(throws: (any Error).self) { try LibraryScanner.scan(root: absentRoot) }
}
