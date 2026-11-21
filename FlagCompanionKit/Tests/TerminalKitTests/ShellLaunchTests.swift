import Foundation
import Testing

@testable import TerminalKit

private let filesFolder = URL(
    filePath: "/Users/me/CTFs/pico/enc/files", directoryHint: .isDirectory)

private let appEnvironment = [
    "HOME": "/Users/me",
    "PATH": "/usr/bin:/bin",
    "DYLD_INSERT_LIBRARIES": "/Xcode/libViewDebug.dylib",
    "__XPC_SERVICE_NAME": "xcode",
]

private func variables(of launch: ShellLaunch) -> [String: String] {
    Dictionary(
        uniqueKeysWithValues: launch.environment.map { entry in
            let parts = entry.split(separator: "=", maxSplits: 1)
            return (String(parts[0]), String(parts[1]))
        })
}

@Test func loginShellRunsInFilesFolderWithHyphenatedName() {
    let launch = ShellLaunch.login(shell: "/bin/zsh", in: filesFolder, appEnvironment: [:])
    #expect(launch.executable == "/bin/zsh")
    #expect(launch.processName == "-zsh")
    #expect(launch.currentDirectory == "/Users/me/CTFs/pico/enc/files")
}

@Test func environmentKeepsUserVariablesAndDropsDebuggerOnes() {
    let launch = ShellLaunch.login(
        shell: "/bin/zsh", in: filesFolder, appEnvironment: appEnvironment)
    let shellVariables = variables(of: launch)
    #expect(shellVariables["HOME"] == "/Users/me")
    #expect(shellVariables["PATH"] == "/usr/bin:/bin")
    #expect(shellVariables["DYLD_INSERT_LIBRARIES"] == nil)
    #expect(shellVariables["__XPC_SERVICE_NAME"] == nil)
}

@Test func environmentDescribesTheTerminal() {
    let launch = ShellLaunch.login(
        shell: "/opt/homebrew/bin/zsh", in: filesFolder, appEnvironment: [:])
    let shellVariables = variables(of: launch)
    #expect(shellVariables["TERM"] == "xterm-256color")
    #expect(shellVariables["COLORTERM"] == "truecolor")
    #expect(shellVariables["SHELL"] == "/opt/homebrew/bin/zsh")
    #expect(shellVariables["LANG"] == "en_US.UTF-8")
}

@Test func existingLanguageIsKept() {
    let launch = ShellLaunch.login(
        shell: "/bin/zsh", in: filesFolder, appEnvironment: ["LANG": "pt_BR.UTF-8"])
    #expect(variables(of: launch)["LANG"] == "pt_BR.UTF-8")
}

private let integrationFolder = URL(
    filePath: "/Users/me/Library/Application Support/FlagCompanion/zsh",
    directoryHint: .isDirectory)

@Test func zshStartsFromTheIntegrationFolder() {
    let launch = ShellLaunch.login(
        shell: "/bin/zsh", in: filesFolder, integration: integrationFolder, appEnvironment: [:])
    let shellVariables = variables(of: launch)
    #expect(shellVariables["ZDOTDIR"] == integrationFolder.path)
    #expect(shellVariables["FC_USER_ZDOTDIR"] == nil)
}

@Test func usersOwnZdotdirIsHandedToTheScripts() {
    let launch = ShellLaunch.login(
        shell: "/bin/zsh", in: filesFolder, integration: integrationFolder,
        appEnvironment: ["ZDOTDIR": "/Users/me/.config/zsh"])
    #expect(variables(of: launch)["FC_USER_ZDOTDIR"] == "/Users/me/.config/zsh")
}

@Test func withoutIntegrationZdotdirIsNotSet() {
    let launch = ShellLaunch.login(shell: "/bin/zsh", in: filesFolder, appEnvironment: [:])
    #expect(variables(of: launch)["ZDOTDIR"] == nil)
}

@Test func otherShellsIgnoreTheIntegration() {
    let launch = ShellLaunch.login(
        shell: "/bin/bash", in: filesFolder, integration: integrationFolder, appEnvironment: [:])
    #expect(variables(of: launch)["ZDOTDIR"] == nil)
}

@Test func userShellIsAnExecutable() {
    #expect(FileManager.default.isExecutableFile(atPath: UserShell.path()))
}
