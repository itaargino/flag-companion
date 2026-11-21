import Foundation
import TerminalKit

/// The app's zsh scripts, installed once per launch the first time a terminal
/// opens. Installing again on every launch keeps them in step with this
/// version of the app.
enum InstalledShellIntegration {
    /// The folder to pass as `ZDOTDIR`, or nil when the scripts could not be
    /// written. Terminals then still open, only without markers, because a
    /// recording problem must never keep the user from their shell.
    static let folder: URL? = try? ShellIntegration.install(in: ShellIntegration.appFolder)
}
