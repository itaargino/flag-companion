import SwiftUI

/// The row of terminal tabs with a + button. Double-clicking a tab renames it.
struct TerminalTabBar: View {
    let workspace: ChallengeWorkspace

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(workspace.tabs) { tab in
                        TerminalTabButton(tab: tab, workspace: workspace)
                    }
                }
            }
            Button("New Tab", systemImage: "plus") { workspace.openTab() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("New Tab (⌘T)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

private struct TerminalTabButton: View {
    let tab: TerminalTab
    let workspace: ChallengeWorkspace
    @State private var isRenaming = false
    @State private var draftName = ""

    private var isSelected: Bool { workspace.selectedTabID == tab.id }

    var body: some View {
        HStack(spacing: 6) {
            TabTitle(tab: tab, isRenaming: $isRenaming, draftName: $draftName)
            Button("Close Tab", systemImage: "xmark") { workspace.requestClose(tab) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .imageScale(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isSelected ? AnyShapeStyle(.selection.opacity(0.35)) : AnyShapeStyle(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            draftName = tab.name
            isRenaming = true
        }
        .onTapGesture { workspace.selectedTabID = tab.id }
    }
}

private struct TabTitle: View {
    let tab: TerminalTab
    @Binding var isRenaming: Bool
    @Binding var draftName: String

    var body: some View {
        if isRenaming {
            TextField("Tab name", text: $draftName)
                .textFieldStyle(.plain)
                .frame(width: 110)
                .onSubmit(commitRename)
                .onExitCommand { isRenaming = false }
        } else {
            Text(tab.name).lineLimit(1)
        }
    }

    private func commitRename() {
        tab.name = TabName.renamed(tab.name, to: draftName)
        isRenaming = false
    }
}

/// Rules for renaming a tab: surrounding spaces are dropped and an empty name
/// keeps the old one.
nonisolated enum TabName {
    static func renamed(_ current: String, to typed: String) -> String {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? current : trimmed
    }
}
