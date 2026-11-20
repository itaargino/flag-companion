//
//  FlagCompanionTests.swift
//  FlagCompanionTests
//
//  Created by Isaque da Silva Targino on 17/10/26.
//

import ChallengeLibrary
import Foundation
import Testing

@testable import FlagCompanion

private let ctfFolder = URL(filePath: "/tmp/CTFs/pico", directoryHint: .isDirectory)
private let createdAt = Date(timeIntervalSince1970: 1_792_074_878)

@Test func completeDraftBecomesTrimmedChallenge() throws {
    let draft = ChallengeDraft(
        name: "  enc ", category: "Crypto", points: "100", ctfFolder: ctfFolder)
    let challenge = try #require(draft.challenge(createdAt: createdAt))
    #expect(challenge.name == "enc")
    #expect(challenge.category == "crypto")
    #expect(challenge.points == 100)
    #expect(challenge.status == .todo)
}

@Test func draftWithoutPointsIsComplete() {
    let draft = ChallengeDraft(name: "enc", category: "crypto", ctfFolder: ctfFolder)
    #expect(draft.isComplete)
    #expect(draft.challenge(createdAt: createdAt)?.points == nil)
}

@Test(arguments: [
    ChallengeDraft(name: " ", category: "crypto", ctfFolder: ctfFolder),
    ChallengeDraft(name: "enc", category: "", ctfFolder: ctfFolder),
    ChallengeDraft(name: "enc", category: "crypto", points: "lots", ctfFolder: ctfFolder),
    ChallengeDraft(name: "enc", category: "crypto", points: "-5", ctfFolder: ctfFolder),
    ChallengeDraft(name: "enc", category: "crypto"),
])
func incompleteDraftIsRejected(draft: ChallengeDraft) {
    #expect(!draft.isComplete)
    #expect(draft.challenge(createdAt: createdAt) == nil)
}

@Test func existingFolderFailureNamesTheFolder() {
    let error = LibraryError.itemAlreadyExists(received: ctfFolder, expected: "a free path")
    #expect(libraryFailureMessage(for: error) == "A folder named “pico” already exists here.")
}

@Test func slugFailureExplainsWhatTheNameNeeds() {
    let error = SlugError.noLatinLettersOrDigits(received: "!!!", expected: "")
    #expect(libraryFailureMessage(for: error).contains("at least one letter or digit"))
}

@Test func rootFolderPreferenceDefaultsToCTFsAndRemembersChoice() throws {
    let defaults = try #require(UserDefaults(suiteName: "RootFolderPreferenceTests"))
    defaults.removePersistentDomain(forName: "RootFolderPreferenceTests")
    #expect(RootFolderPreference.load(from: defaults) == RootFolderPreference.defaultFolder)
    RootFolderPreference.save(ctfFolder, to: defaults)
    #expect(RootFolderPreference.load(from: defaults).path == ctfFolder.path)
    defaults.removePersistentDomain(forName: "RootFolderPreferenceTests")
}

@Test func emptyTabNameKeepsCurrentName() {
    #expect(TabName.renamed("Terminal 1", to: "   ") == "Terminal 1")
    #expect(TabName.renamed("Terminal 1", to: " thinkpad ") == "thinkpad")
}
