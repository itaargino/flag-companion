//
//  FlagCompanionApp.swift
//  FlagCompanion
//
//  Created by Isaque da Silva Targino on 17/10/26.
//

import AppKit
import SwiftUI

@main
struct FlagCompanionApp: App {
    @State private var library = LibraryModel()

    init() {
        // Terminal tabs live inside the challenge window; macOS window tabs would
        // add a second, competing tab bar and claim ⌘T-style shortcuts.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        Window("Flag Companion", id: "library") {
            LibraryView(model: library)
        }
        .commands {
            LibraryCommands(model: library)
            ChallengeCommands()
        }

        // One window per challenge, identified by its folder.
        WindowGroup("Challenge", id: "challenge", for: URL.self) { $challengeFolder in
            if let challengeFolder {
                ChallengeWindow(challengeFolder: challengeFolder, library: library)
            }
        }
    }
}
