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

    func testFormatting() {
        XCTAssertEqual(Fmt.time("3725.5"), "1:02:05")
        XCTAssertEqual(Fmt.time("65.25", showMilliseconds: true), "1:05.250")
        XCTAssertEqual(Fmt.bytes("1536"), "1.50 KB")
        XCTAssertEqual(Fmt.bitrate("14640000"), "14.64 Mb/s")
        XCTAssertEqual(Fmt.fps("24000/1001"), "23.976 fps")
        XCTAssertNil(Fmt.fps("0/0"))
    }
}
