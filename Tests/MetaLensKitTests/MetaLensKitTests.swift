import XCTest

@testable import MetaLensKit

final class MetaLensKitTests: XCTestCase {
    private var directory: URL {
        URL(filePath: NSTemporaryDirectory()).appending(path: "metalens-test")
    }

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func testSaveThenProbeRoundtrip() throws {
        for ext in ["mkv", "mp4"] {
            let file = directory.appending(path: "clip.\(ext)")
            try FFmpeg.run("ffmpeg", [
                "-v", "error", "-y",
                "-f", "lavfi", "-i", "testsrc=d=1:s=160x90",
                "-f", "lavfi", "-i", "sine=d=1", "-shortest", file.path,
            ])

            try Media.save(url: file, formatTags: ["title": "Ciao"], streamTags: [1: ["language": "ita"]])

            let info = try Media.probe(file)
            XCTAssertEqual(info.format.tags?["title"], "Ciao", ext)
            XCTAssertEqual(info.streams.count, 2, ext)
            XCTAssertEqual(info.streams[1].tags?["language"], "ita", ext)
        }
    }

    func testImagesHideSequenceValues() throws {
        let file = directory.appending(path: "shot.png")
        try FFmpeg.run("ffmpeg", [
            "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc=d=1:s=64x48", "-frames:v", "1", file.path,
        ])

        let info = try Media.probe(file)
        XCTAssertTrue(Fmt.isImage(info))
        XCTAssertEqual(Fmt.container(info), "Immagine PNG")
        XCTAssertEqual(Fmt.trackMix(info), "Immagine")
        // The 25 fps and the bitrate ffprobe reports are muxer defaults, not the file's.
        let rows = Fmt.details(info.streams[0], image: true)
        XCTAssertFalse(rows.contains { $0.label == "Frame rate" || $0.label == "Bitrate" })
    }

    /// The fields MediaInfo shows and ffprobe already reports: level, scan type, colour range,
    /// frame count, codec ID.
    func testStreamDetailsFromProbeFields() throws {
        let json = """
        {"index": 0, "codec_type": "video", "codec_name": "hevc", "profile": "Main",
         "codec_tag_string": "hvc1", "width": 1330, "height": 720,
         "coded_width": 1336, "coded_height": 720, "level": 93,
         "field_order": "progressive", "color_range": "tv", "nb_frames": "166917"}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let stream = try decoder.decode(MediaInfo.Stream.self, from: Data(json.utf8))

        let rows = Dictionary(uniqueKeysWithValues: Fmt.details(stream).map { ($0.label, $0.value) })
        XCTAssertEqual(rows["Livello"], "L3.1")          // HEVC stores the level ×30
        XCTAssertEqual(rows["Scansione"], "Progressivo")
        XCTAssertEqual(rows["Intervallo colore"], "Limitato (TV)")
        XCTAssertEqual(rows["ID codec"], "hvc1")
        XCTAssertEqual(rows["Codificata"], "1336 × 720") // only when it differs from the display size
        XCTAssertNotNil(rows["Fotogrammi"])

        var h264 = stream
        h264.codecName = "h264"
        h264.level = 31                                   // H.264 stores it ×10
        XCTAssertEqual(Fmt.level(h264), "L3.1")
        h264.level = 40
        XCTAssertEqual(Fmt.level(h264), "L4")
    }

    func testFormatting() {
        XCTAssertEqual(Fmt.time("3725.5"), "1:02:05")
        XCTAssertEqual(Fmt.time("65.25", showMilliseconds: true), "1:05.250")
        // Locale-aware, so assert the unit rather than the exact separator.
        XCTAssertEqual(Fmt.bytes("1536")?.hasSuffix("kB"), true)
        XCTAssertNil(Fmt.bytes("non un numero"))
        XCTAssertEqual(Fmt.bitrate("14640000"), "14.64 Mb/s")
        XCTAssertEqual(Fmt.bitrate("121320"), "121 kb/s")
        XCTAssertEqual(Fmt.bitrate("86"), "86 bit/s")
        XCTAssertNil(Fmt.bitrate("0"))
        XCTAssertEqual(Fmt.fps("24000/1001"), "23.976 fps")
        XCTAssertNil(Fmt.fps("0/0"))
    }
}
