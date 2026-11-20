import AppKit
import SwiftTerm

/// `TerminalEmulating` backed by SwiftTerm's `LocalProcessTerminalView`, which
/// creates the pseudo-terminal, runs the shell and draws its output.
///
/// ```swift
/// let terminal = SwiftTermTerminal()
/// terminal.start(ShellLaunch.login(shell: UserShell.path(), in: filesFolder))
/// ```
@MainActor
public final class SwiftTermTerminal: TerminalEmulating {
    private let terminalView = LocalProcessTerminalView(frame: .zero)
    private let processEvents = ProcessEvents()

    public var onExit: (() -> Void)?
    public var view: NSView { terminalView }

    public init(fontSize: CGFloat = 13) {
        terminalView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        // Text colors follow the system appearance, so the terminal matches light and dark mode.
        terminalView.nativeBackgroundColor = .textBackgroundColor
        terminalView.nativeForegroundColor = .textColor
        terminalView.processDelegate = processEvents
        processEvents.onTerminated = { [weak self] in self?.onExit?() }
    }

    public var hasRunningCommand: Bool {
        guard let process = terminalView.process, process.running, process.childfd >= 0 else {
            return false
        }
        // The terminal's foreground process group is the shell itself while it waits at
        // the prompt, and the running program's group while a command runs.
        let foregroundGroup = tcgetpgrp(process.childfd)
        return foregroundGroup > 0 && foregroundGroup != process.shellPid
    }

    public func start(_ launch: ShellLaunch) {
        terminalView.startProcess(
            executable: launch.executable,
            args: [],
            environment: launch.environment,
            execName: launch.processName,
            currentDirectory: launch.currentDirectory
        )
    }

    public func terminate() {
        processEvents.onTerminated = nil
        terminalView.process?.terminate()
    }

    public func focus() {
        terminalView.window?.makeFirstResponder(terminalView)
    }
}

/// Receives SwiftTerm's process callbacks, which arrive on the main queue.
@MainActor
private final class ProcessEvents: @preconcurrency LocalProcessTerminalViewDelegate {
    var onTerminated: (() -> Void)?

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        onTerminated?()
        onTerminated = nil
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
