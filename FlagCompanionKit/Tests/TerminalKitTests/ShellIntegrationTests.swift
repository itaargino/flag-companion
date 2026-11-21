import Foundation
import Testing

@testable import TerminalKit

/// A fresh folder for one test, removed afterwards. Each test gets its own
/// fake home, so the developer's real ~/.zshrc never runs in the tests.
private func withTemporaryFolder<Result>(_ body: (URL) throws -> Result) throws -> Result {
    let folder = FileManager.default.temporaryDirectory
        .appending(path: "TerminalKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    return try body(folder)
}

private func permissions(of url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return try #require(attributes[.posixPermissions] as? Int)
}

/// Runs a real zsh with the app's ZDOTDIR and a fake HOME, and returns what
/// `command` prints.
private func runZsh(
    _ command: String,
    interactive: Bool,
    integration: URL,
    home: URL
) throws -> String {
    let process = Process()
    process.executableURL = URL(filePath: "/bin/zsh")
    process.arguments = (interactive ? ["-i"] : []) + ["-c", command]
    process.environment = [
        "HOME": home.path,
        "ZDOTDIR": integration.path,
        "PATH": "/usr/bin:/bin",
        "TERM": "dumb",
    ]
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

// MARK: - Installing the scripts

@Test func installWritesBothScriptsWithRestrictedPermissions() throws {
    try withTemporaryFolder { root in
        let appFolder = root.appending(path: "FlagCompanion")
        let folder = try ShellIntegration.install(in: appFolder)
        #expect(folder == appFolder.appending(path: "zsh", directoryHint: .isDirectory))
        #expect(try permissions(of: appFolder) == 0o700)
        #expect(try permissions(of: folder) == 0o700)
        #expect(try permissions(of: folder.appending(path: ".zshenv")) == 0o600)
        #expect(try permissions(of: folder.appending(path: "hooks.zsh")) == 0o600)
    }
}

@Test func installRestrictsAnAppFolderCreatedEarlier() throws {
    try withTemporaryFolder { root in
        // Versions before this fix left the app's folder at 0755.
        let appFolder = root.appending(path: "FlagCompanion")
        try FileManager.default.createDirectory(
            at: appFolder, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o755])

        try ShellIntegration.install(in: appFolder)

        #expect(try permissions(of: appFolder) == 0o700)
    }
}

@Test func installingAgainRestoresAnEditedScript() throws {
    try withTemporaryFolder { root in
        let folder = try ShellIntegration.install(in: root.appending(path: "FlagCompanion"))
        let hooks = folder.appending(path: "hooks.zsh")
        try Data("echo edited\n".utf8).write(to: hooks)

        try ShellIntegration.install(in: root.appending(path: "FlagCompanion"))

        #expect(try String(contentsOf: hooks, encoding: .utf8) == ShellIntegration.hooks)
    }
}

// MARK: - A real zsh started from the app's folder

@Test func zshKeepsTheUsersHistoryFile() throws {
    try withTemporaryFolder { root in
        let integration = try ShellIntegration.install(in: root.appending(path: "FlagCompanion"))
        let home = root.appending(path: "home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

        let output = try runZsh(
            "print -r -- $HISTFILE", interactive: true, integration: integration, home: home)

        #expect(output == home.appending(path: ".zsh_history").path + "\n")
    }
}

@Test func zshLoadsTheUsersZshenv() throws {
    try withTemporaryFolder { root in
        let integration = try ShellIntegration.install(in: root.appending(path: "FlagCompanion"))
        let home = root.appending(path: "home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try Data("USER_ZSHENV=loaded\n".utf8).write(to: home.appending(path: ".zshenv"))

        let output = try runZsh(
            "print -r -- $USER_ZSHENV", interactive: false, integration: integration, home: home)

        #expect(output == "loaded\n")
    }
}

@Test func interactiveZshRegistersTheHooks() throws {
    try withTemporaryFolder { root in
        let integration = try ShellIntegration.install(in: root.appending(path: "FlagCompanion"))
        let home = root.appending(path: "home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

        let output = try runZsh(
            "print -r -- $precmd_functions / $preexec_functions",
            interactive: true, integration: integration, home: home)

        #expect(output == "_fc_status _fc_prompt / _fc_preexec\n")
    }
}

@Test func preexecSendsTheCommandURLEscapedInsideOSC133C() throws {
    try withTemporaryFolder { root in
        let integration = try ShellIntegration.install(in: root.appending(path: "FlagCompanion"))
        let home = root.appending(path: "home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

        // Accent, ";", newline, ESC and BEL: none may reach the OSC unescaped,
        // or the command could end the marker early.
        let output = try runZsh(
            #"_fc_preexec $'echo \'á\' ; nc host 1337\n\e]0;x\a'"#,
            interactive: true, integration: integration, home: home)

        let prefix = "\u{1B}]133;C;cmdline_url="
        #expect(output.hasPrefix(prefix))
        #expect(output.hasSuffix("\u{07}"))
        let payload = output.dropFirst(prefix.count).dropLast()
        #expect(payload.allSatisfy { $0.isASCII && $0 != ";" && !$0.isNewline })
        #expect(payload.removingPercentEncoding == "echo 'á' ; nc host 1337\n\u{1B}]0;x\u{07}")
    }
}

@Test func scriptsRunWithoutTheHooks() throws {
    try withTemporaryFolder { root in
        let integration = try ShellIntegration.install(in: root.appending(path: "FlagCompanion"))
        let home = root.appending(path: "home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try Data("USER_ZSHENV=loaded\n".utf8).write(to: home.appending(path: ".zshenv"))

        let output = try runZsh(
            "print -r -- ${+functions[_fc_status]} $USER_ZSHENV",
            interactive: false, integration: integration, home: home)

        // "loaded" proves the app's .zshenv ran to the end, so the missing hooks
        // mean it skipped them on purpose, not that it broke before reaching them.
        #expect(output == "0 loaded\n")
    }
}
