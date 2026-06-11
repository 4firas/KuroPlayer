import Foundation

@MainActor class SoundCloudProvider: MusicProvider {
    var type: MusicProviderType { .soundcloud }
    var isAuthenticated: Bool { true }
    
    private let ytdlpPath = "/opt/homebrew/bin/yt-dlp"
    
    func authenticate() async throws {}
    func logout() async throws {}
    
    func search(query: String) async throws -> [Track] {
        let cacheKey = "scsearch_\(query)"
        if let cached = Cache.shared.getObject(forKey: cacheKey, type: [Track].self) {
            return cached
        }
        
        guard FileManager.default.fileExists(atPath: ytdlpPath) else {
            throw ProviderError.networkError("yt-dlp not found at \(ytdlpPath)")
        }
        
        let sanitized = query.replacingOccurrences(of: "\"", with: "\\\"")
        let args = [
            "--flat-playlist",
            "--dump-json",
            "--no-playlist",
            "scsearch20:\(sanitized)"
        ]
        
        let output = try await runYtDlp(args: args)
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let tracks = lines.compactMap { parseSearchResult($0) }
        Cache.shared.setObject(tracks, forKey: cacheKey, ttl: 1800)
        return tracks
    }
    
    func getTrack(id: String) async throws -> Track {
        let args = ["--dump-json", id]
        let output = try await runYtDlp(args: args)
        
        guard let firstLine = output.components(separatedBy: .newlines).first(where: { !$0.isEmpty }),
              let track = parseSearchResult(firstLine) else {
            throw ProviderError.trackNotFound
        }
        return track
    }
    
    func getStreamURL(for track: Track) async throws -> URL {
        let args = ["-f", "bestaudio/best", "--get-url", track.providerTrackId]
        let output = try await runYtDlp(args: args)
        let urlString = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: urlString) else {
            throw ProviderError.streamUnavailable
        }
        return url
    }
    
    func getLibrary() async throws -> [Track] { [] }
    func getPlaylists() async throws -> [Playlist] { [] }
    func createPlaylist(name: String) async throws -> Playlist { throw ProviderError.networkError("Not supported") }
    func addTrackToPlaylist(playlist: Playlist, track: Track) async throws { throw ProviderError.networkError("Not supported") }
    func removeTrackFromPlaylist(playlist: Playlist, track: Track) async throws { throw ProviderError.networkError("Not supported") }
    func deletePlaylist(playlist: Playlist) async throws { throw ProviderError.networkError("Not supported") }

    // MARK: - Thread-safe data buffer
    
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
    
    // MARK: - YT-DLP execution

    private func runYtDlp(args: [String]) async throws -> String {
        let ytdlp = self.ytdlpPath
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: ytdlp)
                process.arguments = args

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let outputBuffer = DataBuffer()
                let errorBuffer = DataBuffer()

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        outputBuffer.append(data)
                    }
                }

                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        errorBuffer.append(data)
                    }
                }

                process.terminationHandler = { proc in
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    if proc.terminationStatus == 0 {
                        let output = String(data: outputBuffer.getData(), encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    } else {
                        let err = String(data: errorBuffer.getData(), encoding: .utf8) ?? "unknown error"
                        continuation.resume(throwing: ProviderError.networkError("yt-dlp failed: \(err.prefix(200))"))
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: ProviderError.networkError("Failed to run yt-dlp: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func parseSearchResult(_ jsonString: String) -> Track? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        guard let id = json["id"] as? String,
              let title = json["title"] as? String,
              let urlString = json["url"] as? String else {
            return nil
        }
        
        let artist = json["uploader"] as? String ?? "Unknown Artist"
        let duration = json["duration"] as? Double ?? 0
        
        var artworkURL: URL?
        if let thumbnail = json["thumbnail"] as? String {
            artworkURL = URL(string: thumbnail)
        }
        
        return Track(
            id: "sc-\(id)",
            title: title,
            artist: artist,
            album: "",
            duration: duration,
            artworkURL: artworkURL,
            streamURL: nil,
            providerType: .soundcloud,
            providerTrackId: urlString
        )
    }
}
