import Foundation

/// Shared yt-dlp runner used by every streaming provider.
///
/// Centralizing this fixes the inconsistencies between providers:
/// - one binary lookup (Homebrew, /usr/local, MacPorts, ~/.local) instead of a
///   hard-coded path,
/// - the same base flags everywhere (no config files, bounded socket timeouts,
///   bounded retries) so SoundCloud and YouTube Music behave the same way,
/// - cooperative cancellation: when a search Task is cancelled the underlying
///   process is terminated instead of left running,
/// - a hard timeout so a stalled network call can never leave the UI loading
///   forever.
enum YtDlp {
    enum RunError: Error, LocalizedError {
        case binaryNotFound
        case timedOut
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "yt-dlp not found. Install it with: brew install yt-dlp"
            case .timedOut:
                return "yt-dlp timed out"
            case .failed(let message):
                return "yt-dlp failed: \(message)"
            }
        }
    }

    /// Flags applied to every invocation.
    private static let baseFlags = [
        "--no-config",
        "--no-warnings",
        "--socket-timeout", "15",
        "--retries", "2"
    ]

    /// Resolved once, thread-safe by `static let` semantics.
    static let binaryPath: String? = {
        let candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/opt/local/bin/yt-dlp",
            "/usr/bin/yt-dlp",
            (NSHomeDirectory() as NSString).appendingPathComponent(".local/bin/yt-dlp")
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    static var isAvailable: Bool { binaryPath != nil }

    /// Runs yt-dlp and returns stdout. Throws on non-zero exit, timeout,
    /// missing binary, or task cancellation.
    static func run(_ args: [String], timeout: TimeInterval = 30) async throws -> String {
        guard let path = binaryPath else {
            throw RunError.binaryNotFound
        }

        let box = ProcessBox()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = baseFlags + args
        box.store(process)

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let outputBuffer = DataBuffer()
                let errorBuffer = DataBuffer()
                let timedOut = Locked(false)

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty { outputBuffer.append(data) }
                }
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty { errorBuffer.append(data) }
                }

                let timeoutWork = DispatchWorkItem {
                    timedOut.set(true)
                    box.terminate()
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

                process.terminationHandler = { proc in
                    timeoutWork.cancel()

                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    // Drain anything still buffered in the pipes.
                    if let rest = try? stdoutPipe.fileHandleForReading.readToEnd(), let rest {
                        outputBuffer.append(rest)
                    }
                    if let rest = try? stderrPipe.fileHandleForReading.readToEnd(), let rest {
                        errorBuffer.append(rest)
                    }

                    if proc.terminationStatus == 0 {
                        let output = String(data: outputBuffer.getData(), encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    } else if timedOut.get() {
                        continuation.resume(throwing: RunError.timedOut)
                    } else {
                        let stderr = String(data: errorBuffer.getData(), encoding: .utf8) ?? "unknown error"
                        let summary = stderr
                            .components(separatedBy: .newlines)
                            .first { $0.contains("ERROR") } ?? String(stderr.prefix(200))
                        continuation.resume(throwing: RunError.failed(String(summary.prefix(200))))
                    }
                }

                do {
                    try process.run()
                } catch {
                    timeoutWork.cancel()
                    continuation.resume(throwing: RunError.failed(error.localizedDescription))
                }
            }
        } onCancel: {
            box.terminate()
        }
    }

    // MARK: - JSON helpers shared by providers

    /// Parses one `--dump-json` line into a dictionary.
    static func jsonObject(from line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    /// Best artwork URL from a yt-dlp info dict: prefers the last (largest)
    /// entry of `thumbnails`, falls back to `thumbnail`.
    static func artworkURL(from json: [String: Any]) -> URL? {
        if let thumbnails = json["thumbnails"] as? [[String: Any]] {
            for thumb in thumbnails.reversed() {
                if let urlString = thumb["url"] as? String, let url = URL(string: urlString) {
                    return url
                }
            }
        }
        if let thumbnail = json["thumbnail"] as? String {
            return URL(string: thumbnail)
        }
        return nil
    }

    /// Artist from a yt-dlp info dict with consistent fallbacks across extractors.
    static func artist(from json: [String: Any]) -> String {
        for key in ["artist", "uploader", "channel", "creator"] {
            if let value = json[key] as? String, !value.isEmpty {
                return value
            }
        }
        return "Unknown Artist"
    }

    // MARK: - Supporting types

    /// Holds the Process so the cancellation handler can reach it without
    /// capturing a non-Sendable type directly.
    private final class ProcessBox: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?

        func store(_ process: Process) {
            lock.lock()
            self.process = process
            lock.unlock()
        }

        func terminate() {
            lock.lock()
            let proc = process
            lock.unlock()
            if let proc, proc.isRunning {
                proc.terminate()
            }
        }
    }

    private final class DataBuffer: @unchecked Sendable {
        private var data = Data()
        private let lock = NSLock()

        func append(_ newData: Data) {
            lock.lock()
            data.append(newData)
            lock.unlock()
        }

        func getData() -> Data {
            lock.lock()
            defer { lock.unlock() }
            return data
        }
    }

    private final class Locked<T>: @unchecked Sendable {
        private var value: T
        private let lock = NSLock()

        init(_ value: T) { self.value = value }

        func set(_ newValue: T) {
            lock.lock()
            value = newValue
            lock.unlock()
        }

        func get() -> T {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }
}
