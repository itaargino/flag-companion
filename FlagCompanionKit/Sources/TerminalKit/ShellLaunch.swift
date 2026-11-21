import Foundation

/// Everything needed to start a shell in a terminal: which program, the name
/// it sees in `argv[0]`, its environment and its current directory.
///
/// ```swift
/// let launch = ShellLaunch.login(shell: "/bin/zsh", in: filesFolder)
/// print(launch.processName) // "-zsh"
/// ```
public struct ShellLaunch: Equatable, Sendable {
    public let executable: String
    public let processName: String
    public let environment: [String]
    public let currentDirectory: String

    /// Variables copied from the app into the shell. Everything else is left out,
    /// because an app launched from Xcode carries debugger variables (DYLD_*,
    /// __XPC_*) that would leak into every program run in the terminal.
    public static let inheritedVariables = [
        "HOME", "USER", "LOGNAME", "PATH", "TMPDIR", "SSH_AUTH_SOCK", "LANG", "LC_ALL",
        "LC_CTYPE",
    ]

    /// Starts `shell` as a login shell, like macOS Terminal does, so `/etc/zprofile`
    /// and `~/.zprofile` run and tools installed with Homebrew are on the PATH.
    ///
    /// When `integration` is the folder from `ShellIntegration.install` and the
    /// shell is zsh, zsh starts from that folder and loads the app's hooks.
    /// Other shells ignore it and run without markers.
    public static func login(
        shell: String,
        in directory: URL,
        integration: URL? = nil,
        appEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ShellLaunch {
        let shellName = URL(filePath: shell).lastPathComponent
        return ShellLaunch(
            executable: shell,
            // A leading hyphen in argv[0] is the Unix convention for "login shell".
            processName: "-" + shellName,
            environment: shellEnvironment(
                shell: shell,
                integration: shellName == "zsh" ? integration : nil,
                appEnvironment: appEnvironment
            ),
            currentDirectory: directory.path
        )
    }

    static func shellEnvironment(
        shell: String,
        integration: URL?,
        appEnvironment: [String: String]
    ) -> [String] {
        var variables = appEnvironment.filter { inheritedVariables.contains($0.key) }
        if let integration {
            variables["ZDOTDIR"] = integration.path
            // The app's .zshenv hands ZDOTDIR back to this value, or to HOME without one.
            variables["FC_USER_ZDOTDIR"] = appEnvironment["ZDOTDIR"]
        }
        variables["TERM"] = "xterm-256color"
        variables["COLORTERM"] = "truecolor"
        variables["TERM_PROGRAM"] = "FlagCompanion"
        variables["SHELL"] = shell
        // Without a UTF-8 locale, vim and other tools print accented text as escapes.
        variables["LANG"] = variables["LANG"] ?? "en_US.UTF-8"
        return variables.map { "\($0.key)=\($0.value)" }.sorted()
    }
}
