import ChallengeLibrary
import SwiftUI

struct LibrarySheetView: View {
    let sheet: LibrarySheet
    let model: LibraryModel

    var body: some View {
        switch sheet {
        case .newCTF:
            NewCTFSheet(model: model)
        case .newChallenge(let ctfFolder):
            NewChallengeSheet(model: model, ctfFolder: ctfFolder ?? model.scan.ctfs.first?.folder)
        case .recordFlag(let challengeFolder):
            RecordFlagSheet(model: model, challengeFolder: challengeFolder)
        }
    }
}

private struct NewCTFSheet: View {
    let model: LibraryModel
    @State private var name = ""
    @State private var failureMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetForm(title: "New CTF", failureMessage: failureMessage, canCreate: !name.isBlank) {
            TextField("Name", text: $name, prompt: Text("picoCTF 2026"))
        } create: {
            failureMessage = model.createCTF(named: name)
            if failureMessage == nil { dismiss() }
        }
    }
}

private struct NewChallengeSheet: View {
    let model: LibraryModel
    @State private var draft: ChallengeDraft
    @State private var failureMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(model: LibraryModel, ctfFolder: URL?) {
        self.model = model
        _draft = State(initialValue: ChallengeDraft(ctfFolder: ctfFolder))
    }

    var body: some View {
        SheetForm(
            title: "New Challenge", failureMessage: failureMessage, canCreate: draft.isComplete
        ) {
            ChallengeDraftFields(draft: $draft, ctfs: model.scan.ctfs)
        } create: {
            failureMessage = model.createChallenge(from: draft)
            if failureMessage == nil { dismiss() }
        }
    }
}

private struct RecordFlagSheet: View {
    let model: LibraryModel
    let challengeFolder: URL
    @State private var flag: String
    @State private var failureMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(model: LibraryModel, challengeFolder: URL) {
        self.model = model
        self.challengeFolder = challengeFolder
        _flag = State(initialValue: model.challenge(at: challengeFolder)?.metadata.flag ?? "")
    }

    var body: some View {
        SheetForm(
            title: "Solved: \(model.challenge(at: challengeFolder)?.metadata.name ?? "")",
            actionTitle: "Save Flag",
            failureMessage: failureMessage,
            canCreate: !flag.isBlank
        ) {
            TextField("Flag", text: $flag, prompt: Text("picoCTF{...}"))
                .font(.body.monospaced())
        } create: {
            failureMessage = model.recordFlag(flag, forChallengeAt: challengeFolder)
            if failureMessage == nil { dismiss() }
        }
    }
}

private struct ChallengeDraftFields: View {
    @Binding var draft: ChallengeDraft
    let ctfs: [LibraryCTF]

    var body: some View {
        Picker("CTF", selection: $draft.ctfFolder) {
            ForEach(ctfs) { ctf in Text(ctf.metadata.name).tag(Optional(ctf.folder)) }
        }
        TextField("Name", text: $draft.name, prompt: Text("enc"))
        HStack {
            TextField("Category", text: $draft.category, prompt: Text("crypto"))
            Menu("Suggestions") {
                ForEach(ChallengeDraft.suggestedCategories, id: \.self) { category in
                    Button(category) { draft.category = category }
                }
            }
            .fixedSize()
        }
        TextField("Points", text: $draft.points, prompt: Text("Optional"))
    }
}

/// The shared layout of the creation sheets: a form, an inline failure message
/// and Cancel / Create buttons.
private struct SheetForm<Fields: View>: View {
    let title: String
    var actionTitle = "Create"
    let failureMessage: String?
    let canCreate: Bool
    @ViewBuilder let fields: () -> Fields
    let create: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            Form { fields() }
            if let failureMessage {
                Text(failureMessage).foregroundStyle(.red).fixedSize(
                    horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(actionTitle, action: create).keyboardShortcut(.defaultAction).disabled(
                    !canCreate)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

extension String {
    fileprivate var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
