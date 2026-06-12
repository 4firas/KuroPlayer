import Foundation

/// Shared yt-dlp process runner used by YouTube Music and SoundCloud providers.
/// Handles path detection, process lifecycle, and thread-safe output buffering.
actor YtDlpRunner {
    static let shared = YtDlpRunner()

    /// Resolved path to the yt-dlp binary, cached after first lookup.
    private var resolvedPath: String?

    /// Locates yt-dlp on disk. Checks Homebrew (ARM + Intel) then falls back to `which`.
    func ytdlpPath() throws -> String {
        if let cached = resolvedPath { return cached }

        let candidates = [
            "/opt/homebrew/bin/yt-dlp",   // ARM Mac (Homebrew)
            "/usr/local/bin/yt-dlp",       // Intel Mac (Homebrew)
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                resolvedPath = path
                return path
            }
        }

        // Fallback: ask the shell
        if let whichPath = try? runShell("/usr/bin/which", args: ["yt-dlp"]),
           !whichPath.isEmpty,
           FileManager.default.fileExists(atPath: whichPath) {
            resolvedPath = whichPath
            return whichPath
        }

        throw YtDlpError.notFound
    }

    /// Returns the installed yt-dlp version string, or nil if not found.
    func version() async -> String? {
        guard let path = try? ytdlpPath() else { return nil }
        return try? await run(executablePath: path, args: ["--version"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let defaultUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    /// Run yt-dlp with the given arguments and return stdout.
    func run(args: [String]) async throws -> String {
        let path = try ytdlpPath()
        var finalArgs = args
        if !finalArgs.contains("--user-agent") {
            finalArgs.append(contentsOf: ["--user-agent", YtDlpRunner.defaultUserAgent])
        }
        return try await run(executablePath: path, args: finalArgs)
    }

    // MARK: - Private

    private func run(executablePath: String, args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = args

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let outputBuffer = DataBuffer()
            let errorBuffer = DataBuffer()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { outputBuffer.append(data) }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { errorBuffer.append(data) }
            }

            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                if proc.terminationStatus == 0 {
                    let output = String(data: outputBuffer.data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } else {
                    let err = String(data: errorBuffer.data, encoding: .utf8) ?? "unknown error"
                    continuation.resume(throwing: YtDlpError.processFailed(String(err.prefix(300))))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: YtDlpError.processFailed(error.localizedDescription))
            }
        }
    }

    private func runShell(_ path: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

// MARK: - Thread-safe data buffer

private final class DataBuffer: @unchecked Sendable {
    private var _data = Data()
    private let lock = NSLock()

    func append(_ newData: Data) {
        lock.lock()
        _data.append(newData)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return _data
    }
}

// MARK: - Errors

enum YtDlpError: Error, LocalizedError {
    case notFound
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "yt-dlp not found. Install it with: brew install yt-dlp"
        case .processFailed(let message):
            return "yt-dlp error: \(message)"
        }
    }
}
