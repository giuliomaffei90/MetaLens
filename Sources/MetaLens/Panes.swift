import MetaLensKit
import SwiftUI

struct OverviewPane: View {
    let info: MediaInfo

    var body: some View {
        let image = Fmt.isImage(info)
        Form {
            Section("File") {
                LabeledContent("Nome", value: URL(filePath: info.format.filename).lastPathComponent)
                LabeledContent("Formato", value: Fmt.container(info))
                if !image {
                    LabeledContent("Durata", value: Fmt.time(info.format.duration, showMilliseconds: true) ?? "—")
                }
                LabeledContent("Dimensione", value: Fmt.bytes(info.format.size) ?? "—")
                if !image {
                    LabeledContent("Bitrate", value: Fmt.bitrate(info.format.bitRate) ?? "—")
                }
                LabeledContent("Contenuto", value: Fmt.trackMix(info))
            }

            Section(image ? "Immagine" : "Tracce") {
                ForEach(info.streams) { stream in
                    LabeledContent {
                        Text(Fmt.summary(stream, image: image))
                            .foregroundStyle(.secondary)
                    } label: {
                        Text("\(image ? "Immagine" : "\(Fmt.typeLabel(stream.codecType)) \(stream.index)") · \((stream.codecName ?? "?").uppercased())")
                    }
                }
            }

            if let title = info.format.tags?["title"], !title.isEmpty {
                Section("Titolo") {
                    Text(title).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct StreamPane: View {
    @ObservedObject var model: AppModel
    let info: MediaInfo
    let stream: MediaInfo.Stream

    var body: some View {
        let image = Fmt.isImage(info)
        Form {
            let badges = Fmt.badges(stream)
            Section("Dettagli") {
                ForEach(Fmt.details(stream, image: image)) { row in
                    LabeledContent(row.label) {
                        Text(row.value).textSelection(.enabled)
                    }
                }
                if !badges.isEmpty {
                    LabeledContent("Caratteristiche") {
                        HStack(spacing: 6) {
                            ForEach(badges, id: \.self) { badge in
                                Text(badge)
                                    .font(.caption)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: .capsule)
                            }
                        }
                    }
                }
            }

            if image {
                Section("Metadati") {
                    imageNotice
                }
            } else {
                TagEditor(tags: binding, original: stream.tags ?? [:], suggestions: Fmt.streamKeys)
            }
        }
        .formStyle(.grouped)
    }

    private var binding: Binding<[String: String]> {
        Binding(get: { model.draftStreams[stream.index] ?? [:] },
                set: { model.draftStreams[stream.index] = $0 })
    }

    @ViewBuilder
    private var imageNotice: some View {
        let tags = stream.tags ?? [:]
        Text("Sulle immagini MetaLens legge i metadati ma non li scrive: riscrivere il file con FFmpeg perderebbe EXIF e profilo colore.")
            .foregroundStyle(.secondary)
        ForEach(tags.keys.sorted(), id: \.self) { key in
            LabeledContent(key) { Text(tags[key] ?? "").textSelection(.enabled) }
        }
    }
}

struct FileTagsPane: View {
    @ObservedObject var model: AppModel
    let info: MediaInfo

    var body: some View {
        Form {
            if Fmt.isImage(info) {
                Section("Metadati") {
                    Text("Sulle immagini MetaLens legge i metadati ma non li scrive: riscrivere il file con FFmpeg perderebbe EXIF e profilo colore.")
                        .foregroundStyle(.secondary)
                    ForEach((info.format.tags ?? [:]).keys.sorted(), id: \.self) { key in
                        LabeledContent(key) {
                            Text(info.format.tags?[key] ?? "").textSelection(.enabled)
                        }
                    }
                }
            } else {
                TagEditor(tags: $model.draftFormat,
                          original: info.format.tags ?? [:],
                          suggestions: Fmt.fileKeys,
                          footer: "Metadati globali del file. Un campo lasciato vuoto viene rimosso al salvataggio.")
            }
        }
        .formStyle(.grouped)
    }
}

struct ChaptersPane: View {
    let chapters: [MediaInfo.Chapter]

    private struct Row: Identifiable {
        let id: Int
        let number: Int
        let start: String
        let end: String
        let title: String
    }

    var body: some View {
        Table(rows) {
            TableColumn("#") { Text("\($0.number)") }.width(30)
            TableColumn("Inizio", value: \.start).width(90)
            TableColumn("Fine", value: \.end).width(90)
            TableColumn("Titolo", value: \.title)
        }
    }

    private var rows: [Row] {
        chapters.enumerated().map { index, chapter in
            Row(id: chapter.id,
                number: index + 1,
                start: Fmt.time(chapter.startTime, showMilliseconds: true) ?? "—",
                end: Fmt.time(chapter.endTime, showMilliseconds: true) ?? "—",
                title: chapter.tags?["title"] ?? "")
        }
    }
}

/// The editable tag list: one row per tag, plus a row to add one.
struct TagEditor: View {
    @Binding var tags: [String: String]
    let original: [String: String]
    let suggestions: [String]
    var footer: String?

    @State private var newKey = ""
    @State private var newValue = ""

    private var removed: [String] { original.keys.filter { tags[$0] == nil }.sorted() }

    var body: some View {
        Section {
            ForEach(tags.keys.sorted(), id: \.self) { key in
                LabeledContent(key) {
                    HStack(spacing: 6) {
                        TextField("valore", text: Binding(
                            get: { tags[key] ?? "" },
                            set: { tags[key] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .multilineTextAlignment(.leading)
                        if original[key] != tags[key] {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(.tint)
                                .help("Modificato")
                        }
                        Button {
                            tags.removeValue(forKey: key)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Rimuovi il campo")
                    }
                }
            }

            ForEach(removed, id: \.self) { key in
                LabeledContent {
                    HStack(spacing: 6) {
                        Text(original[key] ?? "")
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            tags[key] = original[key]
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Ripristina il campo")
                    }
                } label: {
                    Text(key).strikethrough().foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                TextField("nuovo campo", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 150)
                Menu("") {
                    ForEach(suggestions.filter { tags[$0] == nil }, id: \.self) { suggestion in
                        Button(suggestion) { newKey = suggestion }
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 16)
                TextField("valore", text: $newValue)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(newKey.trimmingCharacters(in: .whitespaces).isEmpty)
                .help("Aggiungi il campo")
            }
        } header: {
            Text("Metadati")
        } footer: {
            if let footer {
                Text(footer).foregroundStyle(.secondary)
            }
        }
    }

    private func add() {
        let key = newKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        tags[key] = newValue
        newKey = ""
        newValue = ""
    }
}
