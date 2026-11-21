import ChallengeLibrary
import Foundation
import Testing

private let createdAt = Date(timeIntervalSince1970: 1_792_074_878)

private func makeChallenge(in root: URL) throws -> LibraryChallenge {
    let ctf = try LibraryFolders.createCTF(named: "pico", in: root, createdAt: createdAt)
    let challenge = Challenge(name: "enc", category: "crypto", createdAt: createdAt)
    return try LibraryFolders.createChallenge(challenge, in: ctf)
}

private func savedTabs(of challenge: LibraryChallenge) throws -> [String] {
    let file = challenge.folder.appending(path: "challenge.json")
    return try MetadataJSON.decoder().decode(Challenge.self, from: Data(contentsOf: file)).tabs
}

@Test func newChallengeHasContextAndFindingsNoteTabs() throws {
    try withTemporaryFolder { root in
        let challenge = try makeChallenge(in: root)
        #expect(ChallengeNotes.noteTabs(of: challenge.metadata) == ["context", "findings"])
        #expect(try ChallengeNotes.read(tab: "context", of: challenge) == "")
    }
}

@Test func writtenNoteIsReadBackWithRestrictedPermissions() throws {
    try withTemporaryFolder { root in
        let challenge = try makeChallenge(in: root)
        try ChallengeNotes.write("## Key\nxor 0x42\n", tab: "findings", of: challenge)
        #expect(try ChallengeNotes.read(tab: "findings", of: challenge) == "## Key\nxor 0x42\n")
        let file = ChallengeNotes.noteFile(tab: "findings", of: challenge)
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        #expect(attributes[.posixPermissions] as? Int == 0o600)
    }
}

@Test func customTabCreatesFileAndIsSavedInOrder() throws {
    try withTemporaryFolder { root in
        var challenge = try makeChallenge(in: root)
        let tab = try ChallengeNotes.addCustomTab(named: "Tools Used", to: &challenge)
        #expect(tab == "tools-used")
        #expect(
            ChallengeNotes.noteTabs(of: challenge.metadata) == [
                "context", "findings", "tools-used",
            ])
        #expect(try savedTabs(of: challenge) == ["context", "findings", "prints", "tools-used"])
        #expect(
            FileManager.default.fileExists(
                atPath: ChallengeNotes.noteFile(tab: tab, of: challenge).path))
    }
}

@Test func duplicateOrFixedTabNamesAreRejected() throws {
    try withTemporaryFolder { root in
        var challenge = try makeChallenge(in: root)
        _ = try ChallengeNotes.addCustomTab(named: "tools", to: &challenge)
        for name in ["Tools", "Findings", "prints"] {
            #expect(throws: NotesError.self) {
                _ = try ChallengeNotes.addCustomTab(named: name, to: &challenge)
            }
        }
    }
}

@Test func renamingCustomTabKeepsTextAndPosition() throws {
    try withTemporaryFolder { root in
        var challenge = try makeChallenge(in: root)
        _ = try ChallengeNotes.addCustomTab(named: "tools", to: &challenge)
        _ = try ChallengeNotes.addCustomTab(named: "ideas", to: &challenge)
        try ChallengeNotes.write("ghidra", tab: "tools", of: challenge)
        let renamed = try ChallengeNotes.renameCustomTab("tools", to: "Software", in: &challenge)
        #expect(try ChallengeNotes.read(tab: renamed, of: challenge) == "ghidra")
        #expect(ChallengeNotes.customTabs(of: challenge.metadata) == ["software", "ideas"])
    }
}

@Test func removingCustomTabDropsItFromTabs() throws {
    try withTemporaryFolder { root in
        var challenge = try makeChallenge(in: root)
        let tab = try ChallengeNotes.addCustomTab(named: "tools", to: &challenge)
        try ChallengeNotes.removeCustomTab(tab, from: &challenge)
        #expect(try savedTabs(of: challenge) == ["context", "findings", "prints"])
        #expect(
            !FileManager.default.fileExists(
                atPath: ChallengeNotes.noteFile(tab: tab, of: challenge).path))
    }
}

@Test func fixedTabsCannotBeRenamedOrRemoved() throws {
    try withTemporaryFolder { root in
        var challenge = try makeChallenge(in: root)
        #expect(throws: NotesError.self) {
            try ChallengeNotes.removeCustomTab("findings", from: &challenge)
        }
        #expect(throws: NotesError.self) {
            _ = try ChallengeNotes.renameCustomTab("context", to: "intro", in: &challenge)
        }
    }
}

@Test func olderChallengeWithoutTabsStillShowsFixedTabs() {
    var challenge = Challenge(name: "enc", category: "crypto", createdAt: createdAt)
    challenge.tabs = ["tools"]
    #expect(ChallengeNotes.noteTabs(of: challenge) == ["context", "findings", "tools"])
}
