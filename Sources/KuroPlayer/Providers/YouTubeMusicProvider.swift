import Foundation

@MainActor class YouTubeMusicProvider: MusicProvider {
    var type: MusicProviderType { .youtubeMusic }
    var isAuthenticated: Bool { YouTubeMusicAuth.shared.isSignedIn }

    /// Progressive HTTP audio preferred: starts faster than DASH/HLS and is
    /// required for the parametric EQ tap to attach.
    private let audioFormat = "bestaudio[ext=m4a][protocol^=http]/bestaudio[protocol^=http]/bestaudio/best"
    
    // In-memory cache for stream URLs
    private var streamCache: [String: (url: URL, expires: Date)] = [:]

    func authenticate() async throws {
        try await YouTubeMusicAuth.shared.authenticate()
    }

    func logout() async throws {
        YouTubeMusicAuth.shared.logout()
    }

    func search(query: String) async throws -> [Track] {
        let sanitized = query
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !sanitized.isEmpty else { return [] }

        let cacheKey = "ytsearch_\(sanitized)"
        if let cached = Cache.shared.getObject(forKey: cacheKey, type: [Track].self) {
            return cached
        }

        let args = [
            "--flat-playlist",
            "--dump-json",
            "ytsearch12:\(sanitized)"
        ]

        let output = try await YtDlp.run(args, timeout: 25)
        let tracks = output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { track(fromJSONLine: $0) }

        Cache.shared.setObject(tracks, forKey: cacheKey, ttl: 1800)
        return tracks
    }

    func getTrack(id: String) async throws -> Track {
        // id is the YouTube video ID
        let args = ["--dump-json", "--no-playlist", "https://music.youtube.com/watch?v=\(id)"]
        let output = try await YtDlp.run(args, timeout: 30)

        guard let firstLine = output.components(separatedBy: .newlines).first(where: { !$0.isEmpty }),
              let track = track(fromJSONLine: firstLine) else {
            throw ProviderError.trackNotFound
        }

        return track
    }

    func getStreamURL(for track: Track) async throws -> URL {
        if let cached = streamCache[track.id], cached.expires > Date() {
            return cached.url
        }

        let args = [
            "-f", audioFormat,
            "--no-playlist",
            "--get-url",
            "https://music.youtube.com/watch?v=\(track.providerTrackId)"
        ]

        let output = try await YtDlp.run(args, timeout: 30)
        let urlString = output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else {
            throw ProviderError.streamUnavailable
        }

        // YouTube URLs last ~6h, caching in-memory for 20 minutes is safe
        streamCache[track.id] = (url: url, expires: Date().addingTimeInterval(1200))
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

    func createPlaylist(name: String) async throws -> Playlist {
        throw ProviderError.networkError("YouTube API integration for playlists not fully implemented")
    }

    func addTrackToPlaylist(playlist: Playlist, track: Track) async throws {
        throw ProviderError.networkError("YouTube API integration for playlists not fully implemented")
    }

    func removeTrackFromPlaylist(playlist: Playlist, track: Track) async throws {
        throw ProviderError.networkError("YouTube API integration for playlists not fully implemented")
    }

    func deletePlaylist(playlist: Playlist) async throws {
        throw ProviderError.networkError("YouTube API integration for playlists not fully implemented")
    }

    // MARK: - Playlist import

    func canImportPlaylist(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isYouTubeHost = host.contains("youtube.com") || host == "youtu.be"
        guard isYouTubeHost else { return false }
        if url.path.contains("/playlist") { return true }
        let query = url.query ?? ""
        return query.contains("list=")
    }

    func importPlaylist(url: URL) async throws -> Playlist {
        // Flat extraction is fast and YouTube's flat entries carry full
        // metadata (title, duration, uploader, thumbnails) — one HTTP round
        // trip for the whole playlist.
        let args = ["-J", "--flat-playlist", url.absoluteString]
        let output = try await YtDlp.run(args, timeout: 90)

        guard let json = YtDlp.jsonObject(from: output.trimmingCharacters(in: .whitespacesAndNewlines)),
              let entries = json["entries"] as? [[String: Any]] else {
            throw ProviderError.playlistNotFound
        }

        let tracks = entries.compactMap { track(fromJSON: $0) }
        guard !tracks.isEmpty else {
            throw ProviderError.playlistNotFound
        }

        let name = (json["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "YouTube Playlist"
        let playlistId = json["id"] as? String

        return Playlist(
            id: "youtube-playlist-\(playlistId ?? UUID().uuidString)",
            name: name,
            tracks: tracks,
            providerType: .youtubeMusic,
            providerPlaylistId: playlistId,
            artworkURL: YtDlp.artworkURL(from: json) ?? tracks.first?.artworkURL,
            uploader: (json["uploader"] as? String) ?? (json["channel"] as? String),
            sourceURL: url
        )
    }

    // MARK: - Parsing

    private func track(fromJSONLine line: String) -> Track? {
        guard let json = YtDlp.jsonObject(from: line) else { return nil }
        return track(fromJSON: json)
    }

    private func track(fromJSON json: [String: Any]) -> Track? {
        guard let id = json["id"] as? String,
              let title = json["title"] as? String else {
            return nil
        }

        return Track(
            id: "youtube-\(id)",
            title: title,
            artist: YtDlp.artist(from: json),
            album: json["album"] as? String ?? "",
            duration: json["duration"] as? Double ?? 0,
            artworkURL: YtDlp.artworkURL(from: json),
            streamURL: nil,
            providerType: .youtubeMusic,
            providerTrackId: id
        )
    }
}
