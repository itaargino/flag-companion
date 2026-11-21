import Foundation

/// The zsh scripts that make the shell report each command to the app with
/// invisible OSC markers, installed in a folder that `ZDOTDIR` points to.
///
/// The app writes them again on every launch, so a new version of the app
/// always runs its own hooks and a deleted or edited script is repaired.
///
/// ```swift
/// let folder = try ShellIntegration.install(in: ShellIntegration.appFolder)
/// ```
public enum ShellIntegration {
    /// `~/Library/Application Support/FlagCompanion/`, the app's own folder.
    public static var appFolder: URL {
        URL.applicationSupportDirectory.appending(path: "FlagCompanion", directoryHint: .isDirectory)
    }

    static let folderPermissions = 0o700
    static let filePermissions = 0o600

    /// Writes `.zshenv` and `hooks.zsh` into `zsh/` inside `appFolder`, and
    /// returns that `zsh/` folder so it can be passed to `ShellLaunch`.
    @discardableResult
    public static func install(in appFolder: URL) throws -> URL {
        let folder = appFolder.appending(path: "zsh", directoryHint: .isDirectory)
        try restrictedFolder(appFolder)
        try restrictedFolder(folder)
        try write(zshenv, to: folder.appending(path: ".zshenv"))
        try write(hooks, to: folder.appending(path: "hooks.zsh"))
        return folder
    }

    /// Creates the folder when needed and sets it to `0700`. createDirectory
    /// leaves an existing folder as it was, so the permissions are applied every
    /// time, which also fixes folders left at `0755` by earlier versions.
    private static func restrictedFolder(_ folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.posixPermissions: folderPermissions], ofItemAtPath: folder.path)
    }

    private static func write(_ script: String, to file: URL) throws {
        try Data(script.utf8).write(to: file, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: filePermissions], ofItemAtPath: file.path)
    }

    /// The only startup file read from the app's folder. It hands `ZDOTDIR`
    /// back to the user right away, so zsh reads their `.zprofile`, `.zshrc`
    /// and `.zlogin` and keeps their `HISTFILE` (see the E5 spike).
    static let zshenv = """
        # Written by Flag Companion on every launch. Edits here are overwritten.
        _fc_dir="$ZDOTDIR"
        ZDOTDIR="${FC_USER_ZDOTDIR:-$HOME}"
        unset FC_USER_ZDOTDIR
        [[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
        [[ -o interactive ]] && source "$_fc_dir/hooks.zsh"
        unset _fc_dir

        """

    /// The hooks from the spec ("Terminal capture", step 3).
    static let hooks = #"""
        # Written by Flag Companion on every launch. Edits here are overwritten.
        _fc_status() {
          local ec=$?
          printf '\e]133;D;%s\a' "$ec"
          # Keep _fc_status first, to read $? before any other hook, and
          # _fc_prompt last, to run after any theme has rebuilt PS1.
          precmd_functions=(_fc_status ${precmd_functions:#_fc_(status|prompt)} _fc_prompt)
        }
        _fc_prompt() {
          printf '\e]7;file://%s%s\a' "$HOST" "$PWD"
          printf '\e]133;A\a'
          [[ $PS1 == *$'\e]133;B'* ]] || PS1="$PS1%{"$'\e]133;B\a'"%}"
        }
        # Byte -> %XX table, built once, so encoding a long command takes
        # milliseconds instead of one printf per character.
        typeset -gA _fc_hex
        () {
          emulate -L zsh
          setopt no_multibyte
          local -i b
          local hex
          for (( b = 1; b < 256; b++ )); do
            printf -v hex '%%%02X' $b
            _fc_hex[${(#)b}]=$hex
          done
        }
        # URL-escapes $1 into REPLY, byte by byte, so the command can never
        # contain ESC, BEL or ";" and end the OSC early.
        _fc_urlencode() {
          emulate -L zsh
          setopt no_multibyte extended_glob
          REPLY=${1//(#m)[^A-Za-z0-9._~\/-]/$_fc_hex[$MATCH]}
        }
        _fc_preexec() {
          local REPLY
          _fc_urlencode "$1"
          printf '\e]133;C;cmdline_url=%s\a' "$REPLY"
        }
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd _fc_status
        add-zsh-hook precmd _fc_prompt
        add-zsh-hook preexec _fc_preexec

        """#
}
