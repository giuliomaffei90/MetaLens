import AppKit
import MetaLensKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Selection: Hashable {
        case overview
        case tags
        case chapters
        case stream(Int)
    }

    @Published var url: URL?
    @Published var info: MediaInfo?
    @Published var draftFormat: [String: String] = [:]
    @Published var draftStreams: [Int: [String: String]] = [:]
    @Published var selection: Selection? = .overview
    @Published var busy = false
    @Published private(set) var saving = false
    @Published var confirmingSave = false
    @Published var importing = false
    @Published var failure: Failure?

    struct Failure: Identifiable {
        let id = UUID()
        var title: String
        var message: String
    }

    var isImage: Bool { info.map(Fmt.isImage) ?? false }

    /// Window subtitle: what is happening, or what is pending.
    var status: String {
        if busy { return saving ? "Salvataggio…" : "Lettura…" }
        guard changes > 0 else { return "" }
        return "\(changes) \(changes == 1 ? "modifica non salvata" : "modifiche non salvate")"
    }

    /// `MetaLens file.mkv` from the terminal.
    func openFromCommandLine() {
        guard let path = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) else { return }
        load(URL(filePath: path))
    }

    /// Shown as a sheet on the window by `.fileImporter`, not as a free-floating modal panel.
    func chooseFile() {
        importing = true
    }

    func load(_ fileURL: URL) {
        busy = true
        Task {
            do {
                let probed = try await Task.detached { try Media.probe(fileURL) }.value
                url = fileURL
                info = probed
                resetDraft()
                selection = .overview
            } catch {
                failure = Failure(title: "Impossibile leggere il file",
                                  message: error.localizedDescription)
            }
            busy = false
        }
    }

    func resetDraft() {
        guard let info else { return }
        draftFormat = info.format.tags ?? [:]
        draftStreams = Dictionary(uniqueKeysWithValues: info.streams.map { ($0.index, $0.tags ?? [:]) })
    }

    /// Only what the user actually changed; an empty value means "remove this tag".
    var edits: (format: [String: String], streams: [Int: [String: String]]) {
        guard let info else { return ([:], [:]) }
        var streams: [Int: [String: String]] = [:]
        for stream in info.streams {
            let changed = Self.diff(stream.tags ?? [:], draftStreams[stream.index] ?? [:])
            if !changed.isEmpty { streams[stream.index] = changed }
        }
        return (Self.diff(info.format.tags ?? [:], draftFormat), streams)
    }

    var changes: Int {
        let edits = edits
        return edits.format.count + edits.streams.values.reduce(0) { $0 + $1.count }
    }

    static func diff(_ original: [String: String], _ next: [String: String]) -> [String: String] {
        var changed: [String: String] = [:]
        for key in Set(original.keys).union(next.keys) where (next[key] ?? "") != (original[key] ?? "") {
            changed[key] = next[key] ?? ""
        }
        return changed
    }

    func requestSave() {
        guard changes > 0, !isImage else { return }
        confirmingSave = true
    }

    func save() {
        guard let url, changes > 0 else { return }
        let edits = edits
        busy = true
        saving = true
        Task {
            defer { saving = false }
            do {
                try await Task.detached {
                    try Media.save(url: url, formatTags: edits.format, streamTags: edits.streams)
                }.value
                info = try await Task.detached { try Media.probe(url) }.value
                resetDraft()
            } catch {
                failure = Failure(title: "Impossibile salvare i metadati",
                                  message: error.localizedDescription)
            }
            busy = false
        }
    }

    func copyReport() {
        guard let info else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Fmt.report(info), forType: .string)
    }

    func icon(for stream: MediaInfo.Stream) -> String {
        if isImage { return "photo" }
        return switch stream.codecType {
        case "video": "film"
        case "audio": "waveform"
        case "subtitle": "captions.bubble"
        case "attachment": "paperclip"
        default: "square.stack.3d.up"
        }
    }
}
