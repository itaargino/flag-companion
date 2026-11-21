import ChallengeLibrary
import Foundation
import Observation
import TerminalKit

/// One terminal tab in a challenge window. The name is editable; the number
/// stays fixed, because the spec names log files `t<N>-<name>.jsonl`.
@Observable
final class TerminalTab: Identifiable {
    let id = UUID()
    let number: Int
    var name: String
    let terminal: any TerminalEmulating

    init(number: Int, terminal: any TerminalEmulating) {
        self.number = number
        self.name = "Terminal \(number)"
        self.terminal = terminal
    }
}

/// The terminals of one open challenge. Every tab runs a login shell in the
/// challenge's `files/` folder and keeps running while other tabs are shown.
///
/// ```swift
/// let workspace = ChallengeWorkspace(challengeFolder: folder)
/// workspace.openTab()
/// ```
@Observable
final class ChallengeWorkspace {
    let challengeFolder: URL
    private(set) var tabs: [TerminalTab] = []
    var selectedTabID: TerminalTab.ID?
    /// Set when the user goes back to the library; the window then closes itself.
    private(set) var isLeaving = false

    @ObservationIgnored private var nextTabNumber = 1
    @ObservationIgnored private let shell: String
    @ObservationIgnored private let shellIntegration: URL?
    @ObservationIgnored private let makeTerminal: @MainActor () -> any TerminalEmulating
    @ObservationIgnored private let confirmClosingRunningTab: @MainActor (TerminalTab) -> Bool

    init(
        challengeFolder: URL,
        shell: String = UserShell.path(),
        shellIntegration: URL? = InstalledShellIntegration.folder,
        makeTerminal: @escaping @MainActor () -> any TerminalEmulating = { SwiftTermTerminal() },
        confirmClosingRunningTab: @escaping @MainActor (TerminalTab) -> Bool = TabCloseConfirmation
            .ask
    ) {
        self.challengeFolder = challengeFolder
        self.shell = shell
        self.shellIntegration = shellIntegration
        self.makeTerminal = makeTerminal
        self.confirmClosingRunningTab = confirmClosingRunningTab
    }

    var filesFolder: URL {
        challengeFolder.appending(
            path: ChallengeSubfolder.files.rawValue, directoryHint: .isDirectory)
    }

    var selectedTab: TerminalTab? { tabs.first { $0.id == selectedTabID } }

    func openTab() {
        let tab = TerminalTab(number: nextTabNumber, terminal: makeTerminal())
        nextTabNumber += 1
        // `exit` in the shell closes its tab, like macOS Terminal.
        tab.terminal.onExit = { [weak self, weak tab] in
            if let tab { self?.remove(tab) }
        }
        tab.terminal.start(
            ShellLaunch.login(shell: shell, in: filesFolder, integration: shellIntegration))
        tabs.append(tab)
        selectedTabID = tab.id
    }

    /// Closes the tab, asking first when a program is still running in it.
    func requestClose(_ tab: TerminalTab) {
        if tab.terminal.hasRunningCommand && !confirmClosingRunningTab(tab) { return }
        tab.terminal.terminate()
        remove(tab)
    }

    func requestCloseSelectedTab() {
        if let selectedTab { requestClose(selectedTab) }
    }

    /// Selects the tab at a zero-based position, as ⌘1 to ⌘9 do. ⌘9 always
    /// means the last tab, following macOS conventions.
    func selectTab(atPosition position: Int) {
        guard !tabs.isEmpty else { return }
        let index = position >= 8 ? tabs.count - 1 : position
        guard tabs.indices.contains(index) else { return }
        selectedTabID = tabs[index].id
    }

    /// Goes back to the library and closes this window (the Library button, ⌘[).
    /// Each tab still running a program asks first; cancelling one keeps the window.
    func requestLeave() {
        for tab in tabs where tab.terminal.hasRunningCommand {
            guard confirmClosingRunningTab(tab) else { return }
        }
        isLeaving = true
    }

    /// Ends every shell, for example when the window closes.
    func closeAllTabs() {
        for tab in tabs { tab.terminal.terminate() }
        tabs.removeAll()
        selectedTabID = nil
    }

    private func remove(_ tab: TerminalTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: index)
        guard selectedTabID == tab.id else { return }
        selectedTabID = tabs.isEmpty ? nil : tabs[min(index, tabs.count - 1)].id
    }
}
