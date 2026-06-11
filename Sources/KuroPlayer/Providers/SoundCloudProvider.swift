import Foundation

class SoundCloudProvider: MusicProvider {
    var type: MusicProviderType { .soundcloud }
    // We scrape with yt-dlp, so no auth required
    var isAuthenticated: Bool { true }
    
    private let ytdlpPath = "/opt/homebrew/bin/yt-dlp"
    
    func authenticate() async throws {
        // No-op for scraping provider
    }
    
    func logout() async throws {
        // No-op for scraping provider
    }
    
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
        let args = [
            "-f", "bestaudio/best",
            "--get-url",
            track.providerTrackId
        ]
        
        let output = try await runYtDlp(args: args)
        let urlString = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: urlString) else {
            throw ProviderError.streamUnavailable
        }
        
        return url
    }
    
    func getLibrary() async throws -> [Track] {
        return []
    }
    
    func getPlaylists() async throws -> [Playlist] {
        return []
    }

    func createPlaylist(name: String) async throws -> Playlist {
        throw ProviderError.networkError("Playlists not supported by anonymous SoundCloud provider")
    }

    func addTrackToPlaylist(playlist: Playlist, track: Track) async throws {
        throw ProviderError.networkError("Playlists not supported by anonymous SoundCloud provider")
    }

    func removeTrackFromPlaylist(playlist: Playlist, track: Track) async throws {
        throw ProviderError.networkError("Playlists not supported by anonymous SoundCloud provider")
    }

    func deletePlaylist(playlist: Playlist) async throws {
        throw ProviderError.networkError("Playlists not supported by anonymous SoundCloud provider")
    }

    // MARK: - YT-DLP execution

    private func runYtDlp(args: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: self.ytdlpPath)
                process.arguments = args

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                var outputData = Data()
                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        outputData.append(data)
                    }
                }

                var errorData = Data()
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        errorData.append(data)
                    }
                }

                process.terminationHandler = { proc in
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    if proc.terminationStatus == 0 {
                        let output = String(data: outputData, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    } else {
                        let err = String(data: errorData, encoding: .utf8) ?? "unknown error"
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
            providerTrackId: urlString // we use the full url for yt-dlp for soundcloud
        )
    }
}
