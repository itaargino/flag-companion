import SwiftUI

/// Note tabs (Context, Findings and custom ones), a + button for a new tab and
/// a toggle between the editor and the preview. Custom tabs are renamed or
/// removed from their context menu.
struct NoteTabBar: View {
    let notes: NotesModel
    @State private var prompt: NoteTabPrompt?
    @State private var typedName = ""
    @State private var tabToRemove: String?

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(notes.tabs, id: \.self) { tab in
                        NoteTabButton(
                            tab: tab, notes: notes, prompt: $prompt, typedName: $typedName,
                            tabToRemove: $tabToRemove)
                    }
                }
            }
            Button("New Note Tab", systemImage: "plus") {
                typedName = ""
                prompt = .add
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("New note tab")
            PreviewToggle(notes: notes)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
        .alert(prompt?.title ?? "", isPresented: promptBinding, presenting: prompt) { shown in
            TextField("Name", text: $typedName)
            Button(shown.actionTitle) { apply(shown) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Move “\(tabToRemove ?? "")” to the Trash?", isPresented: removalBinding,
            presenting: tabToRemove
        ) { tab in
            Button("Move to Trash", role: .destructive) { notes.removeTab(tab) }
        } message: { _ in
            Text("The tab’s note file goes to the Trash, where you can still recover it.")
        }
    }

    private func apply(_ shown: NoteTabPrompt) {
        switch shown {
        case .add: notes.addTab(named: typedName)
        case .rename(let tab): notes.renameTab(tab, to: typedName)
        }
    }

    private var promptBinding: Binding<Bool> {
        Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })
    }

    private var removalBinding: Binding<Bool> {
        Binding(get: { tabToRemove != nil }, set: { if !$0 { tabToRemove = nil } })
    }
}

/// The name prompt shown by the tab bar: creating a tab or renaming one.
enum NoteTabPrompt: Hashable {
    case add
    case rename(String)

    var title: String {
        switch self {
        case .add: "New Note Tab"
        case .rename(let tab): "Rename “\(tab)”"
        }
    }

    var actionTitle: String {
        switch self {
        case .add: "Create"
        case .rename: "Rename"
        }
    }
}

private struct NoteTabButton: View {
    let tab: String
    let notes: NotesModel
    @Binding var prompt: NoteTabPrompt?
    @Binding var typedName: String
    @Binding var tabToRemove: String?

    var body: some View {
        Button(tab.capitalized) { notes.select(tab) }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                notes.selectedTab == tab
                    ? AnyShapeStyle(.selection.opacity(0.35)) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contextMenu {
                if notes.isCustomTab(tab) {
                    Button("Rename…") {
                        typedName = tab
                        prompt = .rename(tab)
                    }
                    Button("Move to Trash…", role: .destructive) { tabToRemove = tab }
                }
            }
    }
}

private struct PreviewToggle: View {
    @Bindable var notes: NotesModel

    var body: some View {
        Toggle(isOn: $notes.isPreviewing) {
            Label("Preview", systemImage: notes.isPreviewing ? "eye.fill" : "eye")
        }
        .toggleStyle(.button)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help(notes.isPreviewing ? "Edit note" : "Preview note")
    }
}
