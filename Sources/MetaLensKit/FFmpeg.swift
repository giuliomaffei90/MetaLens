import Foundation

public enum FFmpegError: LocalizedError {
    case notFound(String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let tool): "\(tool) non trovato. Installa FFmpeg con: brew install ffmpeg"
        case .failed(let message): message
        }
    }
}

enum FFmpeg {
    // ponytail: system binaries; copy them into Resources as a fallback before distributing.
    static func url(_ name: String) throws -> URL {
        let candidates = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
            .map { URL(filePath: $0).appending(path: name) }
        guard let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw FFmpegError.notFound(name)
        }
        return found
    }

    /// Runs the tool and returns stdout, or throws with whatever it wrote to stderr.
    @discardableResult
    static func run(_ name: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = try url(name)
        process.arguments = arguments
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        // Both tools are called with -v error, so stderr stays far below the pipe buffer.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw FFmpegError.failed(message.isEmpty ? "\(name) è uscito con codice \(process.terminationStatus)" : message)
        }
        return data
    }
}
