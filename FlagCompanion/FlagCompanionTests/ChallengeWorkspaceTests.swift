import AppKit
import Foundation
import TerminalKit
import Testing

@testable import FlagCompanion

/// Records what the workspace asks of a terminal, without starting a shell.
@MainActor
private final class FakeTerminal: TerminalEmulating {
    let view = NSView()
    var hasRunningCommand = false
    var onExit: (() -> Void)?
    private(set) var startedLaunch: ShellLaunch?
    private(set) var wasTerminated = false

    func start(_ launch: ShellLaunch) { startedLaunch = launch }
    func terminate() { wasTerminated = true }
    func focus() {}
}

private let challengeFolder = URL(filePath: "/tmp/CTFs/pico/enc", directoryHint: .isDirectory)

// Never the real folder in Application Support: tests must not write outside their own files.
private let shellIntegration = URL(filePath: "/tmp/FlagCompanion/zsh", directoryHint: .isDirectory)

@MainActor
private final class WorkspaceFixture {
    private(set) var terminals: [FakeTerminal] = []
    private(set) var confirmations = 0
    var userConfirmsClose = false
    private(set) lazy var workspace = ChallengeWorkspace(
        challengeFolder: challengeFolder,
        shell: "/bin/zsh",
        shellIntegration: shellIntegration,
        makeTerminal: { [unowned self] in
            let terminal = FakeTerminal()
            terminals.append(terminal)
            return terminal
        },
        confirmClosingRunningTab: { [unowned self] _ in
            confirmations += 1
            return userConfirmsClose
        }
    )

    func openTabs(_ count: Int) {
        for _ in 0..<count { workspace.openTab() }
    }
}

@MainActor
@Test func newTabStartsLoginShellInFilesFolderAndIsSelected() throws {
    let fixture = WorkspaceFixture()
    fixture.openTabs(2)
    let launch = try #require(fixture.terminals[1].startedLaunch)
    #expect(launch.currentDirectory == "/tmp/CTFs/pico/enc/files")
    #expect(launch.processName == "-zsh")
    #expect(fixture.workspace.selectedTab?.name == "Terminal 2")
}

@MainActor
@Test func newTabStartsZshFromTheIntegrationFolder() throws {
    let fixture = WorkspaceFixture()
    fixture.openTabs(1)
    let launch = try #require(fixture.terminals[0].startedLaunch)
    #expect(launch.environment.contains("ZDOTDIR=/tmp/FlagCompanion/zsh"))
}

@MainActor
@Test func closingSelectedTabSelectsItsNeighbour() {
    let fixture = WorkspaceFixture()
    fixture.openTabs(3)
    fixture.workspace.selectTab(atPosition: 1)
    fixture.workspace.requestCloseSelectedTab()
    #expect(fixture.terminals[1].wasTerminated)
    #expect(fixture.workspace.tabs.map(\.number) == [1, 3])
    #expect(fixture.workspace.selectedTab?.number == 3)
}

@MainActor
@Test func runningTabAsksBeforeClosingAndStaysWhenCancelled() {
    let fixture = WorkspaceFixture()
    fixture.openTabs(1)
    fixture.terminals[0].hasRunningCommand = true
    fixture.workspace.requestCloseSelectedTab()
    #expect(fixture.confirmations == 1)
    #expect(fixture.workspace.tabs.count == 1)
    #expect(!fixture.terminals[0].wasTerminated)
}

@MainActor
@Test func idleTabClosesWithoutAsking() {
    let fixture = WorkspaceFixture()
    fixture.openTabs(1)
    fixture.workspace.requestCloseSelectedTab()
    #expect(fixture.confirmations == 0)
    #expect(fixture.workspace.tabs.isEmpty)
    #expect(fixture.workspace.selectedTabID == nil)
}

@MainActor
@Test func shellExitRemovesItsTab() {
    let fixture = WorkspaceFixture()
    fixture.openTabs(2)
    fixture.terminals[0].onExit?()
    #expect(fixture.workspace.tabs.map(\.number) == [2])
}

@MainActor
@Test func commandNineSelectsLastTab() {
    let fixture = WorkspaceFixture()
    fixture.openTabs(3)
    fixture.workspace.selectTab(atPosition: 0)
    fixture.workspace.selectTab(atPosition: 8)
    #expect(fixture.workspace.selectedTab?.number == 3)
    fixture.workspace.selectTab(atPosition: 5)
    #expect(fixture.workspace.selectedTab?.number == 3)
}

@MainActor
@Test func closingWindowEndsEveryShell() {
    let fixture = WorkspaceFixture()
    fixture.openTabs(2)
    fixture.workspace.closeAllTabs()
    #expect(fixture.terminals.allSatisfy { $0.wasTerminated })
    #expect(fixture.workspace.tabs.isEmpty)
}

@MainActor
@Test func leavingWithIdleTabsDoesNotAsk() {
    let fixture = WorkspaceFixture()
    fixture.openTabs(2)
    fixture.workspace.requestLeave()
    #expect(fixture.confirmations == 0)
    #expect(fixture.workspace.isLeaving)
}

@MainActor
@Test func leavingIsCancelledWhenARunningTabIsKept() {
    let fixture = WorkspaceFixture()
    fixture.openTabs(2)
    fixture.terminals[1].hasRunningCommand = true
    fixture.workspace.requestLeave()
    #expect(fixture.confirmations == 1)
    #expect(!fixture.workspace.isLeaving)
    #expect(fixture.workspace.tabs.count == 2)
}
