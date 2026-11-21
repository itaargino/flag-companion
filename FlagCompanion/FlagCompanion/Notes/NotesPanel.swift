import AppKit
import SwiftUI

/// The notes column: note tabs on top, then the editor or its preview.
struct NotesPanel: View {
    @Bindable var notes: NotesModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            NoteTabBar(notes: notes)
            Divider()
            if notes.isPreviewing {
                MarkdownPreview(markdown: notes.text)
            } else {
                TextEditor(text: $notes.text)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
        }
        .onAppear { notes.load() }
        .onDisappear { notes.saveNow() }
        // Save before leaving the app and reread on return, so edits in Obsidian show up.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { notes.reloadFromDisk() } else { notes.saveNow() }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
            notes.saveNow()
        }
        .alert("Could Not Update Notes", isPresented: failureBinding) {
        } message: {
            Text(notes.failureMessage ?? "")
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { notes.failureMessage != nil },
            set: { if !$0 { notes.failureMessage = nil } }
        )
    }
}

private struct MarkdownPreview: View {
    let markdown: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(MarkdownBlocks.parse(markdown).enumerated()), id: \.offset) {
                    _, block in
                    MarkdownBlockView(block: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .textSelection(.enabled)
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(inlineMarkdown(text)).font(level == 1 ? .title2 : level == 2 ? .title3 : .headline)
        case .code(let code):
            Text(code)
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        case .paragraph(let text):
            Text(inlineMarkdown(text))
        }
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
