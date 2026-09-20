import Foundation

/// Turning ffprobe's raw values into what the interface shows.
public enum Fmt {
    public struct Row: Identifiable, Sendable {
        public let label: String
        public let value: String
        public var id: String { label }
    }

    public static let fileKeys = [
        "title", "artist", "album_artist", "album", "date", "genre", "comment", "description", "copyright", "track",
    ]
    public static let streamKeys = ["title", "language", "handler_name"]

    private static let typeLabels = [
        "video": "Video", "audio": "Audio", "subtitle": "Sottotitoli", "attachment": "Allegato", "data": "Dati",
    ]

    public static func typeLabel(_ type: String) -> String { typeLabels[type] ?? type }

    public static func time(_ value: String?, showMilliseconds: Bool = false) -> String? {
        guard let seconds = value.flatMap(Double.init), seconds.isFinite else { return nil }
        let whole = Int(seconds)
        let hours = whole / 3600, minutes = (whole % 3600) / 60
        let secondsText = showMilliseconds
            ? String(format: "%06.3f", seconds.truncatingRemainder(dividingBy: 60))
            : String(format: "%02d", whole % 60)
        return hours > 0
            ? "\(hours):\(String(format: "%02d", minutes)):\(secondsText)"
            : "\(minutes):\(secondsText)"
    }

    public static func bytes(_ value: String?) -> String? {
        guard let count = value.flatMap(Double.init), count.isFinite else { return nil }
        let units = ["B", "KB", "MB", "GB", "TB"]
        let step = count > 0 ? min(Int(log(count) / log(1024)), units.count - 1) : 0
        let scaled = count / pow(1024, Double(step))
        return step == 0 ? "\(Int(scaled)) \(units[step])" : String(format: "%.2f %@", scaled, units[step])
    }

    public static func bitrate(_ value: String?) -> String? {
        guard let bits = value.flatMap(Double.init), bits.isFinite else { return nil }
        return bits >= 1e6 ? String(format: "%.2f Mb/s", bits / 1e6) : "\(Int((bits / 1e3).rounded())) kb/s"
    }

    public static func fps(_ value: String?) -> String? {
        guard let value, !value.hasPrefix("0/") else { return nil }
        let parts = value.split(separator: "/").compactMap { Double($0) }
        guard let numerator = parts.first else { return nil }
        let rate = parts.count > 1 && parts[1] != 0 ? numerator / parts[1] : numerator
        guard rate > 0 else { return nil }
        return rate == rate.rounded()
            ? String(format: "%.0f fps", rate)
            : String(format: "%.3f fps", rate)
    }

    public static func language(_ code: String?) -> String? {
        guard let code, code != "und" else { return nil }
        return Locale(identifier: "it").localizedString(forLanguageCode: code) ?? code
    }

    /// FFmpeg reads a still image as a one-frame "sequence": its fps, duration and bitrate
    /// are muxer defaults rather than properties of the file, so we hide them.
    public static func isImage(_ info: MediaInfo) -> Bool {
        info.format.formatName == "image2" || info.format.formatName.hasSuffix("_pipe")
    }

    public static func container(_ info: MediaInfo) -> String {
        isImage(info)
            ? "Immagine \((info.streams.first?.codecName ?? "").uppercased())"
            : (info.format.formatLongName ?? info.format.formatName)
    }

    public static func trackMix(_ info: MediaInfo) -> String {
        if isImage(info) { return "Immagine" }
        var counts: [(String, Int)] = []
        for stream in info.streams {
            if let position = counts.firstIndex(where: { $0.0 == stream.codecType }) {
                counts[position].1 += 1
            } else {
                counts.append((stream.codecType, 1))
            }
        }
        return counts.map { "\($0.1) \(typeLabel($0.0).lowercased())" }.joined(separator: " · ")
    }

    public static func badges(_ stream: MediaInfo.Stream) -> [String] {
        var badges: [String] = []
        if stream.sideDataList?.contains(where: { $0.sideDataType?.contains("DOVI") == true }) == true {
            badges.append("Dolby Vision")
        }
        if stream.colorTransfer == "smpte2084" { badges.append("HDR10") }
        if stream.colorTransfer == "arib-std-b67" { badges.append("HLG") }
        if stream.disposition?["default"] == 1 { badges.append("Default") }
        if stream.disposition?["forced"] == 1 { badges.append("Forced") }
        if stream.disposition?["attached_pic"] == 1 { badges.append("Copertina") }
        return badges
    }

    public static func summary(_ stream: MediaInfo.Stream, image: Bool = false) -> String {
        var parts: [String?] = []
        switch stream.codecType {
        case "video":
            parts = [stream.width.map { "\($0) × \(stream.height ?? 0)" },
                     image ? nil : (fps(stream.avgFrameRate) ?? fps(stream.rFrameRate))]
        case "audio":
            parts = [stream.channelLayout ?? stream.channels.map { "\($0) canali" },
                     stream.sampleRate.flatMap(Double.init).map { "\(($0 / 1000).clean) kHz" }]
        default:
            parts = [language(stream.tags?["language"]), stream.tags?["title"]]
        }
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    public static func details(_ stream: MediaInfo.Stream, image: Bool = false) -> [Row] {
        let common: [(String, String?)] = [
            ("Codec", stream.codecLongName),
            ("Profilo", stream.profile),
            ("Bitrate", image ? nil : bitrate(stream.bitRate ?? stream.tags?["BPS"])),
            ("Lingua", language(stream.tags?["language"])),
            ("Titolo", stream.tags?["title"]),
        ]
        var rows: [(String, String?)]
        switch stream.codecType {
        case "video":
            rows = [
                ("Risoluzione", stream.width.map { "\($0) × \(stream.height ?? 0)" }),
                ("Aspetto", stream.displayAspectRatio),
                ("Frame rate", image ? nil : (fps(stream.avgFrameRate) ?? fps(stream.rFrameRate))),
                ("Pixel", stream.pixFmt),
                ("Profondità", stream.bitsPerRawSample.map { "\($0) bit" }),
                ("Colore", [stream.colorPrimaries, stream.colorTransfer, stream.colorSpace]
                    .compactMap { $0 }.joined(separator: " · ").nilIfEmpty),
            ] + common
        case "audio":
            rows = [
                ("Canali", stream.channels.map { channels in
                    stream.channelLayout.map { "\(channels) (\($0))" } ?? "\(channels)"
                }),
                ("Campionamento", stream.sampleRate.flatMap(Double.init).map { "\(($0 / 1000).clean) kHz" }),
            ] + common
        default:
            rows = common
        }
        return rows.compactMap { label, value in value.map { Row(label: label, value: $0) } }
    }

    public static func report(_ info: MediaInfo) -> String {
        let image = isImage(info)
        var lines = [
            URL(filePath: info.format.filename).lastPathComponent,
            "Formato: \(container(info))",
        ]
        if !image { lines.append("Durata: \(time(info.format.duration, showMilliseconds: true) ?? "—")") }
        lines.append("Dimensione: \(bytes(info.format.size) ?? "—")")
        if !image { lines.append("Bitrate: \(bitrate(info.format.bitRate) ?? "—")") }

        for stream in info.streams {
            let head = image ? "Immagine" : "#\(stream.index) \(typeLabel(stream.codecType))"
            lines.append("")
            lines.append("\(head) — \((stream.codecName ?? "?").uppercased())")
            for row in details(stream, image: image) {
                lines.append("  \(row.label): \(row.value)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension Double {
    /// 44.1 stays 44.1, 48.0 becomes 48.
    var clean: String { self == rounded() ? String(Int(self)) : String(self) }
}
