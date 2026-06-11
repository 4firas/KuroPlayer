import Foundation

class YouTubeMusicProvider: MusicProvider {
    var type: MusicProviderType { .youtubeMusic }
    var isAuthenticated: Bool { YouTubeMusicAuth.shared.isSignedIn }
    
    private let ytdlpPath = "/opt/homebrew/bin/yt-dlp"
    
    func authenticate() async throws {
        try await YouTubeMusicAuth.shared.authenticate()
    }
    
    func logout() async throws {
        YouTubeMusicAuth.shared.logout()
    }
    
    func search(query: String) async throws -> [Track] {
        guard FileManager.default.fileExists(atPath: ytdlpPath) else {
            throw ProviderError.networkError("yt-dlp not found at \(ytdlpPath)")
        }
        
        let sanitized = query.replacingOccurrences(of: "\"", with: "\\\"")
        let args = [
            "--flat-playlist",
            "--dump-json",
            "--no-playlist",
            "--extractor-args", "youtube:skip=webpage",
            "ytsearch20:\(sanitized)"
        ]
        
        let output = try await runYtDlp(args: args)
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        return lines.compactMap { parseSearchResult($0) }
    }
    
    func getTrack(id: String) async throws -> Track {
        // id is the YouTube video ID
        let args = ["--dump-json", "https://music.youtube.com/watch?v=\(id)"]
        let output = try await runYtDlp(args: args)
        
        guard let firstLine = output.components(separatedBy: .newlines).first(where: { !$0.isEmpty }),
              let track = parseSearchResult(firstLine) else {
            throw ProviderError.trackNotFound
        }
        
        return track
    }
    
    func getStreamURL(for track: Track) async throws -> URL {
        let args = [
            "-f", "bestaudio[ext=m4a]/bestaudio",
            "--get-url",
            "https://music.youtube.com/watch?v=\(track.providerTrackId)"
        ]
        
        let output = try await runYtDlp(args: args)
        let urlString = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: urlString) else {
            throw ProviderError.streamUnavailable
        }
        
        return url
    }
    
    func getLibrary() async throws -> [Track] {
        // Requires Google OAuth with YouTube scope
        guard isAuthenticated else {
            throw ProviderError.notAuthenticated
        }
        // TODO: fetch user's liked/uploaded music via YouTube API
        return []
    }
    
    func getPlaylists() async throws -> [Playlist] {
        guard isAuthenticated else {
            throw ProviderError.notAuthenticated
        }
        // TODO: fetch user's YouTube Music playlists
        return []
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
                
                // Read stdout asynchronously to avoid pipe buffer deadlock
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
                    // Clean up handlers to avoid leaks
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
              let title = json["title"] as? String else {
            return nil
        }
        
        let artist: String
        if let uploader = json["uploader"] as? String, !uploader.isEmpty {
            artist = uploader
        } else if let channel = json["channel"] as? String, !channel.isEmpty {
            artist = channel
        } else {
            artist = "Unknown Artist"
        }
        
        let album = json["album"] as? String ?? ""
        let duration = json["duration"] as? Double ?? 0
        
        var artworkURL: URL?
        if let thumbnails = json["thumbnails"] as? [[String: Any]],
           let lastThumb = thumbnails.last,
           let urlString = lastThumb["url"] as? String {
            artworkURL = URL(string: urlString)
        } else if let thumbnail = json["thumbnail"] as? String {
            artworkURL = URL(string: thumbnail)
        }
        
        return Track(
            id: "youtube-\(id)",
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkURL: artworkURL,
            streamURL: nil,
            providerType: .youtubeMusic,
            providerTrackId: id
        )
    }
}
