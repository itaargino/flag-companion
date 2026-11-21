import Foundation

/// The login shell of the current user, read from the user database.
///
/// ```swift
/// let shell = UserShell.path() // "/bin/zsh"
/// ```
public enum UserShell {
    public static let fallback = "/bin/zsh"

    /// Apps opened from Finder or the Dock do not always get `$SHELL`, so the
    /// shell comes from the user database, falling back to zsh.
    public static func path() -> String {
        guard let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell else {
            return fallback
        }
        let path = String(cString: shell)
        return FileManager.default.isExecutableFile(atPath: path) ? path : fallback
    }
}
