import AppKit

/// A terminal the app can embed: a view that runs a shell in a pseudo-terminal.
/// The app depends on this protocol, never on SwiftTerm directly, so the
/// emulator can be swapped or faked in tests.
///
/// ```swift
/// let terminal: TerminalEmulating = SwiftTermTerminal()
/// terminal.onExit = { print("shell exited") }
/// terminal.start(ShellLaunch.login(shell: "/bin/zsh", in: filesFolder))
/// ```
@MainActor
public protocol TerminalEmulating: AnyObject {
    /// The view that draws the terminal and receives keyboard input.
    var view: NSView { get }

    /// True while a program other than the shell itself is in the foreground,
    /// for example `vim` or a long `nmap`, so closing the tab would kill it.
    var hasRunningCommand: Bool { get }

    /// Called once when the shell process exits, for example after `exit`.
    var onExit: (() -> Void)? { get set }

    func start(_ launch: ShellLaunch)

    /// Ends the shell and every program it started.
    func terminate()

    /// Makes the terminal receive keyboard input.
    func focus()
}
