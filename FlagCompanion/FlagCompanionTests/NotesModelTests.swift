import ChallengeLibrary
import Foundation
import Testing

@testable import FlagCompanion

/// A library in a new temporary root with one challenge, deleted by `cleanUp()`.
@MainActor
private struct NotesFixture {
    let root: URL
    let library: LibraryModel
    let challenge: LibraryChallenge

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(
                path: "flag-companion-app-tests/\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let ctf = try LibraryFolders.createCTF(named: "pico", in: root)
        challenge = try LibraryFolders.createChallenge(
            Challenge(name: "enc", category: "crypto", createdAt: .now), in: ctf)
        library = LibraryModel(rootFolder: root)
        library.reload()
    }

    func makeNotes(saveDelay: Duration = .seconds(60)) -> NotesModel {
        let notes = NotesModel(
            challengeFolder: challenge.folder, library: library, saveDelay: saveDelay)
        notes.load()
        return notes
    }

    func fileText(_ tab: String) throws -> String {
        try String(contentsOf: ChallengeNotes.noteFile(tab: tab, of: challenge), encoding: .utf8)
    }

    func cleanUp() { try? FileManager.default.removeItem(at: root) }
}

@MainActor
@Test func typingIsSavedAfterTheDelay() async throws {
    let fixture = try NotesFixture()
    defer { fixture.cleanUp() }
    let notes = fixture.makeNotes(saveDelay: .milliseconds(20))
    notes.text = "xor key 0x42"
    #expect(try fixture.fileText("context") == "")
    try await Task.sleep(for: .milliseconds(300))
    #expect(try fixture.fileText("context") == "xor key 0x42")
    #expect(!notes.hasUnsavedChanges)
}

@MainActor
@Test func switchingTabSavesAndLoadsTheOtherNote() throws {
    let fixture = try NotesFixture()
    defer { fixture.cleanUp() }
    try ChallengeNotes.write("found it", tab: "findings", of: fixture.challenge)
    let notes = fixture.makeNotes()
    notes.text = "context text"
    notes.select("findings")
    #expect(try fixture.fileText("context") == "context text")
    #expect(notes.text == "found it")
}

@MainActor
@Test func externalEditIsPickedUpWhenNothingIsPending() throws {
    let fixture = try NotesFixture()
    defer { fixture.cleanUp() }
    let notes = fixture.makeNotes()
    try ChallengeNotes.write("edited in Obsidian", tab: "context", of: fixture.challenge)
    notes.reloadFromDisk()
    #expect(notes.text == "edited in Obsidian")
}

@MainActor
@Test func unsavedTypingWinsOverExternalEdit() throws {
    let fixture = try NotesFixture()
    defer { fixture.cleanUp() }
    let notes = fixture.makeNotes()
    notes.text = "typing here"
    try ChallengeNotes.write("edited in Obsidian", tab: "context", of: fixture.challenge)
    notes.reloadFromDisk()
    #expect(notes.text == "typing here")
}

@MainActor
@Test func addingTabOpensIt() throws {
    let fixture = try NotesFixture()
    defer { fixture.cleanUp() }
    let notes = fixture.makeNotes()
    notes.addTab(named: "Tools")
    #expect(notes.tabs == ["context", "findings", "tools"])
    #expect(notes.selectedTab == "tools")
    notes.addTab(named: "tools")
    #expect(notes.failureMessage == "A tab named “tools” already exists.")
}

@MainActor
@Test func removingOpenTabReturnsToContext() throws {
    let fixture = try NotesFixture()
    defer { fixture.cleanUp() }
    let notes = fixture.makeNotes()
    notes.addTab(named: "tools")
    notes.removeTab("tools")
    #expect(notes.tabs == ["context", "findings"])
    #expect(notes.selectedTab == "context")
}

@Test func markdownIsSplitIntoHeadingsCodeAndParagraphs() {
    let note = "# Enc\nfirst line\nsecond line\n\n```\nxxd enc\n\n00: 41\n```\n##no space"
    #expect(
        MarkdownBlocks.parse(note) == [
            .heading(level: 1, text: "Enc"),
            .paragraph("first line\nsecond line"),
            .code("xxd enc\n\n00: 41"),
            .paragraph("##no space"),
        ])
}

@Test func unclosedCodeFenceStillShowsCode() {
    #expect(MarkdownBlocks.parse("```\nnc host 1337") == [.code("nc host 1337")])
}
