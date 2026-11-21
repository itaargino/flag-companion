import Foundation

/// One of the invisible markers the app's zsh hooks print, read from the text
/// of an OSC sequence (see the spec, "Terminal capture").
///
/// ```swift
/// ShellMarker(oscPayload: Array("133;D;1".utf8)) // .commandEnd(exitCode: 1)
/// ```
public enum ShellMarker: Equatable, Sendable {
    /// `OSC 133;A`: the prompt is about to be drawn.
    case promptStart
    /// `OSC 133;B`: the prompt ended. Missing with Powerlevel10k, so the
    /// parser never depends on it.
    case promptEnd
    /// `OSC 133;C`: a command was confirmed and its output starts. The text is
    /// empty when the marker has no `cmdline_url`.
    case commandStart(command: String)
    /// `OSC 133;D`: the command finished. `nil` when no number was sent.
    case commandEnd(exitCode: Int?)
    /// `OSC 7`: the shell's current directory.
    case currentDirectory(path: String)
}

extension ShellMarker {
    /// Reads the bytes between `ESC ]` and the terminator. Returns `nil` for
    /// any OSC that is not one of the app's markers, such as a window title.
    public init?(oscPayload: [UInt8]) {
        let text = String(decoding: oscPayload, as: UTF8.self)
        let fields = text.split(separator: ";", omittingEmptySubsequences: false)
        switch fields.first {
        case "133": self.init(semanticPrompt: fields.dropFirst())
        case "7": self.init(directoryURL: text.dropFirst(2))
        default: return nil
        }
    }

    private init?(semanticPrompt fields: ArraySlice<Substring>) {
        switch fields.first {
        case "A": self = .promptStart
        case "B": self = .promptEnd
        case "C": self = .commandStart(command: Self.commandLine(in: fields.dropFirst()))
        case "D": self = .commandEnd(exitCode: fields.dropFirst().first.flatMap { Int($0) })
        default: return nil
        }
    }

    /// The `cmdline_url=` parameter, URL-decoded. Text that is not valid
    /// percent-encoded UTF-8 is kept as sent rather than lost.
    private static func commandLine(in parameters: ArraySlice<Substring>) -> String {
        let key = "cmdline_url="
        guard let parameter = parameters.first(where: { $0.hasPrefix(key) }) else { return "" }
        let escaped = parameter.dropFirst(key.count)
        return escaped.removingPercentEncoding ?? String(escaped)
    }

    /// `file://<host><path>`: the hook prints `$PWD` as it is, so the path
    /// is everything from the first `/` after the host.
    private init?(directoryURL text: Substring) {
        let scheme = "file://"
        guard text.hasPrefix(scheme) else { return nil }
        let hostAndPath = text.dropFirst(scheme.count)
        guard let slash = hostAndPath.firstIndex(of: "/") else { return nil }
        self = .currentDirectory(path: String(hostAndPath[slash...]))
    }
}
