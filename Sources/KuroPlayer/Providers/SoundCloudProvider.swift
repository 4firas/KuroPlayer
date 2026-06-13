import Foundation

@MainActor class SoundCloudProvider: MusicProvider {
    var type: MusicProviderType { .soundcloud }
    var isAuthenticated: Bool { true }

    /// SoundCloud serves both progressive MP3 and HLS. Progressive starts
    /// faster in AVPlayer and is required for the parametric EQ tap, so
    /// prefer it explicitly — this also makes load times consistent with
    /// the YouTube Music provider.
    private let audioFormat = "bestaudio[protocol^=http]/bestaudio/best"
    
    // In-memory cache for ephemeral stream URLs (SoundCloud URLs expire quickly)
    private var streamCache: [String: (url: URL, expires: Date)] = [:]

    func authenticate() async throws {}
    func logout() async throws {}

    func search(query: String) async throws -> [Track] {
        let sanitized = query
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !sanitized.isEmpty else { return [] }

        let cacheKey = "scsearch_\(sanitized)"
        if let cached = Cache.shared.getObject(forKey: cacheKey, type: [Track].self) {
            return cached
        }

        let args = [
            "--flat-playlist",
            "--dump-json",
            "scsearch12:\(sanitized)"
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
        let args = ["--dump-json", "--no-playlist", id]
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

        let args = ["-f", audioFormat, "--no-playlist", "--get-url", track.providerTrackId]
        let output = try await YtDlp.run(args, timeout: 30)
        let urlString = output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else {
            throw ProviderError.streamUnavailable
        }

        // Cache for 3 minutes maximum to ensure we don't serve expired URLs
        streamCache[track.id] = (url: url, expires: Date().addingTimeInterval(180))
        return url
    }

    func getLibrary() async throws -> [Track] { [] }
    func getPlaylists() async throws -> [Playlist] { [] }
    func createPlaylist(name: String) async throws -> Playlist { throw ProviderError.networkError("Not supported") }
    func addTrackToPlaylist(playlist: Playlist, track: Track) async throws { throw ProviderError.networkError("Not supported") }
    func removeTrackFromPlaylist(playlist: Playlist, track: Track) async throws { throw ProviderError.networkError("Not supported") }
    func deletePlaylist(playlist: Playlist) async throws { throw ProviderError.networkError("Not supported") }

    // MARK: - Playlist import

    func canImportPlaylist(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("soundcloud.com") && url.path.contains("/sets/")
    }

    func importPlaylist(url: URL) async throws -> Playlist {
        // Full (non-flat) extraction is required: SoundCloud's flat playlist
        // entries are bare API references without titles, durations or
        // artwork. We use --sleep-requests to prevent HTTP 403 rate limits
        // when extracting large sets.
        let args = ["-J", "--sleep-requests", "1", url.absoluteString]
        let output = try await YtDlp.run(args, timeout: 300)

        guard let json = YtDlp.jsonObject(from: output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ProviderError.networkError("Failed to parse JSON. Output prefix: \(String(output.prefix(100)))")
        }
        guard let rawEntries = json["entries"] as? [Any] else {
            throw ProviderError.networkError("JSON had no 'entries'. Keys: \(json.keys.joined(separator: ", "))")
        }

        let entries = rawEntries.compactMap { $0 as? [String: Any] }
        let tracks = entries.compactMap { track(fromFullJSON: $0) }
        guard !tracks.isEmpty else {
            throw ProviderError.networkError("Tracks array is empty. rawEntries count: \(rawEntries.count)")
        }

        let name = (json["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "SoundCloud Set"
        let playlistId = (json["id"] as? String) ?? (json["id"] as? Int).map(String.init)

        return Playlist(
            id: "sc-playlist-\(playlistId ?? UUID().uuidString)",
            name: name,
            tracks: tracks,
            providerType: .soundcloud,
            providerPlaylistId: playlistId,
            // The set's own cover from SoundCloud, not the first track's.
            artworkURL: YtDlp.artworkURL(from: json) ?? tracks.first?.artworkURL,
            uploader: json["uploader"] as? String,
            sourceURL: url
        )
    }

    // MARK: - Parsing

    /// Flat search results: `url` is the track's permalink, which yt-dlp can
    /// resolve directly when streaming.
    private func track(fromJSONLine line: String) -> Track? {
        guard let json = YtDlp.jsonObject(from: line) else { return nil }

        guard let id = trackId(from: json),
              let title = json["title"] as? String,
              let urlString = json["url"] as? String else {
            return nil
        }

        return Track(
            id: "sc-\(id)",
            title: title,
            artist: YtDlp.artist(from: json),
            album: "",
            duration: json["duration"] as? Double ?? 0,
            artworkURL: YtDlp.artworkURL(from: json),
            streamURL: nil,
            providerType: .soundcloud,
            providerTrackId: urlString
        )
    }

    /// Fully-extracted entries (playlist import): `webpage_url` is the
    /// canonical permalink.
    private func track(fromFullJSON json: [String: Any]) -> Track? {
        guard let id = trackId(from: json),
              let title = json["title"] as? String else {
            return nil
        }

        guard let permalink = (json["webpage_url"] as? String) ?? (json["url"] as? String) else {
            return nil
        }

        return Track(
            id: "sc-\(id)",
            title: title,
            artist: YtDlp.artist(from: json),
            album: "",
            duration: json["duration"] as? Double ?? 0,
            artworkURL: YtDlp.artworkURL(from: json),
            streamURL: nil,
            providerType: .soundcloud,
            providerTrackId: permalink
        )
    }

    /// SoundCloud IDs come back as strings or numbers depending on the code path.
    private func trackId(from json: [String: Any]) -> String? {
        if let id = json["id"] as? String { return id }
        if let id = json["id"] as? Int { return String(id) }
        return nil
    }
}
