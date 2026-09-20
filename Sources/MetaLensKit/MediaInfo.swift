import Foundation

/// What ffprobe reports about one file.
public struct MediaInfo: Decodable, Sendable {
    public struct Format: Decodable, Sendable {
        public var filename: String
        public var formatName: String
        public var formatLongName: String?
        public var duration: String?
        public var size: String?
        public var bitRate: String?
        public var tags: [String: String]?
    }

    public struct SideData: Decodable, Sendable {
        public var sideDataType: String?
    }

    public struct Stream: Decodable, Sendable, Identifiable {
        public var index: Int
        public var codecType: String
        public var codecName: String?
        public var codecLongName: String?
        public var profile: String?
        public var width: Int?
        public var height: Int?
        public var pixFmt: String?
        public var avgFrameRate: String?
        public var rFrameRate: String?
        public var bitRate: String?
        public var sampleRate: String?
        public var channels: Int?
        public var channelLayout: String?
        public var colorPrimaries: String?
        public var colorTransfer: String?
        public var colorSpace: String?
        public var displayAspectRatio: String?
        public var bitsPerRawSample: String?
        public var tags: [String: String]?
        public var disposition: [String: Int]?
        public var sideDataList: [SideData]?

        public var id: Int { index }
    }

    public struct Chapter: Decodable, Sendable, Identifiable {
        public var id: Int
        public var startTime: String?
        public var endTime: String?
        public var tags: [String: String]?
    }

    public var format: Format
    public var streams: [Stream]
    public var chapters: [Chapter]?
}

public enum Media {
    public static func probe(_ url: URL) throws -> MediaInfo {
        let data = try FFmpeg.run("ffprobe", [
            "-v", "error", "-print_format", "json",
            "-show_format", "-show_streams", "-show_chapters", url.path,
        ])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(MediaInfo.self, from: data)
    }

    /// Writes only the changed tags; an empty value removes one.
    /// Streams are copied, never re-encoded, and the original is replaced only once
    /// ffmpeg has written a complete file.
    // ponytail: MP4/MOV keep only tags the mov muxer knows; custom keys are dropped.
    public static func save(url: URL, formatTags: [String: String], streamTags: [Int: [String: String]]) throws {
        // Same folder and extension: the rename stays atomic and ffmpeg picks the same muxer.
        let temporary = url.deletingLastPathComponent().appending(path: ".metalens-tmp-\(url.lastPathComponent)")
        var arguments = ["-v", "error", "-y", "-i", url.path, "-map", "0", "-c", "copy", "-ignore_unknown"]
        for (key, value) in formatTags {
            arguments += ["-metadata", "\(key)=\(value)"]
        }
        for (index, tags) in streamTags {
            for (key, value) in tags {
                arguments += ["-metadata:s:\(index)", "\(key)=\(value)"]
            }
        }
        arguments.append(temporary.path)

        do {
            try FFmpeg.run("ffmpeg", arguments)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
    }
}
