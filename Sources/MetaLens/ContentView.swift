import MetaLensKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var dragging = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 280)
        } detail: {
            detail
        }
        .navigationTitle(model.url?.lastPathComponent ?? "Nessun file")
        .navigationSubtitle(model.status)
        .toolbar { toolbar }
        .focusedSceneValue(\.fileActions, menuActions)
        .onDrop(of: [.fileURL], isTargeted: $dragging) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in model.load(url) }
            }
            return true
        }
        .overlay {
            if dragging {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .ignoresSafeArea()
            }
        }
        .fileImporter(isPresented: $model.importing,
                      allowedContentTypes: [.movie, .audio, .image, .data]) { result in
            if case .success(let url) = result { model.load(url) }
        }
        .fileDialogMessage("Scegli un file audio, video o un'immagine")
        .fileDialogConfirmationLabel("Apri")
        .alert("Salvare le modifiche?", isPresented: $model.confirmingSave) {
            Button("Salva") { model.save() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Il file verrà riscritto con i nuovi metadati. Audio e video non vengono ricodificati.")
        }
        .alert(item: $model.failure) { failure in
            Alert(title: Text(failure.title),
                  message: Text(failure.message),
                  dismissButton: .default(Text("OK")))
        }
        .modify { view in
            if let url = model.url { view.navigationDocument(url) } else { view }
        }
    }

    private var menuActions: FileActions {
        FileActions(open: { model.chooseFile() },
                    save: model.changes > 0 ? { model.requestSave() } : nil,
                    copyReport: model.info != nil ? { model.copyReport() } : nil)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if model.busy {
            ToolbarItem {
                ProgressView().controlSize(.small)
            }
            .withoutSharedBackground()
        }
        ToolbarItemGroup {
            Button {
                model.chooseFile()
            } label: {
                Label("Apri", systemImage: "folder")
            }
            .help("Apri un file")
            Button {
                model.copyReport()
            } label: {
                Label("Copia report", systemImage: "doc.on.doc")
            }
            .help("Copia il riepilogo negli appunti")
            .disabled(model.info == nil)
        }
        ToolbarGap()
        ToolbarItem {
            // The one primary action, tinted and on the trailing edge. Text, not a symbol:
            // no symbol says "write the metadata into the file" to everyone.
            Button("Salva") { model.requestSave() }
                .prominentToolbarButton()
                .disabled(model.changes == 0)
                .help("Scrive i metadati modificati nel file")
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if let info = model.info {
            List(selection: $model.selection) {
                Section("File") {
                    Label("Panoramica", systemImage: "info.circle")
                        .tag(AppModel.Selection.overview)
                    Label("Metadati", systemImage: "tag")
                        .tag(AppModel.Selection.tags)
                    if !(info.chapters?.isEmpty ?? true) {
                        Label("Capitoli", systemImage: "list.bullet.indent")
                            .badge(info.chapters?.count ?? 0)
                            .tag(AppModel.Selection.chapters)
                    }
                }
                Section(model.isImage ? "Immagine" : "Tracce") {
                    ForEach(info.streams) { stream in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(model.isImage
                                    ? "Immagine"
                                    : "\(Fmt.typeLabel(stream.codecType)) \(stream.index)")
                                Text((stream.codecName ?? "?").uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: model.icon(for: stream))
                        }
                        .tag(AppModel.Selection.stream(stream.index))
                    }
                }
            }
        } else {
            List { Text("Nessun file").foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let info = model.info {
            switch model.selection {
            case .overview, .none:
                OverviewPane(info: info)
            case .tags:
                FileTagsPane(model: model, info: info)
            case .chapters:
                ChaptersPane(chapters: info.chapters ?? [])
            case .stream(let index):
                if let stream = info.streams.first(where: { $0.index == index }) {
                    StreamPane(model: model, info: info, stream: stream)
                }
            }
        } else {
            ContentUnavailableView {
                Label("Nessun file aperto", systemImage: "film.stack")
            } description: {
                Text("Trascina qui un file video, audio o un'immagine per vederne i metadati.")
            } actions: {
                Button("Scegli file…") { model.chooseFile() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

extension View {
    /// Small helper so an optional modifier stays readable inline.
    @ViewBuilder
    func modify<Result: View>(@ViewBuilder _ transform: (Self) -> Result) -> some View {
        transform(self)
    }
}
