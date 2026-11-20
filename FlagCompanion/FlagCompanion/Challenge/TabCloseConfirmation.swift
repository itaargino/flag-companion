import AppKit

/// Asks before closing a tab whose terminal is still running a program.
enum TabCloseConfirmation {
    static func ask(for tab: TerminalTab) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Close “\(tab.name)”?"
        alert.informativeText =
            "A program is still running in this tab. Closing it will stop the program."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close Tab")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
