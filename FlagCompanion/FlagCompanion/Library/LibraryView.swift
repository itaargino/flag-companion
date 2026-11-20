import ChallengeLibrary
import SwiftUI

/// The home screen: every CTF in the root folder with its challenges.
struct LibraryView: View {
    @Bindable var model: LibraryModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        LibraryList(model: model)
            .overlay { if model.scan.ctfs.isEmpty { EmptyLibraryView(model: model) } }
            .safeAreaInset(edge: .bottom) { LibraryProblemsBar(problems: model.scan.problems) }
            .toolbar { LibraryToolbar(model: model) }
            .navigationTitle("Library")
            .navigationSubtitle(model.rootFolder.path)
            .sheet(item: $model.activeSheet) { sheet in LibrarySheetView(sheet: sheet, model: model)
            }
            .confirmationDialog(
                "Move “\(model.itemToTrash?.name ?? "")” to the Trash?",
                isPresented: trashBinding, presenting: model.itemToTrash
            ) { item in
                Button("Move to Trash", role: .destructive) { model.moveToTrash(item) }
            } message: { item in
                Text(item.explanation)
            }
            .alert("Could Not Update the Library", isPresented: $model.isShowingFailure) {
            } message: {
                Text(model.failureMessage ?? "")
            }
            // The spec rereads folders whenever the app becomes active, so edits in Finder show up.
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { model.reload() }
            }
            .frame(minWidth: 520, minHeight: 360)
    }

    private var trashBinding: Binding<Bool> {
        Binding(
            get: { model.itemToTrash != nil },
            set: { if !$0 { model.itemToTrash = nil } }
        )
    }
}

private struct LibraryList: View {
    @Bindable var model: LibraryModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        List(selection: $model.selectedChallengeFolder) {
            ForEach(model.scan.ctfs) { ctf in
                Section {
                    CTFChallengeRows(ctf: ctf)
                } header: {
                    CTFHeader(ctf: ctf, model: model)
                }
            }
        }
        // Double-click or Return on a row opens the challenge; right-click shows the menu.
        .contextMenu(forSelectionType: URL.self) { folders in
            if let challenge = model.challenge(at: folders.first) {
                ChallengeMenu(challenge: challenge, model: model)
            }
        } primaryAction: { folders in
            if let challenge = model.challenge(at: folders.first) {
                model.markStarted(challenge)
                openWindow(id: "challenge", value: challenge.folder)
            }
        }
    }
}

private struct CTFChallengeRows: View {
    let ctf: LibraryCTF

    var body: some View {
        if ctf.challenges.isEmpty {
            Text("No challenges yet").foregroundStyle(.secondary)
        }
        ForEach(ctf.challenges) { challenge in
            ChallengeRow(challenge: challenge).tag(challenge.folder)
        }
    }
}

private struct CTFHeader: View {
    let ctf: LibraryCTF
    let model: LibraryModel

    var body: some View {
        HStack {
            Text(ctf.metadata.name)
            Spacer()
            Button("New Challenge", systemImage: "plus") {
                model.activeSheet = .newChallenge(ctfFolder: ctf.folder)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("New challenge in \(ctf.metadata.name)")
        }
        .contextMenu {
            Button("Show in Finder") { model.showInFinder(ctf.folder) }
            Divider()
            Button("Move CTF to Trash…", role: .destructive) { model.itemToTrash = .ctf(ctf) }
        }
    }
}

private struct ChallengeRow: View {
    let challenge: LibraryChallenge

    var body: some View {
        HStack {
            Image(systemName: challenge.metadata.status.symbolName)
                .foregroundStyle(challenge.metadata.status.tint)
                .help(challenge.metadata.status.title)
            Text(challenge.metadata.name)
            if challenge.metadata.flag != nil {
                Image(systemName: "flag.fill").foregroundStyle(.green).help("Flag recorded")
            }
            Spacer()
            Text(challenge.metadata.category).foregroundStyle(.secondary)
            if let points = challenge.metadata.points {
                Text("\(points) pts").foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }
}

private struct ChallengeMenu: View {
    let challenge: LibraryChallenge
    let model: LibraryModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open") {
            model.markStarted(challenge)
            openWindow(id: "challenge", value: challenge.folder)
        }
        Button("Open files/ in macOS Terminal") { model.openTerminal(for: challenge) }
        Button("Show in Finder") { model.showInFinder(challenge.folder) }
        Divider()
        Button(challenge.metadata.flag == nil ? "Mark as Solved…" : "Edit Flag…") {
            model.activeSheet = .recordFlag(challengeFolder: challenge.folder)
        }
        Picker("Status", selection: statusBinding) {
            ForEach(ChallengeStatus.allCases, id: \.self) { status in
                Text(status.title).tag(status)
            }
        }
        Divider()
        Button("Move to Trash…", role: .destructive) {
            model.itemToTrash = .challenge(challenge)
        }
    }

    private var statusBinding: Binding<ChallengeStatus> {
        Binding(
            get: { challenge.metadata.status },
            set: { model.setStatus($0, of: challenge) }
        )
    }
}
