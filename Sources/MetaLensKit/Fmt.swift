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
        guard let count = value.flatMap(Int64.init) else { return nil }
        return count.formatted(.byteCount(style: .file))
    }

    public static func bitrate(_ value: String?) -> String? {
        guard let bits = value.flatMap(Double.init), bits.isFinite, bits > 0 else { return nil }
        if bits >= 1e6 { return String(format: "%.2f Mb/s", bits / 1e6) }
        // Subtitle tracks run at a few dozen bit/s: rounding them to kb/s would show "0 kb/s".
        if bits < 1000 { return "\(Int(bits.rounded())) bit/s" }
        return "\(Int((bits / 1e3).rounded())) kb/s"
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

    /// H.264 stores the level ×10, HEVC ×30: 93 is level 3.1. Other codecs use their own
    /// numbering, so show the raw value rather than invent one.
    public static func level(_ stream: MediaInfo.Stream) -> String? {
        guard let level = stream.level, level > 0 else { return nil }
        let divisor: Int
        switch stream.codecName {
        case "hevc": divisor = 30
        case "h264": divisor = 10
        default: return String(level)
        }
        let whole = level / divisor, rest = level % divisor
        return rest == 0 ? "L\(whole)" : "L\(whole).\(rest * 10 / divisor)"
    }

    public static func scanType(_ value: String?) -> String? {
        switch value {
        case "progressive": "Progressivo"
        case "tt", "bb", "tb", "bt": "Interlacciato"
        case "unknown", .none: nil
        case .some(let other): other
        }
    }

    public static func colorRange(_ value: String?) -> String? {
        switch value {
        case "tv", "mpeg": "Limitato (TV)"
        case "pc", "jpeg": "Pieno (PC)"
        default: nil
        }
    }

    public static func count(_ value: String?) -> String? {
        guard let count = value.flatMap(Int.init), count > 0 else { return nil }
        return count.formatted()
    }

    /// The four-character brand an MP4/MOV declares; MediaInfo shows it as the format profile.
    public static func containerBrand(_ info: MediaInfo) -> String? {
        guard let brand = info.format.tags?["major_brand"]?.trimmingCharacters(in: .whitespaces),
              !brand.isEmpty else { return nil }
        let names = [
            "isom": "MPEG-4 (Base Media)", "iso2": "MPEG-4 (Base Media v2)",
            "mp41": "MPEG-4 v1", "mp42": "MPEG-4 v2", "avc1": "MPEG-4 (AVC)",
            "qt  ": "QuickTime", "M4V ": "MPEG-4 Video", "M4A ": "MPEG-4 Audio",
        ]
        return names[brand].map { "\($0) · \(brand)" } ?? brand
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
            ("ID codec", stream.codecTagString.flatMap { $0 == "[0][0][0][0]" ? nil : $0 }),
            ("Bitrate", image ? nil : bitrate(stream.bitRate ?? stream.tags?["BPS"])),
            ("Lingua", language(stream.tags?["language"])),
            ("Titolo", stream.tags?["title"]),
        ]
        var rows: [(String, String?)]
        switch stream.codecType {
        case "video":
            rows = [
                ("Risoluzione", stream.width.map { "\($0) × \(stream.height ?? 0)" }),
                ("Codificata", stream.codedWidth.flatMap { coded in
                    coded == stream.width && stream.codedHeight == stream.height
                        ? nil : "\(coded) × \(stream.codedHeight ?? 0)"
                }),
                ("Aspetto", stream.displayAspectRatio),
                ("Frame rate", image ? nil : (fps(stream.avgFrameRate) ?? fps(stream.rFrameRate))),
                ("Pixel", stream.pixFmt),
                ("Profondità", stream.bitsPerRawSample.map { "\($0) bit" }),
                ("Scansione", image ? nil : scanType(stream.fieldOrder)),
                ("Colore", [stream.colorPrimaries, stream.colorTransfer, stream.colorSpace]
                    .compactMap { $0 }.joined(separator: " · ").nilIfEmpty),
                ("Intervallo colore", colorRange(stream.colorRange)),
                ("Livello", level(stream)),
                ("Fotogrammi", image ? nil : count(stream.nbFrames)),
            ] + common
        case "audio":
            rows = [
                ("Canali", stream.channels.map { channels in
                    stream.channelLayout.map { "\(channels) (\($0))" } ?? "\(channels)"
                }),
                ("Campionamento", stream.sampleRate.flatMap(Double.init).map { "\(($0 / 1000).clean) kHz" }),
            ] + common
        case "subtitle":
            rows = [("Elementi", count(stream.nbFrames))] + common
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
