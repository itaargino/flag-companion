import ChallengeLibrary
import Foundation
import Testing

private let createdAt = Date(timeIntervalSince1970: 1_792_074_878)

private func permissions(of url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return try #require(attributes[.posixPermissions] as? Int)
}

private func makeCTF(in root: URL) throws -> LibraryCTF {
    try LibraryFolders.createCTF(named: "picoCTF 2026", in: root, createdAt: createdAt)
}

private func makeChallenge(in ctf: LibraryCTF) throws -> LibraryChallenge {
    let challenge = Challenge(name: "Enc Two", category: "crypto", createdAt: createdAt)
    return try LibraryFolders.createChallenge(challenge, in: ctf)
}

@Test func ctfFolderIsNamedBySlugAndHoldsMetadata() throws {
    try withTemporaryFolder { root in
        let ctf = try makeCTF(in: root)
        #expect(ctf.folder.lastPathComponent == "picoctf-2026")
        let data = try Data(contentsOf: ctf.folder.appending(path: "ctf.json"))
        #expect(try MetadataJSON.decoder().decode(CTF.self, from: data) == ctf.metadata)
    }
}

@Test func challengeFolderHasSpecStructure() throws {
    try withTemporaryFolder { root in
        let challenge = try makeChallenge(in: try makeCTF(in: root))
        let contents = try FileManager.default.subpathsOfDirectory(atPath: challenge.folder.path)
        #expect(
            Set(contents) == [
                "challenge.json", "notes", "notes/context.md", "notes/findings.md",
                "prints", "files", "logs",
            ])
        #expect(challenge.folder.lastPathComponent == "enc-two")
    }
}

@Test func everyCreatedItemHasRestrictedPermissions() throws {
    try withTemporaryFolder { root in
        let challenge = try makeChallenge(in: try makeCTF(in: root))
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: root.appending(path: "picoctf-2026"), includingPropertiesForKeys: nil))
        for case let item as URL in enumerator {
            let isFolder = item.hasDirectoryPath
            #expect(try permissions(of: item) == (isFolder ? 0o700 : 0o600), "\(item.path)")
        }
        #expect(try permissions(of: challenge.folder) == 0o700)
    }
}

@Test func existingFolderIsNeverOverwritten() throws {
    try withTemporaryFolder { root in
        let ctf = try makeCTF(in: root)
        #expect(throws: LibraryError.self) { try makeCTF(in: root) }
        _ = try makeChallenge(in: ctf)
        #expect(throws: LibraryError.self) { try makeChallenge(in: ctf) }
    }
}

@Test func savedChallengeIsReadBackWithNewStatus() throws {
    try withTemporaryFolder { root in
        var challenge = try makeChallenge(in: try makeCTF(in: root))
        challenge.metadata.status = .solved
        challenge.metadata.flag = "picoCTF{done}"
        try LibraryFolders.save(challenge)
        let scan = try LibraryScanner.scan(root: root)
        #expect(scan.ctfs.first?.challenges == [challenge])
    }
}

@Test func missingRootIsCreatedWithRestrictedPermissions() throws {
    try withTemporaryFolder { folder in
        let root = folder.appending(path: "CTFs")
        try LibraryFolders.prepareRoot(root)
        #expect(try permissions(of: root) == 0o700)
    }
}

@Test func trashedChallengeDisappearsFromScan() throws {
    try withTemporaryFolder { root in
        let ctf = try makeCTF(in: root)
        let challenge = try makeChallenge(in: ctf)
        try LibraryFolders.moveToTrash(challenge)
        #expect(!FileManager.default.fileExists(atPath: challenge.folder.path))
        let scan = try LibraryScanner.scan(root: root)
        #expect(scan.ctfs.map(\.challenges.count) == [0])
    }
}

@Test func trashedCTFTakesItsChallengesAlong() throws {
    try withTemporaryFolder { root in
        let ctf = try makeCTF(in: root)
        _ = try makeChallenge(in: ctf)
        try LibraryFolders.moveToTrash(ctf)
        #expect(try LibraryScanner.scan(root: root).ctfs.isEmpty)
    }
}
