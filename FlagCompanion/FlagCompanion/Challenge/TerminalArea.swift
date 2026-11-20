import SwiftUI
import TerminalKit

/// The tab bar and the terminals below it. Every terminal stays in the view
/// hierarchy and only the selected one is visible, so programs keep running and
/// keep their screen when another tab is shown.
struct TerminalArea: View {
    let workspace: ChallengeWorkspace

    var body: some View {
        VStack(spacing: 0) {
            TerminalTabBar(workspace: workspace)
            Divider()
            ZStack {
                ForEach(workspace.tabs) { tab in
                    TerminalHost(
                        terminal: tab.terminal, isActive: tab.id == workspace.selectedTabID)
                }
                if workspace.tabs.isEmpty {
                    NoTerminalsView(workspace: workspace)
                }
            }
        }
    }
}

private struct NoTerminalsView: View {
    let workspace: ChallengeWorkspace

    var body: some View {
        ContentUnavailableView {
            Label("No Terminals", systemImage: "terminal")
        } actions: {
            Button("New Tab") { workspace.openTab() }
        }
    }
}

/// Puts a terminal's AppKit view into SwiftUI and gives it keyboard focus
/// when its tab becomes the selected one.
private struct TerminalHost: NSViewRepresentable {
    let terminal: any TerminalEmulating
    let isActive: Bool

    func makeNSView(context: Context) -> NSView {
        terminal.view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.isHidden = !isActive
        guard isActive, !context.coordinator.wasActive else {
            context.coordinator.wasActive = isActive
            return
        }
        context.coordinator.wasActive = true
        // The view may not be in a window yet on the first update; focus on the next turn.
        DispatchQueue.main.async { terminal.focus() }
    }

    func makeCoordinator() -> FocusTracker { FocusTracker() }

    final class FocusTracker {
        var wasActive = false
    }
}
